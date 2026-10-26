#!/bin/sh
# SPDX-License-Identifier: MIT
# base618's SPL into the eMMC splloader slot (boot0) over USB, from a Linux PC - the unit
# can be on anything, or boot nothing.
#
#   scripts/flash-spl.sh LOADERS [SPL]
#
#   LOADERS  the unit's two download-mode loaders (FDL1, FDL2), from either
#            - a folder holding fdl1-dl.bin and fdl2-dl.bin, e.g. spl-flasher/ from
#              spl-flasher.zip at https://github.com/beebono/distribution/releases, or
#            - the stock firmware .pac or GammaOS's, taken out with pac-fdl.py.
#            Nothing else of either is written.
#   SPL   default spl-cm4.img next to this script (as in the release's spl zip).
#
# Needs spd_dump (https://github.com/TomKing062/spreadtrum_flash, `make`) on PATH or as
# SPD_DUMP=, and USB access to 1782:4d00 (sudo, or a udev rule - see docs/install.md).
# Keeps the slot's old contents as splloader-backup-<date>.bin and checks a readback.
# splloader_bak (boot1) is left as it is: if boot0 ever fails its check the BootROM
# falls back to it and the unit boots as it did before.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=${1:?usage: flash-spl.sh LOADERS [SPL]}
SPL=${2:-$HERE/spl-cm4.img}
SPD=${SPD_DUMP:-spd_dump}
say() { echo "flash-spl: $*"; }
die() { echo "flash-spl: $*" >&2; exit 1; }
command -v "$SPD" > /dev/null || die "need spd_dump (or SPD_DUMP=path)"
[ -f "$SPL" ] || die "no $SPL (give the SPL image as the second argument)"
[ "$(stat -c %s "$SPL")" -le 4194304 ] || die "$SPL is larger than the 4 MiB slot"
python3 "$HERE/check-dhtb.py" "$SPL" > /dev/null || die "$SPL fails its DHTB check"
T=$(mktemp -d "${TMPDIR:-/var/tmp}/flash-spl.XXXXXX")
trap 'rm -rf "$T"' EXIT
if [ -d "$SRC" ]; then
	cp "$SRC/fdl1-dl.bin" "$T/fdl1.bin" && cp "$SRC/fdl2-dl.bin" "$T/fdl2.bin" \
		|| die "$SRC has no fdl1-dl.bin and fdl2-dl.bin"
else
	python3 "$HERE/pac-fdl.py" "$SRC" "$T"
fi
BAK=splloader-backup-$(date +%Y%m%d-%H%M%S).bin
[ -e "$BAK" ] && die "$BAK exists"

say "now: unplug the unit, power it off, slide the screen open, hold Home/Back and plug it in"
say "then keep it plugged in until this says verified - about a minute; the screen stays dark"
# spd_dump saves what it reads (and the unit's partition table) into its working
# directory, so it runs in $T; a read of splloader comes
# back trimmed to the DHTB image (the rest of the slot is zeros), so the readback is
# padded to 4 MiB and compared with the SPL padded the same way. The readback, not
# spd_dump's exit status, decides: on some ports the link drops after the write.
SPLA=$(cd "$(dirname "$SPL")" && pwd)/$(basename "$SPL")
( cd "$T" && "$SPD" --wait 300 keep_charge 1 fdl fdl1.bin 0x5500 fdl fdl2.bin 0x9EFFFE00 exec \
	read_part splloader 0 0x400000 backup.bin \
	write_part splloader "$SPLA" \
	read_part splloader 0 0x400000 check.bin \
	poweroff ) || say "spd_dump stopped early; checking what it read back"
[ -s "$T/backup.bin" ] && cp "$T/backup.bin" "$BAK"
[ -s "$T/check.bin" ] || die "no readback: the slot may or may not have been written - run it again"
pad() { cp "$1" "$2"; truncate -s 4194304 "$2"; }
pad "$T/check.bin" "$T/check.4m"; pad "$SPL" "$T/spl.4m"
cmp -s "$T/check.4m" "$T/spl.4m" || die "readback differs from $SPL - run it again before booting"
if [ -s "$BAK" ]; then say "verified; old SPL kept in $BAK"; else say "verified (no backup was read this time)"; fi
say "unplug, put in a base618 card and power on"
