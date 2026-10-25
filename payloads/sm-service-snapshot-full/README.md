# Full `sm_service` state snapshot

This firmware-locked diagnostic copies one bounded `0x1380`-byte region from the 13.50 Orbis kernel data segment to external USB. The range consists of `0x3A0` bytes of `sm_service` control/request state followed by the complete `0xFE0`-byte staging area identified by targeted Ghidra analysis of the owned reference console's kernel dump.

It is a passive snapshot. It does not install a hook, restart or respawn a secure module, invoke an undocumented mailbox function, access flash, or modify kernel state. Persistent writes are limited to uniquely named files below `/mnt/usb0/ps4-re-output`.

The raw snapshot is private evidence and must not be committed. Analysis must read the current transfer length at snapshot offset `0x39C` and classify only that many bytes from staging offset `0x3A0` as current. Any remaining bytes are retained scratch history.

The separate v2 filenames prevent this experiment from overwriting or being confused with the completed 4 KiB v1 snapshot.
