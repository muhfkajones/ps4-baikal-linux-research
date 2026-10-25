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

## Offline binary audit result

GitHub Actions run `40244433237` built the plugin twice from commit `9d17a176aa017eb6f971459b0e07c3b2d91432b5`. Both ELF files and both PRX files were byte-identical.

- ELF: 68,928 bytes; SHA-256 `64059F65F0D183CE6CF83A7A1511309E547D01A1648DA43664FCF7725EEAE4A8`
- OELF: 71,104 bytes; SHA-256 `8BBA364B03676D104E42942331A308C5CE6C5864C90BC908E550CCD832D3B56C`
- PRX: 53,408 bytes; SHA-256 `82BC5D8039E854377DACE81C74BCEA3231C11D5F6D00E3112CED49F9405D57CE`
- Workflow artifact ZIP: SHA-256 `0508DB11533B4043EF3619EF693E5488906FCA6F66E214004A8C032E6B9EEA63`, matching GitHub's artifact digest
- Expected dynamic relocations: four `R_X86_64_RELATIVE` metadata pointers and seven `R_X86_64_JUMP_SLOT` imports for `memset`, `sceKernelGetSystemSwVersion`, `open`, `close`, `unlink`, `write`, and `mkdir`
- Kernel-callback disassembly: checks length `0x1380`; reads MSR `0xC0000082`; subtracts `0x1C0`; computes `copyout` at `+0x2BD600`; computes the sole data source at `+0x2680800`; performs one 4,992-byte copyout plus one 8-byte copyout of the kernel-base value
- Compiled paths: only the three declared `/mnt/usb0/ps4-re-output` paths; no `/dev/` path

The pre-deployment FTP check found `/data/hen/plugins.ini` absent and `/data/hen/plugins/` empty. Therefore rollback for this console is deletion of the newly created config and PRX, not restoration of a prior config file.

The source and binary are approved for reversible staging only. Payload Guest must not be launched until the console-retrieved PRX and `plugins.ini` hashes match the audited local files.

## Provenance

- HEN plugin loading model and title-specific configuration: `Scene-Collective/ps4-hen-plugins` revision `49534177d69d17609bcc09cd185c88df42fed8b5` (MIT).
- Fixed-arity syscall assembly adapted from that repository's `common/syscall.c`, which credits `john-tornblom/tiny-ps4-shell` revision `5ca90b7d2825e3e2c7f9fb1e81cf8949b37af563`.
- Firmware 13.50 kernel-base and `copyout` offsets cross-checked against `Scene-Collective/ps4-payload-sdk` revision `b7326416c23ce14639e9180a24093bdc5eedb579`.
- PRX build environment: OpenOrbis PS4 Toolchain release `v0.5.3` (GPL-3.0).
