#!/bin/sh
# SPDX-License-Identifier: MIT
# base618's first boot on a card made by make-card.sh: the unit's own firmware
# off its eMMC (extract-firmware.sh), the firmware initrd the base618 kernel
# boots with (make-initrd-fw.sh), the updated modules indexed, then POWER OFF -
# a reboot is unreliable on this chain (docs/firmware.md). Once: the marker on
# /boot stops the service. Anything missing marks it failed, says so on tty1
# and lets the boot go on without audio, Wi-Fi/BT and deep sleep.
#
# Installed by make-card.sh as /usr/share/base618/firstboot.sh beside
# extract-firmware.sh and make-initrd-fw.sh; run by base618-firstboot.service.
set -u
HERE=$(dirname "$0")
BOOT=${BOOT:-/boot}
TTY=${TTY:-/dev/tty1}
log() { echo "base618-firstboot: $*"; }
screen() {
	{ printf '\033[2J\033[H\n'; for l; do printf '  %s\n' "$l"; done; } > "$TTY" 2>/dev/null
}
fail() {
	log "$1"
	echo "$1" > "$BOOT/base618-fw.failed"
	sync
	screen "base618: could not set up the firmware" "from this unit's internal storage:" "  $1" "" \
		"Audio, Wi-Fi/BT and deep sleep will not work." "Starting anyway..."
	sleep 15
	exit 0
}

screen "base618: setting up this unit's firmware..." "" "Please wait, do not turn it off."
udevadm settle -t 30
# Armbian's resize (ordered before this service) gives the grown root partition a
# new PARTUUID; the base618 label boots root=PARTUUID= (no initramfs to find a
# UUID), so point it at the partition as it is now - else the next boot waits forever.
ROOT=$(findmnt -no SOURCE /)
PU=$(blkid -p -s PART_ENTRY_UUID -o value "$ROOT")
if [ -n "$PU" ]; then
	sed -i "/^label base618/,/^label /s/root=PARTUUID=[^ ]*/root=PARTUUID=$PU/" "$BOOT/extlinux/extlinux.conf"
	sync
fi
grep -q "root=PARTUUID=$PU " "$BOOT/extlinux/extlinux.conf" 2>/dev/null ||
	log "WARNING: could not set root=PARTUUID=$PU in $BOOT/extlinux/extlinux.conf - the next boot may not find root"
sh "$HERE/extract-firmware.sh" / || fail "extract-firmware.sh found no valid image (see the journal)"
sh "$HERE/make-initrd-fw.sh" / "$BOOT/initrd-fw.cpio.gz" || fail "could not write $BOOT/initrd-fw.cpio.gz"
depmod -a "$(uname -r)" || log "depmod failed; the updated modules may not load"
touch "$BOOT/base618-fw.done"
sync
log "firmware initrd written, powering off"
screen "base618: firmware set up." "" "The unit will now power off." "Turn it on again to boot."
sleep 8
systemctl --no-block poweroff
