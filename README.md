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

```elixir
# Future dates
iex> Chronix.parse("in 2 minutes")
~U[2025-01-27 12:57:37Z]  # 2 minutes from now

iex> Chronix.parse("in 3 days")
~U[2025-01-30 11:55:37Z]  # 3 days from now

# Past dates
iex> Chronix.parse("2 hours ago")
~U[2025-01-27 09:55:37Z]  # 2 hours before now

# Weekday-based parsing
iex> Chronix.parse("next monday")
~U[2025-02-03 11:55:37Z]  # Next Monday

iex> Chronix.parse("last friday")
~U[2025-01-24 11:55:37Z]  # Previous Friday

# Using a reference date
iex> reference = ~U[2025-01-27 00:00:00Z]
iex> Chronix.parse("in 1 day", reference_date: reference)
~U[2025-01-28 00:00:00Z]
```

Chronix supports various natural language formats:

- Future expressions: "in X minutes/hours/days/weeks/months/years"
- Past expressions: "X minutes/hours/days/weeks/months/years ago"
- Next weekday: "next monday/tuesday/etc."
- Previous weekday: "last monday/tuesday/etc."

All parsing is case-insensitive and whitespace-tolerant.
