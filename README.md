# Avaota A1 T527 Mainline Linux

Reproducible, source-first support for the Avaota A1 (Allwinner
T527/A523 family) using:

- U-Boot 2026.07
- Trusted Firmware-A from the upstream A523 development commit
- Linux 7.2
- Buildroot 2026.05.1
- Arm GNU AArch64 toolchain 10.3-2021.07
- eMMC root filesystem

The persistent boot chain is fully mainline. A board-matched Tina/IMAGEWTY
loader is used **only in RAM** to enter Allwinner FES and safely program eMMC.
SyterKit and vendor U-Boot are not part of the installed system.

## One-command build

On Ubuntu 24.04:

```bash
sudo apt install autoconf automake bc bison build-essential curl \
  device-tree-compiler dosfstools e2fsprogs flex git libssl-dev \
  mtools patch python3 python3-pyelftools python3-setuptools rsync \
  swig uuid-dev xz-utils
make build
```

默认执行干净构建。只有在同一源码锁定版本和同一工作树中续跑已中断的构建时，才使用
`CLEAN_BUILD=0 make build`；发布复现必须至少完成一次默认干净构建。

`scripts/bootstrap.sh` downloads the exact official release archives, verifies
their SHA-256 hashes, checks out the two pinned Git commits, applies the board
patches, and installs the Buildroot board files. Generated sources and images
remain in `.work/` and `out/`; neither is committed.

The result is:

```text
out/avaota-a1-full-mainline.img
out/avaota-a1-full-mainline.img.sha256
out/avaota-a1-full-mainline.img.xz
out/avaota-a1-full-mainline.manifest
```

## Flash through FES

Build OpenixCLI branch `feat/t527-mainline-emmc-fes` at the commit pinned in
`manifests/sources.lock`, connect the board in FEL, and provide a licensed,
board-matched loader:

```bash
export OPENIXCLI=/path/to/openixcli
export BOOTSTRAP_FIRMWARE=/path/to/avaota-a1-loader.img
export DEVICE_LOCATION=libusb:BUS:PORT   # optional but recommended
./scripts/flash.sh | tee flash.jsonl
```

The script refuses to flash unless the image passes the structural verifier.
It requests:

1. RAM-only FEL to FES bootstrap.
2. eMMC storage/capacity preflight.
3. mainline SPL extraction from image offset 8 KiB.
4. FES Boot0 programming.
5. raw eMMC user-area image write.
6. FES verification.
7. `post-action=none`, so power cycling remains an explicit hardware action.

The loader is not stored here because its redistribution licence has not been
established. See [FES flashing](docs/fes-flashing.md).

## Verified hardware

- Board: Avaota A1 T527
- DRAM: 4 GiB
- Storage: 58.2 GiB eMMC; Boot0/Boot1 each 4 MiB
- Console: UART0, 115200
- Cold boot: BootROM → eMMC Boot0 mainline SPL → TF-A → U-Boot 2026.07 →
  Linux 7.2 → `/dev/mmcblk1p2` Buildroot

The successful cold-boot transcript and compact FES record are under `logs/`.
The exact flashed 768 MiB image had SHA-256
`7e2b0c34dde11dd0a73a810e6918640a941a703433a23f501c807e9d055b6bae`.

## Documentation

- [Hardware and storage](docs/hardware.md)
- [Boot chain and image layout](docs/boot-chain.md)
- [Porting order](docs/porting-order.md)
- [FES flashing](docs/fes-flashing.md)
- [Failures and fixes](docs/failures-and-fixes.md)
- [Reproducibility and validation](docs/reproducibility.md)
- [Development journal](docs/development-journal.md)

## Status

The final hardware image has completed an FES write/verify and a power-cycle
cold boot to login. A clean-output repository build and structural artifact
verification also pass. The newly rebuilt image is marked software-verified,
not hardware-qualified; every source-lock or patch change still requires the
FES and cold-boot gates before its hash can replace the qualified artifact.
