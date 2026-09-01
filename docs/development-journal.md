# Development journal

## 2026-08-26 — bring-up

- Established UART0 output and mainline SPL DRAM initialization.
- Confirmed upstream A523 TF-A can hand off to U-Boot 2026.07.
- Built Linux 7.2 and Buildroot 2026.05.1 with Avaota board files.
- Defined the 8 KiB / 16 MiB / 256 MiB raw layout.

## 2026-08-27 — eMMC cold-boot closure

- Isolated FES Boot0 programming from the raw user-area write.
- Diagnosed Boot0 startup followed by failed user-area FIT access.
- Added explicit Boot1 → user-area switching in SPL.
- Added conservative 25 MHz MMC2 operation and failure diagnostics.
- Avoided unreliable high relocation by capping U-Boot relocation at 0x50000000.
- Added Linux MMC2 `no-sd`, `no-sdio` and 25 MHz constraints.
- Replaced the root label argument with the verified `/dev/mmcblk1p2`.
- FES wrote and verified the 768 MiB image.
- A power-cycle cold boot reached Linux 7.2 and the Buildroot login prompt.

## Repository cleanup

- Kept only final source/configuration changes.
- Classified SyterKit and vendor chains as rejected experiments.
- Excluded loaders without clear redistribution permission.
- Added pinned downloads, structural verification and FES automation.

## 2026-08-27 — repository reproduction

- Bootstrapped all pinned sources into an empty output tree and completed the
  TF-A, U-Boot 2026.07, Linux 7.2 and Buildroot 2026.05.1 build.
- Fixed permanent board files that had drifted from the successful build:
  the Buildroot U-Boot source directory and init-script exit status.
- Added an explicit `CLEAN_BUILD=0` recovery path for a host-interrupted build;
  clean output remains the default and release requirement.
- Passed the artifact verifier for eGON, FIT, raw offsets, FAT/ext4 contents,
  effective kernel configuration and installed modules.
- The software-verified image SHA-256 is
  `ee4935777ce2468c539c7219a0fb507ae41d424eca6ea94ec4090106740bd9c1`.
  It has not replaced the separately recorded hardware-qualified image.

## 2026-09-01 — stable 4-bit v6 and dedicated loader

- Decoded failed MMC transfers with `rint=0x40ac` as data CRC errors, not only
  request-size timeouts.
- Confirmed 8-bit still failed at 25 MHz and 128-block requests.
- Unified SPL, U-Boot proper and Linux MMC2 at 4-bit/25 MHz; removed Linux
  HS200 and DDR capabilities.
- Retained explicit eMMC user-area selection, 128-block cap, one bounded retry
  and safe U-Boot RAM top.
- Rebuilt U-Boot and Linux DTB and assembled the v6 hardware candidate while
  preserving the known kernel, extlinux file and complete rootfs bytes.
- Replaced the 714 MiB installer-as-loader shortcut with a deterministic
  1,337,344-byte IMAGEWTY loader containing exactly five files and no MBR or
  partitions.
- Reused the exact Tina `sunxi.fex` from the bootstrap set that previously
  completed FEL→FES; rejected a different unqualified current-pack DTB.
- Passed loader unpack comparison, SPL checksum, embedded U-Boot/DTB checks,
  FAT/ext4 fsck and OpenixCLI no-device raw preflight.
- v6 remains offline-verified until a new FES write and cold boot are recorded.
