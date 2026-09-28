# 失败原因与最终修复

| 现象 | 根因 | 最终修复 |
|---|---|---|
| SPL 从 Boot0 启动后 FIT 读取失败 | 控制器/卡仍残留 boot-access 状态，但缓存块设备认为在 user area | 在 raw FIT 读取前强制 Boot1→user area 的真实切换 |
| `CMD18` 返回 `rint=0x40ac` | `0x80 DATA_CRC_ERROR`；4-bit/25 MHz 下也复现，排除单纯 8-bit 或超时问题 | 对照 Tina v0x50500/TM4 驱动，补齐 1x 模式、180° 输出相位、采样延迟和控制器初始化 |
| 从 FES 写完后偶尔能读，真正冷断电失败 | FES/Tina 已初始化过 MMC2，暖状态掩盖了主线驱动的 TM4 初始化缺失 | 只以断电冷启动为准；SPL 和 U-Boot proper 都独立完成 A523 MMC2 初始化 |
| 25 MHz、128 块、4-bit | 这些是降低变量的保守边界，不是 CRC 根因 | 继续保持 SDR/25 MHz/4-bit、禁用 HS200/DDR，并保留一次有限重试；稳定后再单独做性能调优 |
| U-Boot relocation 后同步异常/命令损坏 | 4 GiB 边界附近 relocation 不可靠 | U-Boot usable RAM top 限制到 `0x50000000`，Linux 仍看到 4 GiB |
| Linux 等待 root | 设备号与 root 参数必须和已验证镜像一致 | v9 原样保留已进入文件系统的 v7 参数 `root=/dev/mmcblk1p2 rootwait` |
| MMC2 探测含糊 | eMMC 节点仍允许 SD/SDIO 语义 | 增加 `no-sd`、`no-sdio`、`non-removable` |
| FES 报成功但冷启动失败 | 传输验证不覆盖 BootROM→SPL→FIT→rootfs | 冷断电 UART 启动到登录提示符作为独立门槛 |
| SPL 失败后停在 `Please RESET`，再次进 FEL 很麻烦 | 默认启动顺序只尝试原启动介质 | 仅 T527/A523-family SPL 在 eMMC 失败后追加标准 `BOOT_DEVICE_BOARD`，自动返回 BootROM FEL |
| FEL→FES USB 节点变化 | 重新枚举后 device address 改变 | 锁定物理 libusb 位置，仅允许唯一匹配设备 |
| loader 体积 714 MiB、边界混乱 | 把完整 installer 当作 RAM loader 容器 | 改为 1.28 MiB、5 文件、0 分区的独立 FES loader |
| v9 在 FAT 环境初始化时循环复位 | U-Boot MMC2 电源循环存在时序竞争；在时钟、CLDO3、CLDO1 操作之间加入同步 UART 输出后可启动 | 已定位但尚未形成发布修复；需要用显式延时或保持 eMMC 供电的板级策略替代诊断打印，并完成重复冷启动验收 |

所有带 `diag`、`safe25`、`force-user`、`bmax`、SyterKit 或完整 installer
的中间镜像只用于定位问题，不属于发布输入。

修复作用域刻意限定在 T527（主线内部 `SUN55I_A523` 族名）的 SPL/U-Boot
MMC2/eMMC：Linux 沿用已经进入过文件系统的原镜像，MMC0/MMC1 以及 OpenixCLI
共用烧录逻辑均不改变。最终候选必须同时通过 eGON/FIT、分区偏移、FAT、ext4
和 SHA-256 校验，实机验收则必须是彻底断电后的 BootROM → SPL → FIT →
U-Boot → Linux → 登录提示符完整链路。

2026-09-28 的复现和诊断见
[`incident-20260928-mmc-power-timing.md`](incident-20260928-mmc-power-timing.md)。
