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
| `avaota-a1-mainline-v6-stable-4bit.img` | 主线 SPL/FIT、FAT 内核分区、ext4 rootfs | 写入 eMMC |

旧的完整 `installer_v3.img` 已从本流程废弃，不能再作为 loader 或最终固件。

## 稳定 eMMC 配置

现场日志确认 MMC2 在 8-bit 数据传输时出现 `DATA_CRC_ERROR`；把时钟降到
25 MHz、把单次读降到 128 块仍不能消除。v6 因此统一采用：

```text
SPL             4-bit / 25 MHz / b_max=128
U-Boot proper   4-bit / 25 MHz / b_max=128
Linux           4-bit / 25 MHz / SDR-only
重试策略         一次有限读重试，不循环
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
out/release-v6-stable-4bit/
├── avaota-a1-mainline-v6-stable-4bit.img
├── avaota-a1-mainline-v6-stable-4bit.img.xz
├── avaota-a1-t527-fes-loader.img
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
export IMAGE=/path/to/avaota-a1-mainline-v6-stable-4bit.img
export IMAGE_SHA256=b61f688188a57283cf0f5606cf52aaded37b88ff254bce6d3ef79b0c40d32d09
./scripts/flash.sh
```

脚本强制执行 loader/镜像验证、单 FEL 设备约束和 USB 占用检查。若
FEL→FES 失败，不得直接重跑，必须手动重新进入 FEL。

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
- 2026-09-01 v6 stable-4bit 已完成构建、逐字节内容核对、SPL 校验、
  FAT/ext4 检查和 OpenixCLI 离线预检。
- v6 在完成新的实际烧录与冷启动前，状态是“离线验证通过，待硬件验收”。

## 文档

- [打包流程](docs/packaging.md)
- [启动链与磁盘布局](docs/boot-chain.md)
- [FES 烧录](docs/fes-flashing.md)
- [失败原因与修复](docs/failures-and-fixes.md)
- [复现与验证](docs/reproducibility.md)
- [硬件信息](docs/hardware.md)
- [移植顺序](docs/porting-order.md)
- [开发记录](docs/development-journal.md)
