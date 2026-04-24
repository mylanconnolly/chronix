# Chronix

Chronix is a natural language date parser. It is heavily inspired by [Chronic](https://github.com/mojombo/chronic).

## Installation

Until a proper Hex package is available, you can add Chronix as a dependency in your `mix.exs`:

```elixir
def deps do
  [
    {:chronix, github: "mylanconnolly/chronix"}
  ]
end
```

## Usage

The main entry points are `Chronix.parse/2`, `Chronix.parse!/2`, and `Chronix.expression?/1`. All three share the same definition of "a valid Chronix expression."

- `parse/2` returns `{:ok, %DateTime{}}` on success or `{:error, reason}` on failure. It never raises.
- `parse!/2` returns the `DateTime` directly and raises `ArgumentError` on failure.
- `expression?/1` returns `true` if and only if `parse/2` would succeed on the same input.

```elixir
# Current dates (two equivalent formats)
iex> Chronix.parse("today")
{:ok, ~U[2025-01-27 11:59:03Z]}

iex> Chronix.parse("now")
{:ok, ~U[2025-01-27 11:59:03Z]}

# Future dates (two equivalent formats)
iex> Chronix.parse("in 2 minutes")
{:ok, ~U[2025-01-27 12:01:03Z]}  # 2 minutes from now

iex> Chronix.parse("2 minutes from now")
{:ok, ~U[2025-01-27 12:01:03Z]}  # same as above

iex> Chronix.parse("in 3 days")
{:ok, ~U[2025-01-30 11:59:03Z]}  # 3 days from now

# Past dates
iex> Chronix.parse("2 hours ago")
{:ok, ~U[2025-01-27 09:59:03Z]}  # 2 hours before now

# Weekday-based parsing
iex> Chronix.parse("next monday")
{:ok, ~U[2025-02-03 11:59:03Z]}  # Next Monday

iex> Chronix.parse("last friday")
{:ok, ~U[2025-01-24 11:59:03Z]}  # Previous Friday

# Using a reference date (applies to ALL relative expressions, including "today" / "now")
iex> reference = ~U[2025-01-27 00:00:00Z]
iex> Chronix.parse("in 1 day", reference_date: reference)
{:ok, ~U[2025-01-28 00:00:00Z]}
iex> Chronix.parse("today", reference_date: reference)
{:ok, ~U[2025-01-27 00:00:00Z]}

# Raising variant
iex> Chronix.parse!("in 1 day", reference_date: reference)
~U[2025-01-28 00:00:00Z]

# Validity check
iex> Chronix.expression?("in 3 days")
true
iex> Chronix.expression?("tomorrow")
false
```

## Beginning and End of Durations

Chronix can parse expressions that refer to the beginning or end of a duration:

```elixir
# Beginning of durations
iex> Chronix.parse("beginning of 2 days from now")
{:ok, ~U[2025-01-29 00:00:00.000000Z]}  # Start of the day, 2 days from now

iex> Chronix.parse("beginning of 1 week from now")
{:ok, ~U[2025-02-03 00:00:00.000000Z]}  # Monday 00:00:00, start of next week

iex> Chronix.parse("beginning of 2 months from now")
{:ok, ~U[2025-03-01 00:00:00.000000Z]}  # First day of the month, 2 months ahead

# End of durations
iex> Chronix.parse("end of 2 days from now")
{:ok, ~U[2025-01-29 23:59:59.999999Z]}  # Last microsecond of the day

iex> Chronix.parse("end of 1 week from now")
{:ok, ~U[2025-02-09 23:59:59.999999Z]}  # Sunday 23:59:59, end of next week

iex> Chronix.parse("end of 1 month from now")
{:ok, ~U[2025-02-28 23:59:59.999999Z]}  # Last microsecond of the last day of next month

# With reference date
iex> reference = ~U[2025-01-01 12:30:45Z]
iex> Chronix.parse("beginning of 1 year from now", reference_date: reference)
{:ok, ~U[2026-01-01 00:00:00.000000Z]}  # Start of next year
iex> Chronix.parse("end of 1 year from now", reference_date: reference)
{:ok, ~U[2026-12-31 23:59:59.999999Z]}  # End of next year
```

## Supported formats

- Single-token: `"now"`, `"today"`, `"tomorrow"`, `"yesterday"`
- Compound day aliases: `"the day after tomorrow"`, `"the day before yesterday"` (the word `"the"` is optional)
- Future: `"in X <unit>s"` or `"X <unit>s from now"`
- Past: `"X <unit>s ago"`
- Bare: `"X <unit>s"` (treated as future from the reference date)
- Weekday: `"next monday"`, `"last friday"`, etc.
- Period: `"next week" | "next month" | "next year"` (and `"last ..."`)
- Boundaries: `"beginning of ..."`, `"end of ..."` applied to any of the above
- Explicit dates: `mm/dd/yyyy`, `dd/mm/yyyy`, `mm-dd-yyyy`, `dd-mm-yyyy`, `yyyy-mm-dd`, `yyyy/mm/dd` (midnight UTC). Month and day components may be unpadded (`"1/5/2024"`, `"2024-1-5"`); year must be four digits. Ambiguous three-component forms default to US-style (month first); pass `endian: :eu` to flip that.
- ISO-8601 timestamps: `"2024-12-25T15:30:00Z"`, `"2024-12-25T15:30:00+02:00"`, `"2024-12-25T15:30:00.123456Z"`. Non-UTC offsets are converted to UTC. A bare space (`"2024-12-25 15:30:00Z"`) also works. A trailing offset is required — naive timestamps like `"2024-12-25T15:30:00"` are rejected (use `"2024-12-25 at 15:30"` instead).
- Time-of-day: `"noon"`, `"midnight"`, `"3pm"`, `"3 p.m."`, `"3:15pm"`, `"3:15:30pm"`, `"15:30"`, `"15:30:45"`. On its own, resolves to the reference date at that time.
- Combined date + time: any date expression followed by `" at "` and a time — `"tomorrow at 3pm"`, `"next monday at noon"`, `"2024-12-25 at 3pm"`, `"in 3 days at 8am"`. Bare `"at 3pm"` is shorthand for today at that time.

Supported units: `second`, `minute`, `hour`, `day`, `week`, `month`, `year` (each also accepts the plural).

Numbers may include commas for readability (`"in 1,000 seconds"`) and can be fractional for fixed-duration units (`"in 1.5 hours"`, `"0.5 days ago"`). Fractional months and years are rejected (no unambiguous conversion); `"beginning of"` / `"end of"` require integer durations. The words `"a"` and `"an"` are accepted as synonyms for `1` (`"in a week"`, `"an hour ago"`).

Parsing is case-insensitive and whitespace-tolerant. Contradictory phrases like `"in 2 seconds ago"` are rejected with `{:error, _}` rather than silently normalized.

## Reference date

All relative expressions — including `"today"` and `"now"` — are resolved against the `:reference_date` option. If omitted, Chronix uses `DateTime.utc_now/0`. Pinning the reference date is the right way to make tests deterministic:

```elixir
Chronix.parse("next monday", reference_date: ~U[2025-01-27 00:00:00Z])
```
