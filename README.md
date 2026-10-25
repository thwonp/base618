# base618

A base for custom firmware on Unisoc T618 (ums512 / sharkl5pro) handhelds,
starting with the Anbernic RG Rotate: the boot chain, the kernel, and what each part of the hardware
needs - written down, so a CFW (NextUI, ROCKNIX, your own) can start from working hardware instead of
re-deriving it. Same idea as BaseOS for the Allwinner H700.

Tested on one device only: the RG Rotate (no other T618 handheld was available).

## What it is

| Part | Source | Notes |
|---|---|---|
| SPL | [thwonp/ums512_spl](https://github.com/thwonp/ums512_spl) branch `plorpos-cm4` | Armbian's SPL with `cm4_sec()` skipped, so Linux can start the CM4 power coprocessor (deep sleep). Flashed once to the eMMC `splloader`. |
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
- [docs/deep-sleep.md](docs/deep-sleep.md) - from 35.7 mA to 3.3 mA asleep (stock 2.55 mA).
- [docs/quirks.md](docs/quirks.md) - things that cost us a day each.
- [docs/firmware.md](docs/firmware.md) - extracting the vendor firmware from the user's own device.
- [docs/install.md](docs/install.md) - putting each part on a unit, checking it, and getting back.
- [docs/boot-logo.md](docs/boot-logo.md) - the two boot logos and how to change them.
- [docs/coming-from-h700.md](docs/coming-from-h700.md), [docs/coming-from-a133p.md](docs/coming-from-a133p.md).

## Status

Everything here runs [plorpOS](https://github.com/thwonp/plorpOS) on the RG Rotate day to day: display and
rotation, touch, buttons, audio (speaker, headphones, mic, USB DACs, Bluetooth), Wi-Fi, charging and USB
host, and deep sleep at 3.3 mA. Known gaps:

- Mic capture held open across a suspend stops; the next open works.
- Asleep, 0.75 mA above stock: the USB2 PHY is never powered off (up to 0.3 mA), the rest unexplained.
- One unit tested. Nothing here has been tried on another T618 device.

## Licence

- **Scripts** (`scripts/`): MIT - [LICENSE](LICENSE). Each file carries an SPDX line.
- **Docs** (`README.md`, `AGENTS.md`, `docs/`): [CC-BY-4.0](LICENSES/CC-BY-4.0.txt).
- **Kernel, U-Boot, SPL**: GPL-2.0 (the SPL GPL-2.0-or-later), from their public source branches named in the
  table above; every release names the exact commits its binaries were built from.
  `pm_bootcode.bin` is 31 words taken from that GPL U-Boot source.
- **Vendor firmware**: none in this repository or its releases. `scripts/extract-firmware.sh` reads each
  unit's own copy off its eMMC.
