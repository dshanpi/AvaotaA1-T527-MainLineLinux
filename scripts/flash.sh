#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

for tool in awk lsusb pgrep sha256sum tee; do need "$tool"; done

openixcli=${OPENIXCLI:-openixcli}
image=${IMAGE:-"$out_dir/avaota-a1-full-mainline.img"}
loader=${FES_LOADER:-"$out_dir/avaota-a1-t527-fes-loader.img"}
log=${FLASH_LOG:-"$out_dir/fes-flash-$(date +%Y%m%d-%H%M%S).jsonl"}

[ -s "$image" ] || die "missing mainline raw image: $image"
[ -s "$loader" ] || die "missing dedicated FES loader: $loader (run make loader)"
command -v "$openixcli" >/dev/null 2>&1 || die "OpenixCLI is not installed: $openixcli"

"$repo_dir/scripts/verify-loader.sh" "$loader"
if [ -s "$work_dir/u-boot-2026.07/u-boot-sunxi-with-spl.bin" ]; then
	"$repo_dir/scripts/verify-artifacts.sh" \
		"$work_dir/u-boot-2026.07/u-boot-sunxi-with-spl.bin" "$image"
elif [ -n "${IMAGE_SHA256:-}" ]; then
	verify_sha256 "$image" "$IMAGE_SHA256"
else
	die "build artifacts are absent; set IMAGE_SHA256 to the trusted release hash"
fi

if [ -n "${OPENIXCLI_SHA256:-}" ]; then
	verify_sha256 "$(command -v "$openixcli")" "$OPENIXCLI_SHA256"
fi

if pgrep -x lynx-app >/dev/null; then
	die "lynx-app is running and may claim the Allwinner USB device"
fi
if pgrep -x openixcli >/dev/null; then
	die "another openixcli process is already running"
fi

device_location=${DEVICE_LOCATION:-}
if [ -z "$device_location" ]; then
	mapfile -t fel_devices < <(lsusb -d 1f3a:efe8)
	[ "${#fel_devices[@]}" -eq 1 ] || \
		die "expected exactly one FEL device (1f3a:efe8), found ${#fel_devices[@]}"
	if [[ ${fel_devices[0]} =~ ^Bus[[:space:]]+([0-9]+)[[:space:]]+Device[[:space:]]+([0-9]+): ]]; then
		bus=$((10#${BASH_REMATCH[1]}))
		port=$((10#${BASH_REMATCH[2]}))
		device_location="libusb:$bus:$port"
	else
		die "cannot parse FEL USB location: ${fel_devices[0]}"
	fi
fi
case "$device_location" in libusb:*:*) ;; *) die "invalid DEVICE_LOCATION: $device_location";; esac

mkdir -p "$(dirname "$log")"
printf 'FES loader: %s\n' "$loader" >&2
printf 'Mainline raw: %s\n' "$image" >&2
printf 'FEL device: %s\n' "$device_location" >&2
printf 'Flash log: %s\n' "$log" >&2
printf '%s\n' \
	'One attempt only. After a FEL-to-FES failure, manually re-enter FEL before retrying.' >&2

"$openixcli" --output jsonl raw "$loader" "$image" \
	--mode command \
	--emmc-boot0-from-image \
	--device-location "$device_location" |& tee "$log"
