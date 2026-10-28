# EXP-015 design — initial-load HEN loader trace

## Purpose

Retain EXP-014's bounded loader return-code evidence while eliminating its failed live-HEN replacement route.

## Deployment correction

EXP-014 attempted to overwrite the kernel payload after ordinary HEN and its hooks were already active. Stock HEN deliberately checks its installed marker and skips that case. EXP-015 instead runs only as the initial HEN payload from the established Beast exploit host after a cold start, before any HEN payload or hook exists.

The initial-load installer:

1. requires firmware 13.50;
2. performs the normal jailbreak step;
3. checks stock HEN's `IS_INSTALLED_PATH` marker and stops if HEN is active;
4. applies the required installer-side kernel patches once;
5. installs the instrumented kernel component with its normal internal patches and plugin hooks enabled; and
6. performs no configuration, plugin, marker, flash, or other filesystem write.

The installed hook remains exact-title locked to Payload Guest `AZIF00003` and firmware 13.50. Readback remains one caller-only 56-byte record through existing syscall 109 command 10. The existing strict collector and host parser remain applicable, but no EXP-014 binary may be reused.

## Offline audit status

- Initial installer source: `payloads/hen-loader-return-trace/source/initial-installer-main.c`
- Two clean installer builds: byte-identical
- ELF: 77,240 bytes; SHA-256 `B61BF1E0003E024E1FF50FCB40BFBA1C239DED966D1F607F96FDB8A8C0A8E8FA`
- Flat payload: 55,044 bytes; SHA-256 `FA3ED59E61653613E415022D8DDBC5DF1DD5901761466FA30C4EE9D2492301C6`
- Relocations: zero
- Ghidra: 22 functions found, 22 decompiled
- Ghidra analysis SHA-256: `E1D000BAFFAF6CDF81E8F1942DF5389A6264554013E2B360D10390F173097C52`
- Ghidra decompilation SHA-256: `42CF180C88E710382BC62360E9FCF1A63CB878CFAC4C9E26DD0ADF03BF27E7B7`
- Reachable filesystem behavior: read-only `file_exists()` marker check plus SDK libc resolution; no reachable write, unlink, rename, mkdir, configuration, or plugin-install routine

## Hardware result

The candidate was executed once through the reviewed initial-load URL after a full shutdown. The exploit host fetched the exact 55,044-byte payload, completed all 54 checks, and recorded `PAYLOAD-RUNNING`. The console then shut down before any installer notification, Payload Guest launch, collector execution, or capture.

Recovery required two power-on attempts. The second boot displayed `CE-36329-0` before allowing the operator to continue to the home screen. This is evidence of an abnormal system-software failure, not a normal shutdown, but it does not identify the exact kernel fault.

This initial-load result refutes the earlier assumption that EXP-014 failed solely because it replaced active HEN. The instrumented component and its shared installation path are now the common failure boundary across both attempts. No panic trace was captured, so the exact cause remains unproven.

EXP-015 is closed against repetition. The source is compile-time blocked, the host staging copy was removed, and the normal pinned HEN URL was hash-verified after rollback.

The first normal-HEN recovery attempt later reached `PAYLOAD-RUNNING` but the browser displayed a free-system-memory warning instructing a restart. That warning was incorrectly treated as non-blocking. After the restart, merely opening the browser automatically began another exploit attempt from the retained URL. The host recorded two failed anchor proofs (`pass=20 fail=2`) before another shutdown. This third shutdown was not an EXP-015 execution; it was an unsafe automatic repeat of the normal-HEN exploit while the browser/session state remained unstable. The host and capture services were stopped before further recovery.
