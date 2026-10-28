# EXP-015 gated runbook — initial-load HEN trace

## Status

Hardware execution is not authorized. This runbook records the reviewed order and the remaining gates; it is not an instruction to deploy.

## Host selection and rollback

The exploit page accepts a validated bare `payloadfile` query value. The reviewed host correction makes the selected file `PAYLOAD_OVERRIDE || "hen.bin"`; it does not replace or rename `hen.bin`.

- Normal pinned HEN remains `hen.bin`: 500,448 bytes; SHA-256 `C05F6097DBC0707E8EC2FB5443EE507DA6AC6E79C6FA8E9F78544658710EFEFF`.
- EXP-015 candidate uses the unique name `exp015-initial-load-1350.bin`: 55,044 bytes; SHA-256 `FA3ED59E61653613E415022D8DDBC5DF1DD5901761466FA30C4EE9D2492301C6`.
- Normal load URL omits `payloadfile`; the candidate URL names the unique candidate explicitly.
- Rollback is selecting the normal URL on the next cold start. No file swap is required.

`scripts/Test-Exp015HostPreflight.ps1` fails closed unless the local normal HEN, local candidate, host override line, and—when requested—both HTTP-served payloads match their reviewed lengths and hashes.

An isolated loopback audit served both payloads from a copied host tree. Both HTTP responses exactly matched the reviewed hashes. The live host's `hen.bin` remained unchanged. No console transfer or execution occurred.

## Initial-load capture order

For a future separately authorized run, the assistant must complete these prerequisites before handing the console to the operator:

1. Round-trip verify the uniquely named EXP-015 collector through console FTP.
2. Place the uniquely named initial-load candidate only in the host directory and verify both candidate and normal HEN over the actual LAN HTTP service.
3. Start the one-shot bounded listener on TCP 9024 and confirm it is listening.
4. Confirm the normal URL still resolves to the pinned HEN and record the exact candidate URL.

Only after those gates pass and the user explicitly authorizes the exact run may the physical sequence begin: cold start, open the exact candidate URL once, wait for the shell restart, open Payload Guest once to trigger the title-locked hook, then run the uniquely named collector once. Any unexpected result stops the experiment; do not retry.

## Remaining gate

The uniquely named collector was rebuilt twice from source with byte-identical outputs. Its 30,664-byte ELF has SHA-256 `93B0F550B8A06563A87939698981A4141491349FB573378F05448D70B305D518`; its 6,852-byte flat payload has SHA-256 `B7AA8E305FB05E0EA03DAAEE3E358DB25F80BE198F6180DBF73D8F930C188B8C`. The executed flat bytes are identical to the prior private collector that completed zero-relocation and Ghidra 12/12 review; the private build-time address remains excluded from Git and the Wiki.

The host substitution, rollback design, collector rebuild, and collector ordering are reviewed. Hardware remains blocked on console-side collector round-trip verification, live-LAN served-hash verification, listener-ready confirmation, and explicit authorization.
