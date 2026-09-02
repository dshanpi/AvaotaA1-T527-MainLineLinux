#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

for tool in install sha256sum stat xz; do need "$tool"; done

source_image=${IMAGE:-"$out_dir/avaota-a1-full-mainline.img"}
source_loader=${FES_LOADER:-"$out_dir/avaota-a1-t527-fes-loader.img"}
source_bootloader=${BOOTLOADER:-"$work_dir/u-boot-2026.07/u-boot-sunxi-with-spl.bin"}
source_openixcli=${OPENIXCLI_BIN:-}
source_flash_log=${FLASH_LOG:-}
release_dir="$out_dir/release-v9-tm4-coldboot"
release_image="$release_dir/avaota-a1-mainline-v9-tm4-coldboot.img"
release_loader="$release_dir/avaota-a1-t527-fes-loader.img"
release_bootloader="$release_dir/avaota-a1-mainline-v9-u-boot-sunxi-with-spl.bin"
expected_image_sha256=22d9775202898f55814bee156058d8d010c2461f67cb11e7dc35c8c8c609d5f2
expected_loader_sha256=867d43d12399016252a3d34c2ae50f6f362868f95c2985169d5a4b655a16417c
expected_bootloader_sha256=0d405263a5ea10bf97c64e5f07c5b04b11a484372ce1c8fd769980ca4e5b70c3
expected_openixcli_sha256=c370b3b5079ff67672728d127df57e1cb234e18a10febd4ca3cda36a635662ae
expected_flash_log_sha256=3f8064c3ad4b8acf7468cb2a0de932d4c8fbe59dbb9d0462f206aa9a0ad21d65

[ -s "$source_image" ] || die "missing verified image: $source_image"
[ -s "$source_loader" ] || \
	die "missing dedicated FES loader: $source_loader (run make loader)"
[ -s "$source_bootloader" ] || die "missing v9 U-Boot/SPL: $source_bootloader"
verify_sha256 "$source_image" "$expected_image_sha256"
verify_sha256 "$source_loader" "$expected_loader_sha256"
verify_sha256 "$source_bootloader" "$expected_bootloader_sha256"
if [ -n "$source_openixcli" ]; then
	[ -s "$source_openixcli" ] || die "missing frozen OpenixCLI: $source_openixcli"
	verify_sha256 "$source_openixcli" "$expected_openixcli_sha256"
fi
if [ -n "$source_flash_log" ]; then
	[ -s "$source_flash_log" ] || die "missing successful flash log: $source_flash_log"
	verify_sha256 "$source_flash_log" "$expected_flash_log_sha256"
fi
mkdir -p "$release_dir"
install -m 0644 "$source_image" "$release_image"

"$repo_dir/scripts/verify-loader.sh" "$source_loader"
install -m 0644 "$source_loader" "$release_loader"
install -m 0644 "$source_bootloader" "$release_bootloader"
if [ -n "$source_openixcli" ]; then
	install -m 0755 "$source_openixcli" "$release_dir/openixcli-linux-x86_64"
fi
if [ -n "$source_flash_log" ]; then
	install -m 0644 "$source_flash_log" "$release_dir/t527-v9-flash-20260901.jsonl"
fi

xz -T0 -6 -k -f "$release_image"
(
	cd "$release_dir"
	# SHA256SUMS lists the files uploaded to GitHub Release.  The hash of the
	# uncompressed raw remains in release.manifest and is checked after unxz.
	sha256sum avaota-a1-mainline-v9-tm4-coldboot.img.xz > SHA256SUMS
	sha256sum avaota-a1-t527-fes-loader.img >> SHA256SUMS
	sha256sum avaota-a1-mainline-v9-u-boot-sunxi-with-spl.bin >> SHA256SUMS
	if [ -s openixcli-linux-x86_64 ]; then
		sha256sum openixcli-linux-x86_64 >> SHA256SUMS
	fi
	if [ -s t527-v9-flash-20260901.jsonl ]; then
		sha256sum t527-v9-flash-20260901.jsonl >> SHA256SUMS
	fi
)

cat > "$release_dir/release.manifest" <<EOF
release=v2026.09.01-v9-tm4-coldboot
status=hardware-verified-two-cold-boots-to-Buildroot-root-shell
raw=avaota-a1-mainline-v9-tm4-coldboot.img
raw_sha256=$(sha256sum "$release_image" | awk '{print $1}')
raw_size=$(stat -c %s "$release_image")
compressed=avaota-a1-mainline-v9-tm4-coldboot.img.xz
compressed_sha256=$(sha256sum "$release_image.xz" | awk '{print $1}')
compressed_size=$(stat -c %s "$release_image.xz")
loader=avaota-a1-t527-fes-loader.img
loader_sha256=867d43d12399016252a3d34c2ae50f6f362868f95c2985169d5a4b655a16417c
loader_size=1337344
loader_format=IMAGEWTY-v3-five-files-zero-partitions-RAM-only
bootloader=avaota-a1-mainline-v9-u-boot-sunxi-with-spl.bin
bootloader_sha256=$expected_bootloader_sha256
bootloader_size=$(stat -c %s "$release_bootloader")
buildroot=2026.05.1
linux=7.2
u_boot=2026.07
trusted_firmware_a_commit=$(source_field trusted-firmware-a 5)
toolchain=Arm-GNU-10.3-2021.07
emmc_profile=T527-SUN55I-MMC2-TM4-1x,drive-phase-180,drive-delay-enabled,sample-delay-0,4-bit,25MHz,SDR-only,b_max-128,one-bounded-retry
layout=bootloader@8KiB,boot-fat@16MiB,rootfs-ext4@256MiB
root_device=/dev/mmcblk1p2
spl_failure_recovery=return-to-BootROM-FEL
openixcli_sha256=c370b3b5079ff67672728d127df57e1cb234e18a10febd4ca3cda36a635662ae
openixcli_asset=$(if [ -s "$release_dir/openixcli-linux-x86_64" ]; then printf '%s' openixcli-linux-x86_64; else printf '%s' not-packaged; fi)
flash_log=$(if [ -s "$release_dir/t527-v9-flash-20260901.jsonl" ]; then printf '%s' t527-v9-flash-20260901.jsonl; else printf '%s' not-packaged; fi)
flash_log_sha256=$expected_flash_log_sha256
hardware_acceptance=two-cold-boots-SPL-FIT-U-Boot-Linux-Buildroot-root-shell
EOF

printf 'Release package written under %s\n' "$release_dir"
