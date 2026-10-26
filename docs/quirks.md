# Quirks

Each of these cost at least a day.

- **Wi-Fi connect wedge**: after one failed connect the UWE5622 firmware rejects every connect (status 16) until
  the interface is closed and reopened. Fixed in the driver (reopen via dev_close/dev_open on firmware connect
  failure). Repro: rmmod the module while connected.
- **Bluetooth off/on took 30 s**: btsprdsdio's shutdown must send 0xfca1 {0,9,0} and set NON_PERSISTENT_SETUP
  (now 1.4 s).
- **sc23xx commands across PM**: issue them directly during suspend; -EBUSY after the bus suspended.
- **First PCM open after the sound server starts stalls** (SC2730): open and close one at startup.
- **Headphone volume inverted** (HPL/HPR), reset on every PCM open: re-seed it after each open.
- **USB DAC unplug froze the device** (musb) and **suspend with a DAC** needs the host role dropped first.
- **Charging after OTG** stopped until the bq2415x defaults were restored (vbus_disable).
- **A USB DAC's stream stop panicked the kernel** (musb sprd_dma BUG_ON, channel still busy): abort it instead.
- **Power-off with a USB device attached rebooted**: the charger's boost kept VBUS up; turn boost off at shutdown.
- **Boot stall**: ums512 clock probes power-cycled the PMU domain per clock (msleep 50 each way) - hold a runtime
  PM reference during the probe. Kernel boot 4.9 -> 2.0 s.
- **Display**: reading the DPU/IOMMU while the output is off hangs the bus. Resume needed IOMMU restore and DPU
  clock fixes.
- **Touch**: Goodix reports raw panel coordinates; injected events need the slot value to change (equal ABS
  values are dropped by the kernel).
- **Compositor**: sway does not reliably raise a newly mapped window over a fullscreen one - place windows
  explicitly (swaymsg) when handing the screen between processes. A workspace holds one fullscreen view:
  mapping a fullscreen window clears another's fullscreen on the same workspace.
- **Mesa**: Debian's Mesa links libLLVM; Mono-based games (FNA) that export their own LLVM symbols crash
  when EGL loads it, and it gives no GLES 1 context. A Panfrost-only Mesa without LLVM, with GLES 1, fixes
  both (ROCKNIX's choice). plorpOS builds one (Debian's version, 25.0.7, no glvnd, 19 MB) with
  [mk/build-ports-mesa.sh](https://github.com/thwonp/plorpOS/blob/feat/rotate/mk/build-ports-mesa.sh) into
  `/usr/lib/plorpos-mesa`, and puts it on `LD_LIBRARY_PATH` for games only; the compositor keeps Debian's.
- **32-bit userland** is absent on a Debian arm64 rootfs: box86/gmloader (armhf) games need it.
- **Reboot can hang** after journald stops: for test reboots, sync and hard-reset (Vol-Down+Power).
- **ramoops works**; Vol-Down+Power wipes it. `panic=10` gives a record and an automatic reboot.
