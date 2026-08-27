#!/bin/sh
set -eu

target_dir="$1"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
buildroot_dir="$(CDPATH= cd -- "$script_dir/../../.." && pwd)"
mainline_dir="$(dirname -- "$buildroot_dir")"
uboot_dir="$mainline_dir/u-boot-2026.07"

test -s "$uboot_dir/u-boot-sunxi-with-spl.bin"
install -D -m 0644 "$uboot_dir/u-boot-sunxi-with-spl.bin" \
	"$BINARIES_DIR/u-boot-sunxi-with-spl.bin"
install -D -m 0644 "$script_dir/rootfs-overlay/boot/extlinux/extlinux.conf" \
	"$BINARIES_DIR/extlinux/extlinux.conf"

# Keep the target's /boot useful for diagnostics without making it a second
# source of kernel artifacts. Buildroot has already installed the matching
# Image and DTB into BINARIES_DIR at this point.
install -D -m 0644 "$BINARIES_DIR/Image" "$target_dir/boot/Image"
install -D -m 0644 \
	"$BINARIES_DIR/sun55i-t527-avaota-a1.dtb" \
	"$target_dir/boot/sun55i-t527-avaota-a1.dtb"
