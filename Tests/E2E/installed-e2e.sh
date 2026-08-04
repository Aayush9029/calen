#!/bin/zsh
set -euo pipefail

CALEN_BIN_PATH="${CALEN_BIN:-$(command -v calen)}"
CALEN_RUN_ID="$(uuidgen)"
CALEN_PREFIX="calen-e2e-$CALEN_RUN_ID"
CALEN_CALENDAR_A=""
CALEN_CALENDAR_B=""
CALEN_LIST_A=""
CALEN_LIST_B=""
CALEN_CHECKS=0

fail() {
  print -u2 "E2E failure: $1"
  exit 1
}

check_json() {
  local label="$1"
  local json="$2"
  local expression="$3"
  if ! printf '%s' "$json" | jq -e "$expression" >/dev/null; then
    print -u2 "$json"
    fail "$label"
  fi
  CALEN_CHECKS=$((CALEN_CHECKS + 1))
  print "ok $CALEN_CHECKS - $label"
}

expect_failure() {
  local label="$1"
  shift
  local output_file
  output_file="$(mktemp "/tmp/calen-e2e-error.XXXXXX")"
  if "$@" >"$output_file" 2>&1; then
    rm -f "$output_file"
    fail "$label unexpectedly succeeded"
  fi
  rm -f "$output_file"
  CALEN_CHECKS=$((CALEN_CHECKS + 1))
  print "ok $CALEN_CHECKS - $label"
}

cleanup() {
  for identifier in "$CALEN_CALENDAR_A" "$CALEN_CALENDAR_B"; do
    if [[ -n "$identifier" ]]; then
      "$CALEN_BIN_PATH" calendars delete "$identifier" --force >/dev/null 2>&1 || true
    fi
  done
  for identifier in "$CALEN_LIST_A" "$CALEN_LIST_B"; do
    if [[ -n "$identifier" ]]; then
      "$CALEN_BIN_PATH" lists delete "$identifier" --force >/dev/null 2>&1 || true
    fi
  done
}
trap cleanup EXIT INT TERM

command -v jq >/dev/null || fail "jq is required to run the E2E suite"
command -v expect >/dev/null || fail "expect is required to run the E2E suite"
[[ -x "$CALEN_BIN_PATH" ]] || fail "calen binary is not executable: $CALEN_BIN_PATH"

permission_status="$("$CALEN_BIN_PATH" permissions status --json)"
check_json "Calendar and Reminders permissions are full access" "$permission_status" \
  '.events == "fullAccess" and .reminders == "fullAccess"'

permission_request="$("$CALEN_BIN_PATH" permissions request --entity all --json)"
check_json "permission request is idempotent" "$permission_request" \
  '.events == "fullAccess" and .reminders == "fullAccess"'

diagnostics="$("$CALEN_BIN_PATH" permissions diagnose --json)"
check_json "installed binary has usage descriptions and bundle identity" "$diagnostics" \
  '.bundleIdentifier == "art.aayush.calen"
   and .calendarUsageDescriptionEmbedded
   and .remindersUsageDescriptionEmbedded
   and .travelTimeAPI == "unavailable in public EventKit"'

sources="$("$CALEN_BIN_PATH" sources list --json)"
check_json "calendar sources are visible" "$sources" 'length > 0'
event_source_id="$(printf '%s' "$sources" | jq -r \
  'map(select(.title == "iCloud" and .eventCalendarCount > 0))[0].identifier // empty')"
[[ -n "$event_source_id" ]] || fail "an iCloud event source is required for availability E2E"

calendar_a_json="$("$CALEN_BIN_PATH" calendars create \
  --title "$CALEN_PREFIX-events-a" --source "$event_source_id" \
  --color '#4F8EF7' --json)"
CALEN_CALENDAR_A="$(printf '%s' "$calendar_a_json" | jq -r '.value.identifier')"
check_json "first event calendar is created" "$calendar_a_json" \
  '.operation == "create" and .changed and (.value.identifier | length > 0)'

calendar_b_json="$("$CALEN_BIN_PATH" calendars create \
  --title "$CALEN_PREFIX-events-b" --source "$event_source_id" \
  --color '#34C759' --json)"
CALEN_CALENDAR_B="$(printf '%s' "$calendar_b_json" | jq -r '.value.identifier')"
check_json "second event calendar is created" "$calendar_b_json" \
  '.operation == "create" and .changed'

list_a_json="$("$CALEN_BIN_PATH" lists create \
  --title "$CALEN_PREFIX-list-a" --color '#FF9500' --json)"
CALEN_LIST_A="$(printf '%s' "$list_a_json" | jq -r '.value.identifier')"
check_json "first reminder list is created" "$list_a_json" \
  '.operation == "create" and .changed and (.value.identifier | length > 0)'

list_b_json="$("$CALEN_BIN_PATH" lists create \
  --title "$CALEN_PREFIX-list-b" --color '#AF52DE' --json)"
CALEN_LIST_B="$(printf '%s' "$list_b_json" | jq -r '.value.identifier')"
check_json "second reminder list is created" "$list_b_json" \
  '.operation == "create" and .changed'

calendar_show="$("$CALEN_BIN_PATH" calendars show "$CALEN_CALENDAR_A" --json)"
check_json "calendar show returns source and color metadata" "$calendar_show" \
  '(.sourceIdentifier | length > 0)
   and (.color | startswith("#"))
   and (.supportedAvailabilities | index("free") != null)'

calendar_rename="$("$CALEN_BIN_PATH" calendars rename "$CALEN_CALENDAR_A" \
  --title "$CALEN_PREFIX-events-primary" --json)"
check_json "calendar rename persists" "$calendar_rename" \
  '.changed and .value.title == "'"$CALEN_PREFIX-events-primary"'"'

calendar_recolor="$("$CALEN_BIN_PATH" calendars recolor "$CALEN_CALENDAR_A" \
  --color '#007AFF' --json)"
check_json "calendar recolor persists a normalized color" "$calendar_recolor" \
  '.changed and (.value.color | startswith("#"))'

list_update="$("$CALEN_BIN_PATH" lists update "$CALEN_LIST_A" \
  --title "$CALEN_PREFIX-list-primary" --color '#FF2D55' --json)"
check_json "reminder list update persists" "$list_update" \
  '.changed and .value.title == "'"$CALEN_PREFIX-list-primary"'"'

event_json="$("$CALEN_BIN_PATH" events create \
  --title "$CALEN_PREFIX-flag-event" \
  --calendar "$CALEN_CALENDAR_A" \
  --start '2026-09-10 09:00' \
  --end '2026-09-10 10:00' \
  --time-zone America/Edmonton \
  --notes initial \
  --url https://example.com/initial \
  --location Office \
  --latitude 53.5461 \
  --longitude=-113.4938 \
  --location-radius 120 \
  --availability free \
  --alarm-relative=-15m \
  --alarm-at '2026-09-10 08:00' \
  --json)"
event_id="$(printf '%s' "$event_json" | jq -r '.value.identifier')"
event_external_id="$(printf '%s' "$event_json" | jq -r '.value.externalIdentifier')"
check_json "flag event covers URLs, structured location, time zone, availability, and alarms" \
  "$event_json" \
  '.changed
   and .value.timeZone == "America/Edmonton"
   and .value.availability == "free"
   and .value.structuredLocation.latitude == 53.5461
   and (.value.alarms | length) == 2'

external_event="$("$CALEN_BIN_PATH" events show "$event_external_id" --external-id --json)"
check_json "event external identifiers resolve" "$external_event" \
  '.title == "'"$CALEN_PREFIX-flag-event"'"'

event_list="$("$CALEN_BIN_PATH" events list \
  --from 2026-09-09 --to 2026-09-12 --calendar "$CALEN_CALENDAR_A" --json)"
check_json "event list JSON contains the created event" "$event_list" \
  'map(select(.title == "'"$CALEN_PREFIX-flag-event"'")) | length == 1'

event_show="$("$CALEN_BIN_PATH" events show "$event_id" --json)"
check_json "event show includes read-only metadata fields" "$event_show" \
  'has("status") and has("isDetached") and has("attendees")
   and .travelTimeWritable == false'

event_noop="$("$CALEN_BIN_PATH" events update "$event_id" \
  --title "$CALEN_PREFIX-flag-event" --json)"
check_json "event no-op update stays unchanged" "$event_noop" '.changed == false'

event_update="$("$CALEN_BIN_PATH" events update "$event_id" \
  --notes updated \
  --url https://example.com/updated \
  --location Headquarters \
  --latitude 53.55 \
  --longitude=-113.49 \
  --location-radius 200 \
  --availability busy \
  --alarm-relative=-10m \
  --json)"
check_json "event update persists changed fields" "$event_update" \
  '.changed
   and .value.notes == "updated"
   and .value.url == "https://example.com/updated"
   and .value.location == "Headquarters"
   and .value.availability == "busy"
   and (.value.alarms | length) == 1'

event_move="$("$CALEN_BIN_PATH" events move "$event_id" \
  --calendar "$CALEN_CALENDAR_B" --json)"
event_id="$(printf '%s' "$event_move" | jq -r '.value.identifier')"
check_json "event move changes calendar assignment" "$event_move" \
  '.changed and .value.calendarIdentifier == "'"$CALEN_CALENDAR_B"'"'

expect_failure "travel time is rejected as unavailable" \
  "$CALEN_BIN_PATH" events update "$event_id" --travel-time 30m

all_day_json="$("$CALEN_BIN_PATH" events create \
  --title "$CALEN_PREFIX-all-day" \
  --calendar "$CALEN_CALENDAR_A" \
  --start 2026-09-12 \
  --end 2026-09-14 \
  --all-day \
  --json)"
all_day_id="$(printf '%s' "$all_day_json" | jq -r '.value.identifier')"
check_json "all-day event preserves date-only semantics" "$all_day_json" \
  '.value.isAllDay and ((.value.endDate | fromdateiso8601) - (.value.startDate | fromdateiso8601) == 172800)'

CALEN_BIN_ABS="$CALEN_BIN_PATH" CALEN_CAL_ID_ENV="$CALEN_CALENDAR_A" \
  CALEN_INTERACTIVE_TITLE="$CALEN_PREFIX-interactive-event" expect <<'EXPECT'
set timeout 10
spawn $env(CALEN_BIN_ABS) events create \
  --calendar $env(CALEN_CAL_ID_ENV) \
  --time-zone America/Edmonton
expect "Event title:"
send "$env(CALEN_INTERACTIVE_TITLE)\r"
expect "Start"
send "2026-09-15 14:00\r"
expect eof
catch wait result
exit [lindex $result 3]
EXPECT
interactive_search="$("$CALEN_BIN_PATH" events search "$CALEN_PREFIX-interactive-event" \
  --from 2026-09-15 --to 2026-09-16 --calendar "$CALEN_CALENDAR_A" --json)"
check_json "interactive event creation supplies omitted required values" "$interactive_search" \
  'length == 1 and .[0].title == "'"$CALEN_PREFIX-interactive-event"'"'

series_json="$("$CALEN_BIN_PATH" events create \
  --title "$CALEN_PREFIX-series" \
  --calendar "$CALEN_CALENDAR_A" \
  --start '2026-09-20T15:00:00Z' \
  --end '2026-09-20T16:00:00Z' \
  --repeat daily \
  --repeat-count 3 \
  --json)"
series_id="$(printf '%s' "$series_json" | jq -r '.value.identifier')"
check_json "recurring event has an explicit count end" "$series_json" \
  '.value.recurrenceRules[0].end.occurrenceCount == 3'

series_occurrences="$("$CALEN_BIN_PATH" events list \
  --from 2026-09-19 --to 2026-09-25 --calendar "$CALEN_CALENDAR_A" --json)"
check_json "event query returns one result per recurrence occurrence" "$series_occurrences" \
  'map(select(.title == "'"$CALEN_PREFIX-series"'")) | length == 3'

series_occurrence="$(printf '%s' "$series_occurrences" | jq -r \
  'map(select(.title == "'"$CALEN_PREFIX-series"'")) | .[1].occurrenceDate')"
expect_failure "recurring event update requires an explicit span" \
  "$CALEN_BIN_PATH" events update "$series_id" --title unsafe

detached_json="$("$CALEN_BIN_PATH" events update "$series_id" \
  --occurrence "$series_occurrence" \
  --span this \
  --title "$CALEN_PREFIX-detached" \
  --json)"
check_json "one recurring occurrence detaches safely" "$detached_json" \
  '.changed and .value.isDetached and .value.title == "'"$CALEN_PREFIX-detached"'"'

series_after="$("$CALEN_BIN_PATH" events list \
  --from 2026-09-19 --to 2026-09-25 --calendar "$CALEN_CALENDAR_A" --json)"
check_json "detached occurrence does not rename its siblings" "$series_after" \
  '(map(select(.title == "'"$CALEN_PREFIX-detached"'")) | length) == 1
   and (map(select(.title == "'"$CALEN_PREFIX-series"'")) | length) == 2'

dry_event="$("$CALEN_BIN_PATH" events create \
  --title "$CALEN_PREFIX-dry-event" \
  --calendar "$CALEN_CALENDAR_A" \
  --start '2026-09-25 09:00' \
  --end '2026-09-25 10:00' \
  --dry-run \
  --json)"
check_json "event dry-run reports without saving" "$dry_event" \
  '.dryRun and .changed'
dry_event_search="$("$CALEN_BIN_PATH" events search "$CALEN_PREFIX-dry-event" \
  --from 2026-09-25 --to 2026-09-26 --calendar "$CALEN_CALENDAR_A" --json)"
check_json "event dry-run leaves no saved item" "$dry_event_search" 'length == 0'

expect_failure "invalid event date is rejected" \
  "$CALEN_BIN_PATH" events create \
  --title invalid --calendar "$CALEN_CALENDAR_A" \
  --start '2026-03-08 02:30' --end '2026-03-08 03:30' \
  --time-zone America/Edmonton

empty_events="$("$CALEN_BIN_PATH" events search "$CALEN_PREFIX-missing" \
  --from 2026-09-01 --to 2026-10-01 --json)"
check_json "empty event search is a JSON array" "$empty_events" 'length == 0'

expect_failure "event delete refuses noninteractive input without force" \
  "$CALEN_BIN_PATH" events delete "$event_id"

event_dry_delete="$("$CALEN_BIN_PATH" events delete "$event_id" --dry-run --json)"
check_json "event delete dry-run keeps the event" "$event_dry_delete" \
  '.dryRun and .operation == "delete"'
"$CALEN_BIN_PATH" events show "$event_id" --json >/dev/null

CALEN_BIN_ABS="$CALEN_BIN_PATH" CALEN_EVENT_ID_ENV="$event_id" expect <<'EXPECT'
set timeout 10
spawn $env(CALEN_BIN_ABS) events delete $env(CALEN_EVENT_ID_ENV)
expect "Delete event"
send "n\r"
expect "Cancelled"
expect eof
catch wait result
exit 0
EXPECT
"$CALEN_BIN_PATH" events show "$event_id" --json >/dev/null
CALEN_CHECKS=$((CALEN_CHECKS + 1))
print "ok $CALEN_CHECKS - interactive destructive cancellation leaves the event intact"

event_delete="$("$CALEN_BIN_PATH" events delete "$event_id" --force --json)"
check_json "forced event delete succeeds" "$event_delete" \
  '.operation == "delete" and .changed'
expect_failure "deleted event cannot be shown" \
  "$CALEN_BIN_PATH" events show "$event_id"

"$CALEN_BIN_PATH" events delete "$all_day_id" --force >/dev/null
"$CALEN_BIN_PATH" events delete "$series_id" --span future --force >/dev/null

reminder_json="$("$CALEN_BIN_PATH" reminders create \
  --title "$CALEN_PREFIX-reminder" \
  --list "$CALEN_LIST_A" \
  --start 2026-09-10 \
  --due '2026-09-11 17:00' \
  --time-zone America/Edmonton \
  --priority 1 \
  --notes initial \
  --url https://example.com/task \
  --location Home \
  --alarm-relative=-30m \
  --alarm-location 'enter,53.5461,-113.4938,100,Home' \
  --json)"
reminder_id="$(printf '%s' "$reminder_json" | jq -r '.value.identifier')"
reminder_external_id="$(printf '%s' "$reminder_json" | jq -r '.value.externalIdentifier')"
check_json "reminder covers dates, priority, URL, notes, and location alarms" \
  "$reminder_json" \
  '.changed
   and .value.priority == 1
   and .value.dueDate != null
   and (.value.alarms | length) == 2'

reminder_external="$("$CALEN_BIN_PATH" reminders show \
  "$reminder_external_id" --external-id --json)"
check_json "reminder external identifiers resolve" "$reminder_external" \
  '.title == "'"$CALEN_PREFIX-reminder"'"'

reminder_list="$("$CALEN_BIN_PATH" reminders list \
  --list "$CALEN_LIST_A" --state incomplete --json)"
check_json "reminder list JSON contains the created reminder" "$reminder_list" \
  'map(select(.title == "'"$CALEN_PREFIX-reminder"'")) | length == 1'

reminder_noop="$("$CALEN_BIN_PATH" reminders update "$reminder_id" \
  --title "$CALEN_PREFIX-reminder" --json)"
check_json "reminder no-op update stays unchanged" "$reminder_noop" '.changed == false'

reminder_update="$("$CALEN_BIN_PATH" reminders update "$reminder_id" \
  --notes updated \
  --url https://example.com/task-updated \
  --location Office \
  --due '2026-09-12 18:00' \
  --time-zone America/Edmonton \
  --priority 5 \
  --alarm-relative=-10m \
  --json)"
check_json "reminder update persists changed fields" "$reminder_update" \
  '.changed
   and .value.notes == "updated"
   and .value.priority == 5
   and (.value.alarms | length) == 1'

reminder_move="$("$CALEN_BIN_PATH" reminders move "$reminder_id" \
  --list "$CALEN_LIST_B" --json)"
reminder_id="$(printf '%s' "$reminder_move" | jq -r '.value.identifier')"
check_json "reminder move changes list assignment" "$reminder_move" \
  '.changed and .value.listIdentifier == "'"$CALEN_LIST_B"'"'

reminder_complete="$("$CALEN_BIN_PATH" reminders complete "$reminder_id" --json)"
check_json "reminder completion sets completion metadata" "$reminder_complete" \
  '.changed and .value.isCompleted and .value.completionDate != null'

reminder_reopen="$("$CALEN_BIN_PATH" reminders reopen "$reminder_id" --json)"
check_json "reminder reopen clears completion metadata" "$reminder_reopen" \
  '.changed and (.value.isCompleted | not) and .value.completionDate == null'

recurring_reminder="$("$CALEN_BIN_PATH" reminders create \
  --title "$CALEN_PREFIX-recurring-reminder" \
  --list "$CALEN_LIST_A" \
  --due '2026-09-20 12:00' \
  --time-zone America/Edmonton \
  --repeat weekly \
  --repeat-on sun \
  --repeat-count 4 \
  --alarm-relative=-1h \
  --json)"
recurring_reminder_id="$(printf '%s' "$recurring_reminder" | jq -r '.value.identifier')"
check_json "recurring reminder persists recurrence and alarm" "$recurring_reminder" \
  '.value.recurrenceRules[0].end.occurrenceCount == 4
   and (.value.alarms | length) == 1'

expect_failure "recurring reminder without due date is rejected" \
  "$CALEN_BIN_PATH" reminders create \
  --title invalid --list "$CALEN_LIST_A" --repeat daily

expect_failure "invalid reminder priority is rejected" \
  "$CALEN_BIN_PATH" reminders create \
  --title invalid --list "$CALEN_LIST_A" --priority 10

empty_reminders="$("$CALEN_BIN_PATH" reminders search "$CALEN_PREFIX-missing" --json)"
check_json "empty reminder search is a JSON array" "$empty_reminders" 'length == 0'

expect_failure "reminder delete refuses noninteractive input without force" \
  "$CALEN_BIN_PATH" reminders delete "$reminder_id"

reminder_dry_delete="$("$CALEN_BIN_PATH" reminders delete \
  "$reminder_id" --dry-run --json)"
check_json "reminder delete dry-run keeps the reminder" "$reminder_dry_delete" \
  '.dryRun and .operation == "delete"'
"$CALEN_BIN_PATH" reminders show "$reminder_id" --json >/dev/null

reminder_delete="$("$CALEN_BIN_PATH" reminders delete \
  "$reminder_id" --force --json)"
check_json "forced reminder delete succeeds" "$reminder_delete" \
  '.operation == "delete" and .changed'
expect_failure "deleted reminder cannot be shown" \
  "$CALEN_BIN_PATH" reminders show "$reminder_id"

"$CALEN_BIN_PATH" reminders delete "$recurring_reminder_id" --force >/dev/null

"$CALEN_BIN_PATH" calendars delete "$CALEN_CALENDAR_A" --force >/dev/null
CALEN_CALENDAR_A=""
"$CALEN_BIN_PATH" calendars delete "$CALEN_CALENDAR_B" --force >/dev/null
CALEN_CALENDAR_B=""
"$CALEN_BIN_PATH" lists delete "$CALEN_LIST_A" --force >/dev/null
CALEN_LIST_A=""
"$CALEN_BIN_PATH" lists delete "$CALEN_LIST_B" --force >/dev/null
CALEN_LIST_B=""

remaining_events="$("$CALEN_BIN_PATH" events search "$CALEN_PREFIX" \
  --from 2026-09-01 --to 2026-10-01 --json)"
check_json "temporary event data is fully cleaned up" "$remaining_events" 'length == 0'

remaining_reminders="$("$CALEN_BIN_PATH" reminders search "$CALEN_PREFIX" --json)"
check_json "temporary reminder data is fully cleaned up" "$remaining_reminders" 'length == 0'

print "Installed binary E2E passed: $CALEN_CHECKS checks"
