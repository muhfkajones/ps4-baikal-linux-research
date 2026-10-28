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

## EXP-007 — Signed boot-module identification

- Date: 2026-10-24
- Input: private SLB2 entry set from EXP-006 and the privately acquired 13.50 Orbis kernel
- Public reference: `Al-Azif/ps4-re-utilities` revision `241782df7b3d72b762e5c4c324537d0c868eeb8d`
- Confirmed identities: `80000001` Secure Loader; `80010001` Secure Kernel; `80010002` Orbis kernel; `80010006` PUP update secure module; `80010008` AuthMgr secure module
- Kernel evidence: `80010006` is spawned from the compiled `sbl/pup_update/pup_update.c` path; `80010008` is spawned from `sbl/authmgr/authmgr_secure_module.c`; update logic searches the small SLB2 banks for `80000001`
- Container evidence: 14 of 16 extracted entries begin with little-endian `0x1d3d154f`, the magic checked by `_sceSblAuthMgrCheckSelfHeader`; both `80000001` entries use a different still-unclassified container header
- Unresolved identities: `80010009`, `8001000A`, and `8001000B` are preserved as unknown secure modules until a primary source or code evidence identifies them
- Conclusion: the on-flash entries are not the decrypted inputs required by the public 13.50 utilities. Future acquisition must capture decrypted runtime modules after the secure processor has authenticated and transformed them

## EXP-008 — Targeted Secure Kernel and AuthMgr decryptor, offline audit

- Date: 2026-10-24
- Hardware status: executed; no snapshot was produced
- Target firmware: exactly 13.50
- Inputs: A/B copies of signed `80010001` and `80010008`, read only from `/mnt/usb0/ps4-re-input`
- Outputs: reconstructed ELF32 program segments, log, and completion marker only under `/mnt/usb0/ps4-re-output`
- Kernel action: the pinned SDK's volatile `mmap_patch`; no persistent kernel or flash modification
- ELF build: 39,832 bytes; SHA-256 `9DD503027E90428CFF6C1FB97D7B77DF6B6F0CDCD27060195F220A5C7276E32A`
- Flat payload: 15,108 bytes; SHA-256 `AF4C84DBFA288F71926F7544200AF124D1A4684870E1D6C13A9512C8B510FF73`
- Reproducibility: two consecutive clean invocations produced identical sizes and hashes
- Relocation audit: the linked ELF contains no relocation records
- Ghidra audit: the flat payload was analyzed as x86-64; 30 functions were found and all 30 decompiled successfully
- Compiled-path audit: all persistent paths are under the two declared USB directories; no `/dev/` path is present
- Structural basis: both `80010001` copies contain two ordinary ELF32 load segments; both `80010008` copies contain three ordinary ELF32 load segments; no nested or special unencrypted program segment is present
- Decision: retain as prepared but unexecuted until the reviewed source and audit record are committed and the transferred payload hash is reverified

## EXP-009 — Secure Kernel and AuthMgr ordinary-mapper rejection

- Date: 2026-10-24
- Reference system: PS4 Pro CUH-7215B, firmware 13.50, Baikal B1
- Inputs: hash-verified A/B signed SELF copies of `80010001` and `80010008` on external USB
- v1 flat payload SHA-256: `AF4C84DBFA288F71926F7544200AF124D1A4684870E1D6C13A9512C8B510FF73`
- Diagnostic v2 flat payload SHA-256: `2F1789C3F508E0787D18B8FF8F3A19F3B08D2A188984152A347DA30260893323`
- Runtime preconditions: firmware check passed; jailbreak result `0`; volatile `mmap_patch` result `0`
- Result: all four inputs failed on program segment zero with `mmap` errno `8` (`ENOEXEC`)
- Output behavior: diagnostic v2 removed each incomplete output; no `.complete` marker was created
- Repetition: a later diagnostic run produced a byte-identical log with SHA-256 `9F0B99949831B93C6AB70965DA38E429236EE663A4D793233D9C53543EC2FBA7`
- Kernel trace: the 13.50 Orbis kernel starts AuthMgr with `sceSblServiceSpawn("80010008", ...)` and exchanges requests through `sceSblServiceMailbox`; this is separate from the ordinary x86 SELF mapping path used by v1/v2
- Conclusion: the signed containers are readable and structurally valid, but the ordinary AuthMgr-backed executable mapper rejects their secure-module ELF machine/type. Retrying paths, flags, USB preparation, or the same mapper cannot expose their plaintext
- Next target: trace the secure-module spawn/service path and SAMU-facing buffers without modifying flash; do not attempt another ordinary `mmap` decryptor revision

## EXP-010 — Bounded `sm_service` state snapshot

- Date: 2026-10-25
- Hardware status: executed on the owned reference console
- Target firmware: exactly 13.50
- Read range: `kernel_base + 0x02680800`, exactly `0x1000` bytes
- Basis: targeted Ghidra analysis places the `sm_service` control/request records and sector staging buffer inside this range
- Persistent writes: snapshot, log, and completion marker only under `/mnt/usb0/ps4-re-output`
- Excluded actions: no flash access, hook installation, secure-module respawn, or undocumented mailbox request
- ELF build: 37,928 bytes; SHA-256 `996498329D4F58963DFAC32112B7461140F11D596E9E3E92FFF7A842F8E3051D`
- Flat payload: 15,524 bytes; SHA-256 `2FCB173556A554F272F692E043513A53B11972D4006567D8E3B83F1AA1BE4F78`
- Reproducibility: two consecutive clean invocations produced identical sizes and hashes
- Relocation audit: the linked ELF contains zero `SHT_REL`/`SHT_RELA` sections
- Ghidra audit: 26 functions found; all 26 decompiled successfully
- Compiled-path audit: all persistent paths are below the declared external-USB output root; no `/dev/` path is present
- Transfer verification: the FTP round-trip copy matched the audited flat-payload hash before execution
- Runtime log: firmware `0x546` (decimal 1350), kernel base `0xffffffffdf46c000`, bounded kernel read result `0`, file write result `0`, and final `PASS`
- Snapshot: exactly 4,096 bytes; SHA-256 `CBECE299A0B1845620B08D40BED0838394C5445239D9620A63675CAE11CFFCB2`
- Completion marker: present and contains `complete`
- Observed service record: ASCII service identifier `8001000B` at snapshot offset `0x48`
- Current transfer length: the `sm_service` length field at snapshot offset `0x39C` is `4`; only the first four bytes of the staging area at `0x3A0` belong to the current transfer
- Bound correction: the staging area begins at snapshot offset `0x3A0`; the 4 KiB snapshot therefore contains only `0xC60` (3,168) of its expected `0xFE0` (4,064) bytes and omits the final `0x380` (896) bytes
- Scratch-state correction: the staging area is not cleared between transfers, so bytes after the current four-byte transfer are retained history rather than current service output
- Exact private comparison: snapshot range `[0x5E0, 0x1000)` is identical to bank-A signed entry `8001000B` range `[0xC5E0, 0xD000)`, an exact 2,592-byte retained-history match
- Cross-entry comparison: no meaningful 32-byte-or-larger match at a 16-byte-aligned snapshot offset was found against the other acquired signed bank entries, including `80010008`
- Conclusion: the passive post-boot staging state contains four current bytes plus uncleared history. The retained tail includes signed `8001000B` input, but the unmatched prefix is unclassified scratch history and is not evidence of SAMU output. No identifiable decrypted AuthMgr image was acquired. The next observation must distinguish the current transfer from retained history and be tied to the `80010008` lifecycle

## EXP-011 — Full bounded `sm_service` state snapshot

- Date prepared: 2026-10-25
- Hardware status: executed on the owned reference console
- Target firmware: exactly 13.50
- Read range: `kernel_base + 0x02680800`, exactly `0x1380` (4,992) bytes
- Coverage: `0x3A0` bytes of control/request state plus the complete `0xFE0`-byte staging area
- Persistent writes: uniquely named snapshot, log, and completion marker only under `/mnt/usb0/ps4-re-output`
- Excluded actions: no flash access, kernel write, hook installation, secure-module respawn, or undocumented mailbox request
- ELF build: 37,912 bytes; SHA-256 `9DCAE587AC477012C54202756D6BBDD2A36DD1FE9283FE5B455DA4EDD59BA8BA`
- Flat payload: 15,556 bytes; SHA-256 `9B2472DC8018369E4691A347F7F5286A570AC27B9B636093F9926BA87E9DB19C`
- Reproducibility: two consecutive build invocations produced identical sizes and hashes
- Relocation audit: the linked ELF contains zero `SHT_REL`/`SHT_RELA` sections
- Ghidra audit: 26 functions found; all 26 decompiled successfully
- Compiled-path audit: only the three declared external-USB output paths are present; no `/dev/` path is present
- Analysis rule: only the declared transfer length at offset `0x39C` identifies current staging bytes; the remaining staging bytes are retained history
- Transfer verification: the uploaded payload was retrieved through FTP and its SHA-256 matched the audited build exactly
- Lifecycle basis: the 13.50 kernel clears AuthMgr's started flag during suspend, while the inspected HEN source registers a resume-phase patch handler and documents Rest Mode support; the capture sequence is recorded in [AUTHMGR-LIFECYCLE.md](AUTHMGR-LIFECYCLE.md)
- Rest-mode attempt: Payload Guest returned an application error immediately on resume, before this diagnostic was selected; no EXP-011 output was created by that attempt
- Executed sequence: after the subsequent restart, HEN was restored and PS4-Xplorer supplied FTP; the full snapshot was then run as a post-boot baseline
- Runtime log: firmware `0x546` (decimal 1350), kernel base `0xffffffffce774000`, bounded kernel read result `0`, file write result `0`, and final `PASS`
- Payload Guest behavior: the host application displayed an error after the payload ran; the complete diagnostic output proves that this was not a payload failure
- Snapshot: exactly 4,992 bytes; SHA-256 `D2B9ED6590C783C1C0824145CF0470FFF8D8964A1C41EFEE2BA04A006C5250FD`
- Completion marker: present and contains `complete`
- Observed service: `8001000B`
- Declared request length: `4` bytes
- Declared current transfer length: `4` bytes; current data `c4 b6 a3 61`
- Full-buffer result: all `0xFE0` staging bytes were captured; no staging bytes are omitted
- Exact private comparison: retained snapshot range `[0x5E0, 0x1380)` is identical to bank-A signed entry `8001000B` range `[0xC5E0, 0xD380)`, an exact 3,488-byte stale-history match
- Cross-entry comparison: no meaningful current or retained-history match was found against either acquired `80010008` AuthMgr entry
- Conclusion: completing the previously omitted tail strengthens the input-history classification but does not expose AuthMgr plaintext. Another delayed passive snapshot is not a useful repetition; further work must observe the `80010008` transaction closer to its spawn boundary

## EXP-012 — Payload Guest early-load `sm_service` snapshot plugin

- Date prepared: 2026-10-25
- Hardware status: not executed
- Target firmware: exactly 13.50
- Target application: Payload Guest title ID `AZIF00003` only
- Timing change: HEN's existing title-specific plugin loader invokes the diagnostic while Payload Guest starts, before manual payload selection
- Read range: `kernel_base + 0x02680800`, exactly `0x1380` bytes
- Persistent writes: uniquely named snapshot, log, and completion marker only under `/mnt/usb0/ps4-re-output`
- Excluded actions: no flash access, kernel write, hook installation, secure-module respawn, or undocumented mailbox request
- Configuration rule: install only in the `[AZIF00003]` section; never enable in `[all]`
- Rollback: restore the exact pre-deployment `/data/hen/plugins.ini` backup and delete the plugin PRX
- Offline build: GitHub Actions run `40244433237` completed successfully; two builds produced byte-identical ELF and PRX files
- Audited PRX: 53,408 bytes; SHA-256 `82BC5D8039E854377DACE81C74BCEA3231C11D5F6D00E3112CED49F9405D57CE`
- Callback audit: fixed firmware offsets and exactly two computed `copyout` calls—one 4,992-byte state read and one 8-byte kernel-base report; no other kernel call or write
- Compiled-path audit: only the three declared external-USB output paths; no `/dev/` path
- Configuration pre-state: `/data/hen/plugins.ini` absent and `/data/hen/plugins/` empty through PS4-Xplorer FTP
- Staging: the PRX and new title-specific config were uploaded through PS4-Xplorer FTP, retrieved, and verified byte-for-byte
- Round-trip PRX SHA-256: `82BC5D8039E854377DACE81C74BCEA3231C11D5F6D00E3112CED49F9405D57CE`
- Round-trip config SHA-256: `B41B95CB8CCE9C217ABE109D40CFBBD551B8C5081A4C9C151CDDC35927EB4548`
- Runtime preconditions: installed HEN reported `2.2.0 BETA`; `/data/hen/hen.ini` had `enable_plugins = 1`; Payload Guest's generated HEN app-info record identified PID 97, title ID `AZIF00003`, category `gde`, and app version `0.98`
- Fresh-launch proof: the HEN log recorded the old `AZIF00003` process being killed, followed by a new `createApp AZIF00003` sequence and new `eboot.bin`/`guest.elf` process creation; this was not a suspended-app resume
- Runtime result: none of the three declared `authmgr-early-state-1350` output files appeared, including the first-entry log; therefore `plugin_load` did not reach its first observable statement
- Loader evidence: the installed config and PRX were retrieved after the fresh launch and still matched the audited hashes exactly, excluding transfer corruption or title-ID/config mismatch
- Conclusion: the stock HEN per-application loader path did not invoke this custom PRX on the verified 13.50 Payload Guest launch. Repeating the same launch is not useful. A subsequent experiment must first instrument or bypass the per-app loader boundary rather than changing snapshot offsets
- Rollback result: `/data/hen/plugins.ini` and `/data/hen/plugins/authmgr-early-snapshot.prx` were deleted; a post-delete listing confirmed the config absent and the plugin directory empty, restoring the documented pre-state
- Decision basis: EXP-011 proved that delayed post-launch snapshots only expose four current bytes plus retained signed `8001000B` input history; EXP-012 tested the lowest-risk timing improvement and closed the uninstrumented stock-loader branch without modifying kernel or flash state

## EXP-013 — Payload Guest user-mode module inventory

- Date reviewed: 2026-10-27
- Hardware status: not executed
- Current source revision: 6
- Purpose: inventory modules visible to the Payload Guest process without repeating the closed EXP-012 plugin launch
- Output: syscall-601 debug channel only; no file or completion-marker output
- Observations: process UID, sandbox state, bounded loaded-module handles, and printable module names
- Excluded actions: no jailbreak helper, kernel-memory read or write, custom PRX load, filesystem access, flash access, hook installation, or secure-module request
- Enumeration bound: 256 handles; invalid or truncated counts stop the diagnostic
- ELF build: 26,376 bytes; SHA-256 `189F84346FDC410FDFA28B4A7461DB84633912BED402709494379CC970EBF28C`
- Flat payload: 5,760 bytes; SHA-256 `ADA2FB9F75DAD721BDD4979D9F30BBCD234B4F752A65FD71D4D33F044BEDB2E8`
- Reproducibility: two consecutive local builds produced identical outputs
- Ghidra audit: 11 functions found; all 11 decompiled successfully; the reachable revision-6 path contains no kernel-memory access, filesystem operation, custom PRX load, flash access, hook installation, or secure-module/service-mailbox call
- Review archive: SHA-256 `32C902C2E418A9D4C6889FC0AC4167D8F2AB2FBB308E6F0293310CD30F7B6FC1`; all five files matched the working copies before documentation reconciliation
- Evidence boundary: current module presence or absence is observational and cannot prove whether a loader hook ran earlier or a module was transiently present
- Current gate: offline source/build/post-link review complete; do not deploy until transfer-hash verification is complete and the user explicitly authorizes the hardware run
- Gate-1 preflight (2026-10-27): PS4-Xplorer exposed its verified FTP service on TCP 2121; the installed HEN reported `2.2.0 BETA`, `enable_plugins = 1`, and included `plugin_server.prx`, but the plugin-server klog port 3232 was not listening
- Current configuration observation: `/data/hen/plugins.ini` is again present with SHA-256 `B41B95CB8CCE9C217ABE109D40CFBBD551B8C5081A4C9C151CDDC35927EB4548`, exactly matching the EXP-012 title-specific config, while `/data/hen/plugins/` is empty; this is a later reintroduction after the documented EXP-012 rollback, not evidence that the rollback record was wrong
- Capture blocker: do not execute revision 6 while the klog capture service is unavailable; establish a separately reviewed capture route first
- Revision-7 fallback review: the same bounded user-mode inventory now has a direct outbound TCP capture route to a private build-time workstation address; it adds no kernel-memory access, file I/O, custom PRX load, flash access, hook, or secure-module request
- Revision-7 flat payload: 7,044 bytes; SHA-256 `8270D9C6470E27A51AF2FC37C5B84F7775C14D5D3988A4051BB9AB64B01CCA70`; two corrected local builds were byte-identical
- Revision-7 Ghidra audit: 15 functions found and all 15 decompiled; reachable behavior is initialization, one outbound capture connection, the revision-6 observations, complete-line sends, socket close, and syscall-601 mirroring
- Revision-7 host tooling: bounded listener and strict parser passed localhost integration; the parser accepted a complete fixture and rejected a truncated fixture
- Current gate: revision 7 has not been transferred or executed; require console-side round-trip hash verification, an active listener, and explicit user approval before launch
- Transfer gate result (2026-10-27): revision 7 was uploaded to `/data/payloads/hen-loader-boundary-network-1350.bin`, retrieved read-only in full despite PS4-Xplorer's short ordinary transfers, and matched the audited 7,044-byte SHA-256 `8270D9C6470E27A51AF2FC37C5B84F7775C14D5D3988A4051BB9AB64B01CCA70`
- Transfer correction: the first raw-socket upload retained only 16 bytes; that exact incomplete new staging file was removed, the upload method was corrected, and the final console-side round trip passed; no payload was executed during either transfer
- Remaining gate: start and confirm the host listener, then obtain explicit authorization for one hardware execution
- Hardware result (2026-10-27): revision 7 executed once after explicit authorization; the 1,606-byte direct capture has SHA-256 `84F6F5530CEE77124AFE4DFE8DD58DAC362E8A79D40F4BF8C28D3DB3735BC4AE` and passed the strict parser
- Runtime observations: UID `0`, sandbox state `1`, enumeration result `0`, 21 modules, zero module-info failures, and the final completion marker; no kernel reads or file writes were attempted
- Loader-boundary finding: the live process contained `guest.elf`, `libkernel_sys.sprx`, and 19 ordinary system/runtime modules; the missing EXP-012 custom plugin was not present in the current module list
- Evidence limit: current absence does not prove that no loader hook ran earlier or that no module was transiently present
- Launch and completion behavior: Payload Guest displayed `CE-34878-0` before the `.bin` ran. The operator returned to the home screen, reopened Payload Guest, and then ran the `.bin` once, producing the complete 1,606-byte capture. The reintroduced EXP-012 `plugins.ini` targeted a missing PRX; the exact 59-byte config was backed up and hash-verified, then reversibly renamed to `plugins.ini.disabled-exp013-20261027`. No post-run crash was confirmed and no second capture was produced.
- Decision: EXP-013 is complete; do not repeat the same module inventory without new evidence or a changed loader implementation

## EXP-014 — HEN loader return-code trace, offline implementation audit

- Date reviewed: 2026-10-28
- Hardware status: not executed; no hardware execution authorized
- Pinned HEN source: `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e`
- Patch SHA-256: `F1BED2059C538614779F9CF1F6F4387ADF7465486D0A87AA54C7E4564D4999AC`; applies cleanly to a fresh pinned checkout and exactly matches the reviewed source
- Scope gates: firmware 13.50, exact Payload Guest title `AZIF00003`, and the existing `/app0/sce_module/libc.prx` hook trigger
- Evidence: original load result/application handle; bootloader-load result/handle; `_init_env` and `plugin_load` lookup results plus pointer-presence flags; both bounded patch-write results; completion marker
- Readback: fixed 56-byte record through existing syscall 109 command 10; only the calling process is accepted; no kernel address, raw memory, device identifier, or unique material is exposed
- Persistence boundary: proposed installer excludes the stock HEN setup/config/plugin-write path and installs only the volatile in-memory component; the collector performs no file I/O
- Kernel component: 49,096-byte ELF SHA-256 `1B9E048A7C8012CCB899EED949FA5AED9472CD9A50BB3E0CCCB640088C11207E`; 35,184-byte flat SHA-256 `AD5CDD21F5726AF55D9E0C6B3A79283EFFF16E2ECA7B0A0480FE0584D5E61066`
- Minimal installer: 69,984-byte ELF SHA-256 `ABC0E3A1CF1B845C65E559F6B236609400EBEAF58BE4230EEABB30EE2E1DE510`; 48,052-byte flat SHA-256 `3C7341D407B192FB01E7168F77974899619EFDC055885258694FD929C7571A45`
- Collector audit build: 30,616-byte ELF SHA-256 `57B9E556B53EF7ED12CBE402180294E97975573A7AAEBF20F774CAEFE17A89B4`; 6,852-byte flat SHA-256 `66D837321B0D1F738B05746DE19BB0446C515E1646E3BA09347538889C5AFAF6`; uses non-routable documentation address `192.0.2.1`, not a private endpoint
- Reproducibility and link audit: two clean builds of every component were byte-identical; all three linked ELFs contain zero relocations
- Ghidra audit: kernel 43/43, minimal installer 19/19, collector 12/12 functions successfully decompiled
- Rejected branch: the full stock HEN installer was built only for comparison and is not a deployment candidate because it can skip when HEN is active and includes persistent `/data/hen` setup/config/plugin behavior
- Private-endpoint collector: two byte-identical builds; 30,616-byte ELF SHA-256 `41DED413F30030DB0AD5413052815D867DCE7E2DFC0E80D796CF32AB4AED18BE`; 6,852-byte flat SHA-256 `B7AA8E305FB05E0EA03DAAEE3E358DB25F80BE198F6180DBF73D8F930C188B8C`; zero relocations; Ghidra 12/12; private address excluded from Git and Wiki
- Host validation: eight committed tests pass, covering the complete record, truncation, bad magic, non-Boolean presence flags, extra lines, one-shot reception, and oversized network input
- Negative-capability link audit: the minimal installer's 19 recovered reachable functions contain no write, rename, unlink, mkdir, configuration, or plugin-install routine; the collector's 12 recovered functions contain no reachable filesystem primitive
- Transfer preflight: both uniquely named staged files were retrieved read-only from `/data/payloads` and matched their audited sizes and hashes exactly; neither file has been executed
- Remaining gates: explicit authorization, transfer of the two reviewed flat binaries, console-side round-trip hashes, and listener-ready confirmation before one hardware run
- Closed branches remain closed: do not repeat EXP-012 stock-plugin launch or EXP-013 module inventory
- Hardware attempt (2026-10-28): both staged flat binaries first passed exact FTP round-trip verification. The minimal installer was then executed once while ordinary HEN was active. The display disappeared and the console powered off before the expected notification. The collector was not executed and no capture was produced.
- Recovery: a normal cold start cleared volatile state; the pinned ordinary HEN was restored successfully; both EXP-014 staging files were removed through FTP and verified absent
- Failure analysis: stock HEN deliberately checks its installed marker and skips reinstallation. The minimal installer omitted that guard and called the payload replacement path while the prior HEN payload and hooks were live. This is the leading explanation for the shutdown, but no panic trace was captured
- Decision: reject and compile-time block the live-HEN replacement installer. Do not rebuild, transfer, or execute either audited EXP-014 binary. A successor must operate during initial HEN installation or avoid overwriting active HEN

## EXP-015 — Initial-load HEN loader trace, offline candidate

- Date reviewed: 2026-10-28
- Hardware status: not executed; not authorized
- Purpose: retain the bounded EXP-014 return-code trace while eliminating live HEN replacement
- Deployment phase: initial HEN load from the established Beast exploit host after a cold start and before any HEN payload or hook exists
- Active-HEN guard: checks stock HEN's installed marker and stops before patching if HEN is already active
- Behavior: applies required installer-side patches once, installs the instrumented component with normal internal patches and plugin hooks enabled, and performs no configuration/plugin/marker/flash write
- Reproducibility: two byte-identical builds
- ELF: 77,240 bytes; SHA-256 `B61BF1E0003E024E1FF50FCB40BFBA1C239DED966D1F607F96FDB8A8C0A8E8FA`
- Flat payload: 55,044 bytes; SHA-256 `FA3ED59E61653613E415022D8DDBC5DF1DD5901761466FA30C4EE9D2492301C6`
- Link audit: zero relocations
- Ghidra audit: 22/22 functions decompiled; no reachable persistent-write, configuration, or plugin-install routine
- Host audit: the exploit page's validated `payloadfile` override initially was not applied to the fetch target; the local host correction now selects `PAYLOAD_OVERRIDE || "hen.bin"`
- Isolated HTTP result: the unchanged 500,448-byte normal HEN served as SHA-256 `C05F6097DBC0707E8EC2FB5443EE507DA6AC6E79C6FA8E9F78544658710EFEFF`; the uniquely named 55,044-byte candidate served as SHA-256 `FA3ED59E61653613E415022D8DDBC5DF1DD5901761466FA30C4EE9D2492301C6`
- Rollback design: normal `hen.bin` is never replaced; omitting the override selects pinned normal HEN on the next cold start
- Collector rebuild: two uniquely named builds were byte-identical; ELF 30,664 bytes SHA-256 `93B0F550B8A06563A87939698981A4141491349FB573378F05448D70B305D518`; flat payload 6,852 bytes SHA-256 `B7AA8E305FB05E0EA03DAAEE3E358DB25F80BE198F6180DBF73D8F930C188B8C`
- Collector audit continuity: the rebuilt flat payload is byte-identical to the prior private collector that completed zero-relocation and Ghidra 12/12 review; the private endpoint remains outside Git and Wiki
- Current gate: hardware remains unauthorized and offline only. Require console-side collector round-trip verification, actual LAN served-hash verification, listener-ready confirmation, and explicit authorization
