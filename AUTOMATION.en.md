# Turning the scheduled run on / off

[한국어](AUTOMATION.md)

Every day at 07:30, macOS launchd runs `scripts/macos/run_daily.sh`, which emails the security briefing for the previous day.
For Debian-based Linux, see the [Debian-based Linux (cron)](#debian-based-linux-cron) section below.

- Job name (Label): `com.user.securitybrief`
- Source config file: `launchd/com.user.securitybrief.plist` (a template with `__PROJECT_DIR__` in place of the path)
- Installed location: `~/Library/LaunchAgents/com.user.securitybrief.plist`

> **Run every command below from the cloned folder (the repository root).**
> First `cd <cloned folder>`. When you register the job, the current folder path (`$PWD`) is filled into the plist automatically, so you don't need to edit the path by hand.

# Debian-based Linux (cron)

cron runs `scripts/debian/run_daily.sh` every day. Run the commands below from the cloned folder as well.

First, run `claude` on that machine, log in with your claude.ai account, and trust the folder (once). Emails are sent through the Gmail connector connected to that account.

```bash
# Check the system time zone — both the run time (30 7) and the "previous day" use this time zone
timedatectl | grep "Time zone"

# Enable: add one line to the current crontab (path filled in from $PWD)
( crontab -l 2>/dev/null | grep -v securitybrief; echo "30 7 * * * $PWD/scripts/debian/run_daily.sh # securitybrief" ) | crontab -

# Check status
crontab -l | grep securitybrief

# Run once right now
scripts/debian/run_daily.sh

# Disable (removes only that line)
crontab -l | grep -v securitybrief | crontab -
```

- If the machine is off or asleep at that time, that run is skipped.
- Run logs are written to `logs/YYYY-MM-DD.log`, the same as on macOS.
- If you move the folder, run "Disable", then run "Enable" again from the new folder.


# macOS

#### 1) Check status

```bash
# Registered? — one line of output means enabled; no output means disabled
launchctl list | grep securitybrief

# Details (number of runs, last exit code, etc.)
launchctl print gui/$(id -u)/com.user.securitybrief

# Check the scheduled 07:25 wake-up
pmset -g sched
```

#### 2) Enable the job

```bash
# Run from the cloned folder
mkdir -p ~/Library/LaunchAgents
test -f launchd/com.user.securitybrief.plist \
  && sed "s|__PROJECT_DIR__|$PWD|g" launchd/com.user.securitybrief.plist > ~/Library/LaunchAgents/com.user.securitybrief.plist \
  && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.securitybrief.plist \
  || echo "FAILED: run this from the cloned folder (repository root)"

# (Recommended) Wake the Mac at 07:25 even if it is asleep — requires the admin password
sudo pmset repeat wake MTWRFSU 07:25:00
```

You can check the registered path with `grep -A1 ProgramArguments ~/Library/LaunchAgents/com.user.securitybrief.plist`.

#### 3) Run once now

```bash
launchctl kickstart gui/$(id -u)/com.user.securitybrief
```

If the first line of the run date's report (`reports/YYYY-MM-DD.md`, today's date) is already `status: sent`, it exits without sending again.

#### 4) Temporarily disable / re-enable

With `bootout` alone, the plist file stays in `~/Library/LaunchAgents/`, so **the job turns back on after a reboot or re-login.** To keep it off, move the file as well.

```bash
# Run from the cloned folder

# Disable
launchctl bootout gui/$(id -u)/com.user.securitybrief
mv ~/Library/LaunchAgents/com.user.securitybrief.plist launchd/disabled.plist

# Re-enable
mv launchd/disabled.plist ~/Library/LaunchAgents/com.user.securitybrief.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.securitybrief.plist
```

`launchd/disabled.plist` contains your folder path, so it is excluded from commits by `.gitignore`.

#### 5) Remove completely

```bash
launchctl bootout gui/$(id -u)/com.user.securitybrief
rm ~/Library/LaunchAgents/com.user.securitybrief.plist

# Cancel the scheduled 07:25 wake-up
# Caution: this also removes any other repeating power schedule you set yourself
sudo pmset repeat cancel
```

The project's source plist (`launchd/`) remains, so you can register it again at any time with the "Enable the job" steps.

#### 6) After changing the run time or settings


```bash
# Run from the cloned folder
launchctl bootout gui/$(id -u)/com.user.securitybrief
test -f launchd/com.user.securitybrief.plist \
  && sed "s|__PROJECT_DIR__|$PWD|g" launchd/com.user.securitybrief.plist > ~/Library/LaunchAgents/com.user.securitybrief.plist \
  && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.securitybrief.plist \
  || echo "FAILED: run this from the cloned folder (repository root)"
```

After editing `launchd/com.user.securitybrief.plist` (e.g. `Hour`, `Minute`), you must register it again for the change to take effect. Leave `__PROJECT_DIR__` as is.


# Troubleshooting

| Symptom | Where to look / Fix |
|---|---|
| No email arrives | `logs/YYYY-MM-DD.log` (the date of the run), `logs/launchd.err` |
| `Not logged in` in the log | Run `claude` in a terminal and log in again |
| `has not been trusted` / permission denied in the log | Run `claude` in the cloned folder and trust the folder |
| `launchctl print` shows `job state = spawn failed`, `last exit code = 78` (and launchd.err is empty), or `launchd.err` shows `can't open input file` (exit code 127) | If the project is inside a macOS protected folder such as `~/Documents`, `~/Desktop`, or `~/Downloads`, background runs are blocked → move it outside the protected folders, then re-register from the new folder with the "After changing the run time or settings" steps |
| It does not run in the morning | It may not run if the Mac is off or the laptop lid is closed → keeping it plugged in with the lid open at that time is recommended |

# Notes

- If you move the project folder, run the "After changing the run time or settings" steps again from the new folder. The new path is filled into the plist automatically. `scripts/macos/run_daily.sh` and `scripts/debian/run_daily.sh` work relative to their own location, so they don't need to be changed.
- If the folder path contains `|` or `&`, the `sed` substitution breaks, so avoid such names.
