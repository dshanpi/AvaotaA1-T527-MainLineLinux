# Boot chain and image layout

## Persistent chain

```text
Allwinner BootROM
  → eMMC Boot0: U-Boot 2026.07 SPL
  → eMMC user area: U-Boot FIT + upstream A523 TF-A
  → U-Boot proper 2026.07
  → FAT partition: Linux 7.2 Image + DTB + extlinux.conf
  → ext4 partition: Buildroot 2026.05.1
```

The FES loader is only a programming transport and is absent after a cold
power cycle.

## User-area image

| Offset | Content |
| ---: | --- |
| 8 KiB | `u-boot-sunxi-with-spl.bin` |
| 16 MiB | 240 MiB FAT32 boot partition |
| 256 MiB | 512 MiB ext4 root partition |

SPL calculates the U-Boot FIT sector from its eGON length. On this SoC a
BootROM load from eMMC Boot0 can leave controller/card selection state
inconsistent with the cached block descriptor. The U-Boot patch forces a real
Boot1 → user-area transition before loading the raw FIT.

U-Boot relocation just below the 4 GiB boundary caused command text corruption
on this board. `board_get_usable_ram_top()` therefore keeps U-Boot relocation
below `0x50000000`, while Linux still receives the full 4 GiB memory map.
