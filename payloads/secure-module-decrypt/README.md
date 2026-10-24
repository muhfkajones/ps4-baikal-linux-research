# Targeted secure-module decryptor

This payload is an offline-prepared research tool for the owned 13.50 Baikal B1 reference console. It asks the running AuthMgr path to decrypt the ELF32 program segments in exactly four signed files supplied on USB:

- A/B copies of `80010001` (Secure Kernel)
- A/B copies of `80010008` (AuthMgr)

The payload does not read or write an internal flash device. Inputs are read from `/mnt/usb0/ps4-re-input`; reconstructed ELF32 files, a log, and the success marker are written under `/mnt/usb0/ps4-re-output`.

The payload does call the pinned SDK's firmware-13.50 `mmap_patch`, which changes only the currently running kernel's RAM to permit authenticated SELF mappings. That volatile patch is lost at reboot.

Do not execute an unaudited build. Follow `AUDIT.md`, require an exact USB-input hash match, and retain the original signed files.
