# EXP-014 audit record

## Pinned input

- HEN source revision: `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e`
- Patch: `hen-exp014.patch`
- Patch SHA-256: `3AD7CD0C667FDC7C51C4E6870D95524592C3473DC6CAA65A133D266FFC4F086F`
- Firmware scope: 13.50
- Title scope: Payload Guest `AZIF00003`

## Completed source gates

- [x] Patch applies cleanly to the pinned revision.
- [x] Existing syscall-594 behavior is preserved.
- [x] Trace output is title-locked and contains no kernel address, memory content, or device-unique value.

## Remaining build gates

- [ ] Two clean builds are byte-identical.
- [ ] ELF and flat-binary SHA-256 values are recorded.
- [ ] Post-link Ghidra accounts for every function and reachable action.
- [ ] Exact rollback and operator steps are reviewed.

Hardware execution is not authorized while any gate remains unchecked.
