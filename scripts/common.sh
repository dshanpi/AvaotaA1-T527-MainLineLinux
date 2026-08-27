#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=${WORK_DIR:-"$repo_dir/.work"}
cache_dir=${DOWNLOAD_DIR:-"$repo_dir/.cache"}
out_dir=${OUT_DIR:-"$repo_dir/out"}
lock_file="$repo_dir/manifests/sources.lock"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing host tool: $1"; }

source_field() {
	local wanted=$1 column=$2
	awk -F '|' -v name="$wanted" -v column="$column" \
		'$1 == name { print $column; found=1 } END { if (!found) exit 1 }' \
		"$lock_file"
}

verify_sha256() {
	local file=$1 expected=$2 actual
	actual=$(sha256sum "$file" | awk '{print $1}')
	[ "$actual" = "$expected" ] || \
		die "SHA-256 mismatch for $file: got $actual, expected $expected"
}
