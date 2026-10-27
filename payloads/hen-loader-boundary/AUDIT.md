# Pre-execution audit

## Scope

EXP-013 revision 6 is restricted to the owned PS4 Pro CUH-7215B on firmware 13.50. It inventories the user-mode modules visible to Payload Guest after EXP-012 produced no plugin entry log during a verified fresh launch.

## Source-level properties

1. Output uses only the previously established syscall-601 debug channel.
2. The only observations are `getuid`, `is_in_sandbox`, `getLoadedModules`, and `getModuleInfo` results.
3. Module enumeration is bounded to 256 handles. Execution stops if the result fails, the count is negative, or the count exceeds that bound.
4. Module names are bounded to the 32-byte SDK field and non-printable bytes are replaced before logging.
5. The payload performs no kernel-memory read or write and does not call the jailbreak helper.
6. The payload performs no filesystem I/O, custom PRX load, entry-point call, flash access, hook installation, secure-module spawn, or service-mailbox request.
7. A missing module name is only an observation about the current process list; it is not proof that a hook never ran or a module was never transiently loaded.

## Reproducible build review

Two consecutive local builds from the current revision-6 source produced identical outputs:

- ELF: 26,376 bytes; SHA-256 `189F84346FDC410FDFA28B4A7461DB84633912BED402709494379CC970EBF28C`
- Flat payload: 5,760 bytes; SHA-256 `ADA2FB9F75DAD721BDD4979D9F30BBCD234B4F752A65FD71D4D33F044BEDB2E8`

The source and build records contain no `/dev/`, USB-output, plugin-configuration, or custom-PRX path. Generated binaries remain ignored and outside Git.

## Post-link Ghidra review

Ghidra 12.1.4 PUBLIC imported the linked ELF as `x86:LE:64:default` and identified 11 functions. All 11 decompiled successfully. The reachable `_main` path contains initialization, `getuid`, `is_in_sandbox`, bounded `getLoadedModules`/`getModuleInfo` calls, and syscall-601 debug output. It contains no kernel-memory read/write helper, filesystem operation, custom PRX load, flash access, hook installation, or secure-module/service-mailbox call.

The linked SDK contributes unused resolver names and function-pointer slots for broader SDK APIs. Their string-table presence is not execution evidence; the decompiled call graph was used to verify the actual revision-6 path.

- Ghidra analysis report SHA-256: `C1DDEEA1D9AA85430F6A73893B7F1ECCB7FCBF629098EEAB451DA8BB2B032BE5`
- Ghidra decompilation report SHA-256: `2DB6D6D7401C65959CD924C796719203F062457C85CE935E59306078E21D03FA`

## Hardware gate

This offline review does not authorize deployment. Before any hardware execution, verify the transferred flat-payload hash. Payload Guest is currently open, but revision 6 must not be sent or launched without the user's explicit approval after reviewing this record.

## Provenance

- Payload SDK: `Scene-Collective/ps4-payload-sdk` revision `b7326416c23ce14639e9180a24093bdc5eedb579`
- Toolchain: Zig 0.17.0
- Review ZIP SHA-256: `32C902C2E418A9D4C6889FC0AC4167D8F2AB2FBB308E6F0293310CD30F7B6FC1`

## Revision 7 direct-capture fallback

Revision 7 preserves the revision-6 observation set and safety exclusions. Its only added runtime behavior is network initialization, one outbound TCP connection to a privately supplied build-time host address on TCP 9023, complete-line sends, and socket close. It performs no network listen, inbound command handling, filesystem I/O, kernel-memory access, custom PRX load, flash access, hook installation, or secure-module request.

Two consecutive builds using the verified local workstation address were byte-identical:

- ELF: 31,144 bytes; SHA-256 `703E98379FD2148BAA834049A42CD16779D941464C39545DA558016827B62A28`
- Flat payload: 7,044 bytes; SHA-256 `8270D9C6470E27A51AF2FC37C5B84F7775C14D5D3988A4051BB9AB64B01CCA70`

Ghidra 12.1.4 PUBLIC identified 15 functions and decompiled all 15. The reachable path contains initialization, the outbound connection, UID/sandbox observations, bounded module enumeration, complete-line sends through the resolved `sceNetSend`, socket close, and syscall-601 mirroring. SDK resolver strings for unused APIs are not reachable-action evidence.

- Ghidra analysis report SHA-256: `226921189EC5A19F1BCBBB78BA736A4152749E4C3235A2916B0DF63BBF23C79F`
- Ghidra decompilation report SHA-256: `B1D1E2B30BB3E28A8345AEDA1F1E07DD825EDEA4EDF9AE0493D73FEF743FF541`
- Listener/parser integration: localhost capture reached the terminal marker and the strict parser accepted the complete fixture; a truncated fixture was rejected.

This review does not authorize hardware execution. The console-side round-trip copy must match the recorded flat-payload size and hash, the host listener must already be active, and the user must explicitly approve the exact run.
