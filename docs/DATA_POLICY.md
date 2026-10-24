# Data and publication policy

## Publishable

- Original source code and build scripts
- Ghidra scripts and original annotations
- Hardware model, firmware version, and non-unique device-family facts
- File sizes, partition offsets, public-source provenance, and cryptographic hashes
- Redacted logs that contain no console-unique identifiers or local credentials
- Procedures that require users to acquire data from hardware they own

## Never commit

- Raw or decrypted PS4 firmware and operating-system images
- SFLASH, HDD, NOR, NAND, eMMC, SAMU, EMC, EAP, or Torus dumps
- Sony PKG/PUP/SELF/SPRX content
- Console-unique keys, seeds, IDs, certificates, account data, or credentials
- Private signing keys or exploit material received under confidentiality
- Local secrets, FTP credentials, SSH keys, or personal filesystem data

## Artifact verification

Binary artifacts remain outside Git. Their SHA-256 hashes, byte lengths, acquisition method, source-device description, and tool version may be recorded in `manifests/` after review for unique information.
