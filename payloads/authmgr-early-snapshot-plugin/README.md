# AuthMgr early-load snapshot plugin

EXP-012 is a firmware-locked HEN user plugin for Payload Guest title `AZIF00003`. HEN's existing plugin loader invokes it as Payload Guest starts, before a person can select a payload from the application UI. The plugin immediately takes the same passive, bounded `sm_service` snapshot used by EXP-011 and then asks the loader to unload it.

The timing change is the experiment. The read range is unchanged: `kernel_base + 0x02680800`, exactly `0x1380` bytes. The plugin does not install a hook, write kernel memory, spawn or restart a secure module, send a mailbox request, or access flash.

## Output

- `/mnt/usb0/ps4-re-output/authmgr-early-state-1350.bin`
- `/mnt/usb0/ps4-re-output/authmgr-early-state-1350.log`
- `/mnt/usb0/ps4-re-output/authmgr-early-state-1350.complete`

The raw snapshot is private evidence and must not be committed.

## Intended configuration

After the PRX has passed the offline audit, back up `/data/hen/plugins.ini` and install the PRX at `/data/hen/plugins/authmgr-early-snapshot.prx`. Enable it only for Payload Guest:

```ini
[AZIF00003]
/data/hen/plugins/authmgr-early-snapshot.prx=1
```

Do not enable this plugin in `[all]`. The HEN plugin manager UI currently exposes global enablement; this experiment uses the title-specific section supported by `plugin_loader` directly.

## Rollback

Restore the exact backed-up `/data/hen/plugins.ini` and delete `/data/hen/plugins/authmgr-early-snapshot.prx`. A restart removes all volatile HEN state. No Sony flash device is opened or modified by this experiment.

## Build

The repository workflow downloads OpenOrbis PS4 Toolchain release `v0.5.3`, builds twice, compares the two PRX files, and publishes the untracked build products as a GitHub Actions artifact. Binary build products remain excluded from Git.
