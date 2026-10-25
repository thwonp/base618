#!/bin/sh
# SPDX-License-Identifier: MIT
# Take the Unisoc firmware a T618 handheld needs off its own eMMC.
#
#   extract-firmware.sh [DEST]     (default DEST: /, i.e. install in place)
#   PARTS overrides /dev/disk/by-partlabel (e.g. a directory of dd images)
#
# Writes, under DEST:
#   lib/firmware/updates/agdsp.bin     audio DSP      from l_agdsp_a|b, 5 MiB
#   lib/firmware/sprd/pm_sys.bin       CM4 (pm_sys)   from pm_sys_a|b,  1 MiB
#   lib/firmware/updates/wcnmodem.bin  Wi-Fi/BT       from wcnmodem_a|b, 947200 B
#
# Nothing is shipped: every unit keeps its stock Android on the eMMC (the SPL
# loads the secure world from there), so the firmware is already on it. The a
# and b slots hold the same image; the first one whose header is right wins.
# The lengths are the drivers' windows, not the partition sizes: the WCN
# driver pushes the whole file, so it must not be longer than 0xe7400.
#
# Exit 0 with all three written, 1 if any is missing or not the expected image
# (the others are still written). Run as root on the device.
set -u
DEST=${1:-/}
PARTS=${PARTS:-/dev/disk/by-partlabel}

log() { echo "extract-firmware: $*" >&2; }
magic() { [ "$(od -An -tx1 -N"$2" "$1" 2>/dev/null | tr -d ' \n')" = "$3" ]; }
agdsp_ok() { [ "$(dd "if=$1" bs=14 count=1 status=none 2>/dev/null)" = "SharkL5_AUDCP_" ]; }
pm_sys_ok() { magic "$1" 4 dff80cd0; }
wcn_ok() { magic "$1" 4 a00a1a00; }

# take LABEL BYTES CHECK OUT
take() {
	mkdir -p "$(dirname "$4")"
	for p in "$PARTS/$1_a" "$PARTS/$1_b"; do
		[ -r "$p" ] || continue
		if dd "if=$p" "of=$4.new" bs=512 count=$(($2 / 512)) status=none && "$3" "$4.new"; then
			mv -f "$4.new" "$4"; log "$4 from $p"; return 0
		fi
		log "$p is not the expected image"
	done
	rm -f "$4.new"
	log "no valid $1_a or $1_b"
	return 1
}

ok=0
take l_agdsp   5242880 agdsp_ok  "$DEST/lib/firmware/updates/agdsp.bin"    || ok=1
take pm_sys    1048576 pm_sys_ok "$DEST/lib/firmware/sprd/pm_sys.bin"      || ok=1
take wcnmodem   947200 wcn_ok    "$DEST/lib/firmware/updates/wcnmodem.bin" || ok=1
exit $ok
