#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

case "$work_dir" in
	"$repo_dir"/.work|"$repo_dir"/.work/*) ;;
	*) die "refusing to clean non-repository work directory: $work_dir";;
esac
rm -rf -- "$work_dir"
printf 'Removed generated work tree: %s\n' "$work_dir"
