# Pre-execution audit

## Scope

This payload is restricted to the owned PS4 Pro CUH-7215B on firmware 13.50. It takes one passive snapshot of the complete bounded `sm_service` control-plus-staging region and writes the result to external USB.

## Verified properties

1. The payload stops unless `get_firmware()` returns decimal `1350`.
2. The only kernel read is `kernel_base + 0x02680800`, length `0x1380` bytes.
3. The payload does not write to kernel memory, install a hook, restart or respawn a service, call a service mailbox, or access flash.
4. Persistent writes are limited to the following new paths:
   - `/mnt/usb0/ps4-re-output/sm-service-state-full-1350.bin`
   - `/mnt/usb0/ps4-re-output/sm-service-state-full-1350.log`
   - `/mnt/usb0/ps4-re-output/sm-service-state-full-1350.complete`
5. Compiled-path inspection found no `/dev/` path.
6. Two consecutive clean build invocations produced identical outputs.
7. The linked ELF contains zero `SHT_REL` or `SHT_RELA` sections.
8. Ghidra found 26 functions in the flat payload and successfully decompiled all 26.

## Audited artifacts

- ELF: 37,912 bytes; SHA-256 `9DCAE587AC477012C54202756D6BBDD2A36DD1FE9283FE5B455DA4EDD59BA8BA`
- Flat payload: 15,556 bytes; SHA-256 `9B2472DC8018369E4691A347F7F5286A570AC27B9B636093F9926BA87E9DB19C`

## Decision

The uploaded flat payload was retrieved from the console and matched the audited SHA-256 exactly. Approved for the documented read-only experiment. Hardware execution is not yet recorded.
