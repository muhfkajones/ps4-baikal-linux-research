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
