# HEN loader-boundary diagnostic (EXP-013)

Revision 6 is a read-only user-mode inventory payload for the owned 13.50 reference console. It follows the negative EXP-012 plugin result without repeating that closed launch.

The payload reports through the already-established syscall-601 debug channel. It records the process UID and sandbox state, enumerates the modules visible to the Payload Guest process with `getLoadedModules`, and emits each available module ID and printable module name from `getModuleInfo`.

Revision 6 does **not**:

- read or write kernel memory;
- call the jailbreak helper;
- open or write files;
- load, resolve, call, or unload a custom PRX;
- access flash or send a secure-module request;
- create a completion marker.

The result can establish which modules are visible in the current process. Absence from that list cannot by itself prove that a loader hook never ran or that a module was never transiently present.

The earlier revision-5 source remains in the local ignored backup set for evidence preservation. It is not the current build input and must not be substituted without a fresh review.

Before a user-authorized run, compare the local build with the retrieved console-side round-trip copy:

```powershell
.\scripts\Verify-HenLoaderBoundaryTransfer.ps1 `
  -Local .\build\HenLoaderBoundary\hen-loader-boundary-1350.bin `
  -Retrieved C:\path\to\retrieved\hen-loader-boundary-1350.bin
```

The verifier requires both files to be exactly 5,760 bytes with SHA-256 `ADA2FB9F75DAD721BDD4979D9F30BBCD234B4F752A65FD71D4D33F044BEDB2E8`.

After an authorized run, save the captured debug stream locally and parse it without publishing the raw log first:

```powershell
.\scripts\Parse-HenLoaderBoundaryLog.ps1 `
  -LogPath C:\path\to\captured-kernel-log.txt `
  -OutputJson C:\private\exp013-v6-result.json
```

A complete result requires one copy of each numbered observation, a successful bounded enumeration, exactly one record per declared module or module-info failure, no unknown EXP-013 records, and the final `08 complete` marker. Module absence remains observational rather than proof about earlier transient loader activity.
