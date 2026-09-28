# 2026-09-28 MMC/PMIC power-cycle timing incident

## Summary

Reflashing the published v9 raw image with its recorded SHA-256 reproduced a
continuous cold-boot reset loop. SPL consistently read the eMMC user area,
loaded the FIT, entered TF-A and reached U-Boot proper. The reset occurred while
U-Boot was initializing MMC2 for the FAT environment:

```text
Loading Environment from FAT...
LYNX_MMC_IOS: mmc=2 width=0 clock=0 ...
```

The next visible output was a new SPL banner. This rules out a corrupt raw
image, missing Boot0 installation, failed FIT read, TF-A handoff failure and
Linux/rootfs failure.

## Artifact and source recovery

The local v9 artifact matches the published manifest exactly. A recovered
2026-08-27 component and thirteen other boot-component variants are preserved
outside the release tree in the 2026-09-28 evidence archive. The old candidate
and v9 embedded device trees both reference CLDO1 and CLDO3; their observed
eMMC device-tree difference is bus width 8 versus 4. Neither supply is marked
`regulator-always-on`.

The recovered evidence does not yet prove that a source change was omitted
from v9. Matching each recovered component to a complete successful UART log
remains necessary.

## Experiments

### Repeated eMMC hardware-reset hypothesis

An experimental build suppressed a repeated A523 MMC2 hardware reset inside a
single U-Boot instance. It produced the same reset loop at the same FAT
environment point. The hypothesis was rejected.

### MMC power-path trace

A second build restored the v9 reset code and added synchronous UART markers
before and after:

1. setting the MMC clock to zero;
2. disabling `vmmc` (`cldo3`);
3. disabling `vqmmc` (`cldo1`).

The complete raw image was written through FES with Boot0 sourced from the raw
image. OpenixCLI transferred 805,306,368 bytes and returned `errorCode=0`.

On the following cold boot, both regulator-disable calls returned zero and the
board continued through extlinux, Linux, the ext4 root filesystem and the
Buildroot login prompt. The same power-off sequence ran twice successfully.

## Root-cause assessment

The result proves that the failure is timing-sensitive in the MMC/PMIC power
cycle. Synchronous UART output adds several milliseconds between the clock and
CLDO operations, changing a repeatable reset into a successful boot. The
evidence does not yet identify one minimum delay or one rail as the sole cause.

The current strongest candidates are:

- insufficient settling time between disabling the MMC clock and CLDO3;
- insufficient spacing between the CLDO3 and CLDO1 PMIC writes;
- a transient caused by cycling rails shared with other board functions;
- a missing board-specific rule that keeps non-removable eMMC supplies on.

The diagnostic prints are not a production fix. A release fix should replace
them with an explicit, board-scoped policy and pass repeated cold boots.

## Required closure work

1. Build separate candidates that add explicit bounded delays at each boundary,
   then determine the first boundary that changes the outcome.
2. Compare that result with a candidate that keeps the eMMC supplies enabled
   during U-Boot's logical MMC power cycle.
3. Perform at least two complete power-removal cold boots for the selected fix.
4. Capture an unabridged UART transcript and publish exact bootloader/raw hashes.
5. Update the release status only after the fixed artifact passes the same FES,
   Boot0, filesystem and cold-boot gates.

The selected UART and flash evidence is recorded in
[`logs/mmc-power-timing-20260928.log`](../logs/mmc-power-timing-20260928.log).
