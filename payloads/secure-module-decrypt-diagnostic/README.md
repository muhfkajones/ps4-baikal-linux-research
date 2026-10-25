# Secure-module decrypt diagnostic

This firmware-locked diagnostic revision records the exact `errno` returned when the 13.50 AuthMgr-backed SELF mapping fails. It preserves the v1 USB-only input/output boundary and removes incomplete ELF output files after a failed segment.

The payload reads only the four named inputs below `/mnt/usb0/ps4-re-input` and writes only its log and successful reconstructed files below `/mnt/usb0/ps4-re-output`. It does not open an internal storage device.

This revision exists to classify the v1 runtime failure. It must not be treated as a decryption success unless the `.complete` marker is present and every output passes ELF validation.

## Recorded result

On the reference 13.50 Baikal B1 console, all four A/B Secure Kernel and AuthMgr inputs failed on program segment zero with `mmap` errno `8` (`ENOEXEC`). No completion marker was created, and this diagnostic revision removed the incomplete output files.

This result closes the ordinary SELF mapping branch. The 13.50 kernel starts AuthMgr through `sceSblServiceSpawn("80010008", ...)`, so further acquisition work must investigate the separate secure-module service/SAMU path rather than changing USB paths or retrying `mmap` flags.
