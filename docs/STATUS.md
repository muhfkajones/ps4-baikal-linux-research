# Verified status

Last updated: 2026-10-23

## Confirmed

- HEN and Debug Settings operate on the reference PS4 Pro running 13.50.
- The jailbreak is volatile and is lost after shutdown or restart.
- PS4 Linux boots successfully from external USB using a Baikal-compatible kernel and initramfs.
- The reference southbridge reports Baikal B1 (`0x30201`).
- A 44,040,192-byte decrypted Orbis kernel image was acquired and analyzed.
- A complete 33,554,432-byte raw `sflash0` image was acquired read-only.
- The raw flash layout agrees with the documented 32 MiB PS4 serial-flash layout.
- Extracted EMC, EAP, and Torus containers match archived public firmware objects byte-for-byte.
- Published Aeolia/Belize EMC/EAP keys do not decrypt the Baikal firmware objects.
- Known public legacy key material was not found in the acquired Orbis kernel.

## Current experiment

The first crypt-device acquisition used `/dev/sflash0.crypt`. It produced a complete 32 MiB result but did not expose recognizable plaintext at the flash header or known firmware boundaries.

Kernel string and cross-reference analysis identifies `/dev/sflash0s1.crypt` and its child devices as the system-flash crypt provider used during boot. A completed read-only runtime inventory confirms that `/dev/sflash0s1.crypt` is a 30 MiB view beginning with the Sony plaintext flash header. A corrected, read-only, resumable acquisition payload targets this provider; the full output has not yet been acquired or classified.

The same kernel path inventory identifies child providers `/dev/sflash0s1.cryptx1`, `x2`, `x3`, `x2b`, `x3b`, `x39`, and `x40`. The completed inventory found `SLB2` at the start of `x2`, `x2b`, `x3`, and `x3b`. The two `x2` views share a first-sector fingerprint; the two `x3` views do not. These are boot-container views, but a 512-byte probe is insufficient to establish full-content equivalence or select a modification target.

## Current research boundary

No permanent or cold-boot Linux mechanism has been demonstrated. Evidence currently places the unresolved trust boundary below the ordinary Orbis kernel, involving Baikal/SAMU-mediated decryption and signed early-boot components.

## Success criteria

The project goal is reached only when an owned reference console can boot a documented Linux environment after complete power loss without manually repeating the browser jailbreak and payload sequence, with a tested recovery procedure and independently reproducible build instructions.
