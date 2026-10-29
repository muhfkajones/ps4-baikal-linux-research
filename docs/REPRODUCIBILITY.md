# Reproducibility

## Build environment

The current payload build has been exercised with:

- Windows 11 host
- Zig 0.17.0
- Scene-Collective PS4 Payload SDK
- Ghidra 12.1.4 PUBLIC for post-link review

The rejected EXP-014/EXP-015 HEN kernel component used a separate custom Zig-driven build of an upstream tree whose Makefile declares GCC. Its observed linker delta and previously implicit build inputs are now recorded. `scripts/Build-HenKernelComponentAudit.ps1` reproduces the rejected outputs exactly, but byte identity within that custom pipeline does not establish upstream-toolchain equivalence. Do not use that component or infer that zero relocations plus complete decompilation proves runtime compatibility.

The PS4 Payload SDK is pinned to commit `b7326416c23ce14639e9180a24093bdc5eedb579`. Apply `third_party/ps4-payload-sdk-zig-compat.patch` before building its `libPS4-zig.a` archive.

## Reconstruct the rejected HEN kernel component offline

Start from HEN revision `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e`, apply `payloads/hen-loader-return-trace/hen-exp014.patch`, then apply `third_party/hen-exp014-observed-linker-delta.patch`. Use Zig 0.17.0 and GNU `objcopy`; Zig 0.17.0's `objcopy` cannot remove `.payload_bss` and is not equivalent for this extraction.

```powershell
.\scripts\Build-HenKernelComponentAudit.ps1 `
  -Zig C:\path\to\zig.exe `
  -Objcopy C:\path\to\gnu-objcopy.exe `
  -HenSourceRoot C:\path\to\patched-hen `
  -OutputDirectory .\build\hen-kernel-component-audit `
  -ExpectedELFSHA256 1B9E048A7C8012CCB899EED949FA5AED9472CD9A50BB3E0CCCB640088C11207E `
  -ExpectedBinarySHA256 AD5CDD21F5726AF55D9E0C6B3A79283EFFF16E2ECA7B0A0480FE0584D5E61066
```

The script fails on a hash mismatch. Its normalized ordinal source order and omission of upstream `-masm=intel` are required to reconstruct the rejected Zig build. The result is an offline comparison baseline only; it is compile-time blocked from deployment through the retained installer sources.

## Build

From PowerShell:

```powershell
.\scripts\Build-SflashPayload.ps1 `
  -Variant S1Crypt `
  -Zig C:\path\to\zig.exe `
  -SdkRoot C:\path\to\ps4-payload-sdk
```

The script returns the output path, byte length, and SHA-256 hash. Build products remain ignored by Git.

Build the provider-inventory diagnostic with:

```powershell
.\scripts\Build-SflashInventory.ps1 `
  -Zig C:\path\to\zig.exe `
  -SdkRoot C:\path\to\ps4-payload-sdk
```

Do not execute a new inventory build on hardware until its linked ELF has completed the review below.

Build the EXP-013 revision-7 direct-capture fallback with a private local workstation address that is never committed or indexed:

```powershell
.\scripts\Build-HenLoaderBoundaryNetwork.ps1 `
  -Zig C:\path\to\zig.exe `
  -SdkRoot C:\path\to\ps4-payload-sdk `
  -DebugHost <workstation-LAN-address> `
  -DebugPort 9023
```

For the reviewed reference build, the flat payload is 7,044 bytes with SHA-256 `8270D9C6470E27A51AF2FC37C5B84F7775C14D5D3988A4051BB9AB64B01CCA70`. The address changes the binary, so any different private address requires a fresh build hash, post-link review, and transfer verifier update before hardware use.

Validate a retrieved inventory log with `scripts/Parse-SflashInventoryLog.ps1`. A `complete: true` result requires the expected 13.50 firmware marker, all nine provider records, no unexpected lines, and the payload's final completion marker.

## Required review before hardware execution

1. Import the generated ELF into Ghidra.
2. Confirm all functions decompile or account for every failure.
3. Confirm the selected input path is opened with `O_RDONLY`.
4. Confirm writable paths are restricted to the documented output files (external USB for acquisition payloads; the diagnostic log for the inventory payload).
5. Record source revision, toolchain revisions, output length, and SHA-256.
6. Upload the payload and download it again; require identical SHA-256 hashes before execution.

## Runtime transfer on the reference console

For the recorded hardware experiments, start FTP from the installed **PS4-Xplorer 2.08** application. HEN Settings is not the FTP launcher in this workflow. The verified workstation transfer endpoint is the console's current LAN address on TCP port `21`; port `2121` may also be exposed while PS4-Xplorer is active. Payload Guest is used separately to launch the audited flat payload from `/data/payloads`.

## Classify an acquired SFLASH view

Keep private dump bytes outside the repository. After acquisition, generate a publication-safe JSON report containing hashes, size, entropy samples, structural probes, and block-level comparisons:

```powershell
.\scripts\Classify-SflashDump.ps1 `
  -Candidate C:\private\sflash0s1.crypt.bin `
  -RawReference C:\private\sflash0-raw-reference.bin `
  -WholeCryptReference C:\private\sflash0-crypt-node-reference.bin `
  -OutputJson C:\private\sflash0s1-classification.json
```

Review the JSON before copying any result into `docs/` or `manifests/`. Publish hashes and classification evidence only—never the dump, local paths, console identifiers, keys, or unique plaintext.

Inventory valid SLB2 containers and hash their entries without extracting or publishing the entry bytes:

```powershell
.\scripts\Inspect-Slb2Containers.ps1 `
  -Image C:\private\sflash0s1.crypt.bin `
  -OutputJson C:\private\sflash0s1-slb2-inventory.json `
  -ExtractDirectory C:\private\slb2-entries
```

Omit `-ExtractDirectory` for a hashes-only inventory. Extracted entry bytes are Sony-derived research inputs and must remain outside Git.
