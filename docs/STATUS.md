# Verified status

Last updated: 2026-10-28

## Confirmed

- HEN and Debug Settings operate on the reference PS4 Pro running 13.50.
- The jailbreak is volatile and is lost after shutdown or restart.
- PS4 Linux boots successfully from external USB using a Baikal-compatible kernel and initramfs.
- The reference southbridge reports Baikal B1 (`0x30201`).
- A 44,040,192-byte decrypted Orbis kernel image was acquired and analyzed.
- A complete 33,554,432-byte raw `sflash0` image was acquired read-only.
- The raw flash layout agrees with the documented 32 MiB PS4 serial-flash layout.
- Extracted EMC, EAP, and Torus containers match archived public firmware objects byte-for-byte.
- Published Aeolia/Belize EMC/EAP keys do not decrypt the Baikal firmware objects.
- Known public legacy key material was not found in the acquired Orbis kernel.
- The decrypted system slice contains redundant signed boot banks with Secure Loader (`80000001`), Secure Kernel (`80010001`), Orbis kernel (`80010002`), PUP update (`80010006`), and AuthMgr (`80010008`) entries.
- The extracted flash entries are still signed SELF containers, not the decrypted runtime images required for code-level analysis of the early secure boot stages.
- The targeted 13.50 Secure Kernel/AuthMgr mapper and an errno-instrumented diagnostic revision were executed. All A/B inputs failed on segment zero with `ENOEXEC` (`8`), proving that the ordinary x86 SELF mapping path does not accept these secure-module executables.
- Ghidra analysis of the privately acquired 13.50 kernel confirms that AuthMgr is started through `sceSblServiceSpawn("80010008", ...)` and communicates through `sceSblServiceMailbox`, a separate SAMU-facing service path.

## Current experiment

The first crypt-device acquisition used `/dev/sflash0.crypt`. It produced a complete 32 MiB result but did not expose recognizable plaintext at the flash header or known firmware boundaries.

Kernel string and cross-reference analysis identifies `/dev/sflash0s1.crypt` and its child devices as the system-flash crypt provider used during boot. The complete 30 MiB read-only acquisition has SHA-256 `A6C4E5B897A129AFFEF8EA1F8FE168F70D916C71D20901B9D8CD1DC0E1AEDCB0` and classifies as a structured plaintext candidate. It begins with the Sony plaintext flash header, contains an `SLB2` container at `0x4000`, and has no matching 64 KiB blocks against either the raw slice or the earlier whole-device crypt-node view.

The same kernel path inventory identifies child providers `/dev/sflash0s1.cryptx1`, `x2`, `x3`, `x2b`, `x3b`, `x39`, and `x40`. The completed inventory found `SLB2` at the start of `x2`, `x2b`, `x3`, and `x3b`. The two `x2` views share a first-sector fingerprint; the two `x3` views do not. These are boot-container views, but a 512-byte probe is insufficient to establish full-content equivalence or select a modification target.

Offline inspection of the full decrypted slice found four valid SLB2 containers and 16 entries. Corresponding A/B-bank entry hashes differ throughout. No entry exactly matches the pinned public `ps4-ic-fw` archive, so component identity must be established from structure and code analysis rather than filename or archive-hash assumptions.

## Current research boundary

No permanent or cold-boot Linux mechanism has been demonstrated. Evidence currently places the unresolved trust boundary below the ordinary Orbis kernel, involving Baikal/SAMU-mediated decryption and signed early-boot components.

The next acquisition target remains the decrypted form of Secure Kernel and AuthMgr, but EXP-009 ruled out the ordinary AuthMgr-backed SELF mapper. The next implementation must observe the secure-module spawn/service path or a SAMU-facing DMA buffer and prove that the candidate buffer actually contains plaintext before copying it. Secure Loader remains a later target because its container and boot stage differ. Re-reading flash providers, changing USB paths, or rerunning the rejected mapper cannot supply those runtime images. See [SECURE-BOOT-MODULE-MAP.md](SECURE-BOOT-MODULE-MAP.md).

EXP-010 completed the first passive observation step. The observed `sm_service` record names service `8001000B`, but its current transfer-length field is only `4`. The staging area is not cleared between transfers: only its first four bytes are current, while the remainder is retained scratch history. A 2,592-byte tail matches bank-A signed `8001000B` input exactly, but that match is stale input history, not a live transaction or transformed output. The unmatched prefix is unclassified scratch history and is not evidence of SAMU output. No comparable aligned match was found to the acquired `80010008` AuthMgr entry, and no identifiable decrypted AuthMgr image was acquired. The original 4 KiB bound also omitted the final 896 bytes of the staging area. A useful next observation must record the full bounded area, interpret only the declared transfer length as current, and remain read-only until the `80010008` lifecycle and buffer ownership are established.

EXP-011 completed the full bounded baseline capture. Its 4,992-byte snapshot includes the complete `0xFE0` staging area and has SHA-256 `D2B9ED6590C783C1C0824145CF0470FFF8D8964A1C41EFEE2BA04A006C5250FD`. The service field remains `8001000B`; both the request and current-transfer lengths are `4`. Retained range `[0x5E0, 0x1380)` matches 3,488 bytes of bank-A signed `8001000B` input exactly, including all 896 bytes omitted from EXP-010. No AuthMgr match or identifiable plaintext was acquired. Payload Guest displayed an application error after execution, but the diagnostic log, exact-size snapshot, and completion marker all prove the payload itself passed. A delayed passive snapshot is now closed as a useful acquisition branch; the next experiment must observe `80010008` closer to its spawn/driver boundary.

EXP-012 tested the same bounded read as a title-specific HEN plugin during a verified fresh Payload Guest launch. The staged PRX and config matched their audited hashes before and after execution; HEN reported `2.2.0 BETA`, plugins were enabled, the generated app-info record correctly identified `AZIF00003`, and the HEN log proved the old process was killed before a new process was created. No plugin output appeared, including the first-entry log, so `plugin_load` was not reached. The staged files were removed and the exact pre-deployment state was restored. Repeating this uninstrumented stock-loader launch is closed; the next step must instrument or bypass the per-application loader boundary before attempting another early snapshot.

EXP-013 revision 7 completed in one authorized hardware run. Its 1,606-byte direct capture has SHA-256 `84F6F5530CEE77124AFE4DFE8DD58DAC362E8A79D40F4BF8C28D3DB3735BC4AE` and passed the strict parser: UID `0`, sandboxed, enumeration result `0`, 21 modules, zero module-info failures, and the final completion marker. The current process contained `guest.elf`, `libkernel_sys.sprx`, and 19 ordinary system/runtime modules; the missing EXP-012 custom plugin was not present. This is observational and cannot prove that no loader hook ran earlier or that no module was transiently present. Payload Guest displayed `CE-34878-0` before the `.bin` ran; the operator returned home, reopened Payload Guest, and then completed the single authorized run. The reintroduced EXP-012 config targeting an absent PRX was backed up, hash-verified, and reversibly disabled. No post-run crash was confirmed and no second capture was produced. EXP-013 is now closed against identical repetition; a useful successor must inspect or instrument the loader implementation rather than repeat current-process enumeration.

Read-only retrieval then confirmed that the installed HEN bootloader and plugin loader are byte-identical to the official `build_86` release and embed source commit `a717ffd0b4699d72d4fd33dab0ca422270fcfd25`. Installed-component drift is therefore ruled out as the explanation for EXP-012/EXP-013. The exact embedded source keeps both modules loaded on its normal success path, weakening a transient-unload explanation. The remaining loader-boundary hypotheses are that the hook was not reached/installed, injection failed, or loaded modules were omitted from the later module inventory API result.

Exact-source review identified the next evidence gap: the ordinary syscall-594 application hook discards the bootloader-load, `_init_env` lookup, and `plugin_load` lookup return values. [EXP-014](EXP-014-DESIGN.md) implemented a firmware- and title-locked bounded trace, but its minimal live-replacement installer failed on its single hardware run: video disappeared and the console powered off before a result notification. The collector did not run and no capture was produced. Cold-start rollback and the pinned normal HEN succeeded; both staged candidates were removed. Stock HEN deliberately skips reinstallation when its installed marker exists, while the minimal installer omitted that guard and called the payload replacement path against active HEN. That live-replacement route is rejected and compile-time blocked. Any successor must install the instrumented component during the initial HEN load or use a separately proven non-overwriting observation method; it must not replace active HEN.

[EXP-015](EXP-015-DESIGN.md) is the offline-only initial-load correction. It stops if stock HEN's marker exists, applies the normal installer-side patches before installing the instrumented component, and has no reachable persistent-write/config/plugin-install routine. Two builds are byte-identical, the ELF has zero relocations, and Ghidra decompiled 22/22 functions. It has not been transferred or executed. Host substitution now uses a validated unique-filename override without replacing the pinned `hen.bin`; an isolated HTTP audit verified both exact hashes and left normal HEN unchanged. The uniquely named collector was rebuilt twice, and its flat executable is byte-identical to the prior zero-relocation, Ghidra 12/12 reviewed collector. The reviewed initial-load ordering is recorded in [EXP-015-RUNBOOK.md](EXP-015-RUNBOOK.md). Hardware remains blocked on console-side collector verification, live-LAN served hashes, listener readiness, and explicit authorization.

## Success criteria

The project goal is reached only when an owned reference console can boot a documented Linux environment after complete power loss without manually repeating the browser jailbreak and payload sequence, with a tested recovery procedure and independently reproducible build instructions.
