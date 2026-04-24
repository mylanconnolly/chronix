# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-24

Initial release. Natural-language date parser for Elixir, inspired by Ruby's
[Chronic](https://github.com/mojombo/chronic).

### Added

- `Chronix.parse/2` — returns `{:ok, DateTime.t()} | {:error, reason}`.
- `Chronix.parse!/2` — raises `ArgumentError` on failure.
- `Chronix.expression?/1` — boolean validity check, kept in sync with `parse/2`.
- `:reference_date` option — anchor for all relative expressions (including
  `"today"` and `"now"`). Defaults to `DateTime.utc_now/0`.
- `:endian` option — resolves ambiguous `mm/dd/yyyy` vs `dd/mm/yyyy` forms.
  Defaults to `:us`; pass `:eu` to flip.
- Supported expression forms:
  - Single-token: `now`, `today`, `tomorrow`, `yesterday`
  - Compound day aliases: `the day after tomorrow`, `the day before yesterday`
  - Relative durations: `in X <unit>`, `X <unit> from now`, `X <unit> ago`,
    bare `X <unit>`
  - Weekdays: `next monday`, `last friday`, `this monday`, `on monday`
  - Periods: `next week | next month | next year` (and `last ...`)
  - Pleonasms: `this week/month/year`, `this morning/afternoon/evening/night`,
    `tonight`, `last night`, and the full 12 combinations of
    `{today, tomorrow, yesterday} × {morning, afternoon, evening, night}`
  - Boundaries: `beginning of X`, `end of X`
  - Explicit dates: `mm/dd/yyyy`, `dd/mm/yyyy`, `mm-dd-yyyy`, `dd-mm-yyyy`,
    `yyyy-mm-dd`, `yyyy/mm/dd` (unpadded month/day accepted)
  - ISO-8601 timestamps: `2024-12-25T15:30:00Z`, offsets auto-converted to UTC
  - Word dates: `January 1, 2025`, `Jan 1 2025`, `1 Jan 2025`, `1st Jan 2025`,
    `the 15th of March 2024` (year optional — defaults to reference year)
  - Time-of-day: `noon`, `midnight`, `3pm`, `3 p.m.`, `3:15pm`, `15:30`,
    `15:30:45`
  - Combined date + time: `tomorrow at 3pm`, `next monday at noon`,
    `2024-12-25 at 3pm`, `the 15th of March at 9am`
- Supported units: `second`, `minute`, `hour`, `day`, `week`, `fortnight`
  (14 days), `month`, `quarter` (3 months), `year`, `decade` (10 years),
  `century` (100 years). Each accepts the plural form.
- Numeric words: `zero` through the tens, with compounds like `twenty one` or
  `thirty-five` — `in five days`, `twenty years ago`, etc.
- `a` / `an` as synonyms for `1` (`in a week`, `an hour ago`).
- Fractional durations for fixed-duration units (`in 1.5 hours`,
  `0.5 days ago`) converted internally to microseconds; fractional months and
  years are rejected.

[0.1.0]: https://github.com/mylanconnolly/chronix/releases/tag/v0.1.0
