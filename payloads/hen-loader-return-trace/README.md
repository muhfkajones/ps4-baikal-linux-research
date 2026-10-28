# HEN loader return trace (EXP-014)

This directory contains an offline-only patch against HEN revision `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e`. It preserves the existing syscall-594 hook behavior and records the return codes that the stock application path discards.

The trace is emitted only for Payload Guest title ID `AZIF00003`. It reports return codes, handles, and pointer-presence flags; it does not print kernel addresses, device identifiers, or memory contents.

No build from this directory is authorized for hardware execution. A candidate must pass the reproducible-build and post-link review in `AUDIT.md`, then receive a separate operator authorization.
