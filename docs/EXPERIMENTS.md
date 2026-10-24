# Experiment log

Experiments are append-only. Corrections receive a new entry; previous conclusions are not silently rewritten.

## EXP-001 — Raw serial-flash acquisition

- Date: 2026-10-23
- Input: `/dev/sflash0`, opened read-only
- Expected size: `0x02000000`
- Result: complete
- Output writes: external USB only
- Finding: valid PS4 flash header and documented partition layout recovered

## EXP-002 — Whole-device crypt-node acquisition

- Date: 2026-10-23
- Input: `/dev/sflash0.crypt`, opened read-only
- Expected size: `0x02000000`
- Result: complete
- Finding: output differs from raw SFLASH across 33,423,437 bytes and begins with high-entropy data rather than the plaintext PS4 flash header
- Conclusion: this node is not a directly usable decrypted whole-flash view

## EXP-003 — System-slice crypt-node acquisition

- Date: 2026-10-23
- Input: `/dev/sflash0s1.crypt`, opened read-only
- Tool: `sflash-s1-crypt-dumper-readonly`
- Status: pending acquisition/classification
- Basis: device name and boot-time references recovered from the 13.50 Orbis kernel

## EXP-004 — SFLASH provider inventory, first build

- Date: 2026-10-24
- Tool SHA-256: `187B76989D7E0ED474DA3E02EEFB625A31F43EF923A6387ED702A19AD62A3F7A`
- Result: rejected before provider access
- Runtime evidence: initialization and firmware 13.50 checks completed; the log ended at the first empty `DEVICE` record
- Root cause: the flat payload loader does not apply the ELF data relocation required by the global string-pointer table
- Correction: replace the pointer table with direct code-relative literal calls and require a new build, audit, transfer hash, and runtime attempt
