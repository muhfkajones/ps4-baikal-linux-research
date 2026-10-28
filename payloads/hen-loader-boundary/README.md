# HEN loader-boundary diagnostic (EXP-013)

Revision 6 is a read-only user-mode inventory payload for the owned 13.50 reference console. It follows the negative EXP-012 plugin result without repeating that closed launch.

Revision 7 is the reviewed capture-route fallback for the same inventory. Because the installed HEN plugin-server klog service was not listening on TCP 3232, revision 7 sends the same bounded observations directly to a host listener on TCP 9023. The private host address is supplied only at local build time and is not committed or indexed. Revision 7 still emits each line to syscall 601 as a secondary diagnostic channel.

The payload reports through the already-established syscall-601 debug channel. It records the process UID and sandbox state, enumerates the modules visible to the Payload Guest process with `getLoadedModules`, and emits each available module ID and printable module name from `getModuleInfo`.

Revision 6 does **not**:

- read or write kernel memory;
- call the jailbreak helper;
- open or write files;
- load, resolve, call, or unload a custom PRX;
- access flash or send a secure-module request;
- create a completion marker.

Revision 7 adds only network initialization, one outbound TCP connection, bounded complete-line sends, and socket close. It retains all revision-6 exclusions, including no kernel-memory access, filesystem I/O, custom PRX load, flash access, hook installation, or secure-module request.

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

The pinned HEN plugin-server source exposes `/dev/klog` read-only over TCP port `3232`. Before an authorized launch, start the host capture first:

```powershell
.\scripts\Capture-Exp013Klog.ps1 `
  -Address <PS4-LAN-address> `
  -OutputPath C:\private\exp013-v6-klog.txt
```

If the connection cannot be established, do not launch the payload. The capture stops only after the EXP-013 completion or explicit stop marker and preserves the raw local evidence for the parser.

PS4-Xplorer's FTP server may return only a short prefix from an ordinary retrieval while still supporting `REST`. Use `scripts/Get-Ps4XplorerFile.ps1` with the directory-listed expected length to reconstruct a bounded file read-only; the script refuses to overwrite a local output and fails unless the exact expected byte count is recovered.

For revision 7, start `scripts/Listen-Exp013Network.ps1` before an authorized launch, preserve its raw local capture, and validate it with `scripts/Parse-HenLoaderBoundaryNetworkLog.ps1`. Before execution, upload and retrieve the 7,044-byte flat payload and require `scripts/Verify-HenLoaderBoundaryNetworkTransfer.ps1` to confirm SHA-256 `8270D9C6470E27A51AF2FC37C5B84F7775C14D5D3988A4051BB9AB64B01CCA70`. A listener or transfer failure means do not launch.

Revision 7 completed once on 2026-10-27. The strict parser accepted all 21 observed modules with zero module-info failures and a final completion marker. The current module list did not contain the missing EXP-012 custom plugin. Do not repeat the same inventory without new loader evidence; see `manifests/hen-loader-boundary-network-1350-result.json` for the publication-safe result.
