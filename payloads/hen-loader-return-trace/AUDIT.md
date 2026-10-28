# EXP-014 audit record

## Pinned input

- HEN source revision: `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e`
- Patch: `hen-exp014.patch`
- Patch SHA-256: `F1BED2059C538614779F9CF1F6F4387ADF7465486D0A87AA54C7E4564D4999AC`
- Firmware scope: 13.50
- Title scope: Payload Guest `AZIF00003`

## Completed source gates

- [x] Patch applies cleanly to the pinned revision.
- [x] Existing syscall-594 behavior is preserved.
- [x] Trace output is title-locked and contains no kernel address, memory content, or device-unique value.
- [x] Readback reuses syscall 109 command 10, accepts only the calling process on firmware 13.50, and copies one fixed 56-byte record.
- [x] Collector requires a private build-time host, performs no file I/O, and validates magic, version, trigger, and completion fields.
- [x] Minimal installer omits the stock HEN setup/config/plugin-write path and installs only the volatile in-memory kernel component.

## Completed build gates

- [x] Two clean builds of each component are byte-identical.
- [x] All linked ELFs contain zero relocations.
- [x] Post-link Ghidra accounts for every recovered function in all three components.
- [x] Six committed host-parser tests cover a complete record, truncation, bad magic, non-Boolean flags, extra lines, and the network-size bound.

| Component | ELF bytes | ELF SHA-256 | Flat bytes | Flat SHA-256 | Ghidra |
| --- | ---: | --- | ---: | --- | ---: |
| Kernel component | 49,096 | `1B9E048A7C8012CCB899EED949FA5AED9472CD9A50BB3E0CCCB640088C11207E` | 35,184 | `AD5CDD21F5726AF55D9E0C6B3A79283EFFF16E2ECA7B0A0480FE0584D5E61066` | 43/43 |
| Minimal volatile installer | 69,984 | `ABC0E3A1CF1B845C65E559F6B236609400EBEAF58BE4230EEABB30EE2E1DE510` | 48,052 | `3C7341D407B192FB01E7168F77974899619EFDC055885258694FD929C7571A45` | 19/19 |
| User-mode collector (documentation-address audit build) | 30,616 | `57B9E556B53EF7ED12CBE402180294E97975573A7AAEBF20F774CAEFE17A89B4` | 6,852 | `66D837321B0D1F738B05746DE19BB0446C515E1646E3BA09347538889C5AFAF6` | 12/12 |

The collector hashes above use non-routable documentation address `192.0.2.1`. A hardware candidate must be rebuilt with the private workstation address, audited, and hash-recorded without committing that address.

The private-endpoint collector candidate was also built twice with byte-identical results. Its 30,616-byte ELF has SHA-256 `41DED413F30030DB0AD5413052815D867DCE7E2DFC0E80D796CF32AB4AED18BE`; its 6,852-byte flat binary has SHA-256 `B7AA8E305FB05E0EA03DAAEE3E358DB25F80BE198F6180DBF73D8F930C188B8C`. The ELF contains zero relocations and Ghidra decompiled all 12 recovered functions. The private address is excluded from Git and the Wiki source set.

## Remaining hardware gates

- [x] Rebuild and re-audit the collector with the private capture endpoint.
- [x] Review exact transfer, listener, launch, and rollback steps in [`docs/EXP-014-RUNBOOK.md`](../../docs/EXP-014-RUNBOOK.md).
- [ ] Verify every transferred binary by console-side round trip.
- [ ] Obtain explicit operator authorization for one run.

Hardware execution is not authorized while any gate remains unchecked.
