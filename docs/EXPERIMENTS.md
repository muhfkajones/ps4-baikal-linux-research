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
- Status: complete
- Output bytes: `31457280`
- Output SHA-256: `A6C4E5B897A129AFFEF8EA1F8FE168F70D916C71D20901B9D8CD1DC0E1AEDCB0`
- Classification: `structured-plaintext-candidate`
- Basis: device name and boot-time references recovered from the 13.50 Orbis kernel, followed by EXP-005 confirming a 30 MiB view whose first sector begins with the Sony plaintext flash header

## EXP-004 — SFLASH provider inventory, first build

- Date: 2026-10-24
- Tool SHA-256: `187B76989D7E0ED474DA3E02EEFB625A31F43EF923A6387ED702A19AD62A3F7A`
- Result: rejected before provider access
- Runtime evidence: initialization and firmware 13.50 checks completed; the log ended at the first empty `DEVICE` record
- Root cause: the flat payload loader does not apply the ELF data relocation required by the global string-pointer table
- Correction: replace the pointer table with direct code-relative literal calls and require a new build, audit, transfer hash, and runtime attempt

## EXP-005 — SFLASH provider inventory, corrected build

- Date: 2026-10-24
- Tool SHA-256: `1B4F84E06178EA6E2CD7BE648822132A9CCCC922248C5F90E3CD97B3C1AD4A03`
- Retrieved log SHA-256: `8CEC589893ABD0F965D6B08BF2CC1709A5BED656AD9CE5143FED8A41AD14FAA5`
- Result: complete; strict parser accepted all nine records with zero validation errors
- Finding: `/dev/sflash0s1.crypt` is a 30 MiB view beginning with the Sony plaintext flash header
- Finding: `cryptx2`, `cryptx2b`, `cryptx3`, and `cryptx3b` begin with `SLB2`
- Finding: `cryptx2` and `cryptx2b` have the same size and first-sector fingerprint; `cryptx3` and `cryptx3b` have the same size but different first-sector fingerprints
- Decision: retain `/dev/sflash0s1.crypt` as the next full read-only acquisition target; treat child providers as separate boot-container views requiring independent hashes before drawing equivalence conclusions

## EXP-006 — Decrypted system-slice classification

- Date: 2026-10-24
- Input: completed 30 MiB `/dev/sflash0s1.crypt` acquisition from EXP-003
- SHA-256: `A6C4E5B897A129AFFEF8EA1F8FE168F70D916C71D20901B9D8CD1DC0E1AEDCB0`
- Completion marker: present
- Structural markers: Sony plaintext header at `0x0`; `SLB2` at `0x4000`
- Comparison: zero matching 64 KiB blocks against both the raw system-slice view and the corresponding portion of `/dev/sflash0.crypt`
- Classification: `structured-plaintext-candidate`
- SLB2 inventory: four valid containers at `0x4000`, `0x42000`, `0x1c0000`, and `0xe80000`; 16 entries total
- Bank comparison: both one-entry containers differ; every corresponding entry in the two seven-entry containers also differs
- Reference comparison: no exact entry SHA-256 matched the files in pinned `andy-man/ps4-ic-fw` revision `f669d6c8c583b3cae66a833d1604598907fb8a04`
- Boundary: hashes and layout evidence are publishable; acquired and extracted Sony bytes remain private and excluded from Git
