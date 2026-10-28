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

1. process title ID and matched PRX-path class, without personal or device-unique data;
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
