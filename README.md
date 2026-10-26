# base618

A base for custom firmware on Unisoc T618 (ums512 / sharkl5pro) handhelds,
starting with the Anbernic RG Rotate: the boot chain, the kernel, and what each part of the hardware
needs - written down, so a CFW (NextUI, ROCKNIX, your own) can start from working hardware instead of
re-deriving it. Same idea as BaseOS for the Allwinner H700.

Tested on one device only: the RG Rotate (no other T618 handheld was available).

**Highlight - real deep sleep.** Mainline Linux on this SoC suspends but never reaches the chip's deep
states, and draws ~36 mA asleep. base618 gets the RG Rotate to **3.3 mA asleep, within 0.75 mA (29 %) of
stock Android's 2.55 mA** - about 2 % of the battery per 12 hours asleep. How, step by step:
[docs/deep-sleep.md](docs/deep-sleep.md).

## Credits

base618 stands on two people's work. Getting Linux onto this device at all was theirs:

- **beebono** - the first mainline bring-up of the RG Rotate
  ([beebono/rg-rotate-linux](https://github.com/beebono/rg-rotate-linux)): Linux 7.1 booting a Debian rootfs
  with the panel, USB OTG and Wi-Fi/Bluetooth working, on a kernel fork off Otto Pflüger's
  `ums9230-mainline` line. The kernel, U-Boot and SPL trees base618 builds from all start as beebono's forks
  ([linux-mainline-sprd](https://github.com/beebono/linux-mainline-sprd),
  [u-boot-ums512](https://github.com/beebono/u-boot-ums512),
  [ums512_spl](https://github.com/beebono/ums512_spl), the last forked from TheGammaSqueeze's).
- **crackerjacques** - Armbian's support for the device: the `sprd-ums512` family and the
  `anbernic-rg-rotate` board in [armbian/build](https://github.com/armbian/build), the forward port of the
  kernel fork to 7.2.9 and its Armbian patch set, the U-Boot patches, the SPL built from source as an unsigned
  "open" variant that boots an SD card and still boots stock Android
  ([crackerjacques/ums512_spl](https://github.com/crackerjacques/ums512_spl) branch `armbian`), the
  first-boot firmware extractor, and the SPL flashing guide on every Armbian card. base618's forks sit on
  crackerjacques's [linux-mainline-sprd](https://github.com/crackerjacques/linux-mainline-sprd) and
  [u-boot-ums512](https://github.com/crackerjacques/u-boot-ums512).

Also: **TheGammaSqueeze** published the SPL tree everything here boots through, and the Unisoc BSP sources
(GPL) are the reference under all of it.

## What base618 changed

All by Thwonp, on top of the work above, while porting [plorpOS](https://github.com/thwonp/plorpOS):

| Part | Theirs | Ours |
|---|---|---|
| SPL | crackerjacques's open SPL (`3c5f354`) | one change: skip `cm4_sec()`, so Linux can start the CM4 power coprocessor - the first step to deep sleep (`e229396`) |
| U-Boot | beebono's/crackerjacques's tree + Armbian's patches 0001-0005 | boot logo held through the kernel handoff and turned with the swivel, boot timestamps, kernel load address and gunzip limit for a gzip uImage, SD card on a 4-bit bus, the "Booting" logo (5 commits) |
| Kernel | crackerjacques's 7.2.9 fork + Armbian's `sprd-ums512-7.2` patches | 34 commits: deep sleep (CM4/pm_sys, cooperative AGDSP power-off, USB UTMI clock, arch timer, amp, MICBIAS, Wi-Fi power, USB2 PHY, display/IOMMU/power-domain resume), Wi-Fi connect wedge and scan sizing, Bluetooth power-off, USB-C/OTG charging, USB host role across suspend, a USB DAC's stream stop (musb DMA) and power-off with it attached, mic route after suspend, 2.9 s off the kernel boot (clock probes), battery OCV, LEDs, the boot logo and a user-changeable one |
| Firmware | Armbian's extractor takes the WCN and AGDSP images | pm_sys too, a firmware-only initrd so the built-in drivers get it before root, the CM4 boot stub from GPL source |
| Docs, scripts | - | everything in this repository |

## What it is

| Part | Source | Notes |
|---|---|---|
| SPL | [thwonp/ums512_spl](https://github.com/thwonp/ums512_spl) branch `plorpos-cm4` | crackerjacques's open SPL (Armbian's) with `cm4_sec()` skipped, so Linux can start the CM4 power coprocessor (deep sleep). Flashed once to the eMMC `splloader`. |
| U-Boot | [thwonp/u-boot-ums512](https://github.com/thwonp/u-boot-ums512) branch `plorpos` | SD p1. Boot logo, hall-aware rotation, 4-bit SD fix. |
| Kernel | [thwonp/linux-mainline-sprd](https://github.com/thwonp/linux-mainline-sprd) `rotate-fixes` (device build) / `plorpos-fixes` (upstream staging) | mainline 7.2 + Armbian's sprd patches + the fixes in [docs/](docs/). |
| Firmware | the device's own eMMC | Never shipped. A first-boot script copies AGDSP, pm_sys (CM4) and the WCN modem firmware from the stock partitions. See [docs/firmware.md](docs/firmware.md). |
| Root filesystem | not ours | Armbian trixie (community anbernic-rg-rotate) is what plorpOS uses. |

Stock Android stays on the eMMC and boots when no card is in: the SPL loads the secure world from it,
and the firmware comes from it. Never wipe eMMC partitions other than `splloader`.

## Docs

- [AGENTS.md](AGENTS.md) - instructions for a coding agent working on this hardware (read first).
- [docs/hardware.md](docs/hardware.md) - every device on the board and what drives it.
- [docs/boot-chain.md](docs/boot-chain.md) - BootROM to Linux, dual boot, recovery.
- [docs/deep-sleep.md](docs/deep-sleep.md) - from 35.7 mA to 3.3 mA asleep, within 29 % of stock.
- [docs/quirks.md](docs/quirks.md) - things that cost us a day each.
- [docs/firmware.md](docs/firmware.md) - extracting the vendor firmware from the user's own device.
- [docs/install.md](docs/install.md) - putting each part on a unit, checking it, and getting back; or the
  release's ready card image, or `scripts/make-card.sh` to make one from Armbian's image.
- [docs/boot-logo.md](docs/boot-logo.md) - the two boot logos and how to change them.
- [docs/coming-from-h700.md](docs/coming-from-h700.md), [docs/coming-from-a133p.md](docs/coming-from-a133p.md).

## Status

Everything here runs [plorpOS](https://github.com/thwonp/plorpOS) on the RG Rotate day to day: display and
rotation, touch, buttons, audio (speaker, headphones, mic, USB DACs, Bluetooth), Wi-Fi, charging and USB
host, and deep sleep at 3.3 mA - within 29 % of stock Android. Known gaps:

- Mic capture held open across a suspend stops; the next open works.
- One unit tested. Nothing here has been tried on another T618 device.

## Licence

- **Scripts** (`scripts/`): MIT - [LICENSE](LICENSE). Each file carries an SPDX line.
- **Docs** (`README.md`, `AGENTS.md`, `docs/`): [CC-BY-4.0](LICENSES/CC-BY-4.0.txt).
- **Kernel, U-Boot, SPL**: GPL-2.0 (the SPL GPL-2.0-or-later), from their public source branches named in the
  table above; every release names the exact commits its binaries were built from.
  `pm_bootcode.bin` is 31 words taken from that GPL U-Boot source.
- **Fonts** (`res/lato*.ttf`, the logo and screen): Lato, [SIL OFL 1.1](res/OFL-Lato.txt).
- **Vendor firmware**: none taken from a device, in this repository or its releases. `scripts/extract-firmware.sh`
  reads each unit's own copy (AGDSP, pm_sys, the WCN modem image) off its eMMC at first boot. The card image and
  the copy of Armbian's image carry Armbian's `armbian-firmware` package as Armbian ships it.
