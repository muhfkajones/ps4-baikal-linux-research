# EXP-014 audit record

## Pinned input

- HEN source revision: `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e`
- Patch: `hen-exp014.patch`
- Patch SHA-256: `F1BED2059C538614779F9CF1F6F4387ADF7465486D0A87AA54C7E4564D4999AC`
- Firmware scope: 13.50
- Title scope: Payload Guest `AZIF00003`

## Completed source gates

- [x] Patch applies cleanly to the pinned revision.
- [x] Existing syscall-594 behavior is preserved.
- [x] Trace output is title-locked and contains no kernel address, memory content, or device-unique value.
- [x] Readback reuses syscall 109 command 10, accepts only the calling process on firmware 13.50, and copies one fixed 56-byte record.
- [x] Collector requires a private build-time host, performs no file I/O, and validates magic, version, trigger, and completion fields.
- [x] Minimal installer omits the stock HEN setup/config/plugin-write path and installs only the volatile in-memory kernel component.

## Completed build gates

- [x] Two clean builds of each component are byte-identical.
- [x] All linked ELFs contain zero relocations.
- [x] Post-link Ghidra accounts for every recovered function in all three components.
- [x] Eight committed host tests cover a complete record, truncation, bad magic, non-Boolean flags, extra lines, one-shot reception, and oversized network input.

## Build-provenance correction after hardware failure

The kernel component was built with Zig 0.17.0 rather than the pinned source tree's declared `gcc`. The preserved build tree also changed `kpayload/linker.x` from a catch-all discard to a narrow discard so Zig-emitted orphan sections remained linked. That delta was not part of `hen-exp014.patch`, and there was no committed kernel-component build script when the hardware candidate was built. The exact observed linker change is now preserved at `third_party/hen-exp014-observed-linker-delta.patch`, SHA-256 `5F0D72F3D5FF126A22E65E2F2B5CBF17EAB7372E48759F7B02FD90F9F0173955`.

The post-failure `scripts/Build-HenKernelComponentAudit.ps1` reconstruction now reproduces the recorded 49,096-byte ELF and 35,184-byte flat binary exactly in two clean output directories. Exact reproduction requires Zig without upstream `-masm=intel`, ordinal normalized source ordering with `offsets/` before `offsets_file.c`, the narrow linker delta, and GNU `objcopy` removal of `.payload_bss`. Tool and input hashes are recorded in `manifests/hen-kernel-component-reconstruction.json`.

This confirms the recorded hashes, byte-identical rebuilds, relocation count, and Ghidra coverage as internally reproducible evidence for the rejected custom pipeline. Exact reconstruction alone did not establish equivalence to the upstream GCC build path or prove a panic cause. See `docs/EXP-015-FAILURE-ANALYSIS.md`.

The subsequent upstream-GCC comparison completed in GitHub Actions run `40811117638`. Two stock and two instrumented builds through GCC 11.4 and the original linker were byte-identical within each pair and contained zero relocations. The stock flat is 32,528 bytes with SHA-256 `CDA34C1865663D5995AEBF021AC4EA683E85E340C34A4810811B3F699D93BD94`; the instrumented flat is 33,128 bytes with SHA-256 `B726D9ADB8159EDDAD20384429C5059272FB03E4527D1E8F9A613DD0C8835B2C`. The rejected Zig flat is 2,056 bytes larger than that GCC instrumented result. Toolchain/layout divergence is confirmed; panic causality and hardware safety are not. See `manifests/hen-kernel-component-gcc-comparison.json`.

## Negative-capability post-link review

The minimal installer's 19 recovered reachable functions contain no `write`, `fopen`, `unlink`, `rename`, `mkdir`, configuration, or plugin-install routine. Its only file primitives are `open`, `read`, `lseek`, and `close` in the SDK initialization path that resolves the system libc. Strings for `/data/hen/plugin_mono.prx`, `plugin_bootloader.prx`, and `plugin_server.prx` remain inside the embedded kernel component because those existing HEN hook targets are the behavior under measurement; their presence is not a stock-installer filesystem path. The collector's 12 recovered functions contain socket send/connect/close behavior and no reachable filesystem primitive.

| Component | ELF bytes | ELF SHA-256 | Flat bytes | Flat SHA-256 | Ghidra |
| --- | ---: | --- | ---: | --- | ---: |
| Kernel component | 49,096 | `1B9E048A7C8012CCB899EED949FA5AED9472CD9A50BB3E0CCCB640088C11207E` | 35,184 | `AD5CDD21F5726AF55D9E0C6B3A79283EFFF16E2ECA7B0A0480FE0584D5E61066` | 43/43 |
| Minimal volatile installer | 69,984 | `ABC0E3A1CF1B845C65E559F6B236609400EBEAF58BE4230EEABB30EE2E1DE510` | 48,052 | `3C7341D407B192FB01E7168F77974899619EFDC055885258694FD929C7571A45` | 19/19 |
| User-mode collector (documentation-address audit build) | 30,616 | `57B9E556B53EF7ED12CBE402180294E97975573A7AAEBF20F774CAEFE17A89B4` | 6,852 | `66D837321B0D1F738B05746DE19BB0446C515E1646E3BA09347538889C5AFAF6` | 12/12 |

The collector hashes above use non-routable documentation address `192.0.2.1`. A hardware candidate must be rebuilt with the private workstation address, audited, and hash-recorded without committing that address.

The private-endpoint collector candidate was also built twice with byte-identical results. Its 30,616-byte ELF has SHA-256 `41DED413F30030DB0AD5413052815D867DCE7E2DFC0E80D796CF32AB4AED18BE`; its 6,852-byte flat binary has SHA-256 `B7AA8E305FB05E0EA03DAAEE3E358DB25F80BE198F6180DBF73D8F930C188B8C`. The ELF contains zero relocations and Ghidra decompiled all 12 recovered functions. The private address is excluded from Git and the Wiki source set.

## Hardware result and rejection

- Both reviewed flat binaries passed console-side FTP round-trip verification before execution.
- The minimal installer was executed exactly once while ordinary HEN was active.
- The display disappeared and the console powered off before the expected result notification.
- The collector was not executed and no capture was produced.
- A normal cold start cleared volatile state; the pinned ordinary HEN was restored successfully.
- Both rejected EXP-014 staging files were removed through FTP and verified absent.
- Exact-source review confirmed that stock HEN deliberately checks `IS_INSTALLED_PATH` and skips reinstallation. The minimal installer omitted that guard and entered `install_payload()` against a live HEN payload buffer and live hooks. This is the leading failure explanation, not a proven panic trace.
- The installer source now contains an unconditional compile-time rejection.

This deployment route is closed. No EXP-014 binary from this audit is authorized for transfer or execution.
