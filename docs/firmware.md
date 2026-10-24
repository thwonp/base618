# Vendor firmware: taken from the user's own device, never shipped

Three Unisoc images are needed, and all three are on every RG Rotate's eMMC (A/B slots):

| Firmware | eMMC partition | Bytes read | Check | Where it goes | Who loads it |
|---|---|---|---|---|---|
| AGDSP (audio DSP) | `l_agdsp_a` / `_b` | 5 MiB | starts with `SharkL5_AUDCP_` | initrd `/lib/firmware/updates/agdsp.bin` | built-in audio driver, before the rootfs mounts |
| pm_sys (CM4 power firmware) | `pm_sys_a` / `_b` | 1 MiB | magic `df f8 0c d0` | initrd `/lib/firmware/sprd/pm_sys.bin` **and** the rootfs (the firmware cache re-reads it at suspend) | sprd_pmsys remoteproc |
| WCN (Wi-Fi/BT modem) | Armbian's `rotate-extract-firmware` | - | magic `a0 0a 1a 00` | rootfs `/lib/firmware/updates/wcnmodem.bin` | sprd_wcn |

Plus `pm_bootcode.bin` (the CM4's boot stub), built from source and shipped (plorpOS: `mk/rotate-pm-bootcode.sh`).

## The first boot (plorpOS's `plorpos-firmware.sh`, after Armbian's extractor)

1. Slot a, else b: `dd` the partition head, check the magic.
2. Build `/boot/initrd-fw.cpio.gz` = dev/console + the three files above; pm_sys into the rootfs too.
3. Mark `/boot/plorpos-fw.done`, power off (a reboot is unreliable on this chain), tell the user on tty1.
4. Anything missing: `/boot/plorpos-fw.failed` + a message; boot goes on without audio/deep sleep, once.

Do not put `wcnmodem.bin -> uwe5622/` symlinks from armbian-firmware in place before the real one lands: the WCN
driver loads that other module's firmware on the first boot and oopses.

## Redistribution

Not settled, and not needed: shipping none of them keeps every release free of vendor blobs.
