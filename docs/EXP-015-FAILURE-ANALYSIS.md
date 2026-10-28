# EXP-015 failure analysis

## Verified boundary

EXP-014 and EXP-015 used the same instrumented HEN kernel component. The component's flat binary was 35,184 bytes with SHA-256 `AD5CDD21F5726AF55D9E0C6B3A79283EFFF16E2ECA7B0A0480FE0584D5E61066`.

- EXP-014 attempted to install it while normal HEN was active and the console shut down before the installer returned.
- EXP-015 installed it during the initial HEN load after a full shutdown and the console again shut down before the installer returned.
- The EXP-015 host completed 54/54 exploit checks, fetched the exact reviewed 55,044-byte installer, and recorded `PAYLOAD-RUNNING`.
- Neither attempt reached the title-specific hook, collector, or capture stage.

The initial-load failure disproves the earlier explanation that active-HEN replacement alone caused EXP-014. It does not distinguish an installer fault, component entry fault, hook-install fault, compiler/linker incompatibility, or another kernel panic. No panic trace exists.

## Build-provenance correction

The pinned upstream HEN kernel-component Makefile declares `gcc` and ends its linker script with `/DISCARD/ : { *(*) }`. The reviewed component was instead built with Zig 0.17.0. Preserved build logs contain one unused-argument warning per source file and identify the Zig-driven build, but the repository had no committed script for that component.

The preserved build tree also contains a linker-script change from the upstream catch-all discard to a narrow discard of comments, notes, unwind data, and relocations. That exact change is now preserved as `third_party/hen-exp014-observed-linker-delta.patch`, SHA-256 `5F0D72F3D5FF126A22E65E2F2B5CBF17EAB7372E48759F7B02FD90F9F0173955`; it is not part of `payloads/hen-loader-return-trace/hen-exp014.patch`.

The reviewed ELF confirms the consequence of that delta:

- an orphan executable `.text` section at virtual address `0x3670`, size `0x108`;
- `.payload_rdata` beginning at `0x3780`;
- `.payload_bss` beginning at `0x8970`, size `0x200`;
- two loadable segments and no relocation section in the final ELF; and
- flat extraction ending at `0x8970` after removing `.payload_bss`.

The orphan `.text` contains `sys_proc_info_handle`, `sys_proc_thrinfo_handle`, and `_start`, so simply reverting the linker delta under the Zig build is not a valid correction. The upstream GCC build may inline or place those functions differently. Compiler/linker parity must be established rather than guessed.

## Leading hypotheses

1. **Build parity gap:** the Zig-built component plus the observed linker delta has never been shown equivalent to an upstream GCC-built stock HEN component on hardware. This is the strongest newly identified provenance gap.
2. **Shared component entry/install path:** both failures occur before the installer returns and before the instrumented hook can collect evidence.
3. **Instrumentation semantics:** the added trace state and hook code could still be faulty, but the current evidence does not show that code executing before shutdown.

These are hypotheses, not a panic diagnosis.

## Closed and next-safe work

- Do not rebuild, transfer, or execute EXP-014 or EXP-015.
- Do not test a stock component built with the same custom Zig pipeline on hardware merely to isolate the compiler; that would be a new kernel-payload experiment requiring a new design and review.
- Reconstruct a complete, scripted stock-versus-instrumented build comparison using the upstream-declared compiler/linker path.
- Require section, segment, symbol, relocation, flat-byte, and entrypoint comparisons before proposing any successor.
- Prefer a non-executing observation method or an emulator/unit boundary for trace logic.
