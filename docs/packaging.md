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

## 3. v6 硬件候选镜像的组装

当前 v6 硬件候选以已验证的 768 MiB 基准 raw 为底，只替换重新构建的
主线 U-Boot 和 Linux DTB：

```bash
cp --reflink=auto BASE.img avaota-a1-mainline-v6-stable-4bit.img
dd if=u-boot-sunxi-with-spl.bin \
  of=avaota-a1-mainline-v6-stable-4bit.img bs=8192 seek=1 conv=notrunc
mcopy -o -i 'avaota-a1-mainline-v6-stable-4bit.img@@16777216' \
  sun55i-t527-avaota-a1.dtb ::/sun55i-t527-avaota-a1.dtb
```

内核、extlinux 配置和整个 512 MiB rootfs 与基准镜像逐字节一致。

## 4. GitHub 发布

源码、配置、补丁、loader 输入和工具脚本进入 Git。768 MiB raw 不进入
Git 历史；发布时上传 `.img.xz`、独立 loader、`SHA256SUMS` 和 manifest
到 GitHub Release。
