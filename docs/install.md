# Installing base618 on an RG Rotate

Four parts, each replaceable on its own. Start from Armbian's community image for the RG Rotate
(`anbernic-rg-rotate`, family `sprd-ums512`): it gives the card layout and a rootfs, and its card carries
`/boot/README.flash-bootloader-first.txt`, Armbian's own SPL guide. base618 changes the SPL, U-Boot
and the kernel, and builds a firmware initrd from the unit's own eMMC.

| Part | Lives on | From |
|---|---|---|
| SPL | eMMC `splloader` (boot0), 4 MiB; `splloader_bak` (boot1) keeps the unit's own | release `spl-cm4.img` (thwonp/ums512_spl `plorpos-cm4`) |
| U-Boot | SD p1, GPT name `uboot` (16 MiB raw) | release `uboot_dhtb.img` (thwonp/u-boot-ums512 `plorpos`) |
| Kernel + DTB | SD p2 `bootfs` (FAT): `/Image.uimg`, `/dtb/sprd/ums512-rg-rotate.dtb` | release, or `scripts/make-boot-files.sh` |
| Firmware initrd | SD p2: `/initrd-fw.cpio.gz` | built on the device: `scripts/extract-firmware.sh` + `scripts/make-initrd-fw.sh` |
| Root filesystem | SD p3 ext4 | Armbian |

Never wipe eMMC partitions other than the two SPL slots - see [boot-chain.md](boot-chain.md).

## Quick path: a card from Armbian's image

After the SPL (step 1, once per unit), steps 2-5 are done for you: the release's `base618-card.img.xz` is
a card made this way. To make one yourself, unzip the release's `base618-v<version>-files.zip` and run one
command on a Linux PC, no root needed:

```sh
scripts/make-card.sh base618-v0.2-files base618.img
```

It takes Armbian's image (the one base618 is tested on - the zip carries a copy), puts base618's U-Boot,
kernel, DTB and updated modules on it, boots `root=PARTUUID=` of p3 (Armbian's entry stays as a second label)
and adds a first-boot service that builds the firmware initrd from the unit's own eMMC and powers off once.
Login `root` / `base618` (`ROOT_PASSWORD=...` to choose another). Write
the image to a card with `dd`, boot, wait for the power-off, boot again, then step 6. The steps below are
what it does, for doing them by hand.

## 1. The SPL (once per unit)

base618's SPL is Armbian's with one call skipped (`cm4_sec()`, which locks the CM4 power controller). It goes
into the eMMC's `splloader` slot (boot0) and nothing else: `splloader_bak` (boot1) keeps what the unit had, so
if boot0 ever fails its check the BootROM falls back to it. With no base618 card in, base618's SPL boots the
eMMC's Android (stock or GammaOS) as before. Everything below is in the release's `base618-v<version>-spl.zip`.
Pick one way:

### On GammaOS - any PC with adb (Windows, macOS, Linux)

With the unit running GammaOS (or any rooted Android) and USB debugging on:

```sh
adb root
adb push spl-cm4.img flash-spl-android.sh /data/local/tmp/
adb shell sh /data/local/tmp/flash-spl-android.sh
adb pull /sdcard/base618-spl-backup
```

It saves both old slots to `/sdcard/base618-spl-backup/`, writes boot0 and checks a readback. Keep the pulled
backup. Power off, put in a base618 card, power on.

### From a Linux PC over USB - whatever the unit runs, or if it boots nothing

Needs [spd_dump](https://github.com/TomKing062/spreadtrum_flash) (`make`, then on `PATH`) and a Unisoc `.pac`
for the RG Rotate - the stock firmware or GammaOS's (both linked from
[GammaOS's install page](https://github.com/TheGammaSqueeze/GammaOSNext/wiki/GammaOS-Next-Installation)).
Only its two download-mode loaders are used; nothing else in it is written.

```sh
./flash-spl.sh YOUR.pac
```

Then: unplug the unit, power it off, slide the screen open, hold Home/Back (front, between the sticks) and plug
it in. The old SPL is kept as `splloader-backup-<date>.bin`. USB access to `1782:4d00` needs sudo or a udev rule:

```
SUBSYSTEM=="usb", ATTR{idVendor}=="1782", ATTR{idProduct}=="4d00", MODE="0666", TAG+="uaccess"
```

### From a Windows PC - untested by us

GammaOS's tools, used the way its wiki's "Super only" recovery uses them. From
[GammaOS's install page](https://github.com/TheGammaSqueeze/GammaOSNext/wiki/GammaOS-Next-Installation): get
`UnisocTools_RG_ROTATE.zip` (install its drivers, `UnisocDrivers/DPInst64.exe`) and the stock or GammaOS `.pac`.

1. Run `ResearchDownload.exe`, **Load Packet**, pick the `.pac`.
2. Gear icon, Main Page: untick **Select All Files**, tick only **FDL**, **FDL2** and **SPLLoader**; set
   SPLLoader's file to `spl-cm4.img`. OK.
3. **Play**, then unplug the unit, power it off, slide the screen open, hold Home/Back and plug it in.
4. Wait for **Passed**, unplug, put in a base618 card, power on.

There is no backup on this path; the `.pac`'s own SPLLoader puts the original back.

### Undo

- adb: `adb push splloader.bin /data/local/tmp/` (from the pulled backup), then
  `adb shell sh /data/local/tmp/flash-spl-android.sh /data/local/tmp/splloader.bin`.
- Linux: `./flash-spl.sh YOUR.pac splloader-backup-<date>.bin`.
- Windows: as above, leaving SPLLoader's file as the `.pac`'s.

What we tested: the USB write of `splloader` with readback, by hand with the same `spd_dump` commands
`flash-spl.sh` runs. The adb path and the scripts themselves are not yet tested on a unit; the Windows path
is not tested.

## 2. U-Boot (SD p1)

The SPL finds U-Boot by GPT name `uboot`, as a DHTB-wrapped `u-boot-dtb.bin`. Check it (`scripts/check-dhtb.py uboot_dhtb.img`), then write it raw:

```sh
dd if=uboot_dhtb.img of=/dev/disk/by-partlabel/uboot bs=512 conv=fsync
```

(on a PC card reader, the card's first partition). What it adds over Armbian's: the boot logo held through the
kernel handoff, rotation from the hall sensor, a 4-bit SD bus, and a kernel load address and gunzip limit
that fit a gzip uImage (needed for `Image.uimg`). Build it yourself (Debian trixie, `gcc-aarch64-linux-gnu` 14):

```sh
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- O=out ums512_rg_rotate_defconfig
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- O=out DEVICE_TREE=ums512_rg_rotate -j8
```

then `scripts/dhtb-wrap.py out/u-boot-dtb.bin uboot_dhtb.img` wraps it in the DHTB header (Armbian's `uboot_custom_postprocess`: 512-byte header,
`DHTB`, version 1, SHA-256 of the 512-padded payload at 0x08, its length at 0x30). The SPL builds the same
way from its tree: `CROSS_COMPILE=aarch64-linux-gnu- ./build.sh open` gives `out/open/spl_a_open.img`.

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

`root=PARTUUID=`, not `UUID=`: with no `/init` the kernel mounts root itself, and it only understands
PARTUUID. A card image that writes a fresh partition table must give p3 the PARTUUID its extlinux names, or
the kernel waits at the logo for ever (`rootwait`).

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
- SPL: download mode works whatever is on the eMMC; see step 1, Undo.
- Android: with no card, the SPL boots the stock U-Boot and Android as before.
