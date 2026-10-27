# HEN loader-boundary diagnostic (EXP-013)

Revision 6 is a read-only user-mode inventory payload for the owned 13.50 reference console. It follows the negative EXP-012 plugin result without repeating that closed launch.

The payload reports through the already-established syscall-601 debug channel. It records the process UID and sandbox state, enumerates the modules visible to the Payload Guest process with `getLoadedModules`, and emits each available module ID and printable module name from `getModuleInfo`.

- read or write kernel memory;
- call the jailbreak helper;
- open or write files;
- load, resolve, call, or unload a custom PRX;
- access flash or send a secure-module request;
- create a completion marker.

The result can establish which modules are visible in the current process. Absence from that list cannot by itself prove that a loader hook never ran or that a module was never transiently present.

The earlier revision-5 source remains in the local ignored backup set for evidence preservation. It is not the current build input and must not be substituted without a fresh review.
