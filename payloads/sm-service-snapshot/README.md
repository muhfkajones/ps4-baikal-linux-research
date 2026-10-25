# `sm_service` state snapshot

This firmware-locked diagnostic copies one bounded 4 KiB region from the 13.50 Orbis kernel data segment to external USB. The region contains the `sm_service` control/request records and the sector-sized staging buffer identified by targeted Ghidra analysis of the owned reference console's kernel dump.

It does not install a hook, respawn a secure module, invoke an undocumented mailbox function, or write to flash. Persistent writes are limited to `/mnt/usb0/ps4-re-output`.

The raw snapshot is private evidence and must not be committed. Its purpose is to determine whether the CPU-visible SAMU handoff buffer retains only signed/encrypted input bytes or any transformed/plaintext material after the already-completed AuthMgr startup.
