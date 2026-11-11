# calen

A Swift CLI for Apple Calendar and Reminders over EventKit. It needs macOS 14 or later and ships through `aayush9029/tap`. Status: active.

## Commands

| Task | Command |
|------|---------|
| Build | `make build` |
| Test | `make test` |
| Lint (same as CI) | `make lint` |
| Format | `make format` |
| Signed universal binary into `bin/calen` | `make release` |
| End-to-end test on the installed binary | `Tests/E2E/installed-e2e.sh` |

## Architecture

- `Sources/CalenCore` holds the EventKit service, the date, duration, and recurrence parsers, and the destructive-action policy.
- `Sources/calen` holds the argument-parser commands and the output layer.
- `docs/eventkit.md` lists the EventKit limits: read-only fields, sources, travel time, and identifiers.

## Rules

- The tap formula installs the committed `bin/calen` binary. It does not build from source. Before you tag, run `make release` and commit the new `bin/calen`.
- `scripts/build-universal.sh` signs with `CODESIGN_IDENTITY`. Its default identity is revoked; set `CODESIGN_IDENTITY` to your current `Developer ID Application` identity.
- The linker embeds `Sources/calen/Resources/Info.plist` in the binary, because EventKit needs the usage strings. Change the version there and in `CalenCLI.swift`.
- Each list, show, create, update, move, and delete command supports `--json`. Destructive commands need a terminal confirmation or `--force`. Mutations support `--dry-run`. Keep these for new commands.
- The E2E script writes real events and reminders with a `calen-e2e-` prefix and then deletes them. Run it only on a Mac where that is safe.
