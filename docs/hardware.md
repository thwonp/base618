# RG Rotate hardware (Unisoc T618 / ums512 / sharkl5pro)

Mainline 7.2 kernel + Armbian's sprd patches + base618's fixes (`rotate-fixes`). What each part needs.

| Part | What it is | Driver / interface | Notes |
|---|---|---|---|
| SoC | T618: 2x Cortex-A75 + 6x Cortex-A55, AArch32 at EL0 works (CONFIG_COMPAT) | - | CM4 power coprocessor (pm_sys) and AGDSP (audio DSP) beside it |
| GPU | Mali-G52 MP2 | panfrost (Mesa) | gpu-core 384-850 MHz devfreq; GL 3.1 / GLES 3.x |
| Display | 720x720 DSI panel | sprd DRM (DPU) | backlight black at <= 80, a dead zone ~90-170; the swivel (hall) rotates it 90 degrees |
| Touch | Goodix GT911 | goodix (I2C), evdev | coordinates are raw panel axes: map them through the current rotation yourself |
| Buttons | d-pad, ABXY, L/R 1-2, Start/Select, Home/Back, side key (BTN_THUMBR), Menu | gpio-keys "gpio-keys-gamepad" | POWER and the volume keys are on the system key node |
| Hall | swivel open/closed | SW_LID (1 = closed) | closed = rotate the picture 90 degrees |
| Audio | SC2730 PMIC codec + speaker amp, AGDSP | sprd ASoC (VBC, MCDT, DSP) | first PCM open after the sound server starts stalls (warm it up); the HPL/HPR volume is inverted and must be re-seeded on every PCM open; mic = mono on channel 1 (channel 0 is an unfed ADC pinned at -32768) |
| Wi-Fi + BT | Unisoc UWE5622 (marlin3) over SDIO | sc23xx wlan, btsprdsdio, sprd_wcn | firmware from the stock eMMC; see quirks for the connect wedge and BT power-off |
| USB | USB-C, musb OTG | musb-sprd, bq2415x charger | host mode for USB DACs/pads; after OTG the charger must have its defaults restored (vbus_disable) |
| Battery | 1900 mAh | sprd fuel gauge (fgu), `charge_now` in uAh | the only usable current meter on the device |
| LED | charge/status | leds | |

## Rotation

The hall switch is a lid switch: let the compositor turn the output (sway `bindswitch lid:on output DSI-1
transform 90`) and map touch to the output. Everything else (keys) stays as it is.

## Audio path in one paragraph

Playback goes AP -> VBC -> (AGDSP for some paths) -> codec -> amp. The AGDSP must sleep cooperatively for
the SoC to reach its low-power clock (see deep-sleep.md); after resume, the DSP is restarted and its
MCDT DMA channels restored. Release the speaker (close the PCM) when idle: an open PCM holds the codec's
analog side on (~3 mA asleep).

## USB DAC / headsets

Work as standard USB audio class devices in host mode. Unplugging during playback needed a musb fix (freeze);
suspend with a DAC attached needs the musb PM notifier to drop the host role first.
