#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

for tool in python3 sha256sum stat; do need "$tool"; done
loader=${1:-"$out_dir/avaota-a1-t527-fes-loader.img"}
[ -s "$loader" ] || die "missing FES loader: $loader"

expected_loader_sha=867d43d12399016252a3d34c2ae50f6f362868f95c2985169d5a4b655a16417c
verify_sha256 "$loader" "$expected_loader_sha"
[ "$(stat -c %s "$loader")" -eq 1337344 ] || die "unexpected FES loader size"

python3 - "$loader" <<'PY'
import hashlib
import os
import struct
import sys

path = sys.argv[1]
expected = [
    ("config.fex", "COMMON", "SYS_CONFIG_BIN00", 27648,
     "3be96be474a656b3b38b562dde728e67b8d5535f72a9613fa1f3843c8f1b16d1"),
    ("board.fex", "COMMON", "BOARD_CONFIG_BIN", 1024,
     "ab1d5b1e29bc04511d1fc6942ae365f3202d5795fa06e3699acfae987fafb245"),
    ("sunxi.fex", "COMMON", "DTB_CONFIG000000", 188928,
     "8ff1e6cb1c46dae1a2f111a5d0fc1ddda66d232e2d3de165069d56e59884ce61"),
    ("u-boot.fex", "12345678", "UBOOT_0000000000", 1064960,
     "73212bcade3cb9dbd3661b3417a9ac16b8ec579ef09a3a9d7fdedd95b912da7d"),
    ("fes1.fex", "FES", "FES_1-0000000000", 47456,
     "0a537f3d9aa7cc114d3c38018b974486da9319a69ae5a015e4890a0131ab4f8c"),
]

def text(raw):
    return raw.split(b"\0", 1)[0].decode("ascii").rstrip()

with open(path, "rb") as image:
    header = image.read(1024)
    if header[:8] != b"IMAGEWTY":
        raise SystemExit("loader is not IMAGEWTY")
    version = struct.unpack_from("<I", header, 8)[0]
    if version != 0x300:
        raise SystemExit(f"unexpected IMAGEWTY header version: 0x{version:x}")
    image_size = struct.unpack_from("<Q", header, 24)[0]
    file_count = struct.unpack_from("<I", header, 60)[0]
    if image_size != os.path.getsize(path) or file_count != len(expected):
        raise SystemExit("IMAGEWTY size or file count mismatch")

    observed = []
    for index in range(file_count):
        image.seek(1024 * (index + 1))
        file_header = image.read(1024)
        maintype = text(file_header[8:16])
        subtype = text(file_header[16:32])
        filename = text(file_header[36:292])
        original_length = struct.unpack_from("<Q", file_header, 300)[0]
        offset = struct.unpack_from("<Q", file_header, 308)[0]
        if offset < 1024 * (file_count + 1) or offset + original_length > image_size:
            raise SystemExit(f"invalid payload bounds for {filename}")
        image.seek(offset)
        payload = image.read(original_length)
        observed.append((filename, maintype, subtype, original_length,
                         hashlib.sha256(payload).hexdigest()))

if observed != expected:
    for entry in observed:
        print("observed:", entry, file=sys.stderr)
    raise SystemExit("loader entries do not match the locked five-file contract")

print("FES loader verification PASS")
print(f"  IMAGEWTY files: {file_count}")
print(f"  image bytes:    {image_size}")
print("  partitions:     0 (no MBR entry)")
PY
