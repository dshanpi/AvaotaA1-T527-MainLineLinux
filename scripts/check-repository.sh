#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

for tool in git patch python3; do need "$tool"; done
if grep -q '|PENDING$' "$lock_file"; then
	die "sources.lock still contains a PENDING hash"
fi

for script in "$repo_dir"/scripts/*.sh \
	"$repo_dir"/board/avaota/a1-mainline/post-build.sh \
	"$repo_dir"/board/avaota/a1-mainline/rootfs-overlay/etc/init.d/*; do
	bash -n "$script"
done

(cd "$repo_dir/loader/t527-fes" && sha256sum -c SHA256SUMS)

BOOTSTRAP_SCOPE=source-check DOWNLOAD_DIR=${DOWNLOAD_DIR:-"$cache_dir"} \
	"$repo_dir/scripts/bootstrap.sh"
patch -d "$work_dir/linux-7.2" -p1 --dry-run -R \
	< "$repo_dir/patches/linux/0001-avaota-a1-emmc-mainline-fix.patch"
patch -d "$work_dir/u-boot-2026.07" -p1 --dry-run -R \
	< "$repo_dir/patches/u-boot/0001-avaota-a1-emmc-coldboot-fixes.patch"

grep -q 'root=/dev/mmcblk1p2' \
	"$work_dir/buildroot-2026.05.1/board/avaota/a1-mainline/rootfs-overlay/boot/extlinux/extlinux.conf"
grep -q 'BR2_TOOLCHAIN_EXTERNAL_PATH="$(TOPDIR)/../gcc-arm-10.3' \
	"$work_dir/buildroot-2026.05.1/configs/avaota_a1_mainline_defconfig"

grep -q 'bus-width = <4>;' \
	"$work_dir/u-boot-2026.07/dts/upstream/src/arm64/allwinner/sun55i-t527-avaota-a1.dts"
grep -q 'max-frequency = <25000000>;' \
	"$work_dir/u-boot-2026.07/dts/upstream/src/arm64/allwinner/sun55i-t527-avaota-a1.dts"
grep -q 'bus-width = <4>;' \
	"$work_dir/linux-7.2/arch/arm64/boot/dts/allwinner/sun55i-t527-avaota-a1.dts"
python3 - "$work_dir/linux-7.2/arch/arm64/boot/dts/allwinner/sun55i-t527-avaota-a1.dts" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"&mmc2\s*\{(.*?)\n\};", text, re.S)
if not match:
    raise SystemExit("Linux DTS has no &mmc2 override")
mmc2 = match.group(1)
for forbidden in ("mmc-ddr-1_8v", "mmc-hs200-1_8v"):
    if forbidden in mmc2:
        raise SystemExit(f"Linux mmc2 still advertises {forbidden}")
for required in ("no-sd;", "no-sdio;", "non-removable;"):
    if required not in mmc2:
        raise SystemExit(f"Linux mmc2 is missing {required}")
PY

printf 'Repository source contract PASS\n'
