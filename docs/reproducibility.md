# Reproducibility and validation

`manifests/sources.lock` is the source of truth. Released archives are fetched
from their official project sites and SHA-256 checked before extraction.
Development-only dependencies are checked out at exact commits.

The artifact verifier checks:

- eGON signature, length and checksum;
- exact bootloader bytes at 8 KiB;
- U-Boot and TF-A FIT payload addresses;
- absence of known vendor/SyterKit markers;
- MBR partition types and 16/256 MiB offsets;
- exact FAT and ext4 partition bytes;
- FAT kernel, DTB and extlinux contents;
- ext4 integrity, label, `/boot` files and installed modules;
- required effective Linux configuration symbols.

`CLEAN_BUILD=1` is the default and rebuilds TF-A, U-Boot and Buildroot from
clean outputs. After a host interruption that did not change sources,
`CLEAN_BUILD=0 make build` may resume the same locked work tree. It does not
replace the clean build required for release acceptance.

Release acceptance requires:

1. `make build` from a new clone and empty `.cache/`.
2. A second build with matching source hashes and a reviewed artifact manifest.
3. OpenixCLI unit/integration tests.
4. FES write/verify on the intended physical USB port.
5. Power removal and cold boot to the Buildroot login prompt.

Build timestamps can change raw hashes unless `SOURCE_DATE_EPOCH` and every
upstream timestamp input are normalized. The manifest therefore records exact
artifact hashes for each hardware-qualified build.
