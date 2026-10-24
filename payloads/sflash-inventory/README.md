# Read-only SFLASH provider inventory

This diagnostic payload checks the firmware 13.50 SFLASH provider paths identified in the decrypted Orbis kernel. For each path it records only:

- whether a read-only open succeeded;
- media and sector sizes returned by the device;
- the number of bytes returned by one bounded 512-byte read;
- a non-cryptographic sample fingerprint; and
- whether the sample begins with a small set of known structural markers.

It never opens any SFLASH device for writing. Its only writable path is `/data/payloads/sflash-provider-inventory-readonly.log`.

The inventory is intended to select a precisely identified acquisition target without running separate trial payloads for every child provider. A new binary must receive the same source review, reproducible-build check, and post-link Ghidra audit as the acquisition payload before hardware execution.

The reviewed build record is in [`AUDIT.md`](AUDIT.md). Generated binaries, ELF files, Ghidra projects, and reports remain excluded from Git.
