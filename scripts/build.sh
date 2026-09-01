#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
"$repo_dir/scripts/bootstrap.sh"

for tool in bc bison flex make openssl python3; do need "$tool"; done
jobs=${JOBS:-$(nproc)}
case "$jobs" in ''|*[!0-9]*) die "JOBS must be a positive integer";; esac
[ "$jobs" -gt 0 ] || die "JOBS must be a positive integer"
clean_build=${CLEAN_BUILD:-1}
case "$clean_build" in 0|1) ;; *) die "CLEAN_BUILD must be 0 or 1";; esac

toolchain="$work_dir/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu"
cross="$toolchain/bin/aarch64-none-linux-gnu-"
tfa="$work_dir/trusted-firmware-a-a523"
uboot="$work_dir/u-boot-2026.07"
buildroot="$work_dir/buildroot-2026.05.1"
[ -x "${cross}gcc" ] || die "toolchain is incomplete"

[ "$clean_build" -eq 0 ] || make -C "$tfa" clean
make -C "$tfa" -j"$jobs" CROSS_COMPILE="$cross" PLAT=sun55i_a523 \
	DEBUG=1 SUNXI_PSCI_USE_SCPI=0 SUNXI_PSCI_USE_NATIVE=1 bl31
bl31="$tfa/build/sun55i_a523/debug/bl31.bin"
[ -s "$bl31" ] || die "TF-A did not produce BL31"

[ "$clean_build" -eq 0 ] || make -C "$uboot" ARCH=arm CROSS_COMPILE="$cross" distclean
make -C "$uboot" ARCH=arm CROSS_COMPILE="$cross" avaota-a1_defconfig
make -C "$uboot" -j"$jobs" ARCH=arm CROSS_COMPILE="$cross" BL31="$bl31" SCP= all
[ -s "$uboot/u-boot-sunxi-with-spl.bin" ] || die "U-Boot image is missing"

[ "$clean_build" -eq 0 ] || make -C "$buildroot" clean
make -C "$buildroot" avaota_a1_mainline_defconfig
make -C "$buildroot" -j"$jobs"

mkdir -p "$out_dir"
install -m 0644 "$buildroot/output/images/avaota-a1-full-mainline.img" "$out_dir/"
"$repo_dir/scripts/verify-artifacts.sh"

printf 'Build complete: %s/avaota-a1-full-mainline.img\n' "$out_dir"
printf 'Next: build the FES loader, then run make package\n'
