#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

openixcli=${OPENIXCLI:-openixcli}
image=${IMAGE:-"$out_dir/avaota-a1-full-mainline.img"}
loader=${BOOTSTRAP_FIRMWARE:-}
post_action=${POST_ACTION:-none}

[ -s "$image" ] || die "missing image: $image (run make build)"
[ -n "$loader" ] || die "set BOOTSTRAP_FIRMWARE to the board-matched Tina/IMAGEWTY FES loader"
[ -s "$loader" ] || die "bootstrap firmware does not exist: $loader"
command -v "$openixcli" >/dev/null 2>&1 || die "OpenixCLI is not installed: $openixcli"

"$repo_dir/scripts/verify-artifacts.sh" \
	"$work_dir/u-boot-2026.07/u-boot-sunxi-with-spl.bin" "$image"

args=(
	flash "$image"
	--raw
	--emmc-boot0-from-image
	--bootstrap-firmware "$loader"
	--mode partition
	--verify true
	--post-action "$post_action"
	--output jsonl
)
[ -z "${DEVICE_LOCATION:-}" ] || args+=(--device-location "$DEVICE_LOCATION")

printf 'The loader runs in RAM only; the persistent system is fully mainline.\n' >&2
exec "$openixcli" "${args[@]}"
