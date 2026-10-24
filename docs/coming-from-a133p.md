# Coming from the A133P (TrimUI Brick / Smart Pro, NextUI)

| On the A133P (TrimUI stock BSP) | On the T618 (mainline) |
|---|---|
| Vendor 4.9 kernel, vendor userland, frontend on fbdev/GLES (PowerVR) | Mainline 7.2, Debian userland, Panfrost Mesa; KMS or Wayland |
| Sleep = the vendor kernel's, frontend toggles backlight/mixer | Real suspend needs the CM4/AGDSP work in deep-sleep.md |
| Mixer controls by name in the vendor ALSA driver | ASoC: PipeWire/WirePlumber or plain ALSA; restore volumes per PCM open |
| Keys via vendor input + keymon | gpio-keys evdev; POWER/volume on the system node |
| No compositor | One window at a time is easiest under sway (kiosk): place windows by swaymsg |
| Brightness via vendor disp ioctl | sysfs backlight; panel black at <= 80 |

NextUI's sleep model (light sleep = screen off, CPU on; escalate to suspend after a timeout; do not suspend
on external power) maps directly, and plorpOS uses it on the Rotate. Suspend on USB power works on the T618
after the fixes, but stays off by default for parity.
