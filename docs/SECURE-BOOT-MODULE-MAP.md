# Secure boot module map

This note separates facts established on the owned 13.50 Baikal B1 console from hypotheses. It does not contain Sony binaries, keys, or console-unique data.

## Acquired SLB2 entries

The complete `/dev/sflash0s1.crypt` image contains two small one-entry banks and two larger seven-entry banks. Every corresponding A/B-bank entry has a different SHA-256, consistent with redundant revisioned boot banks rather than duplicate byte-for-byte copies.

| Entry | Evidence-backed role | Evidence | Current form |
|---|---|---|---|
| `80000001` | Secure Loader | Al-Azif's 13.50-compatible utility names this input; the acquired kernel searches the small boot SLB2 bank for this ID | Signed/encrypted container; header format still unclassified |
| `80010001` | Secure Kernel | Al-Azif's 13.50-compatible utility names this input | Signed SELF container |
| `80010002` | Orbis/FreeBSD kernel with AMD microcode wrapper | Al-Azif's kernel utilities name this input | Signed SELF container |
| `80010006` | PUP update secure module | The acquired kernel spawns this ID from `sbl/pup_update/pup_update.c` | Signed SELF container |
| `80010008` | AuthMgr secure module | The acquired kernel spawns this ID from `sbl/authmgr/authmgr_secure_module.c`; Al-Azif independently names it AuthMgr | Signed SELF container |
| `80010009` | Unknown secure module | Spawned by the acquired kernel; no sufficiently authoritative friendly-name source yet | Signed SELF container |
| `8001000A` | Unknown secure module | Spawned by the acquired kernel; no sufficiently authoritative friendly-name source yet | Signed SELF container |
| `8001000B` | Unknown secure module | Spawned by the acquired kernel; no sufficiently authoritative friendly-name source yet | Signed SELF container |

Fourteen of the sixteen bank entries start with bytes `4f 15 3d 1d`, or little-endian `0x1d3d154f`. The acquired kernel's `_sceSblAuthMgrCheckSelfHeader` path checks that same value. This supports classifying those entries as signed SELF containers. It does not establish that their executable plaintext is present on flash.

## What this proves

The ordinary Orbis kernel is above the decisive early trust boundary. Secure Loader and Secure Kernel are selected from signed flash containers, while AuthMgr participates in later SELF authentication. Linux currently runs only after the browser exploit, kernel patch, and loader payload have already bypassed the normal running system.

The public utilities inspected at pinned revision `241782df7b3d72b762e5c4c324537d0c868eeb8d` explicitly require **decrypted** Secure Loader, Secure Kernel, and AuthMgr binaries. Running them on the extracted flash entries would be invalid and could produce misleading output.

## Next acquisition target

The next useful evidence is the decrypted in-memory representation of:

1. `80000001` Secure Loader;
2. `80010001` Secure Kernel; and
3. `80010008` AuthMgr.

Acquisition must be read-only and occur after the secure processor has authenticated/decrypted each target. Before any hardware run, a proposed method must identify the exact address and lifetime of the plaintext, prove that all source reads are bounded, write only to external USB or a diagnostic log, and pass the same build/hash/Ghidra review used for the existing acquisition payloads.

## What is not yet proved

- No cold-boot Linux path has been demonstrated.
- No signing bypass or replacement early-stage image has been produced.
- No write to internal flash is authorized or planned.
- The roles of `80010009`, `8001000A`, and `8001000B` remain unresolved.
- The different header used by `80000001` is not yet classified from primary evidence.

## Public reference

- [Al-Azif/ps4-re-utilities](https://github.com/Al-Azif/ps4-re-utilities), revision `241782df7b3d72b762e5c4c324537d0c868eeb8d`, GPL-3.0. The upstream README states compatibility through firmware 13.50 and requires separately obtained decrypted inputs.
