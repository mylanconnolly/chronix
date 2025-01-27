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

Chronix provides a simple interface for parsing natural language date expressions. Here are some examples:

````elixir
# Future dates (two equivalent formats)
iex> Chronix.parse("in 2 minutes")
~U[2025-01-27 12:01:03Z]  # 2 minutes from now

iex> Chronix.parse("2 minutes from now")
~U[2025-01-27 12:01:03Z]  # same as above

iex> Chronix.parse("in 3 days")
~U[2025-01-30 11:59:03Z]  # 3 days from now

# Past dates
iex> Chronix.parse("2 hours ago")
~U[2025-01-27 09:59:03Z]  # 2 hours before now

# Weekday-based parsing
iex> Chronix.parse("next monday")
~U[2025-02-03 11:59:03Z]  # Next Monday

iex> Chronix.parse("last friday")
~U[2025-01-24 11:59:03Z]  # Previous Friday

# Using a reference date
iex> reference = ~U[2025-01-27 00:00:00Z]
iex> Chronix.parse("in 1 day", reference_date: reference)
~U[2025-01-28 00:00:00Z]

# Beginning and End of Durations

Chronix can parse expressions that refer to the beginning or end of a duration:

```elixir
# Beginning of durations
iex> Chronix.parse("beginning of 2 days from now")
~U[2025-01-29 00:00:00.000000Z]  # Start of the day, 2 days from now

iex> Chronix.parse("beginning of 1 week from now")
~U[2025-02-03 00:00:00.000000Z]  # Monday 00:00:00, start of next week

iex> Chronix.parse("beginning of 2 months from now")
~U[2025-03-01 00:00:00.000000Z]  # First day of the month, 2 months ahead

# End of durations
iex> Chronix.parse("end of 2 days from now")
~U[2025-01-29 23:59:59.999999Z]  # Last microsecond of the day

iex> Chronix.parse("end of 1 week from now")
~U[2025-02-09 23:59:59.999999Z]  # Sunday 23:59:59, end of next week

iex> Chronix.parse("end of 1 month from now")
~U[2025-02-28 23:59:59.999999Z]  # Last microsecond of the last day of next month

# With reference date
iex> reference = ~U[2025-01-01 12:30:45Z]
iex> Chronix.parse("beginning of 1 year from now", reference_date: reference)
~U[2026-01-01 00:00:00.000000Z]  # Start of next year
iex> Chronix.parse("end of 1 year from now", reference_date: reference)
~U[2026-12-31 23:59:59.999999Z]  # End of next year
````

Chronix supports various natural language formats:

- Future expressions: "in X minutes/hours/days/weeks/months/years" or "X minutes/hours/days/weeks/months/years from now"
- Past expressions: "X minutes/hours/days/weeks/months/years ago"
- Weekday expressions: "next monday", "last friday"
- Beginning and End of Durations: "beginning of X days/weeks/months/years from now", "end of X days/weeks/months/years from now"

These expressions are particularly useful when you need to:

- Get the start of a day/week/month/year for reporting periods
- Find the last moment of a time period for deadlines
- Work with precise time boundaries for scheduling

All parsing is case-insensitive and whitespace-tolerant.
