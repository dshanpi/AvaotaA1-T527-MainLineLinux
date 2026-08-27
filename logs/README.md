# Log index

- `fes-flash-success-summary.jsonl` is a compact, path-free record extracted
  from the successful 2026-08-27 OpenixCLI/FES job. High-frequency progress
  samples were intentionally removed; stage, storage, Boot0 and verification
  results are preserved.
- `successful-cold-boot-20260827.log` is the complete captured UART transcript
  containing the final FES handoff and power-cycle boot through the Buildroot
  login prompt.

The original development archive also contains failed experiments and raw
per-transfer progress. Those files are not published here because they include
obsolete vendor/SyterKit images, host-specific paths and repetitive transport
samples. Their causes and dispositions are preserved in
`docs/failures-and-fixes.md`.
