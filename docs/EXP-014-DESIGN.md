# EXP-014 design — HEN loader-hook return-code trace

## Purpose

Distinguish the remaining EXP-013 loader-boundary hypotheses without repeating module enumeration or the closed stock-plugin launch.

## Verified blind spot

The exact HEN source calls the original syscall-594 implementation for `/data/hen/plugin_bootloader.prx`, resolves `_init_env` in the application module, and resolves `plugin_load` in the bootloader. The hook does not retain or log the return values from those three operations on the ordinary application path. Existing HEN logs therefore cannot distinguish:

- hook trigger not reached;
- bootloader load failure;
- `_init_env` lookup failure;
- `plugin_load` lookup failure; or
- successful patch installation.

## Minimum successor evidence

A reviewed diagnostic must emit one bounded record containing:

1. a firmware-13.50 and exact-title gate for Payload Guest `AZIF00003`, plus the fixed libc PRX-path trigger;
2. original syscall-594 result and returned application handle;
3. bootloader-load result and returned bootloader handle;
4. `_init_env` lookup result and pointer-presence flag;
5. `plugin_load` lookup result and pointer-presence flag;
6. both bounded patch-write results; and
7. one final completion marker.

The publication-safe result may contain return codes and Boolean presence flags, but not kernel addresses, device identifiers, private captures, or raw memory.

## Safety gate

No hardware execution is authorized by this design. Before proposing a run, the implementation must:

- be firmware-locked to 13.50 and title-locked to `AZIF00003`;
- preserve the original hook behavior and make no persistent configuration change;
- avoid filesystem, flash, and arbitrary kernel-memory reads;
- use a bounded external diagnostic channel;
- pass reproducible build, hash, source review, and post-link Ghidra review; and
- include an exact rollback and operator handoff.

EXP-014 must not redeploy the EXP-012 plugin or rerun EXP-013's module inventory.

## Offline implementation status

The source implementation extended HEN's existing syscall 109 command path with one caller-only, firmware-locked, fixed-size readback record; no new syscall number was installed. Two clean builds of each component were byte-identical, all three ELFs contained zero relocations, and Ghidra decompiled every recovered function (kernel 43/43, installer 19/19, collector 12/12).

The deployment design failed its single hardware attempt. The minimal installer tried to replace the kernel payload after ordinary HEN was already active; the display disappeared and the console powered off before a result notification. The collector did not run. Stock HEN's installer deliberately skips this active-HEN case, so bypassing that guard is rejected. The installer source is compile-time blocked, both staged files were removed, and this route must not be repeated. Exact evidence is recorded in [`payloads/hen-loader-return-trace/AUDIT.md`](../payloads/hen-loader-return-trace/AUDIT.md).
