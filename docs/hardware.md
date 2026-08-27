# Hardware

| Item | Verified value |
| --- | --- |
| Board | Avaota A1 |
| SoC | Allwinner T527 / A523 family (`SUN55I`) |
| CPU | 8 × Cortex-A55 |
| DRAM | 4 GiB |
| Console | UART0 at `0x02500000`, 115200 |
| eMMC | Linux `mmc1`, `/dev/mmcblk1`, 58.2 GiB |
| eMMC boot areas | `/dev/mmcblk1boot0`, `/dev/mmcblk1boot1`, 4 MiB each |
| Root filesystem | eMMC user partition 2, ext4 |

The Linux device tree marks MMC2 non-removable, excludes SD/SDIO probing and
temporarily limits the bus to 25 MHz. Linux later negotiates HS200 successfully.
The conservative ceiling is intentional until the T527 MMC2 sampling delay is
characterized across boards and temperatures.

Do not infer Linux block numbering from the U-Boot device number. On the
verified board U-Boot scans `mmc 1`, while Linux exposes the same eMMC as
`/dev/mmcblk1`.
