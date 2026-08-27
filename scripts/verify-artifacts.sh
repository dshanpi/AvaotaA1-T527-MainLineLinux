#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/common.sh"
bootloader=${1:-${work_dir}/u-boot-2026.07/u-boot-sunxi-with-spl.bin}
raw=${2:-${out_dir}/avaota-a1-full-mainline.img}
images_dir=${3:-${work_dir}/buildroot-2026.05.1/output/images}
target_dir=${4:-${work_dir}/buildroot-2026.05.1/output/target}
buildroot_dir=$(dirname -- "$images_dir")
linux_config="$buildroot_dir/build/linux-custom/.config"
bootrom_offset=$((8 * 1024))
boot_offset=$((16 * 1024 * 1024))
rootfs_offset=$((256 * 1024 * 1024))

fail()
{
	echo "mainline image verification failed: $*" >&2
	exit 1
}

need()
{
	command -v "$1" >/dev/null 2>&1 || fail "missing host tool: $1"
}

for tool in cmp dd debugfs e2fsck find mcopy mdir mtype python3 sha256sum tune2fs xxd; do
	need "$tool"
done

dumpimage=${DUMPIMAGE:-${work_dir}/u-boot-2026.07/tools/dumpimage}
[ -x "$dumpimage" ] || fail "missing U-Boot dumpimage: $dumpimage"

boot_vfat="$images_dir/boot.vfat"
rootfs="$images_dir/rootfs.ext2"
image="$images_dir/Image"
dtb="$images_dir/sun55i-t527-avaota-a1.dtb"

for file in "$bootloader" "$raw" "$boot_vfat" "$rootfs" "$image" "$dtb" \
	"$linux_config"; do
	[ -s "$file" ] || fail "missing or empty artifact: $file"
done

python3 - "$bootloader" <<'PY' || fail "invalid eGON header or checksum"
import struct
import sys

path = sys.argv[1]
with open(path, "rb") as image:
    header = image.read(96)
    if len(header) < 96 or header[4:12] != b"eGON.BT0":
        raise SystemExit(1)
    checksum, length = struct.unpack_from("<II", header, 12)
    if length < 512 or length % 512:
        raise SystemExit(1)
    image.seek(0)
    payload = bytearray(image.read(length))
    if len(payload) != length:
        raise SystemExit(1)
    struct.pack_into("<I", payload, 12, 0x5F0A6C39)
    calculated = sum(struct.unpack(f"<{length // 4}I", payload)) & 0xFFFFFFFF
    if calculated != checksum:
        raise SystemExit(1)
PY

spl_size_hex=$(xxd -e -g 4 -l 4 -s 16 "$bootloader" | awk '{print $2}')
spl_size=$((16#$spl_size_hex))
fit_in_bootloader=$((spl_size > 32 * 1024 ? spl_size : 32 * 1024))
fit_offset=$((bootrom_offset + fit_in_bootloader))
fit_magic=$(xxd -p -l 4 -s "$fit_offset" "$raw")
[ "$fit_magic" = "d00dfeed" ] || \
	fail "firmware FIT is not at raw offset 0x$(printf '%x' "$fit_offset")"

bootloader_size=$(stat -c %s "$bootloader")
cmp -s -n "$bootloader_size" -i "0:${bootrom_offset}" "$bootloader" "$raw" || \
	fail "raw image does not contain the exact U-Boot image at 8 KiB"
[ $((bootrom_offset + bootloader_size)) -le "$boot_offset" ] || \
	fail "U-Boot overlaps the boot partition"

tmp_dir=$(mktemp -d /tmp/avaota-mainline-verify.XXXXXX)
trap 'rm -rf -- "$tmp_dir"' EXIT
dd if="$bootloader" of="$tmp_dir/firmware.fit" bs=1 \
	skip="$fit_in_bootloader" status=none
fit_listing=$($dumpimage -l "$tmp_dir/firmware.fit")
printf '%s\n' "$fit_listing" | grep -q 'Load Address: 0x4a000000' || \
	fail "FIT has no U-Boot payload at 0x4a000000"
printf '%s\n' "$fit_listing" | grep -q 'Load Address: 0x00054000' || \
	fail "FIT has no TF-A payload at 0x00054000"
printf '%s\n' "$fit_listing" | grep -q 'Firmware:.*atf' || \
	fail "FIT configuration does not select TF-A"
printf '%s\n' "$fit_listing" | grep -q 'allwinner/sun55i-t527-avaota-a1' || \
	fail "FIT does not contain the Avaota A1 U-Boot DT"

if strings -a "$tmp_dir/firmware.fit" | \
	grep -Eq 'BL31: v2\.5|Nov 16 2023|sun55iw3p1|BOOT0 commit|SyterKit'; then
	fail "FIT contains a vendor or SyterKit boot-chain marker"
fi

part1_type=$(xxd -p -l 1 -s $((0x1be + 4)) "$raw")
part2_type=$(xxd -p -l 1 -s $((0x1ce + 4)) "$raw")
[ "$part1_type" = "0c" ] || fail "partition 1 is not FAT32 LBA"
[ "$part2_type" = "83" ] || fail "partition 2 is not Linux"
part1_lba_hex=$(xxd -e -g 4 -l 4 -s $((0x1be + 8)) "$raw" | awk '{print $2}')
part2_lba_hex=$(xxd -e -g 4 -l 4 -s $((0x1ce + 8)) "$raw" | awk '{print $2}')
[ $((16#$part1_lba_hex)) -eq $((boot_offset / 512)) ] || \
	fail "boot partition does not start at 16 MiB"
[ $((16#$part2_lba_hex)) -eq $((rootfs_offset / 512)) ] || \
	fail "rootfs partition does not start at 256 MiB"

cmp -s -n "$(stat -c %s "$boot_vfat")" -i "0:${boot_offset}" \
	"$boot_vfat" "$raw" || fail "raw FAT partition differs from boot.vfat"
cmp -s -n "$(stat -c %s "$rootfs")" -i "0:${rootfs_offset}" \
	"$rootfs" "$raw" || fail "raw rootfs partition differs from rootfs.ext2"

mdir -i "$boot_vfat" ::/Image ::/sun55i-t527-avaota-a1.dtb \
	::/extlinux/extlinux.conf >/dev/null || fail "FAT boot files are incomplete"
mcopy -i "$boot_vfat" ::/Image "$tmp_dir/Image"
mcopy -i "$boot_vfat" ::/sun55i-t527-avaota-a1.dtb "$tmp_dir/board.dtb"
cmp -s "$image" "$tmp_dir/Image" || fail "FAT Image hash mismatch"
cmp -s "$dtb" "$tmp_dir/board.dtb" || fail "FAT DTB hash mismatch"
extlinux=$(mtype -i "$boot_vfat" ::/extlinux/extlinux.conf | tr -d '\r')
printf '%s\n' "$extlinux" | grep -q '^  linux /Image$' || \
	fail "extlinux does not load /Image"
printf '%s\n' "$extlinux" | grep -q '^  fdt /sun55i-t527-avaota-a1.dtb$' || \
	fail "extlinux does not load the Avaota A1 DTB"
printf '%s\n' "$extlinux" | grep -q 'root=/dev/mmcblk1p2 rootwait rw' || \
	fail "extlinux root filesystem arguments are wrong"

e2fsck -fn "$rootfs" >/dev/null || fail "rootfs.ext2 failed read-only fsck"
label=$(tune2fs -l "$rootfs" 2>/dev/null | awk -F: '/Filesystem volume name:/ {sub(/^[[:space:]]+/, "", $2); print $2}')
[ "$label" = "rootfs" ] || fail "rootfs label is '$label', expected rootfs"

for symbol in \
	CONFIG_DEVTMPFS=y CONFIG_DEVTMPFS_MOUNT=y CONFIG_SERIAL_8250_DW=y \
	CONFIG_MMC=y CONFIG_MMC_SUNXI=y CONFIG_EXT4_FS=y CONFIG_CONFIGFS_FS=y \
	CONFIG_USB_CONFIGFS=m CONFIG_DWMAC_SUN55I=m; do
	grep -qx "$symbol" "$linux_config" || \
		fail "effective Linux config is missing $symbol"
done

[ -d "$target_dir/lib/modules" ] || fail "target has no /lib/modules"
mapfile -t module_dirs < <(find "$target_dir/lib/modules" -mindepth 1 \
	-maxdepth 1 -type d -printf '%f\n')
[ "${#module_dirs[@]}" -eq 1 ] || \
	fail "expected one kernel module directory, found ${#module_dirs[@]}"
kernelrelease=${module_dirs[0]}
case "$kernelrelease" in
	7.2.0-avaota-a1-mainline) ;;
	*) fail "unexpected kernelrelease: $kernelrelease" ;;
esac
[ -s "$target_dir/lib/modules/$kernelrelease/modules.dep" ] || \
	fail "modules.dep is missing or empty"
find "$target_dir/lib/modules/$kernelrelease" -type f -name '*.ko*' \
	-print -quit | grep -q . || fail "no kernel modules were installed"

# Inspect the filesystem image itself, not only Buildroot's input tree. This
# catches truncated or stale rootfs packaging before the raw image is flashed.
debugfs -R "dump -p /boot/Image $tmp_dir/rootfs-Image" "$rootfs" \
	>/dev/null 2>&1 || fail "rootfs image has no /boot/Image"
debugfs -R "dump -p /boot/sun55i-t527-avaota-a1.dtb $tmp_dir/rootfs-board.dtb" \
	"$rootfs" >/dev/null 2>&1 || fail "rootfs image has no Avaota A1 DTB"
debugfs -R "dump -p /lib/modules/$kernelrelease/modules.dep $tmp_dir/modules.dep" \
	"$rootfs" >/dev/null 2>&1 || fail "rootfs image has no modules.dep"
cmp -s "$image" "$tmp_dir/rootfs-Image" || fail "rootfs /boot/Image hash mismatch"
cmp -s "$dtb" "$tmp_dir/rootfs-board.dtb" || fail "rootfs /boot DTB hash mismatch"
[ -s "$tmp_dir/modules.dep" ] || fail "rootfs modules.dep is empty"

printf 'mainline image verification PASS\n'
printf '  eGON SPL length:       0x%x\n' "$spl_size"
printf '  firmware FIT offset:  0x%x (sector 0x%x)\n' "$fit_offset" "$((fit_offset / 512))"
printf '  boot/rootfs offsets:  16 MiB / 256 MiB\n'
printf '  kernelrelease:        %s\n' "$kernelrelease"
printf '  image SHA256:         %s\n' "$(sha256sum "$raw" | awk '{print $1}')"
