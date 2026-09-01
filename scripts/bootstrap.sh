#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

for tool in awk curl git mkdir mktemp mv patch rm rmdir sha256sum tar; do need "$tool"; done
mkdir -p "$cache_dir" "$work_dir"
bootstrap_scope=${BOOTSTRAP_SCOPE:-all}
case "$bootstrap_scope" in
	all|source-check) ;;
	*) die "BOOTSTRAP_SCOPE must be all or source-check" ;;
esac

extract_archive() {
	local name=$1 archive_name=$2 destination=$3
	local url expected archive part stamp patch_file patch_sha actual extract_root
	url=$(source_field "$name" 4)
	expected=$(source_field "$name" 5)
	[ "$expected" != PENDING ] || die "source hash is not finalized: $name"
	archive="$cache_dir/$archive_name"
	part="$archive.part"
	if [ -s "$archive" ]; then
		actual=$(sha256sum "$archive" | awk '{print $1}')
		if [ "$actual" != "$expected" ]; then
			printf 'Discarding incomplete or corrupt cache file: %s\n' "$archive" >&2
			rm -f -- "$archive"
		fi
	fi
	if [ ! -s "$archive" ]; then
		printf 'Downloading %s %s...\n' "$name" "$(source_field "$name" 3)"
		rm -f -- "$part"
		curl -L --fail --retry 5 --retry-all-errors "$url" -o "$part"
		verify_sha256 "$part" "$expected"
		mv -- "$part" "$archive"
	fi
	verify_sha256 "$archive" "$expected"
	if [ ! -d "$work_dir/$destination" ]; then
		extract_root=$(mktemp -d "$work_dir/.extract-${destination}.XXXXXX")
		tar -xf "$archive" -C "$extract_root"
		[ -d "$extract_root/$destination" ] || \
			die "archive did not contain the expected directory: $destination"
		mv -- "$extract_root/$destination" "$work_dir/$destination"
		rmdir -- "$extract_root"
	fi
	stamp="$work_dir/$destination/.avaota-source-sha256"
	if [ -e "$stamp" ]; then
		grep -qx "$expected" "$stamp" || die "source stamp mismatch: $destination"
	else
		printf '%s\n' "$expected" > "$stamp"
	fi
	patch_file="$repo_dir/patches/$name/0001-avaota-a1-emmc-mainline-fix.patch"
	[ "$name" != u-boot ] || \
		patch_file="$repo_dir/patches/u-boot/0001-avaota-a1-emmc-coldboot-fixes.patch"
	if [ -s "$patch_file" ]; then
		patch_sha=$(sha256sum "$patch_file" | awk '{print $1}')
		stamp="$work_dir/$destination/.avaota-patch-sha256"
		if [ -e "$stamp" ]; then
			grep -qx "$patch_sha" "$stamp" || die "patch stamp mismatch: $destination"
		else
			patch -d "$work_dir/$destination" -p1 --forward < "$patch_file"
			printf '%s\n' "$patch_sha" > "$stamp"
		fi
	fi
}

extract_archive buildroot buildroot-2026.05.1.tar.xz buildroot-2026.05.1
extract_archive linux linux-7.2.tar.xz linux-7.2
extract_archive u-boot u-boot-2026.07.tar.bz2 u-boot-2026.07
if [ "$bootstrap_scope" = all ]; then
	extract_archive toolchain \
		gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz \
		gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu
fi

clone_exact() {
	local name=$1 destination=$2 url commit
	url=$(source_field "$name" 4)
	commit=$(source_field "$name" 5)
	if [ ! -d "$work_dir/$destination/.git" ]; then
		git init -q "$work_dir/$destination"
		git -C "$work_dir/$destination" remote add origin "$url"
	fi
	if ! git -C "$work_dir/$destination" cat-file -e "$commit^{commit}" 2>/dev/null; then
		git -C "$work_dir/$destination" fetch --depth 1 origin "$commit"
	fi
	git -C "$work_dir/$destination" checkout -q --detach "$commit"
	[ "$(git -C "$work_dir/$destination" rev-parse HEAD)" = "$commit" ] || \
		die "failed to pin $name to $commit"
}

if [ "$bootstrap_scope" = all ]; then
	clone_exact trusted-firmware-a trusted-firmware-a-a523
	clone_exact libxcrypt libxcrypt
fi

br="$work_dir/buildroot-2026.05.1"
mkdir -p "$br/board/avaota"
rm -rf "$br/board/avaota/a1-mainline"
cp -a "$repo_dir/board/avaota/a1-mainline" "$br/board/avaota/"
cp "$repo_dir/configs/avaota_a1_mainline_defconfig" "$br/configs/"
cat > "$br/local.mk" <<'EOF'
LINUX_OVERRIDE_SRCDIR = $(TOPDIR)/../linux-7.2
LIBXCRYPT_OVERRIDE_SRCDIR = $(TOPDIR)/../libxcrypt
LIBXCRYPT_AUTORECONF = YES
EOF

printf 'Bootstrap complete: %s\n' "$work_dir"
