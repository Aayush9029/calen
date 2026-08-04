<p align="center">
  <img src="assets/icon.png" width="128" alt="calen">
  <h1 align="center">calen</h1>
  <p align="center">Manage Apple Calendar and Reminders from the command line with EventKit</p>
</p>

<p align="center">
  <a href="https://github.com/Aayush9029/calen/releases/latest"><img src="https://img.shields.io/github/v/release/Aayush9029/calen" alt="Release"></a>
  <a href="https://github.com/Aayush9029/calen/blob/main/LICENSE"><img src="https://img.shields.io/github/license/Aayush9029/calen" alt="License"></a>
</p>

<p align="center">
  <img src="assets/demo.gif" alt="calen demo" width="800">
</p>

## Install

```bash
brew install aayush9029/tap/calen
```

Or tap first:

```bash
brew tap aayush9029/tap
brew install calen
```

calen requires macOS 14 or later. Run `calen permissions request` once, then allow Calendar and Reminders access for your terminal.

## Usage

```bash
calen permissions status
calen calendars list
calen lists create --title "Launch" --color "#FF9500"

calen events list --from today --to 2026-09-01
calen events create --title "Focus" --start "2026-08-05 09:00" --end "2026-08-05 10:00"
calen events create --title "Standup" --start "2026-08-05 09:00" --repeat weekly --repeat-on mon,wed,fri
calen events update EVENT_ID --title "New title" --span future

calen reminders create --title "Send report" --due "2026-08-05 17:00" --priority 1
calen reminders complete REMINDER_ID
calen reminders search report --state incomplete --json

calen events create
calen events list --json
```

Every list, show, create, update, move, and delete command supports JSON output. Destructive commands require confirmation in a terminal or `--force` in scripts. Use `--dry-run` to inspect mutations without saving.

EventKit keeps organizer, attendee, participation, status, creation, modification, stable server identifiers, defaults, and source metadata read-only. Calendar sources can only be selected when a collection is created. Public EventKit does not expose Calendar travel time to third-party apps, so calen reports it as unavailable. See [EventKit behavior](docs/eventkit.md) for recurrence, date, identifier, and provider details.

## License

MIT
