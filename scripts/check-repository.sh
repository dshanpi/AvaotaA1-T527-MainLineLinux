#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

for tool in git patch; do need "$tool"; done
if grep -q '|PENDING$' "$lock_file"; then
	die "sources.lock still contains a PENDING hash"
fi

for script in "$repo_dir"/scripts/*.sh \
	"$repo_dir"/board/avaota/a1-mainline/post-build.sh \
	"$repo_dir"/board/avaota/a1-mainline/rootfs-overlay/etc/init.d/*; do
	bash -n "$script"
done

DOWNLOAD_DIR=${DOWNLOAD_DIR:-"$cache_dir"} "$repo_dir/scripts/bootstrap.sh"
patch -d "$work_dir/linux-7.2" -p1 --dry-run -R \
	< "$repo_dir/patches/linux/0001-avaota-a1-emmc-mainline-fix.patch"
patch -d "$work_dir/u-boot-2026.07" -p1 --dry-run -R \
	< "$repo_dir/patches/u-boot/0001-avaota-a1-emmc-coldboot-fixes.patch"

grep -q 'root=/dev/mmcblk1p2' \
	"$work_dir/buildroot-2026.05.1/board/avaota/a1-mainline/rootfs-overlay/boot/extlinux/extlinux.conf"
grep -q 'BR2_TOOLCHAIN_EXTERNAL_PATH="$(TOPDIR)/../gcc-arm-10.3' \
	"$work_dir/buildroot-2026.05.1/configs/avaota_a1_mainline_defconfig"

printf 'Repository source contract PASS\n'
