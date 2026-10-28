# HEN loader return trace (EXP-014)

This directory contains an offline-only patch against HEN revision `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e`. It preserves the existing syscall-594 hook behavior and records the return codes that the stock application path discards.

The trace is emitted only on firmware 13.50 for Payload Guest title ID `AZIF00003`. It reports return codes, handles, and pointer-presence flags; it does not print kernel addresses, device identifiers, or memory contents. The hook stores one fixed-size record. The user-mode collector reads that record through HEN's existing syscall 109 command path and sends it to a private build-time workstation address; it performs no file I/O.

No build from this directory is authorized for hardware execution. A candidate must pass the reproducible-build and post-link review in `AUDIT.md`, then receive a separate operator authorization.

`source/installer-main.c` is the proposed minimal volatile installer. It does not run the stock HEN setup path, write HEN configuration/plugins, or touch flash. It firmware-checks 13.50, installs only the reviewed in-memory kernel component with plugin hooks enabled and duplicate general patch installation disabled, then reports the install result. A reboot removes this volatile replacement; restoring normal operation then requires loading the ordinary pinned HEN build again.
