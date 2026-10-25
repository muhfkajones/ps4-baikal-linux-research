# AuthMgr suspend/resume lifecycle

## Confirmed 13.50 kernel behavior

Targeted analysis of the privately acquired, decrypted 13.50 Orbis kernel established the following control flow without publishing Sony code or binaries:

- `_sceSblAuthMgrSmStart` starts secure service `80010008` through `sceSblServiceSpawn` when its started flag is clear.
- The AuthMgr suspend handler clears that started flag.
- The AuthMgr resume handler itself is a no-op.
- Later AuthMgr-backed operations call the start routine and therefore lazily restart `80010008` after suspend.

Relevant static-analysis addresses in the 13.50 kernel image loaded at Ghidra base `0xffffffff9ece4000` are:

- AuthMgr start: `0xffffffff9f322070`
- AuthMgr clear-started-flag: `0xffffffff9f322180`
- AuthMgr suspend handler: `0xffffffff9f327850`
- AuthMgr resume handler: `0xffffffff9f327930`
- confirmed post-resume lazy-start callers: `0xffffffff9f314090` and `0xffffffff9f320d00`

These addresses are analysis coordinates, not a portable patch table.

## HEN rest-mode evidence

The inspected Scene-Collective PS4 HEN revision is `d077fb4031cf0e089fb7a233cebeebcd1ed3c68e`.

- Its README lists Rest Mode Support.
- `kpayload/source/patch.c` registers `apply_patches` for `system_resume_phase4` on firmware newer than 5.50.
- The same revision contains a dedicated 13.50 offsets table, including the event-handler registration address.
- Scene-Collective's `pre-release-main-179` release records the addition of 13.50 support.

Primary sources:

- <https://github.com/Scene-Collective/ps4-hen/tree/d077fb4031cf0e089fb7a233cebeebcd1ed3c68e>
- <https://github.com/Scene-Collective/ps4-hen/blob/d077fb4031cf0e089fb7a233cebeebcd1ed3c68e/kpayload/source/patch.c>
- <https://github.com/Scene-Collective/ps4-hen/releases/tag/pre-release-main-179>

## EXP-011 capture sequence

To reduce unrelated secure-service activity between wake and capture:

1. Open Payload Guest before suspension and leave its payload list on screen.
2. Enter Rest Mode without closing Payload Guest.
3. Wake the console.
4. If Payload Guest resumes normally, immediately run `sm-service-snapshot-full-1350` once without opening another application first.

This is a bounded observation, not proof that `80010008` will remain the last visible service record. Only the transfer-length field identifies current staging bytes; the rest remains scratch history. If HEN or Payload Guest does not survive resume, stop the experiment rather than inserting an unrecorded jailbreak or app-launch sequence.

## Attempt result

Payload Guest displayed an application error immediately after resume, before EXP-011 could be selected. The console was then accidentally restarted, so no post-resume snapshot exists. After HEN was restored, EXP-011 was run as a documented post-boot baseline instead. That baseline completed successfully but again observed service `8001000B`, not `80010008`.
