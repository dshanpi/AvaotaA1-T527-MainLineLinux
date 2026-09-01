# 失败原因与最终修复

| 现象 | 根因 | 最终修复 |
|---|---|---|
| SPL 从 Boot0 启动后 FIT 读取失败 | 控制器/卡仍残留 boot-access 状态，但缓存块设备认为在 user area | 在 raw FIT 读取前强制 Boot1→user area 的真实切换 |
| `CMD18` 返回 `rint=0x40ac` | `0x80 DATA_CRC_ERROR`，8-bit MMC2 数据路径不稳定 | SPL、U-Boot、Linux 全部强制 4-bit |
| 25 MHz、128 块仍失败 | 问题不是单次长度或纯超时，而是 8-bit 数据 CRC | 保持 25 MHz/SDR，禁用 HS200/DDR，并保留一次有限重试 |
| U-Boot relocation 后同步异常/命令损坏 | 4 GiB 边界附近 relocation 不可靠 | U-Boot usable RAM top 限制到 `0x50000000`，Linux 仍看到 4 GiB |
| Linux 等待 root | 早期环境中 label 解析不稳定 | 使用已验证的 `/dev/mmcblk1p2` |
| MMC2 探测含糊 | eMMC 节点仍允许 SD/SDIO 语义 | 增加 `no-sd`、`no-sdio`、`non-removable` |
| FES 报成功但冷启动失败 | 传输验证不覆盖 BootROM→SPL→FIT→rootfs | 冷断电 UART 启动到登录提示符作为独立门槛 |
| FEL→FES USB 节点变化 | 重新枚举后 device address 改变 | 锁定物理 libusb 位置，仅允许唯一匹配设备 |
| loader 体积 714 MiB、边界混乱 | 把完整 installer 当作 RAM loader 容器 | 改为 1.28 MiB、5 文件、0 分区的独立 FES loader |

所有带 `diag`、`safe25`、`force-user`、`bmax`、SyterKit 或完整 installer
的中间镜像只用于定位问题，不属于发布输入。
