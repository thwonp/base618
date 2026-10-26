#!/bin/sh
# SPDX-License-Identifier: MIT
# A bootable base618 card image from Armbian's own RG Rotate image, without
# root: the boot partition is edited with mtools, the rootfs with debugfs, and
# nothing of Armbian's is repacked or rebuilt.
#
#   scripts/make-card.sh FILES_DIR OUT
#
#   FILES_DIR    the release's base618-v<version>-files.zip, unzipped: base618's files
#                (uboot_dhtb.img, Image.uimg, ums512-rg-rotate.dtb, modules-updates-*.tar.gz,
#                pm_bootcode.bin), Armbian's image and SHA256SUMS, which they are checked against.
#   ARMBIAN_IMG  another Armbian image in place of the one in FILES_DIR,
#                Armbian_community_26.11.0-trunk.95_Anbernic-rg-rotate_trixie_edge_7.2.9_minimal.img(.xz),
#                the one base618 was tested on. Another one is refused (its kernel modules may
#                not match ours); FORCE=1 takes it anyway, with a warning.
#   ROOT_PASSWORD  the card's root password (default base618). Armbian's first-login
#                wizard is turned off; ssh stays as Armbian ships it.
#
# What changes on Armbian's image:
#   p1 uboot   base618's U-Boot (uboot_dhtb.img, checked with check-dhtb.py)
#   p2 bootfs  + Image.uimg, dtb/base618/ums512-rg-rotate.dtb, initrd-fw.cpio.gz (a stub:
#              dev/console + pm_bootcode), extlinux.conf: a base618 label first, booting
#              root=PARTUUID= of p3 (no /init, see docs/install.md), Armbian's label kept
#              second, untouched with its own kernel, DTB and initramfs
#   p3 rootfs  + the 4 updated modules (updates/), pm_bootcode.bin, the first-boot service
#              (base618-firstboot.sh: the unit's own firmware off its eMMC, the real initrd,
#              depmod, power off - once); - armbian-firmware's wcnmodem.bin -> uwe5622/
#              symlink (the WCN driver loads it before the real one lands and oopses);
#              root's password; no first-login wizard
#
# Needs: sfdisk, mtools, debugfs + e2fsck (e2fsprogs >= 1.46), python3, openssl, xz,
# sha256sum. Space: about twice the image (2.2 GB).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
RES=$HERE/../res
ASSETS=${1:?usage: make-card.sh FILES_DIR OUT}
OUT=${2:?usage: make-card.sh FILES_DIR OUT}
ROOT_PASSWORD=${ROOT_PASSWORD:-base618}
KREL=7.2.9-edge-sprd-ums512
IN=${ARMBIAN_IMG:-$ASSETS/Armbian_community_26.11.0-trunk.95_Anbernic-rg-rotate_trixie_edge_7.2.9_minimal.img.xz}
# trunk.95 as Armbian published it, compressed and not.
SHA_XZ=94471b9625c146e6f02de6c550d1b763dc660686572a7754b57363c2e4148ac5
SHA_RAW=e8679eec6e469c12ab8df46a0d4ba8d5c387d62cd56daa1eb3bd62b8db933402

say() { echo "make-card: $*"; }
die() { echo "make-card: $*" >&2; exit 1; }
for t in sfdisk mcopy mtype mdel mmd debugfs e2fsck python3 openssl xz sha256sum; do
	command -v "$t" > /dev/null || die "need $t"
done
T=$(mktemp -d "${TMPDIR:-/var/tmp}/make-card.XXXXXX")
trap 'rm -rf "$T"' EXIT

# 1. Armbian's image, as published.
[ -f "$IN" ] || die "no $IN"
case $IN in
*.xz) WANT=$SHA_XZ ;;
*)    WANT=$SHA_RAW ;;
esac
GOT=$(sha256sum "$IN" | cut -d' ' -f1)
if [ "$GOT" != "$WANT" ]; then
	[ -n "${FORCE:-}" ] || die "$IN is not the tested Armbian image (sha256 $GOT); FORCE=1 to use it anyway"
	say "WARNING: not the tested Armbian image - its kernel modules may not load with base618's kernel"
fi
# 2. The base618 parts.
( cd "$ASSETS" && sha256sum -c --ignore-missing --quiet SHA256SUMS ) || die "$ASSETS does not match its SHA256SUMS"
for f in uboot_dhtb.img Image.uimg ums512-rg-rotate.dtb modules-updates-$KREL.tar.gz pm_bootcode.bin \
         base618-screen base618-power; do
	[ -s "$ASSETS/$f" ] || die "no $ASSETS/$f"
done
python3 "$HERE/check-dhtb.py" "$ASSETS/uboot_dhtb.img" > /dev/null || die "uboot_dhtb.img fails its DHTB check"

say "copying Armbian's image to $OUT"
case $IN in
*.xz) xz -dc "$IN" > "$OUT" ;;
*)    cp "$IN" "$OUT" ;;
esac

part() { # N field -> value (start in sectors, size, uuid)
	sfdisk -J "$OUT" | python3 -c "import json,sys;p=json.load(sys.stdin)['partitiontable']['partitions'][$1-1];print(p['$2'])"
}
P1=$(part 1 start); P2=$(part 2 start); P3=$(part 3 start); P3N=$(part 3 size)
P3UUID=$(part 3 uuid | tr 'A-F' 'a-f')
[ "$(part 1 size)" -ge 32768 ] || die "p1 is smaller than 16 MiB: not Armbian's RG Rotate layout"

# 3. p1: U-Boot.
say "p1: base618 U-Boot"
dd if="$ASSETS/uboot_dhtb.img" of="$OUT" bs=512 seek="$P1" conv=notrunc status=none

# 4. p2: kernel, DTB, initrd stub, extlinux.conf.
say "p2: kernel, DTB, initrd stub, extlinux (root=PARTUUID=$P3UUID)"
B="$OUT@@$((P2 * 512))"
python3 - "$ASSETS/pm_bootcode.bin" "$T/initrd-fw.cpio" "$RES/boot-logo.ppm" << 'PY'
# newc by hand: a /dev/console node needs root to make on disk, not in an archive.
import sys
code = open(sys.argv[1], 'rb').read()
logo = open(sys.argv[3], 'rb').read()
ents = [('dev', 0o040755, b''), ('dev/console', 0o020600, b''), ('lib', 0o040755, b''),
        ('lib/firmware', 0o040755, b''), ('lib/firmware/boot-logo.ppm', 0o100644, logo),
        ('lib/firmware/sprd', 0o040755, b''),
        ('lib/firmware/sprd/pm_bootcode.bin', 0o100644, code), ('TRAILER!!!', 0, b'')]
out = bytearray()
for ino, (name, mode, data) in enumerate(ents, 1):
    rmaj, rmin = (5, 1) if name == 'dev/console' else (0, 0)
    n = name.encode() + b'\0'
    hdr = '070701' + ''.join('%08X' % v for v in (
        ino, mode, 0, 0, 1, 0, len(data), 0, 0, rmaj, rmin, len(n), 0))
    out += hdr.encode() + n
    out += b'\0' * (-len(out) % 4) + data
    out += b'\0' * (-len(out) % 4)
out += b'\0' * (-len(out) % 512)
open(sys.argv[2], 'wb').write(out)
PY
gzip -9 -n "$T/initrd-fw.cpio"
mtype -i "$B" ::/extlinux/extlinux.conf > "$T/extlinux.armbian" || die "no extlinux.conf on p2"
grep -q '^label base618' "$T/extlinux.armbian" && die "$IN already has a base618 label"
{
	echo "default base618"
	echo "label base618"
	echo "  kernel /Image.uimg"
	echo "  initrd /initrd-fw.cpio.gz"
	echo "  fdt /dtb/base618/ums512-rg-rotate.dtb"
	echo "  append root=PARTUUID=$P3UUID rootwait ro console=tty0 quiet loglevel=1 systemd.show_status=false vt.global_cursor_default=0 fbcon=logo-pos:center,logo-count:1,rotate:\${plorpos_fbrot} log_buf_len=8M no_console_suspend consoleblank=0 net.ifnames=0"
	echo
	cat "$T/extlinux.armbian"
} > "$T/extlinux.conf"
mmd -i "$B" ::/dtb/base618 2> /dev/null || true
mcopy -o -i "$B" "$ASSETS/Image.uimg" ::/Image.uimg
mcopy -o -i "$B" "$ASSETS/ums512-rg-rotate.dtb" ::/dtb/base618/ums512-rg-rotate.dtb
mcopy -o -i "$B" "$T/initrd-fw.cpio.gz" ::/initrd-fw.cpio.gz
mcopy -o -i "$B" "$T/extlinux.conf" ::/extlinux/extlinux.conf

# 5. p3: the rootfs, edited in place with debugfs on a copy, then written back.
say "p3: modules, first-boot service, screen + power key, root password"
R=$T/p3.img
dd if="$OUT" of="$R" bs=512 skip="$P3" count="$P3N" status=none
mkdir "$T/mod" && tar -C "$T/mod" -xzf "$ASSETS/modules-updates-$KREL.tar.gz"
debugfs -R "cat /etc/shadow" "$R" 2> /dev/null > "$T/shadow"
grep -q '^root:' "$T/shadow" || die "no root in the image's /etc/shadow"
HASH=$(openssl passwd -6 "$ROOT_PASSWORD")
awk -F: -v OFS=: -v h="$HASH" '$1 == "root" { $2 = h } { print }' "$T/shadow" > "$T/shadow.new"
SHADOW_GID=$(debugfs -R "stat /etc/shadow" "$R" 2> /dev/null | sed -n 's/.*Group: *\([0-9]*\).*/\1/p')
{
	echo "rm /usr/lib/firmware/wcnmodem.bin"
	echo "rm /root/.not_logged_in_yet"
	echo "cd /etc"; echo "rm shadow"; echo "write $T/shadow.new shadow"
	echo "sif shadow mode 0100640"; echo "sif shadow uid 0"; echo "sif shadow gid $SHADOW_GID"
	echo "mkdir /usr/lib/modules/$KREL/updates"; echo "cd /usr/lib/modules/$KREL/updates"
	for k in "$T"/mod/*.ko; do
		n=$(basename "$k"); echo "write $k $n"; echo "sif $n mode 0100644"; echo "sif $n uid 0"; echo "sif $n gid 0"
	done
	echo "mkdir /usr/lib/firmware/sprd"; echo "cd /usr/lib/firmware/sprd"
	echo "write $ASSETS/pm_bootcode.bin pm_bootcode.bin"
	echo "sif pm_bootcode.bin mode 0100644"; echo "sif pm_bootcode.bin uid 0"; echo "sif pm_bootcode.bin gid 0"
	echo "mkdir /usr/share/base618"; echo "cd /usr/share/base618"
	for s in firstboot:base618-firstboot.sh extract-firmware:extract-firmware.sh make-initrd-fw:make-initrd-fw.sh; do
		n=${s%%:*}.sh; echo "write $HERE/${s#*:} $n"; echo "sif $n mode 0100755"; echo "sif $n uid 0"; echo "sif $n gid 0"
	done
	echo "cd /etc/systemd/system"
	echo "write $HERE/base618-firstboot.service base618-firstboot.service"
	echo "sif base618-firstboot.service mode 0100644"; echo "sif base618-firstboot.service uid 0"
	echo "sif base618-firstboot.service gid 0"
	echo "cd /usr/lib/firmware"; echo "write $RES/boot-logo.ppm boot-logo.ppm"
	echo "sif boot-logo.ppm mode 0100644"; echo "sif boot-logo.ppm uid 0"; echo "sif boot-logo.ppm gid 0"
	echo "cd /usr/share/base618"; echo "write $RES/screen.pgm screen.pgm"
	echo "sif screen.pgm mode 0100644"; echo "sif screen.pgm uid 0"; echo "sif screen.pgm gid 0"
	echo "cd /usr/local/bin"
	for n in base618-screen base618-power; do
		echo "write $ASSETS/$n $n"; echo "sif $n mode 0100755"; echo "sif $n uid 0"; echo "sif $n gid 0"
	done
	echo "cd /etc/systemd/system"
	for n in base618-screen.service base618-power.service; do
		echo "write $HERE/$n $n"; echo "sif $n mode 0100644"; echo "sif $n uid 0"; echo "sif $n gid 0"
	done
	# The panel shows base618-screen, not a text login; Armbian's USB serial login stays.
	echo "rm getty.target.wants/getty@tty1.service"
	echo "symlink getty@tty1.service /dev/null"
	echo "mkdir /etc/systemd/logind.conf.d"; echo "cd /etc/systemd/logind.conf.d"
	echo "write $HERE/base618-power-logind.conf base618-power.conf"
	echo "sif base618-power.conf mode 0100644"; echo "sif base618-power.conf uid 0"; echo "sif base618-power.conf gid 0"
	echo "cd /etc/systemd/system/multi-user.target.wants"
	for n in base618-firstboot base618-screen base618-power; do
		echo "symlink $n.service /etc/systemd/system/$n.service"
	done
} > "$T/debugfs.cmds"
debugfs -w -f "$T/debugfs.cmds" "$R" > "$T/debugfs.log" 2>&1
# It echoes each command ("debugfs: ...") and an inode per write; anything else is an error.
if grep -v -E '^debugfs[ :]|^Allocated inode|^$' "$T/debugfs.log" | grep -q .; then
	cat "$T/debugfs.log" >&2; die "debugfs reported a problem"
fi
e2fsck -fn "$R" > "$T/fsck.log" 2>&1 || { cat "$T/fsck.log" >&2; die "the edited rootfs fails e2fsck"; }
dd if="$R" of="$OUT" bs=512 seek="$P3" conv=notrunc status=none

# 6. Check what was written, from the image itself.
say "checking"
dd if="$OUT" of="$T/p1" bs=512 skip="$P1" count=32768 status=none
python3 "$HERE/check-dhtb.py" "$T/p1" > /dev/null || die "p1 fails its DHTB check"
mtype -i "$B" ::/extlinux/extlinux.conf | grep -q "root=PARTUUID=$P3UUID " || die "extlinux does not boot p3's PARTUUID"
for f in Image.uimg initrd-fw.cpio.gz dtb/base618/ums512-rg-rotate.dtb; do
	mdir -i "$B" "::/$f" > /dev/null 2>&1 || die "p2 has no /$f"
done
dd if="$OUT" of="$R" bs=512 skip="$P3" count="$P3N" status=none
for f in /usr/share/base618/firstboot.sh /usr/share/base618/extract-firmware.sh \
         /usr/share/base618/make-initrd-fw.sh /usr/lib/firmware/sprd/pm_bootcode.bin \
         /etc/systemd/system/multi-user.target.wants/base618-firstboot.service \
         /etc/systemd/system/multi-user.target.wants/base618-screen.service \
         /etc/systemd/system/multi-user.target.wants/base618-power.service \
         /etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service \
         /etc/systemd/logind.conf.d/base618-power.conf /usr/local/bin/base618-power \
         /usr/local/bin/base618-screen /usr/share/base618/screen.pgm /usr/lib/firmware/boot-logo.ppm \
         /usr/lib/modules/$KREL/updates/btsprdsdio.ko; do
	debugfs -R "stat $f" "$R" 2>&1 | grep -q '^Inode:' || die "p3 has no $f"
done
for f in /usr/lib/firmware/wcnmodem.bin /root/.not_logged_in_yet; do
	debugfs -R "stat $f" "$R" 2>&1 | grep -q '^Inode:' && die "p3 still has $f"
done
sha256sum "$OUT" > "$OUT.sha256"
say "$OUT ($(du -h "$OUT" | cut -f1)), sha256 $(cut -c1-16 "$OUT.sha256")"
say "write it to a card (all of it is replaced), boot: the first boot sets up this unit's firmware and powers off"
