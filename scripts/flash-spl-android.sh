#!/system/bin/sh
# SPDX-License-Identifier: MIT
# base618's SPL into the eMMC splloader slot (boot0), run as root on the unit itself while
# it runs GammaOS (or any rooted Android). Only adb is needed on the PC, any OS:
#
#   adb root
#   adb push spl-cm4.img flash-spl-android.sh /data/local/tmp/
#   adb shell sh /data/local/tmp/flash-spl-android.sh
#   adb pull /sdcard/base618-spl-backup
#
# Keeps both slots' old contents in /sdcard/base618-spl-backup/ (pull them to the PC) and
# checks a readback. splloader_bak (boot1) is left as it is: if boot0 ever fails its check
# the BootROM falls back to it and the unit boots as it did before. With no base618 card
# in, base618's SPL boots the eMMC's Android as before.
set -eu
SPL=${1:-/data/local/tmp/spl-cm4.img}
BAK=/sdcard/base618-spl-backup
say() { echo "flash-spl: $*"; }
die() { echo "flash-spl: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || die "not root: run 'adb root' first (or su -c sh $0)"
tr '\0' ' ' < /proc/device-tree/compatible | grep -q ums512 ||
	die "not a ums512 (T618) unit: $(tr '\0' ' ' < /proc/device-tree/compatible)"
[ -f "$SPL" ] || die "no $SPL (adb push spl-cm4.img /data/local/tmp/)"
[ "$(stat -c %s "$SPL")" = 4194304 ] || die "$SPL is not a 4 MiB SPL image"
[ "$(dd if="$SPL" bs=4 count=1 2> /dev/null)" = DHTB ] || die "$SPL is not a DHTB image"

# The eMMC: the one mmcblk with boot partitions (an SD card has none).
set -- /dev/block/mmcblk*boot0
[ $# = 1 ] && [ -b "$1" ] || die "expected one eMMC boot0, found: $*"
B0=$1 B1=${1%0}1
DEV=${B0##*/}

# A rerun keeps the first backup: that one holds the SPL the unit came with.
if [ ! -s "$BAK/splloader.bin" ]; then
	mkdir -p "$BAK"
	dd if="$B0" of="$BAK/splloader.bin" bs=1M 2> /dev/null
	dd if="$B1" of="$BAK/splloader_bak.bin" bs=1M 2> /dev/null
	[ "$(stat -c %s "$BAK/splloader.bin")" -ge 4194304 ] || { rm -f "$BAK/splloader.bin"; die "could not back up $B0"; }
fi
say "old SPL slots kept in $BAK"

echo 0 > /sys/block/$DEV/force_ro
dd if="$SPL" of="$B0" bs=1M conv=fsync 2> /dev/null || { echo 1 > /sys/block/$DEV/force_ro; die "write to $B0 failed"; }
echo 1 > /sys/block/$DEV/force_ro
dd if="$B0" of=/data/local/tmp/spl-check.bin bs=1M count=4 2> /dev/null
cmp -s /data/local/tmp/spl-check.bin "$SPL" ||
	die "readback differs - run it again before rebooting; to undo: dd if=$BAK/splloader.bin of=$B0 (force_ro 0)"
rm -f /data/local/tmp/spl-check.bin
say "verified. Pull the backup (adb pull $BAK), power off, put in a base618 card, power on"
