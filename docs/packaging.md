# 打包流程

发布物由两条互不混合的构建链产生。

## 1. RAM-only FES loader

输入固定在 `loader/t527-fes/inputs/`：

```text
config.fex   编译后的板级/DRAM sys_config
board.fex    board config
sunxi.fex    已成功 FEL→FES 的板级 FES U-Boot DTB
u-boot.fex   在 RAM 中运行的 Tina USB/FES U-Boot
fes1.fex     FEL 阶段 DRAM 初始化程序
```

`loader/t527-fes/image.cfg` 只声明这五项；`sys_partition.fex` 没有任何
分区。构建命令：

```bash
TINA_SDK_ROOT=/absolute/path/to/AvaotaA1-Tina5-SDK_V1 make loader
```

核心工具调用：

```bash
dragon image.cfg sys_partition.fex
```

`scripts/verify-loader.sh` 会解析 IMAGEWTY v3 文件头、五个条目的
maintype/subtype、长度和内容 SHA-256。固定输出：

```text
size=1337344
sha256=867d43d12399016252a3d34c2ae50f6f362868f95c2985169d5a4b655a16417c
```

## 2. Mainline raw

`scripts/bootstrap.sh` 获取并锁定 Buildroot、Linux、U-Boot、工具链、
TF-A 和 libxcrypt，随后应用 `patches/` 中的板级补丁。

Buildroot 的 `genimage` 布局：

```text
0x00000000  DOS MBR
0x00002000  u-boot-sunxi-with-spl.bin
0x01000000  240 MiB FAT：Image、DTB、extlinux.conf
0x10000000  512 MiB ext4 Buildroot rootfs
```

`make build` 依次构建 TF-A、U-Boot 和 Buildroot，再执行结构验证。loader
不嵌入 raw；raw 中 8 KiB 处的 SPL/U-Boot 是断电后的持久启动组件。

## 3. v9 TM4 冷启动实机验证镜像的组装

根据实机证据，v9 只替换发生冷启动失败的 SPL/U-Boot；Linux、DTB、boot.vfat
和 rootfs.ext4 与已写入成功且进入过文件系统的 v7 逐字节保持一致：

```bash
cp --reflink=auto avaota-a1-mainline-v7-tm4-csdc.img \
  avaota-a1-mainline-v9-tm4-coldboot.img
dd if=u-boot-sunxi-with-spl.bin \
  of=avaota-a1-mainline-v9-tm4-coldboot.img bs=8192 seek=1 conv=notrunc
```

验证器检查 U-Boot/SPL 包含 TM4 与自动 FEL 恢复路径，并逐字节证明 v9 在
U-Boot 占用区之外与 v7 相同；FAT、Image、DTB、ext4 不重新生成。

实机验收所用 raw 的 SHA-256 固定为
`22d9775202898f55814bee156058d8d010c2461f67cb11e7dc35c8c8c609d5f2`。
发布脚本拒绝打包任何哈希不同的 raw、loader 或 U-Boot，防止把“重新编译但
尚未上板”的产物误标成实机验证版本。

## 4. GitHub 发布

源码、配置、补丁、loader 输入和工具脚本进入 Git。768 MiB raw 不进入
Git 历史；发布时上传 `.img.xz`、独立 loader、对应的 U-Boot/SPL、
`SHA256SUMS` 和 manifest 到 GitHub Release。
