# Exploit-host single-use run gate

## Incident

The original host treated `jb.html?run=1` as deliberate on every request. The PS4 browser retained that exact URL across a restart. Opening the browser therefore launched another exploit without the operator re-entering or approving the URL. That repeat failed two host proof checks and the console shut down.

## Correction

`third_party/ps4-diagnostic-host-single-use-run.patch` replaces reusable `run=1` with a random single-use token generated on each host-server start.

- No token, a wrong token, or a consumed token serves only the inert landing page.
- The first request with the current token serves `jb.html` and atomically consumes the token.
- The bind address and port are environment-configurable so the gate can be tested on loopback without exposing a LAN service.
- A new deliberate run requires a new server process and its newly generated token.

## Offline verification

A loopback-only regression uses `scripts/Test-Ps4HostRunGate.ps1` against the actual patched host. It verifies that the no-token request serves the 515-byte inert page; the first matching request serves the 22,409-byte exploit page; reuse of the same token and a wrong token both serve the inert page; and two concurrent requests with the same fresh token serve the exploit page exactly once. No console or LAN service is involved.

## Gate

The corrected host remains stopped. No browser-based payload run is authorized. The duplicate-request regression passes offline, but a future proposal still requires review of the PS4 browser/AppCache request pattern and an inert-browser-session reset procedure that does not depend on opening a retained exploit tab while the server is live.
