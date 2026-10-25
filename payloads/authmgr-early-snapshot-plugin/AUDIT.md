# Pre-execution audit

## Scope

This plugin is restricted to the owned PS4 Pro CUH-7215B on firmware 13.50 and to Payload Guest title ID `AZIF00003`. It makes one early passive snapshot of the bounded `sm_service` control-plus-staging region and writes the result to external USB.

## Source-level properties

1. `sceKernelGetSystemSwVersion` must report firmware word `0x1350` before syscall 11 is invoked.
2. The only kernel read is `kernel_base + 0x02680800`, length `0x1380`.
3. The kernel callback only calls the 13.50 `copyout` function at `kernel_base + 0x002BD600`.
4. The plugin does not write kernel memory, install a hook, spawn or restart a secure module, call a service mailbox, or access flash.
5. Persistent writes are limited to the three declared paths below `/mnt/usb0/ps4-re-output`.
6. Returning `1` from `plugin_load` asks the existing HEN plugin loader to call `plugin_unload` and unload the PRX after the snapshot attempt.
7. Deployment must use only the `[AZIF00003]` section of `/data/hen/plugins.ini`; global enablement is prohibited.

## Required binary checks

The plugin is **not approved for hardware yet**. Before deployment, record:

- two-build reproducibility and exact SHA-256 hashes;
- ELF/PRX header, section, symbol, and relocation reports;
- disassembly proving the kernel callback has no external calls except the computed `copyout` target;
- compiled path inventory proving there is no `/dev/` path;
- retrieved-console SHA-256 matching the audited PRX;
- exact backup hash for the original `/data/hen/plugins.ini`.

## Provenance

- HEN plugin loading model and title-specific configuration: `Scene-Collective/ps4-hen-plugins` revision `49534177d69d17609bcc09cd185c88df42fed8b5` (MIT).
- Fixed-arity syscall assembly adapted from that repository's `common/syscall.c`, which credits `john-tornblom/tiny-ps4-shell` revision `5ca90b7d2825e3e2c7f9fb1e81cf8949b37af563`.
- Firmware 13.50 kernel-base and `copyout` offsets cross-checked against `Scene-Collective/ps4-payload-sdk` revision `b7326416c23ce14639e9180a24093bdc5eedb579`.
- PRX build environment: OpenOrbis PS4 Toolchain release `v0.5.3` (GPL-3.0).
