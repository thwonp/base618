# Working on a T618 (ums512) handheld - instructions for coding agents

Read this before touching the device. Every rule here was paid for once.

## Access

- Linux console: USB gadget serial (`/dev/ttyACM0` on the host), 115200, after Linux is up (nothing earlier;
  the getty needs 1-2 min after boot). Wi-Fi ssh when the network allows client-to-client traffic.
  On networks that isolate clients, an NCM USB network gadget (configfs) gives ssh over the cable.
- BootROM download mode (USB 1782:4d00): start the host tool waiting FIRST, then unplug, slide the screen
  open, hold Home/Back (front, between the sticks) and plug in. Vol-Down+Power is a RESET, not power-off.
- Tool: `spd_dump` (https://github.com/TomKing062/spreadtrum_flash) with the FDLs from the stock
  firmware package (`fdl1 0x5500`, `fdl2 0x9EFFFE00`). Back up a partition before writing it, always.

## Never

- Never wipe eMMC partitions except `splloader`: the SPL loads the secure world (ATF/TrustOS) from the eMMC
  and the firmware is extracted from it.
- Never read the DPU block (0x20300000-0x20300fff, incl. IOMMU at +0x800) while the display is off -
  bus hang. Never read a powered-down block's registers (GPU clock syscon 0x60100000 while the GPU is
  suspended dropped the device off USB). Read clock controllers only at header-defined offsets.
- Never issue a TrustOS SIPCALL on this boot chain from U-Boot or early kernel: hangs. If you load the
  trusty stack, use the stock order (trusty, pm, log, irq, ipc, virtio) and page-aligned buffers.
- Never unbind the vendor WCN driver (`sprd-marlin3`): hard freeze.
- Never set PMU 0x12c bit 24 (DDR_PHY_AUTO_RET_EN): hang. Take register values from pm_sys/ATF behaviour,
  not from Unisoc's SPL bring-up/test code.
- Never gate AP_AHB CKG_EB (b7) or UART0_EB at runtime: freeze.
- `mmap` + `struct.pack_into` on /dev/mem clobbers the neighbouring word: write 32-bit words only.
- `pkill -f` / `pgrep -f` inside an ssh command matches the ssh shell itself - anchor the pattern.

## Measure, don't assume

- Suspend current: `rtcwake` + the fuel gauge's `charge_now` delta, 180 s for an A/B, 300 s for a number
  you will keep, overnight for a milestone. dmesg timestamps stop during suspend - use wall clock.
- PMU sleep counters (regmap debugfs `dummy-syscon@...327e0000`): 0x784 PUB_SYS_DEEP counts every suspend
  once DDR deep works; that is the proof, not the current alone.
- Keep one living ledger per long hunt: hypotheses, status, evidence, never-do, test log. Check it before
  proposing a test.

## Build

- Kernel: cross build in a container (aarch64-linux-gnu), `O=` an out-of-tree build dir that reproduces the
  device kernel; boot files = gzip uImage + DTB + a firmware-only initrd (AGDSP/pm_sys bootcode).
- A whole card: `scripts/make-card.sh ARMBIAN_IMG OUT` (rootless: mtools + debugfs on the image file).
- Keep each fix a separate commit, so a bad one can be dropped after a boot test.
- Boot a test kernel with the stock extlinux entry kept as the fallback; with the USB cable in, a power-off
  lands on U-Boot's charge screen (hold Power), so cold-boot tests are done unplugged.

## Hardware pointers

See [docs/hardware.md](docs/hardware.md); deep sleep: [docs/deep-sleep.md](docs/deep-sleep.md); quirks:
[docs/quirks.md](docs/quirks.md).
