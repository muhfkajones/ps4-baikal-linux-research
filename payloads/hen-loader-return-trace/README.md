# HEN loader return trace (EXP-014)

This directory contains an offline-only patch against HEN revision `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e`. It preserves the existing syscall-594 hook behavior and records the return codes that the stock application path discards.

The trace is emitted only on firmware 13.50 for Payload Guest title ID `AZIF00003`. It reports return codes, handles, and pointer-presence flags; it does not print kernel addresses, device identifiers, or memory contents. The hook stores one fixed-size record. The user-mode collector reads that record through HEN's existing syscall 109 command path and sends it to a private build-time workstation address; it performs no file I/O.

No build from this directory is authorized for hardware execution. A candidate must pass the reproducible-build and post-link review in `AUDIT.md`, then receive a separate operator authorization.

`source/installer-main.c` is retained as rejected evidence and now fails closed at compile time. The reviewed minimal installer omitted stock HEN's installed-state guard and attempted to replace the live HEN kernel payload after HEN was already active. Its single hardware execution immediately removed video and powered off the reference console before a result notification. The console recovered through a normal cold start and the pinned ordinary HEN workflow. Both staged EXP-014 binaries were then removed and verified absent. Do not rebuild, transfer, or execute this installer route.
