# Boot chain

```
BootROM -> SPL (eMMC splloader, ours) -> ATF + TrustOS (eMMC, stock) -> U-Boot (SD p1, ours) -> Linux (SD p2/p3)
                                                                    \-> no card: stock U-Boot -> Android
```

- **SPL**: `thwonp/ums512_spl` branch `plorpos-cm4` = Armbian's SPL with `cm4_sec()` skipped. Stock locks
  the CM4 control register (AON 0x8c) secure-write-only and starts pm_sys through TrustOS; on this chain
  TrustOS cannot be asked (SIPCALLs hang), so the SPL leaves it writable and Linux starts the CM4 through
  remoteproc. Flash it once to both `splloader` slots (download mode). Recovery = flash the backup.
- **ATF / TrustOS**: stock, from the eMMC. A dead or unreachable TrustOS is harmless for normal use (it only
  saves/restores the firewall across suspend).
- **U-Boot** on SD p1 (DHTB-wrapped image): boot logo held until the compositor, hall-aware rotation, SD bus
  in 4-bit mode (the vendor tree's MMC_MODE_HS bits overlap 4BIT/8BIT), kernel at 0x9a200000 with a 64 MB
  BOOTM_LEN for a gzip uImage. With USB power in, power-off lands on U-Boot's charge screen (it lives in RAM).
- **Linux**: gzip uImage + DTB + a firmware-only initrd (AGDSP, `pm_bootcode.bin` and pm_sys; no `/init`),
  extlinux on p2 (FAT, GPT name `bootfs`); rootfs ext4 on p3. plorpOS adds an exFAT data partition, p4.

Boot time on plorpOS: power to frontend ~15 s; kernel ~2 s after the clk probe fix (the ums512 clock
probes power-cycled their PMU domain for each clock with msleep(50) both ways; holding a runtime-PM ref
in the probe fixed it).

## Recovery

- SD card: a hung U-Boot only reads the card - pull it, fix it in a card reader.
- Test kernels: keep the previous extlinux entry as the fallback (`extlinux.conf.stock` on plorpOS).
- eMMC SPL: download mode works whatever is on the eMMC.
