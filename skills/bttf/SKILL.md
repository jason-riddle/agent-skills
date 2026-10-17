---
name: bttf
description: >
  Use this skill whenever the user wants to run the `bttf` command or work
  with date/time parsing, arithmetic, formatting, recurrence, or time-zone
  conversion using bttf. Trigger for requests to convert a timestamp between
  zones, calculate or compare dates, format timestamps, inspect time-zone
  transitions, process timestamped logs, or generate schedules.
---

# bttf date and time operations

Use the installed `bttf` CLI for date/time parsing, arithmetic, formatting,
recurrence, and time-zone work. Check `bttf --version` and use
`bttf <command> --help` when syntax or behavior is uncertain. The README and
user guide are at https://github.com/BurntSushi/bttf.

## Core workflow

1. Preserve the meaning of the input. For a known instant, prefer an
   RFC 3339 timestamp with an explicit offset, or RFC 9557 with an IANA zone.
   Ask for clarification rather than guessing if a local wall time is
   ambiguous or has no offset.
2. Choose the subcommand: `time in` for zone conversion, `time add` for
   arithmetic, `time fmt` for display, `time seq` for recurrence, `span` for
   elapsed durations, and `tz` for zone lists and transitions.
3. Use IANA identifiers such as `America/Los_Angeles` and `Asia/Tokyo` for
   regions with daylight-saving rules. Use `UTC` for the UTC zone.
4. Verify the output zone, offset, date rollover, and requested precision.
   Preserve machine-readable RFC 3339/RFC 9557 output when downstream tools
   will consume the result.

## Time-zone conversion

`bttf time in` accepts the zone followed by one or more datetimes, or a
datetime followed by one or more zones. These forms are equivalent for one
input and one output zone:

```sh
bttf time in America/Los_Angeles 2026-10-17T12:00:00Z
bttf time in 2026-10-17T12:00:00Z America/Los_Angeles
```

Convert one instant to several zones:

```sh
bttf time in 2026-10-17T12:00:00Z America/Los_Angeles Asia/Tokyo
```

Convert newline-delimited timestamps from a pipeline:

```sh
printf '%s\n' 2026-10-17T12:00:00Z 2026-10-18T12:00:00Z \
  | bttf time in America/Los_Angeles \
  | bttf time fmt -f '%Y-%m-%d %H:%M %Z (%:z)'
```

For recurring local schedules, set `TZ` on the `bttf` process so recurrence
is generated in the intended zone; converting a UTC recurrence afterward
does not preserve a fixed local clock time across daylight-saving changes:

```sh
TZ=America/Los_Angeles bttf time seq weekly -c 4 -w mon -H 9 today
```

## Other useful patterns

```sh
# Format as an RFC 3339 timestamp or a readable local-zone string.
bttf time fmt -f rfc3339 now
bttf time fmt -f '%A %Y-%m-%d %H:%M:%S %Z %:z' now

# Add a duration to an explicit instant.
bttf time add 90m 2026-10-17T12:00:00Z

# Compare, sort, round, or generate recurrences.
bttf time cmp gt 2026-10-17T12:00:00Z now
bttf time round -s minute -i 15 now
bttf time seq daily -c 5 -H 9 -w mon..fri 2026-10-19

# Explore named zones and transitions.
bttf tz list
bttf tz next --help

# Extract timestamp tags from log lines, convert, format, and substitute.
bttf tag lines access.log \
  | bttf time in system \
  | bttf time fmt -f '%Y-%m-%d %H:%M:%S %Z' \
  | bttf untag -s
```

## Gotchas

- `bttf` is not a drop-in replacement for POSIX `date`; its syntax and
  behavior are intentionally different.
- Local dates/times without an offset or zone are interpreted in the
  configured system zone (or `TZ`). Use an explicit offset for an
  unambiguous instant.
- `now`, relative values, and shorthand dates depend on runtime time and zone.
  Capture exact input values for reproducible calculations.
- RFC 3339 preserves the offset but not the IANA zone identity. Use RFC 9557
  when the named zone matters.
- A sequence is generated in the process's configured zone. Set `TZ` before
  generating wall-clock schedules intended for a region.
