#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

image="$out_dir/avaota-a1-full-mainline.img"
[ -s "$image" ] || die "missing verified image: $image"
mkdir -p "$out_dir"

sha256sum "$image" > "$image.sha256"
cat > "$out_dir/avaota-a1-full-mainline.manifest" <<EOF
artifact=$(basename "$image")
sha256=$(sha256sum "$image" | awk '{print $1}')
size=$(stat -c %s "$image")
buildroot=2026.05.1
linux=7.2
u_boot=2026.07
trusted_firmware_a_commit=$(source_field trusted-firmware-a 5)
toolchain=Arm-GNU-10.3-2021.07
layout=bootloader@8KiB,boot-fat@16MiB,rootfs-ext4@256MiB
root_device=/dev/mmcblk1p2
EOF

if command -v xz >/dev/null 2>&1; then
	xz -T0 -9 -k -f "$image"
	sha256sum "$image.xz" > "$image.xz.sha256"
fi

printf 'Release metadata written under %s\n' "$out_dir"
