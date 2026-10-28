# EXP-014 host capture

`capture_exp014.py` is a one-shot bounded TCP listener and strict parser. It accepts exactly the 15 numbered hexadecimal records followed by the final PASS line, validates the readback result, magic, version, trigger, Boolean presence fields, and completion marker, then writes the accepted capture to the explicitly supplied local path.

The listener does not contain a workstation address. Keep private endpoint details and runtime captures outside Git and the LLM Wiki source set.
