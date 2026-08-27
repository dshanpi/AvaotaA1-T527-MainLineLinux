# Failures and fixes

| Symptom | Cause | Final correction |
| --- | --- | --- |
| Vendor or SyterKit chain boots but violates target architecture | Reference boot components persisted in the image | Excluded all vendor/SyterKit persistent artifacts; retained only RAM-only FES transport |
| SPL starts from Boot0 but FIT read fails | eMMC controller/card remained in boot-access state while cached block descriptor said user area | Force Boot1, then user-area switch before raw FIT read |
| MMC data CRC/timeouts | Untuned T527 MMC2 sampling at 52 MHz | Limit SPL/U-Boot eMMC path to 25 MHz |
| U-Boot proper reaches relocation then aborts/corrupts commands | Relocation immediately below 4 GiB was unreliable | Cap U-Boot usable relocation top at `0x50000000` |
| Linux waits forever for root | `root=LABEL=rootfs` was not reliable in the verified early-boot configuration | Use the hardware-verified `/dev/mmcblk1p2` root device |
| Linux eMMC probe ambiguity | MMC2 also attempted SD/SDIO semantics | Add `no-sd` and `no-sdio` |
| FES reports success but board does not cold boot | Transport verification does not cover BootROM/SPL/FIT/root handoff | Require power-cycle UART cold-boot evidence |
| Wrong FEL/FES node after re-enumeration | USB device address changes during FES transition | Bind by physical topology and accept only a unique same-bus FEL→FES transition |

Diagnostic images containing SyterKit, vendor BL31, bad offsets, experimental
relocation limits or pre-fix MMC behavior are intentionally not published.
