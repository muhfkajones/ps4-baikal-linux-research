# Verified status

Last updated: 2026-10-24

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

EXP-010 completed the first passive observation step. The current `sm_service` record names service `8001000B`, and 2,592 captured bytes match the bank-A signed `8001000B` input exactly. No comparable aligned match was found to the acquired `80010008` AuthMgr entry. The buffer therefore retained signed/encrypted data from a later service transaction and did not yield an identifiable decrypted AuthMgr image. The original 4 KiB bound also omitted the final 896 bytes of the expected staging area; this is recorded rather than silently treated as a complete-buffer acquisition. A useful next observation must be synchronized with the `80010008` load transaction and remain read-only until its exact lifecycle and buffer ownership are established.

## Success criteria

The project goal is reached only when an owned reference console can boot a documented Linux environment after complete power loss without manually repeating the browser jailbreak and payload sequence, with a tested recovery procedure and independently reproducible build instructions.
