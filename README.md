# Avaota A1 / T527 Mainline Linux

面向 Avaota A1（Allwinner T527/A523）的可复现主线启动与烧录工程：

- U-Boot 2026.07
- Trusted Firmware-A（A523 主线开发提交）
- Linux 7.2
- Buildroot 2026.05.1
- Arm GNU AArch64 10.3-2021.07
- eMMC 持久启动

持久系统全部是主线组件。Tina 派生组件只组成一个 1.28 MiB 的专用
RAM loader，用于从 BootROM FEL 进入 FES/SRV，永远不写入 eMMC。

## 两个且仅两个烧录输入

| 文件 | 内容 | 目标 |
|---|---|---|
| `avaota-a1-t527-fes-loader.img` | 5 个板卡匹配的 Tina FES 启动条目，0 分区 | 只进入 RAM |
| `avaota-a1-mainline-v9-tm4-coldboot.img` | 主线 SPL/FIT、FAT 内核分区、ext4 rootfs | 写入 eMMC |

旧的完整 `installer_v3.img` 已从本流程废弃，不能再作为 loader 或最终固件。

## 稳定 eMMC 配置

现场日志确认 MMC2 的 `CMD18` 在 4-bit/25 MHz 下仍出现 `DATA_CRC_ERROR`，
因此根因不是单纯的总线宽度、频率或单次块数。v9 对照 Tina v0x50500/TM4
驱动修复 SPL/U-Boot，同时保留已经进入过文件系统的 Linux、DTB 和 rootfs：

```text
SPL             4-bit / 25 MHz / b_max=128
U-Boot proper   4-bit / 25 MHz / b_max=128
Linux           沿用 v7 已工作内容（不改驱动）
SPL/U-Boot TM4  1x / output 180° / sample delay 0 + SW enable
重试策略         一次有限读重试，不循环
失败恢复         SPL 自动返回 BootROM FEL
```

## 构建主线 raw

Ubuntu 24.04 依赖：

```bash
sudo apt install autoconf automake bc bison build-essential curl \
  device-tree-compiler dosfstools e2fsprogs flex git libssl-dev \
  mtools patch python3 python3-pyelftools python3-setuptools rsync \
  swig uuid-dev xz-utils
make build
```

默认是干净构建。只有在源码和锁定文件完全未变、仅续跑被中断的同一工作树时，
才使用：

```bash
CLEAN_BUILD=0 make build
```

## 构建独立 FES loader

仓库保存了已完成过 FEL→FES 转换的五个精确 Tina 输入及其哈希，但不复制
Tina `dragon` 工具。提供 Tina 5 SDK 根目录即可确定性重建：

```bash
TINA_SDK_ROOT=/absolute/path/to/AvaotaA1-Tina5-SDK_V1 make loader
make verify-loader
```

loader 合同：IMAGEWTY v3、未加密、恰好 5 个文件、0 分区、无 MBR、无
Boot0、无内核、无 rootfs。

## 打包发布文件

```bash
make package
```

生成目录：

```text
out/release-v9-tm4-coldboot/
├── avaota-a1-mainline-v9-tm4-coldboot.img
├── avaota-a1-mainline-v9-tm4-coldboot.img.xz
├── avaota-a1-t527-fes-loader.img
├── avaota-a1-mainline-v9-u-boot-sunxi-with-spl.bin
├── openixcli-linux-x86_64        # 设置 OPENIXCLI_BIN 时一并归档
├── SHA256SUMS
└── release.manifest
```

## FEL/FES 烧录

准备支持 `raw` 与 `--emmc-boot0-from-image` 的 OpenixCLI。关闭 LYNX GUI，
让板子进入 FEL（USB `1f3a:efe8`），然后运行：

```bash
export OPENIXCLI=/absolute/path/to/openixcli
./scripts/flash.sh
```

烧录 Release 文件时显式指定：

```bash
export OPENIXCLI=/absolute/path/to/openixcli
export FES_LOADER=/path/to/avaota-a1-t527-fes-loader.img
export IMAGE=/path/to/avaota-a1-mainline-v9-tm4-coldboot.img
export IMAGE_SHA256=<release.manifest 中的 raw_sha256>
./scripts/flash.sh
```

脚本强制执行 loader/镜像验证、OpenixCLI 固定哈希、单 FEL 设备约束和 USB
占用检查。若 FEL→FES 失败，不得直接重跑；若失败发生在新 SPL 的 eMMC
读取阶段，SPL 会尝试自动返回 BootROM FEL。

完整数据流：

```text
BootROM FEL
  → 小 loader 进入 RAM
  → FES/SRV
  → eMMC 类型和容量预检
  → 安装 raw@0x2000 的主线 SPL 到 Boot0
  → 从物理 sector 0 写主线 raw 到 user area
  → 整盘验证
  → 冷断电再上电
  → 主线 SPL → TF-A → U-Boot → Linux → Buildroot
```

## 状态

- 2026-08-27 基准镜像完成过 FES 写入、校验和冷启动到登录提示符。
- 2026-09-01 v6/v7 的真实冷启动日志证明仅切换 user area、4-bit、25 MHz 和
  小块读取仍不足以消除 CRC；这些镜像已废弃。
- 2026-09-01 v9 加入 T527（主线内部使用 `SUN55I_A523` 族名）MMC2 的 TM4
  冷启动初始化；Linux、DTB、extlinux 和 rootfs 沿用已工作内容。
- v9 在 2026-09-01 的记录中完成过 FES 整盘写入/校验，并连续两次冷启动进入
  Buildroot root shell。2026-09-28 使用相同发布哈希重新烧写时，复现了 U-Boot
  FAT 环境初始化阶段的循环复位。加入 MMC/PMIC 电源路径串口标记后可启动，
  证明该路径存在时序竞争；正式修复仍需重复冷启动验收。

## 文档

- [打包流程](docs/packaging.md)
- [启动链与磁盘布局](docs/boot-chain.md)
- [FES 烧录](docs/fes-flashing.md)
- [失败原因与修复](docs/failures-and-fixes.md)
- [复现与验证](docs/reproducibility.md)
- [硬件信息](docs/hardware.md)
- [移植顺序](docs/porting-order.md)
- [开发记录](docs/development-journal.md)
- [v9 实机验收记录](logs/successful-v9-cold-boot-20260901.log)
- [2026-09-28 MMC/PMIC 时序事件](docs/incident-20260928-mmc-power-timing.md)
