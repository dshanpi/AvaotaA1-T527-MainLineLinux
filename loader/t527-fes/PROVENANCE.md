# T527 RAM-only FES loader provenance

The five `.fex` inputs in this directory are board-matched Tina 5 SDK
artifacts for the Avaota A1/T527. They were taken from the same IMAGEWTY
bootstrap set that successfully completed the FEL-to-FES transition on the
hardware under test.

They are used only to initialize DRAM and run the Tina USB/FES service in RAM:

| File | Purpose |
|---|---|
| `fes1.fex` | BootROM FEL DRAM initialization helper |
| `u-boot.fex` | Tina USB-product/FES U-Boot, executed in RAM |
| `config.fex` | Compiled board and DRAM configuration |
| `board.fex` | Board configuration block |
| `sunxi.fex` | Board-matched FES U-Boot DTB |

The generated loader has no Boot0, MBR, partitions, kernel, root filesystem or
installer payload. OpenixCLI never writes the loader to target storage.

The Tina `dragon` executable is not copied into this repository. Supply a Tina
5 SDK root through `TINA_SDK_ROOT` when rebuilding. Redistribution of this
minimal Tina-derived loader and its five inputs was explicitly authorized by
the repository owner on 2026-09-01. This notice does not relicense third-party
components beyond the rights held by their respective owners.
