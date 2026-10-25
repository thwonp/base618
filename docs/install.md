# Installing base618 on an RG Rotate

Four parts, each replaceable on its own. Start from Armbian's community image for the RG Rotate
(`anbernic-rg-rotate`, family `sprd-ums512`): it gives the card layout and a rootfs, and its card carries
`/boot/README.flash-bootloader-first.txt`, the reference for the SPL step. base618 changes the SPL, U-Boot
and the kernel, and builds a firmware initrd from the unit's own eMMC.

| Part | Lives on | From |
|---|---|---|
| SPL | eMMC `splloader` (boot0) + `splloader_bak` (boot1), 4 MiB each | release `spl-cm4.img` (thwonp/ums512_spl `plorpos-cm4`) |
| U-Boot | SD p1, GPT name `uboot` (16 MiB raw) | release `uboot_dhtb.img` (thwonp/u-boot-ums512 `plorpos`) |
| Kernel + DTB | SD p2 `bootfs` (FAT): `/Image.uimg`, `/dtb/sprd/ums512-rg-rotate.dtb` | release, or `scripts/make-boot-files.sh` |
| Firmware initrd | SD p2: `/initrd-fw.cpio.gz` | built on the device: `scripts/extract-firmware.sh` + `scripts/make-initrd-fw.sh` |
| Root filesystem | SD p3 ext4 | Armbian |

Never wipe eMMC partitions other than the two SPL slots - see [boot-chain.md](boot-chain.md).

## 1. The SPL (once per unit)

Do Armbian's SPL step first, exactly as its README says: check the DHTB hash (`scripts/check-dhtb.py`), back up both slots, write
boot0, cold boot, then boot1. base618's SPL is Armbian's with one call skipped (`cm4_sec()`, which locks the
CM4 power controller), so the same procedure applies; use `spl-cm4.img` in place of `<image>.spl.img`.

From a running system (Armbian on the card), as root - **find the eMMC first**, it is the `mmcblkN` whose
`device/type` is `MMC` (mmcblk3 on our unit):

```sh
dd if=/dev/mmcblk3boot0 of=stock_boot0.bak bs=1M      # keep both off the device
dd if=/dev/mmcblk3boot1 of=stock_boot1.bak bs=1M
echo 0 > /sys/block/mmcblk3boot0/force_ro
dd if=spl-cm4.img of=/dev/mmcblk3boot0 bs=1M conv=fsync
dd if=/dev/mmcblk3boot0 bs=1M count=4 | cmp - spl-cm4.img && echo verified
```

Power fully off, cold boot (USB unplugged - with it in, power-off stops at the charge screen), and once it
boots write boot1 the same way.

Over USB from the BootROM, when nothing boots: `spd_dump` (https://github.com/ilyakurdyukov/spreadtrum_flash)
with the FDLs from the stock firmware package (`fdl1 0x5500`, `fdl2 0x9EFFFE00`):

```sh
spd_dump --wait 300 keep_charge 1 fdl fdl1-dl.bin 0x5500 fdl fdl2-dl.bin 0x9EFFFE00 exec \
  read_part splloader 0 0x400000 stock_boot0.bak \
  write_part splloader spl-cm4.img \
  read_part splloader 0 0x400000 check.bin poweroff
```

Start the tool first, then enter download mode. On our unit: unplug, slide the screen open, hold Home/Back
(front, between the sticks) and plug in. Armbian's README describes a small tact switch on the mainboard
instead; either way the host must show `1782:4d00`. Vol-Down+Power is a reset, not power-off.

What we tested: the USB path, `splloader` only, with readback. The running-system path is Armbian's and
untested by us.

## 2. U-Boot (SD p1)

The SPL finds U-Boot by GPT name `uboot`, as a DHTB-wrapped `u-boot-dtb.bin`. Check it (`scripts/check-dhtb.py uboot_dhtb.img`), then write it raw:

```sh
dd if=uboot_dhtb.img of=/dev/disk/by-partlabel/uboot bs=512 conv=fsync
```

(on a PC card reader, the card's first partition). What it adds over Armbian's: the boot logo held through the
kernel handoff, rotation from the hall sensor, a 4-bit SD bus, and a kernel load address and gunzip limit
that fit a gzip uImage (needed for `Image.uimg`). Build it yourself: `ums512_rg_rotate_defconfig`, `ARCH=arm`,
`CROSS_COMPILE=aarch64-linux-gnu-`, then wrap with the DHTB header (Armbian's `uboot_custom_postprocess`:
512-byte header, `DHTB`, version 1, SHA-256 of the 512-padded payload at 0x08, its length at 0x30).

## 3. Kernel and DTB (SD p2)

Copy `Image.uimg` to `/boot/` and the DTB to `/boot/dtb/sprd/`. The kernel keeps Armbian's release string
(`7.2.9-edge-sprd-ums512`) and its module set; the release adds the rebuilt Wi-Fi/BT modules for
`/lib/modules/<release>/updates/` (`sc23xx_wlan*.ko`, `btsprdsdio.ko`), then `depmod`. `btsprdsdio.ko` ships with
its `.BTF` section stripped: module BTF from this build does not match Armbian's vmlinux and is refused. Keep Armbian's `/boot/Image` as the
fallback entry.

Building it: thwonp/linux-mainline-sprd branch `rotate-fixes`, out-of-tree (`O=`), with the release's
`config`, in a Debian trixie container with `gcc-aarch64-linux-gnu`; then
`scripts/make-boot-files.sh KBUILD FWDIR` makes `Image.uimg` (and the initrd, reproducibly).

## 4. Firmware initrd (on the device)

The audio DSP and the CM4 drivers are built in and load their firmware before root is mounted, so it goes in
a small initrd. On the unit, as root:

```sh
scripts/extract-firmware.sh /            # agdsp, pm_sys, wcnmodem from the eMMC into /lib/firmware
scripts/build-pm-bootcode.sh U-BOOT-SRC /lib/firmware/sprd/pm_bootcode.bin   # or the release's copy
scripts/make-initrd-fw.sh / /boot/initrd-fw.cpio.gz
```

pm_sys must also stay in the rootfs (`/lib/firmware/sprd/pm_sys.bin`): the firmware cache re-reads it
before every suspend. Do this once per unit, and again only if the stock firmware on the eMMC is reflashed.
Details: [firmware.md](firmware.md).

## 5. extlinux.conf

```
label base618
  kernel /Image.uimg
  initrd /initrd-fw.cpio.gz
  fdt /dtb/sprd/ums512-rg-rotate.dtb
  append root=PARTUUID=<p3> rootwait console=tty0 ro
```

Keep Armbian's entry as a second label, or a copy of the file (`extlinux.conf.stock`) to restore from a card
reader.

## 6. Check it

```sh
dmesg | grep -E 'audio DSP booted|pmsys is now up|marlin_probe'
cat /sys/class/remoteproc/remoteproc0/state       # running
```

Deep sleep: suspend for 180 s with `rtcwake` and compare the fuel gauge's `charge_now` before and after -
about 3.3 mA on our unit with the CM4 running ([deep-sleep.md](deep-sleep.md)).

## Recovery

- Card won't boot: pull it (a hung U-Boot only reads the card) and restore `extlinux.conf` in a card reader.
- SPL: download mode works whatever is on the eMMC; write `stock_boot0.bak` back to `splloader`.
- Android: with no card, the SPL boots the stock U-Boot and Android as before.
