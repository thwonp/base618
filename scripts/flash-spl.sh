#!/bin/sh
# SPDX-License-Identifier: MIT
# base618's SPL into the eMMC splloader slot (boot0) over USB, from a Linux PC - the unit
# can be on anything, or boot nothing.
#
#   scripts/flash-spl.sh PAC [SPL]
#
#   PAC   the unit's stock firmware .pac or GammaOS's: only its two download-mode loaders
#         (FDL1, FDL2) are used, taken out with pac-fdl.py; nothing else of it is written.
#   SPL   default spl-cm4.img next to this script (as in the release's spl zip).
#
# Needs spd_dump (https://github.com/TomKing062/spreadtrum_flash, `make`) on PATH or as
# SPD_DUMP=, and USB access to 1782:4d00 (sudo, or a udev rule - see docs/install.md).
# Keeps the slot's old contents as splloader-backup-<date>.bin and checks a readback.
# splloader_bak (boot1) is left as it is: if boot0 ever fails its check the BootROM
# falls back to it and the unit boots as it did before.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
PAC=${1:?usage: flash-spl.sh PAC [SPL]}
SPL=${2:-$HERE/spl-cm4.img}
SPD=${SPD_DUMP:-spd_dump}
say() { echo "flash-spl: $*"; }
die() { echo "flash-spl: $*" >&2; exit 1; }
command -v "$SPD" > /dev/null || die "need spd_dump (or SPD_DUMP=path)"
[ -f "$SPL" ] || die "no $SPL (give the SPL image as the second argument)"
[ "$(stat -c %s "$SPL")" -eq 4194304 ] || die "$SPL is not a 4 MiB SPL image"
python3 "$HERE/check-dhtb.py" "$SPL" > /dev/null || die "$SPL fails its DHTB check"
T=$(mktemp -d "${TMPDIR:-/var/tmp}/flash-spl.XXXXXX")
trap 'rm -rf "$T"' EXIT
python3 "$HERE/pac-fdl.py" "$PAC" "$T"
BAK=splloader-backup-$(date +%Y%m%d-%H%M%S).bin
[ -e "$BAK" ] && die "$BAK exists"

say "now: unplug the unit, power it off, slide the screen open, hold Home/Back and plug it in"
"$SPD" --wait 300 keep_charge 1 fdl "$T/fdl1.bin" 0x5500 fdl "$T/fdl2.bin" 0x9EFFFE00 exec \
	read_part splloader 0 0x400000 "$BAK" \
	write_part splloader "$SPL" \
	read_part splloader 0 0x400000 "$T/check.bin" \
	poweroff || die "spd_dump failed - nothing is verified; run it again"
[ -s "$BAK" ] || die "no backup was read; the slot may not have been written"
cmp -s "$T/check.bin" "$SPL" || die "readback differs from $SPL - run it again before booting (old SPL: $BAK)"
say "verified; old SPL kept in $BAK"
say "unplug, put in a base618 card and power on"
