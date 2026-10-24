# Read-only SFLASH acquisition payload

This payload opens one PS4 flash device with `O_RDONLY` and copies it to external USB storage in 16 KiB chunks. It validates firmware version, media size, sector size, resume alignment, and all read/write lengths.

The payload never opens the PS4 flash input for writing. Its writable paths are restricted to:

- `/mnt/usb0/.sflash-dumper-probe`
- `/mnt/usb0/PS4/13.50/*.bin`
- `/mnt/usb0/PS4/13.50/*.complete`
- a diagnostic log under `/data/payloads/`

Variants:

- default source: `/dev/sflash0`
- `variants/whole-crypt.h`: `/dev/sflash0.crypt` — retained as a documented negative experiment
- `variants/s1-crypt.h`: `/dev/sflash0s1.crypt` — current system-slice experiment

The `.bin` payloads are build products and are intentionally excluded from Git.

Before running a newly built payload, inspect the linked ELF in Ghidra and confirm that the input device is opened with flags `0, 0` and only the documented USB/log paths are writable.
