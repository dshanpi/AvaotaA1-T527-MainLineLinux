#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

for tool in install sha256sum stat xz; do need "$tool"; done

source_image="$out_dir/avaota-a1-full-mainline.img"
source_loader="$out_dir/avaota-a1-t527-fes-loader.img"
release_dir="$out_dir/release-v6-stable-4bit"
release_image="$release_dir/avaota-a1-mainline-v6-stable-4bit.img"
release_loader="$release_dir/avaota-a1-t527-fes-loader.img"

[ -s "$source_image" ] || die "missing verified image: $source_image"
[ -s "$source_loader" ] || \
	die "missing dedicated FES loader: $source_loader (run make loader)"
mkdir -p "$release_dir"
install -m 0644 "$source_image" "$release_image"

"$repo_dir/scripts/verify-loader.sh" "$source_loader"
install -m 0644 "$source_loader" "$release_loader"

xz -T0 -6 -k -f "$release_image"
(
	cd "$release_dir"
	# SHA256SUMS lists the files uploaded to GitHub Release.  The hash of the
	# uncompressed raw remains in release.manifest and is checked after unxz.
	sha256sum avaota-a1-mainline-v6-stable-4bit.img.xz > SHA256SUMS
	sha256sum avaota-a1-t527-fes-loader.img >> SHA256SUMS
)

cat > "$release_dir/release.manifest" <<EOF
release=v2026.09.01-v6-stable-4bit
status=offline-verified-pending-hardware-flash-and-cold-boot
raw=avaota-a1-mainline-v6-stable-4bit.img
raw_sha256=$(sha256sum "$release_image" | awk '{print $1}')
raw_size=$(stat -c %s "$release_image")
compressed=avaota-a1-mainline-v6-stable-4bit.img.xz
compressed_sha256=$(sha256sum "$release_image.xz" | awk '{print $1}')
compressed_size=$(stat -c %s "$release_image.xz")
loader=avaota-a1-t527-fes-loader.img
loader_sha256=867d43d12399016252a3d34c2ae50f6f362868f95c2985169d5a4b655a16417c
loader_size=1337344
loader_format=IMAGEWTY-v3-five-files-zero-partitions-RAM-only
buildroot=2026.05.1
linux=7.2
u_boot=2026.07
trusted_firmware_a_commit=$(source_field trusted-firmware-a 5)
toolchain=Arm-GNU-10.3-2021.07
emmc_profile=4-bit,25MHz,SDR-only,b_max-128,one-bounded-retry
layout=bootloader@8KiB,boot-fat@16MiB,rootfs-ext4@256MiB
root_device=/dev/mmcblk1p2
EOF

printf 'Release package written under %s\n' "$release_dir"
