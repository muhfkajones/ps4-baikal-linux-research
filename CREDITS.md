# Credits and third-party provenance

This project exists because of years of public PS4, FreeBSD, Linux, and reverse-engineering work. Credit is recorded here even when a component was only studied or used locally and is not redistributed.

Repository maintainers must preserve upstream copyright notices and license terms. A link or acknowledgement is not a substitute for a license. Components listed as **reference only** must not be copied into this repository without separate permission.

## Project work

- **muhfkajones** — project owner, hardware testing, research direction, and repository maintenance.
- **PS4 Baikal Linux Research contributors** — original acquisition payload, build automation, Ghidra scripts, documentation, and analysis recorded in this repository.
- **OpenAI Codex** — assisted with source review, reproducible tooling, documentation, and repository preparation under the project owner's direction. AI assistance does not replace upstream authorship or license obligations.

Original project files are licensed under `GPL-3.0-or-later` unless a file or directory says otherwise.

## Direct build dependency

### Scene-Collective/ps4-payload-sdk

- Source: <https://github.com/Scene-Collective/ps4-payload-sdk>
- Pinned revision: `b7326416c23ce14639e9180a24093bdc5eedb579`
- Use here: headers, startup code, system-call wrappers, and `libPS4` used to build the read-only acquisition payload.
- Upstream development chain, as documented by that project: **CTurt → IDC → xvortex → stooged → Scene-Collective**.
- License status at the pinned revision: no `LICENSE`, `COPYING`, or equivalent file was present in the inspected repository tree.
- Distribution rule here: the SDK is not vendored. Users obtain it directly from upstream. `third_party/ps4-payload-sdk-zig-compat.patch` contains this project's compatibility changes plus the minimum patch context required to apply them; it does not grant rights to the upstream SDK.

## Exploit and runtime components used during experiments

These components enabled local testing or produced research inputs. They are not included in this repository.

### caziques/PS4 local exploit host

- Source: <https://github.com/caziques/PS4>
- Inspected revision: `bfe68cfe24d0a42660a617929285f3421a21923a`
- Use here: local browser exploit hosting, firmware 13.50 kernel-patch testing, payload delivery, and step logging.
- Upstream credited by that repository: [raw13g/raw13g.github.io](https://github.com/raw13g/raw13g.github.io) for the exploit chain and UI; **TheFlow** for the `lapse` kernel vulnerability; **SiSTR0** for GoldHEN; **Scene-Collective**, **flat_z**, **Vortex**, and **Specter** for HEN work.
- License status: no license file was present at the inspected revision. **Reference only; do not redistribute its files from this project.**

### ps4-linux/ps4-linux-loader

- Source: <https://github.com/ps4-linux/ps4-linux-loader>
- Inspected revision: `f70f43a60a973b3662daeb29c1f115d95408db93`
- Runtime release used: `v25.1`.
- Use here: volatile `kexec` Linux loader, firmware/southbridge detection, and boot-path analysis.
- Upstream credits: **marcan, shuffle2, eeply, rancido, valeryy, ethylamine, Joonie86, sleirsgoevy, AlAzif, KiwiDog, Specter, Celesteblue, ChendoChap, zecoxao, SocraticBliss, ctn123, bestpig, EchoStretch, EinTim23, tihmstar, ArabPixel, rmuxnet**, and project contributors.
- License status: no license file was present at the inspected revision. **Reference only; loader binaries are not redistributed here.**

### Scene-Collective/ps4-hen

- Source: <https://github.com/Scene-Collective/ps4-hen>
- Inspected revision: `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e`
- Use here: HEN and Debug Settings during acquisition and Linux-loader experiments.
- Upstream contributors include **qwertyoruiopz, Specter, flat_z, idc, Joonie86, Vortex, zecoxao, SiSTR0, SocraticBliss, ChendoChap, Biorn1950, Al-Azif, illusiony**, and anonymous contributors; the upstream README remains the authoritative list.
- License status: no license file was present at the inspected revision. **Reference only; HEN binaries are not redistributed here.**

### Scene-Collective/ps4-hen-plugins

- Source: <https://github.com/Scene-Collective/ps4-hen-plugins>
- Inspected revision: `49534177d69d17609bcc09cd185c88df42fed8b5`
- Use here: Payload Guest used to launch diagnostic payloads; its title-aware HEN plugin loader and syscall wrapper were studied for EXP-012. The fixed-arity syscall wrapper in this project is an adaptation of the MIT-licensed `common/syscall.c` pattern.
- License: MIT; copyright © 2025 **illusiony**. The upstream license and copyright notice control.
- Distribution rule here: not vendored; runtime packages are not redistributed.

### john-tornblom/tiny-ps4-shell

- Source: <https://github.com/john-tornblom/tiny-ps4-shell>
- Referenced revision: `5ca90b7d2825e3e2c7f9fb1e81cf8949b37af563`
- Author: **John Törnblom** and project contributors.
- Use here: upstream origin credited by `Scene-Collective/ps4-hen-plugins` for the clang-compatible PS4 syscall pattern adapted into EXP-012.
- Distribution rule here: no source or binary from tiny-ps4-shell is redistributed as a standalone component; the relevant lineage is preserved in source comments and this credit entry.

### Scene-Collective/ps4-ftp

- Source: <https://github.com/Scene-Collective/ps4-ftp>
- Inspected revision: `8da148ce07993d36923db585e236373d54f40cdb`
- Use here: transfer of files between the owned reference console and the research workstation.
- Origin credited upstream: **xvortex** and [xvortex/ps4-ftp-vtx](https://github.com/xvortex/ps4-ftp-vtx).
- License status: no license file was present at the inspected revision. **Reference only; not redistributed here.**

### Lapy055/PS4-Xplorer

- Source: <https://github.com/Lapy055/PS4-Xplorer>
- Inspected public-source revision: `98a603834e598ab7907015c2f935aadc42942508`
- Developer: **Lapy** (`Lapy055`, `@Lapy05575948`).
- Use here: the installed PS4-Xplorer 2.08 application supplied the active FTP service used for EXP-011 transfer and evidence retrieval. FTP was opened from PS4-Xplorer, not from HEN Settings.
- License status: no license file was present at the inspected public-source revision. **Reference/runtime dependency only; PS4-Xplorer source and packages are not redistributed here.**

### Scene-Collective/ps4-kernel-dumper

- Source: <https://github.com/Scene-Collective/ps4-kernel-dumper>
- Inspected revision: `42fce7e6f2cf65b25e39a38373ab697593a19f12`
- Use here: acquisition of the owned console's decrypted Orbis kernel for local analysis.
- Origin credited upstream: **eversion** and [eversion/PS4-Kernel-Dumper](https://github.com/eversion/PS4-Kernel-Dumper).
- License status: no license file was present at the inspected revision. **Reference only; not redistributed here.**

### X-F1REBALL-X/PS4-Linux release materials

- Source: <https://github.com/X-F1REBALL-X/PS4-Linux/releases/tag/v1.0>
- Use here: locally downloaded PSXITArch USB image, Baikal/Belize kernels, and initramfs used to confirm volatile Linux booting.
- Distribution rule here: hashes and provenance may be recorded, but the image, kernels, initramfs, and other release binaries are not redistributed by this repository. Their respective upstream authors and licenses remain controlling.

## Reverse-engineering references

### Al-Azif/ps4-re-utilities

- Source: <https://github.com/Al-Azif/ps4-re-utilities>
- Pinned revision: `241782df7b3d72b762e5c4c324537d0c868eeb8d`
- Author: **Al Azif**.
- Use here: authoritative role mapping for the `80000001`, `80010001`, `80010002`, and `80010008` boot entries, plus requirements analysis for future decrypted-runtime acquisition.
- Firmware scope claimed upstream: the relevant extractors work through firmware 13.50.
- License: GPL-3.0 at the pinned revision.
- Distribution rule here: not vendored. The utilities require decrypted module inputs; no Sony-derived input, extracted key material, or utility output is committed to this repository.

### AlexAltea/orbital

- Source: <https://github.com/AlexAltea/orbital>
- Inspected revision: `cc408367da6a6ebbf5ac1ac559fefeadc73b2831`
- Author and copyright: **Alexandro Sanchez**, copyright © 2017.
- Use here: reference for the AuthMgr-backed SELF segment-decryption flow and the distinction between signed containers and reconstructed executable segments.
- License: MIT at the inspected revision.
- Distribution rule here: not vendored; no Orbital source or console-derived output is redistributed.

### Scene-Collective/ps4-module-dumper

- Source: <https://github.com/Scene-Collective/ps4-module-dumper>
- Inspected revision: `b430dce264821be4bd4103e5ba6f84742e4a1e08`
- Use here: reference confirming the public runtime workflow for dumping decrypted modules through firmware support supplied by the Scene-Collective SDK.
- License status: no `LICENSE`, `COPYING`, or equivalent file was present in the inspected repository tree.
- Distribution rule here: **reference only**. No source was copied and no upstream binary is redistributed.

### andy-man/ps4-ic-fw

- Source: <https://github.com/andy-man/ps4-ic-fw>
- Pinned revision: `f669d6c8c583b3cae66a833d1604598907fb8a04`
- Use here: byte-for-byte comparison against archived PS4 southbridge and Torus firmware objects.
- Credit recorded upstream: the collection was provided by **zecoxao**.
- License: GPL-3.0 at the inspected revision. Firmware objects themselves may carry separate rights; none are redistributed here.

### TeamFAPS/PS4-RE-tools

- Source: <https://github.com/TeamFAPS/PS4-RE-tools>
- Pinned revision: `ca8b692f5788fa7a61925b435192be8e6f215f86`
- Use here: PS4 firmware and flash-layout research reference.
- License: GPL-3.0 at the inspected revision.
- Distribution rule here: not vendored.

### Al-Azif/ps4-cfw-toolkit

- Source: <https://github.com/Al-Azif/ps4-cfw-toolkit>
- Pinned revision: `ed826010aa723863b3ba4efe66cb73004046a060`
- Use here: reference for EAP, EMC, Syscon, SAMU, and signed boot-chain constraints.
- License: copyright © 2022 **Al Azif**; all rights reserved, with licensing and distribution requests directed to the author.
- Distribution rule here: **reference only; no source, keys, or binaries from this project are redistributed.**

## Analysis and build tools

- [Ghidra](https://github.com/NationalSecurityAgency/ghidra), version 12.1.4 PUBLIC — reverse engineering framework maintained by the National Security Agency and contributors; Apache License 2.0. Ghidra itself is not redistributed here.
- [OpenOrbis PS4 Toolchain](https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain), release `v0.5.3` — PRX compiler, linker support, headers, stubs, and `create-fself` used for EXP-012; GPL-3.0 at that release. The toolchain is downloaded during CI and is not committed.
- [Zig](https://github.com/ziglang/zig), version 0.17.0 — compiler/toolchain used for the reproducible payload build; MIT License. Zig itself is not redistributed here.
- FreeBSD device-interface definitions informed the documented `DIOCGMEDIASIZE` and `DIOCGSECTORSIZE` constants. See the [FreeBSD source tree](https://cgit.freebsd.org/src/) for authoritative source and applicable BSD licenses.

## Trademark notice

PlayStation and PS4 are trademarks of Sony Interactive Entertainment. This independent research project is not affiliated with, authorized by, or endorsed by Sony Interactive Entertainment. No Sony firmware, operating-system binaries, cryptographic keys, or console-unique secrets are distributed by this repository.

## Corrections

If a credit, revision, or license entry is incomplete or incorrect, open an issue or pull request with the authoritative upstream source. Corrections should add history rather than erase prior contributors.
