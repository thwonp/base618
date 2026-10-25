#!/bin/sh
# SPDX-License-Identifier: MIT
# The fast-boot files, from a kernel build and a firmware directory. Writes
# OUT only, never a device; the same inputs give the same bytes (fixed
# timestamps), so a release can be checked against them.
#
#   make-boot-files.sh KBUILD FWDIR [OUT]   (default OUT: boot)
#   MKIMAGE (default: mkimage on PATH), NAME (uImage name, default "Linux <release>")
#
#   Image.uimg         gzip uImage, loads and runs at 0x80080000. Needs a U-Boot
#                      with kernel_addr_r 0x9a200000 and a 64 MiB gunzip limit
#                      (thwonp/u-boot-ums512 plorpos); the stock limit is too small.
#   initrd-fw.cpio.gz  no /init: dev/console and the firmware the built-in
#                      drivers ask for before root is mounted, after which the
#                      kernel mounts root= itself:
#                        lib/firmware/updates/agdsp.bin     audio DSP, ~0.16 s
#                        lib/firmware/sprd/pm_bootcode.bin  CM4 boot stub
#                        lib/firmware/sprd/pm_sys.bin       CM4 firmware, ~0.38 s;
#                                                           deep sleep needs it
#
# FWDIR holds those three under lib/firmware/ (extract-firmware.sh DEST, plus
# build-pm-bootcode.sh's output); lib/firmware/boot-logo.ppm goes in too when it
# is there (make-logo.sh). FWDIR "-" makes Image.uimg only: the initrd
# holds the unit's own firmware and never goes in a release. KBUILD is the kernel's O= build directory
# (arch/arm64/boot/Image, usr/gen_init_cpio). Install: both into /boot, and
# name them in extlinux.conf (kernel /Image.uimg, initrd /initrd-fw.cpio.gz).
set -eu
KBUILD=$(cd "${1:?usage: make-boot-files.sh KBUILD FWDIR [OUT]}" && pwd)
FW=${2:?usage: make-boot-files.sh KBUILD FWDIR [OUT]}
[ "$FW" = - ] || FW=$(cd "$FW" && pwd)
OUT=${3:-boot}
MKIMAGE=${MKIMAGE:-mkimage}
IMG=$KBUILD/arch/arm64/boot/Image
NEED="$IMG"
[ "$FW" = - ] || NEED="$NEED $KBUILD/usr/gen_init_cpio $FW/lib/firmware/updates/agdsp.bin
	$FW/lib/firmware/sprd/pm_bootcode.bin $FW/lib/firmware/sprd/pm_sys.bin"
for f in $NEED; do
	[ -e "$f" ] || { echo "missing $f" >&2; exit 1; }
done
command -v "$MKIMAGE" > /dev/null || { echo "no mkimage ($MKIMAGE)" >&2; exit 1; }
NAME=${NAME:-Linux $(cat "$KBUILD/include/config/kernel.release")}
# The kernel image's own time, for both: rebuilding from the same build is byte-identical.
EPOCH=$(stat -c %Y "$IMG")
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$OUT"

gzip -9 -n -c "$IMG" > "$T/Image.gz"
"$MKIMAGE" -A arm64 -O linux -T kernel -C gzip -a 0x80080000 -e 0x80080000 \
	-n "$NAME" -d "$T/Image.gz" "$OUT/Image.uimg" > /dev/null
# mkimage stamps the header with now unless SOURCE_DATE_EPOCH is honoured: put
# the image's time in (ih_time, bytes 8-11) and redo the header CRC (bytes 4-7).
python3 - "$OUT/Image.uimg" "$EPOCH" <<'PY'
import struct, sys, zlib
p, t = sys.argv[1], int(sys.argv[2])
with open(p, 'r+b') as f:
    h = bytearray(f.read(64))
    h[4:8] = b'\0' * 4; h[8:12] = struct.pack('>I', t)
    h[4:8] = struct.pack('>I', zlib.crc32(h) & 0xffffffff)
    f.seek(0); f.write(h)
PY

[ "$FW" = - ] && { ( cd "$OUT" && md5sum Image.uimg ); exit 0; }

cat > "$T/list" <<LIST
dir /dev 0755 0 0
nod /dev/console 0600 0 0 c 5 1
dir /lib 0755 0 0
dir /lib/firmware 0755 0 0
dir /lib/firmware/updates 0755 0 0
file /lib/firmware/updates/agdsp.bin $FW/lib/firmware/updates/agdsp.bin 0644 0 0
dir /lib/firmware/sprd 0755 0 0
file /lib/firmware/sprd/pm_bootcode.bin $FW/lib/firmware/sprd/pm_bootcode.bin 0644 0 0
file /lib/firmware/sprd/pm_sys.bin $FW/lib/firmware/sprd/pm_sys.bin 0644 0 0
LIST
[ -f "$FW/lib/firmware/boot-logo.ppm" ] &&
	echo "file /lib/firmware/boot-logo.ppm $FW/lib/firmware/boot-logo.ppm 0644 0 0" >> "$T/list"
"$KBUILD/usr/gen_init_cpio" -t "$EPOCH" "$T/list" | gzip -9 -n > "$OUT/initrd-fw.cpio.gz"

( cd "$OUT" && md5sum Image.uimg initrd-fw.cpio.gz )
