# Reproducibility

## Build environment

The current payload build has been exercised with:

- Windows 11 host
- Zig 0.17.0
- Scene-Collective PS4 Payload SDK
- Ghidra 12.1.4 PUBLIC for post-link review

The PS4 Payload SDK is pinned to commit `b7326416c23ce14639e9180a24093bdc5eedb579`. Apply `third_party/ps4-payload-sdk-zig-compat.patch` before building its `libPS4-zig.a` archive.

## Build

From PowerShell:

```powershell
.\scripts\Build-SflashPayload.ps1 `
  -Variant S1Crypt `
  -Zig C:\path\to\zig.exe `
  -SdkRoot C:\path\to\ps4-payload-sdk
```

The script returns the output path, byte length, and SHA-256 hash. Build products remain ignored by Git.

## Required review before hardware execution

1. Import the generated ELF into Ghidra.
2. Confirm all functions decompile or account for every failure.
3. Confirm the selected input path is opened with `O_RDONLY`.
4. Confirm writable paths are restricted to external USB and the diagnostic log.
5. Record source revision, toolchain revisions, output length, and SHA-256.
6. Upload the payload and download it again; require identical SHA-256 hashes before execution.
