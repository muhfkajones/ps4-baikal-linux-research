# Post-link audit record

## Audited artifact

- File: `sflash-provider-inventory-readonly.bin`
- Length: `10716` bytes
- SHA-256: `187B76989D7E0ED474DA3E02EEFB625A31F43EF923A6387ED702A19AD62A3F7A`
- Build host: Windows 11
- Compiler: Zig `0.17.0`
- SDK base: `Scene-Collective/ps4-payload-sdk` commit `b7326416c23ce14639e9180a24093bdc5eedb579`, with the compatibility patch documented in `third_party/ps4-payload-sdk-zig-compat.patch`
- Linked `libPS4-zig.a` SHA-256: `5A083E5934220827C95E308EDEA7205AEFE9E3544464633A83E4B9BF6406A104`
- Auditor: Ghidra `12.1.4 PUBLIC`

The binary is intentionally excluded from Git. Rebuild it from the source revision containing this record and verify the hash before use.

## Reproducibility result

Two consecutive invocations of `scripts/Build-SflashInventory.ps1` produced the same length and SHA-256 above.

## Ghidra result

- Executable format: x86-64 ELF
- Recognized functions: `23`
- Successfully decompiled functions: `23`
- Failed decompilations: `0`

Post-link call-site review found:

- each SFLASH provider path is opened with flags `0` (`O_RDONLY`) and mode `0`;
- the only payload-owned path opened with write flags is `/data/payloads/sflash-provider-inventory-readonly.log`;
- the log is opened either as `O_WRONLY | O_CREAT | O_TRUNC` (`0x601`) or `O_WRONLY | O_CREAT | O_APPEND` (`0x209`), mode `0644`;
- linked SDK code also opens its firmware-detection library paths read-only; and
- no payload call site writes to, unlinks, renames, mounts, or changes permissions on an SFLASH provider.

## Scope and decision

This audit establishes that the artifact performs a bounded read-only inventory of the listed providers and writes only its diagnostic log. It does not prove that every provider is safe on every firmware. Runtime execution remains restricted to the owned firmware `13.50` reference console, and the payload itself stops when `get_firmware()` does not return `1350`.

**Review decision:** approved for the documented read-only inventory experiment on the owned 13.50 reference console after transfer-hash verification.
