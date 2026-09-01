#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

for tool in cp find install mktemp sha256sum; do need "$tool"; done

sdk_root=${TINA_SDK_ROOT:-${1:-}}
[ -n "$sdk_root" ] || die "set TINA_SDK_ROOT or pass the Tina SDK root as argument 1"
case "$sdk_root" in /*) ;; *) die "Tina SDK root must be an absolute path";; esac

dragon="$sdk_root/tools/pack/pctools/linux/eDragonEx/dragon"
loader_dir="$repo_dir/loader/t527-fes"
output="$out_dir/avaota-a1-t527-fes-loader.img"
[ -x "$dragon" ] || die "Tina dragon tool is missing: $dragon"

(
	cd "$loader_dir"
	sha256sum -c SHA256SUMS
)

mkdir -p "$out_dir"
tmp_dir=$(mktemp -d /tmp/avaota-a1-fes-loader.XXXXXX)
cleanup_loader_tmp()
{
	find "$tmp_dir" -type f -delete 2>/dev/null || true
	find "$tmp_dir" -depth -type d -empty -delete 2>/dev/null || true
}
trap cleanup_loader_tmp EXIT

cp "$loader_dir/image.cfg" "$loader_dir/sys_partition.fex" "$tmp_dir/"
cp "$loader_dir"/inputs/*.fex "$tmp_dir/"
(
	cd "$tmp_dir"
	"$dragon" image.cfg sys_partition.fex
)

generated="$tmp_dir/avaota-a1-t527-fes-loader.img"
[ -s "$generated" ] || die "Tina dragon did not produce the FES loader"
"$repo_dir/scripts/verify-loader.sh" "$generated"
install -m 0644 "$generated" "$output"
printf 'FES loader written: %s\n' "$output"
