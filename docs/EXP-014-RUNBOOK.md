# EXP-014 one-run operator handoff

> **REJECTED:** The reviewed minimal installer powered off the reference console during its single run while ordinary HEN was active. Do not follow this runbook. It is retained only as the exact historical handoff for the failed attempt.

## Authorization boundary

This runbook no longer authorizes any action. Do not rebuild, transfer, or execute either candidate.

## Audited candidates

- Minimal volatile installer: 48,052 bytes; SHA-256 `3C7341D407B192FB01E7168F77974899619EFDC055885258694FD929C7571A45`
- Private-endpoint collector: 6,852 bytes; SHA-256 `B7AA8E305FB05E0EA03DAAEE3E358DB25F80BE198F6180DBF73D8F930C188B8C`

The private workstation address is compiled only into the ignored local collector build. Do not commit or index it.

## Digital preflight

The assistant performs these steps after approval:

1. Confirm the local candidate sizes and hashes.
2. Start `payloads/hen-loader-return-trace/host/capture_exp014.py` on TCP 9024 with a private output path.
3. Upload both flat binaries to uniquely named files under `/data/payloads` through the already established PS4-Xplorer FTP service.
4. Retrieve both files read-only and verify their exact sizes and hashes before execution.
5. Stop immediately if either round-trip hash differs or the listener is not ready.

## Physical operator steps

Only after the assistant confirms the listener and both round-trip hashes:

1. In Payload Guest, select and run the file identified by the assistant as the **EXP-014 minimal installer** exactly once. The expected visible result is a notification ending in install result `0x00000000`.
2. Return to the PS4 home screen and close Payload Guest so the current process is gone.
3. Reopen Payload Guest once. This fresh launch is what allows the firmware/title-locked libc hook to record the loader results.
4. In Payload Guest, select and run the file identified by the assistant as the **EXP-014 collector** exactly once.
5. Stop. Do not rerun either file unless a new review explicitly authorizes it.

The assistant validates the capture. A complete record has exactly 15 numbered fields and the final `PASS bounded trace complete` line. The parser rejects missing, reordered, malformed, oversized, or incomplete captures.

## Rollback

Restart the PS4. The restart removes the volatile replacement kernel component. Restore ordinary operation by loading the pinned normal HEN build through the established workflow. After the capture is retrieved and verified, the assistant may remove only the two uniquely named EXP-014 staging files through FTP; no HEN configuration or plugin file is changed by this experiment.

If the installer reports a nonzero result, Payload Guest errors before the collector runs, the listener does not receive a complete record, or any unexpected behavior occurs, do not retry. Restart the PS4 and report the exact visible result.
