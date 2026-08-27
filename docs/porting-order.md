# Mainline porting order

1. Confirm SoC ID, DRAM size, UART instance/pins and eMMC controller.
2. Boot mainline SPL in FEL and verify DRAM before writing persistent media.
3. Build upstream A523 TF-A and prove the EL3 handoff to U-Boot proper.
4. Boot U-Boot proper from RAM; validate UART, clocks, pinctrl and board DT.
5. Validate eMMC at 400 kHz, then at a conservative 25 MHz.
6. Place SPL at 8 KiB in a user-area test image and validate its eGON header.
7. Program the same SPL into hardware Boot0 through FES.
8. Force SPL from eMMC Boot0 back to the eMMC user area before FIT reads.
9. Constrain U-Boot relocation below the observed corruption boundary.
10. Add a FAT/extlinux boot partition and boot Linux with early console.
11. Make Linux eMMC probing deterministic (`no-sd`, `no-sdio`).
12. Use an explicit verified root device, then bring up the Buildroot userspace.
13. Validate the raw image byte layout before any hardware write.
14. Use a board-matched RAM-only FES loader to write Boot0 and the user area.
15. Require FES verification, then remove power and perform a cold boot.
16. Reproduce from fresh clones with an empty download cache.

Each stage should leave a serial transcript and artifact hash. A FES success
alone proves transport acceptance, not that the persistent mainline chain can
cold boot.
