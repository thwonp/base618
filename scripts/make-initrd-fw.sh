#!/bin/sh
# SPDX-License-Identifier: MIT
# The firmware-only initrd, built with cpio - for the device itself (no kernel
# build tree there), e.g. a first-boot service after extract-firmware.sh.
# make-boot-files.sh builds the same tree reproducibly on a build host.
#
#   make-initrd-fw.sh FWDIR OUT    (e.g. make-initrd-fw.sh / /boot/initrd-fw.cpio.gz)
#
# FWDIR holds lib/firmware/updates/agdsp.bin and lib/firmware/sprd/pm_{bootcode,sys}.bin.
# The built-in audio DSP and pm_sys drivers load them before root is mounted.
# FWDIR/lib/firmware/boot-logo.ppm, if there, goes in too: the second boot
# logo (make-logo.sh, docs/boot-logo.md).
# Written next to OUT and moved over it, so a failed run leaves the old one.
set -eu
FW=${1:?usage: make-initrd-fw.sh FWDIR OUT}
OUT=${2:?usage: make-initrd-fw.sh FWDIR OUT}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/dev" "$T/lib/firmware/updates" "$T/lib/firmware/sprd"
mknod -m 600 "$T/dev/console" c 5 1
for f in updates/agdsp.bin sprd/pm_bootcode.bin sprd/pm_sys.bin; do
	cp "$FW/lib/firmware/$f" "$T/lib/firmware/$f"
done
L=$FW/lib/firmware/boot-logo.ppm
[ -f "$L" ] && cp "$L" "$T/lib/firmware/"
chmod 644 "$T"/lib/firmware/*/*.bin "$T"/lib/firmware/*.ppm 2>/dev/null || true
( cd "$T" && find . -mindepth 1 | sort | cpio -o -H newc -R 0:0 --quiet ) | gzip -9 -n > "$OUT.new"
mv -f "$OUT.new" "$OUT"
md5sum "$OUT"
