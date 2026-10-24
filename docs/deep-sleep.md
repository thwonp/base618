# Deep sleep on the T618: 35.7 mA -> 3.3 mA (stock 2.55 mA)

The long version is plorpOS's `.74` ledger. This is what a new port needs.

## Why mainline does not sleep out of the box

`echo mem > /sys/power/state` works, ATF completes system suspend (PSCI stats count), and the device draws
~36 mA asleep: the SoC never reaches its deep states. Proof is in the PMU (regmap debugfs
`dummy-syscon@...327e0000`):

| Counter | Meaning | Must count per suspend |
|---|---|---|
| 0x788 / 0x770 | AP light / deep | yes |
| 0x758 | APCPU_TOP first stage | yes |
| 0x784 | PUB (DDR) deep - **the one that matters** | yes |
| AON DCXO_LC_REG1 0x40, PMIC 0x1b70/0x1b74 | 26 MHz XO low-current (chip deep) | yes |

## What it takes, in order

1. **Run the CM4 (pm_sys)**. It owns the sleep handshake. Needs the SPL without `cm4_sec()` (boot-chain.md),
   the pm_sys remoteproc DT node enabled, firmware from the eMMC, `echo start` (or auto boot) at startup.
2. **USB PHY clock off at the final moment**: with the OTG UTMI clock (AON EB1 b8) running, PUB deep is refused
   - stock passes unplugged and fails with USB plugged for exactly this reason. musb's noirq suspend gates it.
3. **AGDSP must really be off** (PMU XTL0_REL_CFG b3 AUDCP_SYS_SEL votes for the 26 MHz XO). Forcing the domain
   off kills the DSP and audio; the working way is cooperative: the VBC driver's PM ops shut the DSP down at
   suspend, release AON 0x14c b5 and wait for 0xb8 == 7, then restart it and restore the MCDT DMA channels on
   resume.
4. **`arm,no-tick-in-suspend`** on the arch timer once the XO stops, or sleep time is lost.
5. **Peripherals that hold power**: the speaker amp (PM ops), the codec's MICBIAS hold, the Wi-Fi chip (release
   it; it stays associated otherwise, ~60 mA), Bluetooth (off at sleep), the panel (output off), an open PCM.

Measured on plorpOS: 149 mA (panel + Wi-Fi on) -> 41 -> 29 (PUB deep) -> 14 (XO low) -> 4.1 -> 3.30 mA overnight
(~2 %/12 h on 1900 mAh). Left vs stock: USB2 PHY never powered off (<= 0.3 mA), ~0.6 mA unexplained.

## What did NOT matter

GPU/MM power domains, cluster light/deep (stock never uses them either), DMC low-power config (already right
from the SPL), TrustOS being unreachable, stock DT AON timers.

## Measuring

`rtcwake -m mem -s 180` + fuel gauge `charge_now` before/after, unplugged, radios as they will be in use.
Watch for the ~30 uAh tail of each wake. Overnight runs for milestones only.
