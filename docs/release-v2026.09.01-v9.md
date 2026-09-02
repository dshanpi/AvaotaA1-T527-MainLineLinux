# v2026.09.01-v9-tm4-coldboot

这是 Avaota A1 / Allwinner T527 主线 Linux 的首个完成两次 eMMC 冷启动实机
验收的 TM4 修复版本。

## 验收结果

- OpenixCLI/FES 写入并验证完整 805,306,368 字节 raw，`errorCode=0`。
- BootROM 从 eMMC Boot0 启动主线 U-Boot SPL 2026.07。
- SPL 从 eMMC user area 成功读取 FIT，进入 TF-A 和 U-Boot proper。
- U-Boot 从 FAT 分区读取 Linux 7.2 Image、T527 DTB 和 extlinux 配置。
- Linux 识别 58.2 GiB eMMC、`p1`/`p2`，以读写方式挂载
  `/dev/mmcblk1p2`，启动 Buildroot 2026.05.1 并进入 root shell。
- 完整断电后的第二次启动再次通过；ext4 journal recovery 正常完成。

## 应下载的文件

- `avaota-a1-mainline-v9-tm4-coldboot.img.xz`：写入 eMMC user area 的主线系统。
- `avaota-a1-t527-fes-loader.img`：只在 RAM 中运行的 FEL→FES loader。
- `avaota-a1-mainline-v9-u-boot-sunxi-with-spl.bin`：镜像内同版本启动组件备份。
- `openixcli-linux-x86_64`：本次实机烧录使用并固定哈希的 OpenixCLI。
- `SHA256SUMS`、`release.manifest`：文件哈希、尺寸和构建/验收元数据。
- `t527-v9-flash-20260901.jsonl`：本次成功烧录的原始机器日志。

解压并核对：

```bash
sha256sum -c SHA256SUMS
unxz avaota-a1-mainline-v9-tm4-coldboot.img.xz
```

烧录必须同时提供小 loader 和解压后的 raw：

```bash
chmod +x openixcli-linux-x86_64
./openixcli-linux-x86_64 --output jsonl raw \
  avaota-a1-t527-fes-loader.img \
  avaota-a1-mainline-v9-tm4-coldboot.img \
  --mode command \
  --emmc-boot0-from-image \
  --device-location libusb:BUS:PORT
```

`BUS:PORT` 必须取 OpenixCLI `scan` 输出的 `Physical location`，不是 `lsusb`
显示的临时 Device 编号。烧录完成后彻底断电再上电验收。

## 作用域与已知状态

修复只作用于 T527（主线内部 `SUN55I_A523` 族名）的 SPL/U-Boot MMC2
冷启动路径；OpenixCLI 没有修改。Linux、DTB、extlinux 和 rootfs 与先前已
进入过文件系统的内容逐字节一致。

当前启动与 eMMC/rootfs 已通过。有线网络驱动能枚举 `eth0`/`eth1`，但本次
日志中启动脚本等待接口超时、MDIO address 1 未发现，尚未作为本版本验收项。
