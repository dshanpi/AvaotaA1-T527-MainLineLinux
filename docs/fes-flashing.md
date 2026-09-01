# FES 烧录

## 唯一支持路径

```text
BootROM FEL (1f3a:efe8)
  → 1.28 MiB 专用 IMAGEWTY loader，仅下载到 RAM
  → FES/SRV 重新枚举
  → 查询 eMMC 类型与容量
  → 校验并安装 mainline raw@0x2000 SPL 到 Boot0
  → 写完整 raw 到 eMMC user area
  → 整盘读回验证
  → 明确冷断电
```

不要使用完整 `installer_v3.img`，不要走普通 IMAGEWTY 分区烧录，也不要
使用 NAND component 模式。

OpenixCLI 命令合同：

```bash
openixcli --output jsonl raw \
  avaota-a1-t527-fes-loader.img \
  avaota-a1-mainline-v6-stable-4bit.img \
  --mode command \
  --emmc-boot0-from-image \
  --device-location libusb:BUS:DEVICE
```

仓库的 `scripts/flash.sh` 在执行该命令前验证 loader、raw 和 USB 所有权。

## Loader 写入边界

独立 loader 只有 `fes1.fex`、`u-boot.fex`、`config.fex`、`board.fex`
和 `sunxi.fex`。它没有 MBR 或任何分区，OpenixCLI 只从中提取 DRAM/FES
启动数据。持久介质写入内容只来自第二个参数的 mainline raw。

仓库所有者已确认可以公开备份和分发该 Tina 派生的小 loader。来源及第三方
权利边界记录在 `loader/t527-fes/PROVENANCE.md`。

## 安全规则

- LYNX GUI 和 OpenixCLI 不能同时占用 USB。
- 默认要求恰好一个 `1f3a:efe8` FEL 设备。
- 必须绑定具体 libusb 位置。
- FES 必须报告 eMMC，容量必须大于 raw。
- FEL→FES 失败后不能自动重试；先手动重新进入 FEL。
- Boot0 状态验证和 user-area 全镜像验证是两个不同门槛。
- 烧录完成后必须冷断电测试，FES 成功不等于 BootROM 冷启动成功。
