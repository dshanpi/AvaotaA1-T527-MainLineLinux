# FES flashing

## Supported path

```text
BootROM FEL
  → board-matched Tina/IMAGEWTY loader in RAM
  → FES storage detection
  → FES eMMC Boot0 write
  → FES raw user-area write
  → FES verify
  → explicit power cycle
  → persistent pure-mainline system
```

The bootstrap firmware initializes DRAM and starts FES. It is not copied into
the final OS. Its board and DRAM parameters must match the target.

`scripts/flash.sh` requires OpenixCLI raw mode with
`--emmc-boot0-from-image`. NAND component mode is unrelated and must never be
used for T527 eMMC. Conversely, the eMMC raw path must not be reused for raw
SPI-NAND.

The hardware-qualified OpenixCLI and libefex revisions are pinned in
`manifests/sources.lock`. The libefex revision also carries the case-correct
MinGW `setupapi.h` include used to build the Windows CLI from Linux.

## Loader licensing

The tested loader was extracted from a Tina/IMAGEWTY package whose standalone
redistribution licence could not be identified. It is therefore deliberately
excluded from this public repository. Users must supply a loader from their
licensed SDK or board package.

## Safety rules

- Bind to the USB physical location when more than one Allwinner device exists.
- Reject targets that do not report eMMC.
- Reject images larger than the probed capacity.
- Do not silently retry after a USB/FES failure; return the board to FEL.
- Keep `post-action=none` for validation so the power cycle is observable.
- Treat Boot0 status verification separately from user-area byte verification.
