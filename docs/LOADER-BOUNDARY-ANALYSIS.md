# Payload Guest and HEN loader boundary

## Verified runtime result

EXP-013 revision 7 enumerated 21 modules in the running Payload Guest 0.98 process on firmware 13.50. The list contained `guest.elf`, `libkernel_sys.sprx`, and ordinary application/runtime modules. It did not contain HEN's `plugin_bootloader.prx`, `plugin_loader.prx`, or the missing EXP-012 custom plugin. Enumeration completed with zero module-info failures.

This proves only current module visibility. It does not prove that a module was never transiently loaded, that every loader module is visible through this API, or that the kernel hook never ran.

## Public-source path

The following static path is verified against public source, not yet against the exact installed PRX bytes:

1. Payload Guest revision `f73b7fc701ff1b91e40369486325b440b5816c9e` scans `/data/payloads` and `/mnt/usb*/payloads` for `.bin` and `.elf` files.
2. When the operator presses Cross, Payload Guest first tries local socket loaders and otherwise reads the selected file into a one-megabyte executable mapping and starts it on a new pthread.
3. HEN revision `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e` hooks `dynlib_load_prx`. When a process loads `/app0/sce_module/libc.prx`, the hook loads `/data/hen/plugin_bootloader.prx`, resolves the application's `_init_env`, and patches it to jump to the bootloader's `plugin_load`.
4. The public bootloader loads `/data/hen/plugin_loader.prx` and invokes its `plugin_load` entry.
5. The public loader reads `/data/hen/plugins.ini`, selects `[all]` or the current title ID, and loads each enabled configured module with `sceKernelLoadStartModule`.

Payload Guest includes `sce_module/libc.prx`, so the public-source trigger condition appears relevant. Yet EXP-012 observed no custom-plugin entry log and EXP-013 later observed none of the HEN loader modules in the live process.

## Current hypotheses

- **H1 — hook not reached or not installed:** the installed HEN build may not patch this Payload Guest launch path on firmware 13.50.
- **H2 — injection attempted but failed:** the hook may run but fail to load the bootloader or resolve/patch `_init_env`.
- **H3 — loader modules are transient or omitted:** the bootloader/loader may run and disappear, or may not be reported by `getLoadedModules` at the later payload-thread observation point.
- **H4 — installed bytes differ from reviewed public source:** the console's installed bootloader/loader may not match the public revisions used for static analysis.

The current evidence does not select among these hypotheses.

## Next safe digital and acquisition steps

1. Acquire only lengths and SHA-256 hashes for the installed `/data/hen/plugin_bootloader.prx` and `/data/hen/plugin_loader.prx`, preserving the binaries privately and outside Git/LLM Wiki.
2. Compare those hashes with locally reproducible builds or exact public release artifacts before applying source conclusions to the installed components.
3. Inspect the exact installed or hash-matched bootloader/loader in Ghidra to confirm the trigger, `_init_env` patch target, module lifetime, and failure logging.
4. Design a successor diagnostic only after that comparison. Prefer a read-only observation of loader return codes or module lifecycle; do not repeat current-process enumeration or the closed stock plugin launch.

No new hardware payload is proposed by this document.
