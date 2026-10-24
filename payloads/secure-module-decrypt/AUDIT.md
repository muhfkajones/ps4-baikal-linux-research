# Pre-execution audit

Hardware execution is prohibited until all items pass. Offline items 1–8 passed on 2026-10-24; transfer verification and execution remain pending.

1. Build only against pinned SDK revision `b7326416c23ce14639e9180a24093bdc5eedb579` with this project's compatibility patch.
2. Record the linked ELF and flat-binary SHA-256 values and byte lengths.
3. Confirm all four input paths are below `/mnt/usb0/ps4-re-input` and opened `O_RDONLY`.
4. Confirm all persistent output paths are below `/mnt/usb0/ps4-re-output`.
5. Confirm the only kernel modification is the SDK's volatile 13.50 `mmap_patch` path.
6. Confirm firmware must equal 13.50 before the patch or decrypt request.
7. Confirm each input is size-bound, SELF-header checked, ELF32 checked, machine `0x0667` checked, and program-segment bounds checked.
8. Import the ELF into Ghidra, account for every function, and verify the flat binary has no unresolved data-pointer relocation.
9. Upload and download the payload once; require identical SHA-256 values before execution.
10. Treat decrypted outputs as private Sony-derived research inputs. Never commit them or extracted key material.

## Recorded offline result

- Pinned SDK: `b7326416c23ce14639e9180a24093bdc5eedb579`
- Linked ELF: 39,832 bytes, SHA-256 `9DD503027E90428CFF6C1FB97D7B77DF6B6F0CDCD27060195F220A5C7276E32A`
- Flat binary: 15,108 bytes, SHA-256 `AF4C84DBFA288F71926F7544200AF124D1A4684870E1D6C13A9512C8B510FF73`
- Rebuild check: identical hashes from two consecutive builds
- ELF relocations: none
- Ghidra flat-binary result: 30 functions found; 30 successfully decompiled
- Compiled strings: exactly four declared input files plus output files, log, marker, and their USB roots; no `/dev/` path
- Hardware execution: **not performed**
