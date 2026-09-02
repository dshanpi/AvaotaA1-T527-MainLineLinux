#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

base=${1:-/home/ubuntu/AIHardAgent/avaota-a1-mainline-v7-tm4-csdc.img}
candidate=${2:-/home/ubuntu/AIHardAgent/avaota-a1-mainline-v9-tm4-coldboot.img}
bootloader=${3:-/home/ubuntu/AIHardAgent/avaota-a1-mainline-v9-u-boot-sunxi-with-spl.bin}
base_sha256=${BASE_SHA256:-9b7fc69ba670cde137403541923aba6e1eb3f5fc3904a3b8996925309c985c64}

for tool in dtc mcopy mdir mtype python3 sha256sum stat strings; do need "$tool"; done
for file in "$base" "$candidate" "$bootloader"; do
	[ -s "$file" ] || die "missing candidate input: $file"
done
verify_sha256 "$base" "$base_sha256"

tmp_dir=$(mktemp -d /tmp/avaota-v9-verify.XXXXXX)
cleanup()
{
	find "$tmp_dir" -type f -delete 2>/dev/null || true
	find "$tmp_dir" -depth -type d -empty -delete 2>/dev/null || true
}
trap cleanup EXIT

python3 - "$base" "$candidate" "$bootloader" "$tmp_dir/spl.bin" <<'PY'
import os
import struct
import sys

base, candidate, bootloader, spl_out = sys.argv[1:]
offset = 8 * 1024
expected_size = 768 * 1024 * 1024
boot = open(bootloader, "rb").read()

if os.path.getsize(base) != expected_size or os.path.getsize(candidate) != expected_size:
    raise SystemExit("base/candidate is not the expected 768 MiB raw image")

with open(base, "rb") as old, open(candidate, "rb") as new:
    if old.read(offset) != new.read(offset):
        raise SystemExit("bytes before the 8 KiB bootloader offset changed")
    if new.read(len(boot)) != boot:
        raise SystemExit("candidate does not contain the exact new bootloader")
    old.seek(offset + len(boot))
    new.seek(offset + len(boot))
    while True:
        old_chunk = old.read(8 * 1024 * 1024)
        new_chunk = new.read(8 * 1024 * 1024)
        if old_chunk != new_chunk:
            raise SystemExit("candidate changed data outside the bootloader range")
        if not old_chunk:
            break

if boot[4:12] != b"eGON.BT0":
    raise SystemExit("bootloader has no eGON.BT0 header")
checksum, spl_len = struct.unpack_from("<II", boot, 12)
if spl_len < 512 or spl_len % 512 or len(boot) < spl_len:
    raise SystemExit("invalid SPL length")
spl = bytearray(boot[:spl_len])
struct.pack_into("<I", spl, 12, 0x5F0A6C39)
calculated = sum(struct.unpack(f"<{spl_len // 4}I", spl)) & 0xFFFFFFFF
if calculated != checksum:
    raise SystemExit("invalid eGON checksum")
fit_offset = max(spl_len, 32 * 1024)
if boot[fit_offset:fit_offset + 4] != bytes.fromhex("d00dfeed"):
    raise SystemExit("firmware FIT is not immediately after the SPL")

with open(candidate, "rb") as raw:
    mbr = raw.read(512)
if mbr[510:512] != b"\x55\xaa":
    raise SystemExit("invalid DOS MBR signature")
entries = []
for index in range(2):
    entry = mbr[0x1BE + index * 16:0x1BE + (index + 1) * 16]
    entries.append((entry[4], struct.unpack_from("<I", entry, 8)[0]))
if entries != [(0x0C, 32768), (0x83, 524288)]:
    raise SystemExit(f"unexpected partition layout: {entries}")

open(spl_out, "wb").write(boot[:spl_len])
print(f"delta=[0x{offset:x},0x{offset + len(boot):x})")
print(f"eGON_length=0x{spl_len:x} eGON_checksum=0x{checksum:08x}")
print(f"FIT_offset_in_bootloader=0x{fit_offset:x}")
PY

for marker in 'LYNX_MMC_TM4_INIT:' 'drv_dl=0x%08x' 'LYNX_RECOVERY_FEL:'; do
	strings -a "$tmp_dir/spl.bin" > "$tmp_dir/spl.strings"
	grep -Fq "$marker" "$tmp_dir/spl.strings" || die "SPL marker missing: $marker"
done

mcopy -i "$candidate@@16777216" ::/Image "$tmp_dir/Image"
mcopy -i "$candidate@@16777216" \
	::/sun55i-t527-avaota-a1.dtb "$tmp_dir/board.dtb"
mtype -i "$candidate@@16777216" ::/extlinux/extlinux.conf \
	| tr -d '\r' > "$tmp_dir/extlinux.conf"
grep -q '^  linux /Image$' "$tmp_dir/extlinux.conf" || die "wrong kernel path"
grep -q '^  fdt /sun55i-t527-avaota-a1.dtb$' "$tmp_dir/extlinux.conf" || \
	die "wrong DTB path"
grep -q 'root=/dev/mmcblk1p2 rootwait rw' "$tmp_dir/extlinux.conf" || \
	die "v7 root device changed"

dtc -q -I dtb -O dts -o "$tmp_dir/board.dts" "$tmp_dir/board.dtb"
python3 - "$tmp_dir/board.dts" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"mmc@4022000\s*\{(.*?)\n\t\t\};", text, re.S)
if not match:
    raise SystemExit("preserved Linux DTB has no MMC2 node")
mmc2 = match.group(1)
if not re.search(r"bus-width\s*=\s*<0x04>;", mmc2):
    raise SystemExit("preserved Linux DTB is not 4-bit")
if not re.search(r"max-frequency\s*=\s*<0x17d7840>;", mmc2):
    raise SystemExit("preserved Linux DTB is not capped at 25 MHz")
for forbidden in ("mmc-ddr-1_8v", "mmc-hs200-1_8v"):
    if forbidden in mmc2:
        raise SystemExit(f"preserved Linux DTB contains {forbidden}")
PY

mdir -i "$candidate@@16777216" ::/Image \
	::/sun55i-t527-avaota-a1.dtb ::/extlinux/extlinux.conf >/dev/null

printf 'v9 minimal-delta candidate verification PASS\n'
printf '  base SHA256:       %s\n' "$base_sha256"
printf '  bootloader SHA256: %s\n' "$(sha256sum "$bootloader" | awk '{print $1}')"
printf '  candidate SHA256:  %s\n' "$(sha256sum "$candidate" | awk '{print $1}')"
printf '  Linux Image SHA256:%s\n' "$(sha256sum "$tmp_dir/Image" | awk '{print $1}')"
printf '  Linux DTB SHA256:  %s\n' "$(sha256sum "$tmp_dir/board.dtb" | awk '{print $1}')"
