# Payload Guest and HEN loader boundary

## Verified runtime result

EXP-013 revision 7 enumerated 21 modules in the running Payload Guest 0.98 process on firmware 13.50. The list contained `guest.elf`, `libkernel_sys.sprx`, and ordinary application/runtime modules. It did not contain HEN's `plugin_bootloader.prx`, `plugin_loader.prx`, or the missing EXP-012 custom plugin. Enumeration completed with zero module-info failures.

This proves only current module visibility. It does not prove that a module was never transiently loaded, that every loader module is visible through this API, or that the kernel hook never ran.

## Verified loader path

The following static path is verified against the exact source revision embedded in the installed, hash-matched PRXs:

1. Payload Guest revision `f73b7fc701ff1b91e40369486325b440b5816c9e` scans `/data/payloads` and `/mnt/usb*/payloads` for `.bin` and `.elf` files.
2. When the operator presses Cross, Payload Guest first tries local socket loaders and otherwise reads the selected file into a one-megabyte executable mapping and starts it on a new pthread.
3. HEN revision `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e` hooks `dynlib_load_prx`. When a process loads `/app0/sce_module/libc.prx`, the hook loads `/data/hen/plugin_bootloader.prx`, resolves the application's `_init_env`, and patches it to jump to the bootloader's `plugin_load`.
4. The public bootloader loads `/data/hen/plugin_loader.prx` and invokes its `plugin_load` entry.
5. The public loader reads `/data/hen/plugins.ini`, selects `[all]` or the current title ID, and loads each enabled configured module with `sceKernelLoadStartModule`.

Payload Guest includes `sce_module/libc.prx`, so the public-source trigger condition appears relevant. Yet EXP-012 observed no custom-plugin entry log and EXP-013 later observed none of the HEN loader modules in the live process.

## Current hypotheses

- **H1 — hook not reached or not installed:** the installed HEN build may not patch this Payload Guest launch path on firmware 13.50.
- **H2 — injection attempted but failed:** the hook may run but fail to load the bootloader or resolve/patch `_init_env`.
- **H3 — loader modules are omitted by the API:** the bootloader/loader may not be reported by `getLoadedModules` at the later payload-thread observation point. Transient unload is now unlikely: the exact embedded source keeps both modules loaded on its normal success path and unloads only when a nested `plugin_load` reports a nonzero result.
- **H4 — installed bytes differ from reviewed public source:** ruled out for the bootloader and loader. Read-only private retrieval showed that both installed PRXs are byte-identical to the official `build_86` release, and both embed source commit `a717ffd0b4699d72d4fd33dab0ca422270fcfd25`.

The current evidence does not select among H1–H3, but exact-source module-lifetime behavior weakens the transient-unload form of H3.

## Installed-component verification

Read-only FTP retrieval and private comparison established:

- `/data/hen/plugin_bootloader.prx`: 54,496 bytes; SHA-256 `34A38C8ECEC62904DD206F8BEC8F29962E04FF3D934C8C479C3C33C6C10A47D7`
- `/data/hen/plugin_loader.prx`: 55,296 bytes; SHA-256 `EBE69D421642C95E1FC94D0AB647A68A49D2D593E797FE76831CC2A18700B77C`
- official `build_86` `plugins.zip`: SHA-256 `196E3F8D854CCBC9654C9836F9E73784C39C0E4B88AF64DEE8BC85087F08E7BC`
- both installed files exactly match their official-release counterparts and embed source commit `a717ffd0b4699d72d4fd33dab0ca422270fcfd25`

The relevant bootloader/loader sources do not differ between that embedded commit and the later inspected revision `49534177d69d17609bcc09cd185c88df42fed8b5`.

Direct Ghidra import of a naively sliced embedded ELF is not accepted as evidence: the fSELF container retains file offsets relative to the full container, so the sliced image produces truncated sections and invalid load segments. Until a format-correct reconstruction is available, the hash-matched release and exact embedded source are the authoritative static evidence.

## Next safe digital and acquisition steps

1. Inspect the exact hash-matched source and release containers to confirm the trigger, `_init_env` patch target, module lifetime, and failure logging.
2. Determine whether existing HEN diagnostics can expose the hook/load return codes without installing another title-specific plugin.
3. Design a successor diagnostic only after that comparison. Prefer a read-only observation of loader return codes or module lifecycle; do not repeat current-process enumeration or the closed stock plugin launch.

No new hardware payload is proposed by this document.
