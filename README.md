# PS4 Baikal Linux Research

Open research and tooling for understanding the PlayStation 4 Pro Baikal boot chain and investigating a reproducible cold-boot Linux path.

## Status

Research in progress. This project does **not** currently provide permanent Linux installation or a cold-boot replacement for Orbis OS. The demonstrated Linux path still depends on a volatile jailbreak and payload launch after a full restart.

Verified reference system:

- Console: PlayStation 4 Pro CUH-7215B
- System software: 13.50
- Southbridge: Baikal B1 (`0x30201`)
- Linux boot: working from external USB after HEN and Linux-loader payload

See [docs/STATUS.md](docs/STATUS.md) for confirmed results and the current research boundary.
See [docs/SECURE-BOOT-MODULE-MAP.md](docs/SECURE-BOOT-MODULE-MAP.md) for the evidence-backed map of the acquired signed boot modules and the next acquisition target.
See [docs/EXPERIMENTS.md](docs/EXPERIMENTS.md) for the hardware result from the audited secure-module mapper. The ordinary x86 SELF mapping path was tested and rejected all four Secure Kernel/AuthMgr inputs with `ENOEXEC`; current work has moved to tracing the distinct SAMU-facing secure-module service path.
See [docs/AUTHMGR-LIFECYCLE.md](docs/AUTHMGR-LIFECYCLE.md) for the 13.50 suspend/resume evidence and the controlled EXP-011 capture sequence.
See [payloads/hen-loader-boundary/AUDIT.md](payloads/hen-loader-boundary/AUDIT.md) for the offline-only EXP-013 revision-6 review and the audited revision-7 direct-capture build. Revision 7 completed in one authorized hardware run; its publication-safe result is recorded in [manifests/hen-loader-boundary-network-1350-result.json](manifests/hen-loader-boundary-network-1350-result.json). EXP-013 is closed against identical repetition.
See [docs/EXP-013-RUNBOOK.md](docs/EXP-013-RUNBOOK.md) for the gated operator/assistant sequence; each physical console action is handed off with its expected visible result.
See [docs/LOADER-BOUNDARY-ANALYSIS.md](docs/LOADER-BOUNDARY-ANALYSIS.md) for the completed EXP-013 result, the public Payload Guest/HEN load path, and the non-repetitive next evidence needed.
See [docs/EXP-014-DESIGN.md](docs/EXP-014-DESIGN.md) for the gated successor design that records the currently discarded HEN loader-hook return codes without repeating closed experiments.
See [docs/KNOWLEDGE-CONTINUITY.md](docs/KNOWLEDGE-CONTINUITY.md) for the local, read-only LLM Wiki index and cross-session Codex workflow.

## Repository policy

This repository contains original source code, analysis scripts, reproducibility information, and cryptographic hashes. It must not contain:

- Sony firmware, operating-system binaries, packages, or copyrighted payloads
- console-unique keys, identifiers, credentials, or personal information
- raw or decrypted console dumps
- third-party binaries without redistribution permission

Researchers must obtain any required firmware or dumps from hardware they own and verify them locally against the published manifests.

## Safety

Current acquisition tools are designed for read-only access to PS4 flash devices and write only to external USB storage. No flash-writing experiment belongs on real hardware until it has an independent review, a recovery design, and explicit documentation of brick risk.

## Layout

- `docs/` — verified findings, experiment records, and data-handling policy
- `payloads/` — original PS4 payload source
- `ghidra/` — reusable Ghidra analysis scripts
- `manifests/` — hashes and provenance, never binary artifacts
- `scripts/` — reproducible build and verification automation
- `third_party/` — pinned dependency provenance

## License

Original project code is released under `GPL-3.0-or-later`; third-party components retain their respective licenses.

See [CREDITS.md](CREDITS.md) for authorship, exact upstream revisions, licenses, runtime-component acknowledgements, and non-redistribution boundaries.
