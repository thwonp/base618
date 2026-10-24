# Coming from the H700 (BaseOS, RG35XX/RG SP family)

| On the H700 | On the T618 |
|---|---|
| Boot0/U-Boot on the SD card, nothing on eMMC needed | SPL on the eMMC (flash once), secure world from the eMMC, U-Boot on SD |
| Firmware in the image | Firmware extracted from the device's own eMMC at first boot |
| Mali G31 (lima/panfrost), small fb | Mali-G52 (panfrost), GL 3.1 - Xwayland glamor works but is slow for SDL1-style software ports |
| Suspend works with the vendor-free kernel | Needs the CM4 running + cooperative AGDSP sleep + USB PHY clock off (deep-sleep.md) |
| Panel TE quirks (Mali stale tiles) | Panel fine; DPU/IOMMU must not be read while off |
| ALSA codec directly, no DSP | SC2730 codec + AGDSP; warm the PCM once, re-seed the inverted HP volume |
| RTL/AIC Wi-Fi | UWE5622 SDIO combo with its own wedge and BT power quirks (quirks.md) |
| Fixed landscape screen | 1:1 720x720 with a hall-switch swivel: rotate in the compositor, map touch |
| No touch | Goodix touch in raw panel coordinates |

What carries over unchanged: the frontend side (SDL2, KMS or a Wayland compositor), evdev input handling,
the "measure suspend with the fuel gauge" method, and keeping the base minimal.
