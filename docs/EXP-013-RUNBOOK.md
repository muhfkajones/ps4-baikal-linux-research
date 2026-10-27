# EXP-013 revision-6 controlled runbook

## Current boundary

EXP-013 revision 6 has completed source, reproducible-build, and Ghidra review. Its flat payload is 5,760 bytes with SHA-256 `ADA2FB9F75DAD721BDD4979D9F30BBCD234B4F752A65FD71D4D33F044BEDB2E8`.

No payload transfer or hardware execution is authorized by this document. The operator and assistant proceed one gate at a time. The assistant performs network transfer, hash verification, capture, parsing, documentation, and GitHub work; the operator performs only the explicitly requested console action.

## Gate 1 — expose the established read-only inspection route

Operator action: on the PS4, leave Payload Guest and open **PS4-Xplorer 2.08**.

Expected visible result: PS4-Xplorer reaches its file-browser screen and displays or enables its FTP service. Do not launch any payload.

Assistant work after Gate 1:

1. Confirm the previously established FTP endpoint without publishing the console's LAN address.
2. Inspect only the relevant HEN/plugin configuration and existing log-service files.
3. Determine whether the pinned plugin-server klog service can be enabled through an already-installed component or whether a separately reviewed deployment would be required.
4. Do not upload EXP-013 until its destination, rollback, capture route, and transfer verification are all established.

### Gate-1 result — 2026-10-27

- PS4-Xplorer FTP was reachable on TCP port `2121`.
- The FTP implementation returned only eight bytes per ordinary retrieval but supported `REST`; `scripts/Get-Ps4XplorerFile.ps1` reconstructed bounded files read-only and verified their final lengths and hashes.
- Installed HEN version: `2.2.0 BETA`; `enable_plugins = 1`.
- `plugin_server.prx` exists, but its expected klog service on TCP port `3232` was not listening.
- `/data/hen/plugins.ini` matches the prior EXP-012 config hash, but the referenced custom PRX is absent and `/data/hen/plugins/` is empty.
- No console file was uploaded, edited, renamed, or deleted.

Gate 1 therefore remains blocked on a reliable capture route. Do not proceed to Gate 2 by merely uploading the payload.

## Gate 2 — stage only after separate authorization

If Gate 1 proves a safe capture route, the assistant will request authorization for the exact upload paths. After transfer, `scripts/Verify-HenLoaderBoundaryTransfer.ps1` must validate the local and retrieved copies against the audited size and hash.

The operator will then receive one exact action to reopen Payload Guest, with the expected screen. No run occurs at this gate.

## Gate 3 — single execution only after separate authorization

The assistant starts `scripts/Capture-Exp013Klog.ps1` before execution and confirms that the capture socket is connected. Only then may one Payload Guest execution be authorized.

The captured stream is preserved privately and parsed with `scripts/Parse-HenLoaderBoundaryLog.ps1`. Publication is limited to reviewed, non-unique findings and hashes.

## Stop conditions

- FTP or the intended capture route is unavailable.
- Any transferred file fails exact size or SHA-256 verification.
- The console firmware or target application differs from the recorded reference.
- The capture process is not connected before execution.
- Output lacks the EXP-013 completion or explicit stop marker.
