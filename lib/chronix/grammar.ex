defmodule Chronix.Grammar do
  @moduledoc """
  NimbleParsec grammar for Chronix expressions.

  This module compiles into the core parsers used by `Chronix.Time`,
  `Chronix.Duration`, and `Chronix.Parser`. Each of those modules is a
  thin façade that invokes a `defparsec` defined here and post-processes
  the AST for its own public contract via `Chronix.Evaluator`.

  The public API remains on the façade modules; nothing here is intended
  for direct use by callers of Chronix.

  ## AST shapes

  Time (`:time`):
  - `:noon`, `:midnight`
  - `{:time_12h, keyword_list}` — e.g. `[hour: 3, minute: 15, meridiem: :pm]`
  - `{:time_24h, keyword_list}` — e.g. `[hour: 15, minute: 30, second: 45]`

  Duration (`:duration`):
  - `{:future_shift, [number, {base_unit, multiplier}]}`
  - `{:past_shift, [number, {base_unit, multiplier}]}`
  - `{:next_period, [:week | :month | :year]}`
  - `{:last_period, [:week | :month | :year]}`
  - `{:next_weekday, [atom | {:unknown_weekday, str}]}`
  - `{:last_weekday, [atom | {:unknown_weekday, str}]}`
  - `{:upcoming_weekday, [atom | {:unknown_weekday, str}]}` — `this`/`on`
  - `:in_ago_error`
  - Inside shifts, unknown numbers/units: `{:unknown_number, str}`, `{:unknown_unit, str}`

  Expression (`:expression`):
  - `:now` — today/now
  - `{:day_offset, n}` — tomorrow/yesterday/day-after/day-before
  - `{:this_period, :week | :month | :year}`
  - `:tonight`, `:last_night`
  - `{:this_tod, %Time{}}`, `{:tomorrow_tod, %Time{}}`, `{:yesterday_tod, %Time{}}`
  - `{:at_time, [time_ast]}`
  - `{:year_first_date, [year, month, day]}`
  - `{:year_last_date, [a, b, year]}`
  - `{:beginning_of, [duration_ast]}`, `{:end_of, [duration_ast]}`
  - Duration and Time AST shapes (passed through)

  Custom errors from `post_traverse` are wrapped as `{:chronix_error, reason}`
  to distinguish them from generic grammar-mismatch failures.
  """

  import NimbleParsec

  # ── Basic helpers ─────────────────────────────────────────────────────
  ws1 = ignore(ascii_string([?\s], min: 1))
  ws = ignore(ascii_string([?\s], min: 0))
  word_end = lookahead_not(ascii_char([?a..?z]))

  # ── Numbers ───────────────────────────────────────────────────────────
  number_string =
    ascii_string([?0..?9, ?,, ?.], min: 1)
    |> post_traverse({__MODULE__, :parse_number_string, []})

  # Single-word numbers: teens, tens, and ones. Ordered longest-prefix-first
  # within each starting letter so shorter alternatives don't steal the match
  # (e.g. "seventeen" before "seventy" before "seven").
  single_word_number =
    choice([
      replace(string("seventeen"), 17),
      replace(string("fourteen"), 14),
      replace(string("thirteen"), 13),
      replace(string("eighteen"), 18),
      replace(string("nineteen"), 19),
      replace(string("fifteen"), 15),
      replace(string("sixteen"), 16),
      replace(string("seventy"), 70),
      replace(string("twenty"), 20),
      replace(string("eighty"), 80),
      replace(string("ninety"), 90),
      replace(string("thirty"), 30),
      replace(string("eleven"), 11),
      replace(string("twelve"), 12),
      replace(string("forty"), 40),
      replace(string("fifty"), 50),
      replace(string("sixty"), 60),
      replace(string("three"), 3),
      replace(string("seven"), 7),
      replace(string("eight"), 8),
      replace(string("four"), 4),
      replace(string("five"), 5),
      replace(string("nine"), 9),
      replace(string("zero"), 0),
      replace(string("one"), 1),
      replace(string("two"), 2),
      replace(string("six"), 6),
      replace(string("ten"), 10)
    ])
    |> concat(word_end)

  tens_word =
    choice([
      replace(string("seventy"), 70),
      replace(string("twenty"), 20),
      replace(string("eighty"), 80),
      replace(string("ninety"), 90),
      replace(string("thirty"), 30),
      replace(string("forty"), 40),
      replace(string("fifty"), 50),
      replace(string("sixty"), 60)
    ])
    |> concat(word_end)

  singles_word =
    choice([
      replace(string("three"), 3),
      replace(string("seven"), 7),
      replace(string("eight"), 8),
      replace(string("four"), 4),
      replace(string("five"), 5),
      replace(string("nine"), 9),
      replace(string("one"), 1),
      replace(string("two"), 2),
      replace(string("six"), 6)
    ])
    |> concat(word_end)

  # "twenty one" or "twenty-one" → 21
  compound_word_number =
    tens_word
    |> ignore(choice([ascii_string([?\s], min: 1), string("-")]))
    |> concat(singles_word)
    |> post_traverse({__MODULE__, :sum_compound_number, []})

  # Compound first so "twenty one" doesn't stop at "twenty".
  word_number = choice([compound_word_number, single_word_number])

  unknown_number =
    ascii_string([?a..?z], min: 1)
    |> unwrap_and_tag(:unknown_number)

  number =
    choice([
      number_string,
      word_number,
      replace(string("an"), 1) |> concat(word_end),
      replace(string("a"), 1) |> concat(word_end),
      unknown_number
    ])

  # ── Units ─────────────────────────────────────────────────────────────
  valid_unit =
    choice([
      # Plurals first so "seconds" matches before "second" stops at "s"
      replace(string("seconds"), {:second, 1}),
      replace(string("minutes"), {:minute, 1}),
      replace(string("hours"), {:hour, 1}),
      replace(string("days"), {:day, 1}),
      replace(string("weeks"), {:week, 1}),
      replace(string("fortnights"), {:day, 14}),
      replace(string("months"), {:month, 1}),
      replace(string("quarters"), {:month, 3}),
      replace(string("years"), {:year, 1}),
      replace(string("decades"), {:year, 10}),
      replace(string("centuries"), {:year, 100}),
      replace(string("second"), {:second, 1}),
      replace(string("minute"), {:minute, 1}),
      replace(string("hour"), {:hour, 1}),
      replace(string("day"), {:day, 1}),
      replace(string("week"), {:week, 1}),
      replace(string("fortnight"), {:day, 14}),
      replace(string("month"), {:month, 1}),
      replace(string("quarter"), {:month, 3}),
      replace(string("year"), {:year, 1}),
      replace(string("decade"), {:year, 10}),
      replace(string("century"), {:year, 100})
    ])
    |> concat(word_end)

  unknown_unit =
    ascii_string([?a..?z], min: 1)
    |> unwrap_and_tag(:unknown_unit)

  unit = choice([valid_unit, unknown_unit])

  # ── Periods ───────────────────────────────────────────────────────────
  valid_period =
    choice([
      replace(string("week"), :week),
      replace(string("month"), :month),
      replace(string("year"), :year)
    ])
    |> concat(word_end)

  # ── Weekdays ──────────────────────────────────────────────────────────
  valid_weekday =
    choice([
      replace(string("monday"), :monday),
      replace(string("tuesday"), :tuesday),
      replace(string("wednesday"), :wednesday),
      replace(string("thursday"), :thursday),
      replace(string("friday"), :friday),
      replace(string("saturday"), :saturday),
      replace(string("sunday"), :sunday)
    ])
    |> concat(word_end)

  unknown_weekday =
    ascii_string([?a..?z], min: 1)
    |> unwrap_and_tag(:unknown_weekday)

  weekday = choice([valid_weekday, unknown_weekday])

  # ── Time-of-day combinators (reusable) ────────────────────────────────
  hour = unwrap_and_tag(integer(min: 1, max: 2), :hour)
  minute = unwrap_and_tag(integer(2), :minute)
  second = unwrap_and_tag(integer(2), :second)

  meridiem =
    unwrap_and_tag(
      choice([
        replace(string("a.m."), :am),
        replace(string("p.m."), :pm),
        replace(string("am"), :am),
        replace(string("pm"), :pm)
      ]),
      :meridiem
    )

  noon = replace(string("noon"), :noon)
  midnight = replace(string("midnight"), :midnight)

  time_12h =
    hour
    |> optional(
      ignore(string(":"))
      |> concat(minute)
      |> optional(ignore(string(":")) |> concat(second))
    )
    |> concat(ws)
    |> concat(meridiem)
    |> tag(:time_12h)

  time_24h =
    hour
    |> ignore(string(":"))
    |> concat(minute)
    |> optional(ignore(string(":")) |> concat(second))
    |> tag(:time_24h)

  time_combinator = choice([noon, midnight, time_12h, time_24h])

  # ── Duration forms (reusable) ─────────────────────────────────────────
  duration_amount =
    number
    |> concat(ws1)
    |> concat(unit)

  in_form =
    ignore(string("in"))
    |> concat(ws1)
    |> concat(duration_amount)
    |> optional(
      ws1
      |> ignore(string("from"))
      |> concat(ws1)
      |> ignore(string("now"))
    )

  from_now_form =
    duration_amount
    |> concat(ws1)
    |> ignore(string("from"))
    |> concat(ws1)
    |> ignore(string("now"))

  bare_form = duration_amount

  ago_form =
    duration_amount
    |> concat(ws1)
    |> ignore(string("ago"))

  past_shift = ago_form |> tag(:past_shift)
  future_shift = choice([in_form, from_now_form, bare_form]) |> tag(:future_shift)

  in_ago_error =
    ignore(string("in"))
    |> concat(ws1)
    |> ignore(number)
    |> concat(ws1)
    |> ignore(unit)
    |> concat(ws1)
    |> ignore(string("ago"))
    |> replace(:in_ago_error)

  next_period =
    ignore(string("next"))
    |> concat(ws1)
    |> concat(valid_period)
    |> tag(:next_period)

  last_period =
    ignore(string("last"))
    |> concat(ws1)
    |> concat(valid_period)
    |> tag(:last_period)

  next_weekday =
    ignore(string("next"))
    |> concat(ws1)
    |> concat(weekday)
    |> tag(:next_weekday)

  last_weekday =
    ignore(string("last"))
    |> concat(ws1)
    |> concat(weekday)
    |> tag(:last_weekday)

  this_weekday =
    ignore(string("this"))
    |> concat(ws1)
    |> concat(weekday)
    |> tag(:upcoming_weekday)

  on_weekday =
    ignore(string("on"))
    |> concat(ws1)
    |> concat(weekday)
    |> tag(:upcoming_weekday)

  duration_combinator =
    choice([
      in_ago_error,
      next_period,
      last_period,
      next_weekday,
      last_weekday,
      this_weekday,
      on_weekday,
      past_shift,
      future_shift
    ])

  # ── Expression-level literals ─────────────────────────────────────────
  literal_now =
    choice([string("today"), string("now")])
    |> replace(:now)
    |> concat(word_end)

  literal_tomorrow =
    string("tomorrow")
    |> replace({:day_offset, 1})
    |> concat(word_end)

  literal_yesterday =
    string("yesterday")
    |> replace({:day_offset, -1})
    |> concat(word_end)

  literal_day_after_tomorrow =
    choice([
      string("the day after tomorrow"),
      string("day after tomorrow")
    ])
    |> replace({:day_offset, 2})
    |> concat(word_end)

  literal_day_before_yesterday =
    choice([
      string("the day before yesterday"),
      string("day before yesterday")
    ])
    |> replace({:day_offset, -2})
    |> concat(word_end)

  # ── Pleonasm time-of-day words ────────────────────────────────────────
  tod_word =
    choice([
      replace(string("morning"), ~T[09:00:00.000000]),
      replace(string("afternoon"), ~T[15:00:00.000000]),
      replace(string("evening"), ~T[19:00:00.000000]),
      replace(string("night"), ~T[20:00:00.000000])
    ])

  this_tod =
    ignore(string("this"))
    |> concat(ws1)
    |> concat(tod_word)
    |> concat(word_end)
    |> unwrap_and_tag(:this_tod)

  tomorrow_tod =
    ignore(string("tomorrow"))
    |> concat(ws1)
    |> concat(tod_word)
    |> concat(word_end)
    |> unwrap_and_tag(:tomorrow_tod)

  yesterday_tod =
    ignore(string("yesterday"))
    |> concat(ws1)
    |> concat(tod_word)
    |> concat(word_end)
    |> unwrap_and_tag(:yesterday_tod)

  tonight =
    string("tonight")
    |> replace(:tonight)
    |> concat(word_end)

  last_night =
    string("last night")
    |> replace(:last_night)
    |> concat(word_end)

  # ── "this week/month/year" ────────────────────────────────────────────
  this_period_word =
    choice([
      replace(string("week"), :week),
      replace(string("month"), :month),
      replace(string("year"), :year)
    ])
    |> concat(word_end)

  this_period_alias =
    ignore(string("this"))
    |> concat(ws1)
    |> concat(this_period_word)
    |> unwrap_and_tag(:this_period)

  # ── "at <time>" ───────────────────────────────────────────────────────
  at_time_prefix =
    ignore(string("at"))
    |> concat(ws1)
    |> concat(time_combinator)
    |> tag(:at_time)

  # ── Month names ───────────────────────────────────────────────────────
  # Ordered by length descending so longer names match before their
  # 3-letter abbreviations (january before jan, etc.). "may" is both the
  # full name and the abbreviation, listed once.
  month_name =
    choice([
      replace(string("september"), 9),
      replace(string("february"), 2),
      replace(string("december"), 12),
      replace(string("november"), 11),
      replace(string("january"), 1),
      replace(string("october"), 10),
      replace(string("august"), 8),
      replace(string("march"), 3),
      replace(string("april"), 4),
      replace(string("july"), 7),
      replace(string("june"), 6),
      replace(string("may"), 5),
      replace(string("jan"), 1),
      replace(string("feb"), 2),
      replace(string("mar"), 3),
      replace(string("apr"), 4),
      replace(string("jun"), 6),
      replace(string("jul"), 7),
      replace(string("aug"), 8),
      replace(string("sep"), 9),
      replace(string("oct"), 10),
      replace(string("nov"), 11),
      replace(string("dec"), 12)
    ])
    |> concat(word_end)

  # ── Ordinals ──────────────────────────────────────────────────────────
  ordinal_suffix =
    choice([
      string("st"),
      string("nd"),
      string("rd"),
      string("th")
    ])
    |> concat(word_end)

  ordinal_day =
    integer(min: 1, max: 2)
    |> ignore(optional(ordinal_suffix))

  # Date separator: comma (with optional following space) or whitespace.
  date_sep =
    choice([
      ignore(string(",")) |> concat(ws),
      ws1
    ])

  # ── Word date forms ───────────────────────────────────────────────────
  # "January 1", "January 1 2025", "January 1, 2025", "Jan 1st 2025"
  month_first_word_date =
    month_name
    |> concat(ws1)
    |> concat(ordinal_day)
    |> optional(concat(date_sep, integer(4)))
    |> tag(:word_date_month_first)

  # "1 January", "1 Jan 2025", "1st Jan, 2025"
  day_first_word_date =
    ordinal_day
    |> concat(ws1)
    |> concat(month_name)
    |> optional(concat(date_sep, integer(4)))
    |> tag(:word_date_day_first)

  # "the 1st of January", "the 1st of January 2025"
  ordinal_of_month =
    ignore(string("the"))
    |> concat(ws1)
    |> concat(ordinal_day)
    |> concat(ws1)
    |> ignore(string("of"))
    |> concat(ws1)
    |> concat(month_name)
    |> optional(concat(date_sep, integer(4)))
    |> tag(:word_date_day_first)

  word_date = choice([month_first_word_date, day_first_word_date, ordinal_of_month])

  # ── Explicit date forms ───────────────────────────────────────────────
  year_first_dash =
    integer(4)
    |> ignore(string("-"))
    |> integer(min: 1, max: 2)
    |> ignore(string("-"))
    |> integer(min: 1, max: 2)
    |> tag(:year_first_date)

  year_first_slash =
    integer(4)
    |> ignore(string("/"))
    |> integer(min: 1, max: 2)
    |> ignore(string("/"))
    |> integer(min: 1, max: 2)
    |> tag(:year_first_date)

  year_last_slash =
    integer(min: 1, max: 2)
    |> ignore(string("/"))
    |> integer(min: 1, max: 2)
    |> ignore(string("/"))
    |> integer(4)
    |> tag(:year_last_date)

  year_last_dash =
    integer(min: 1, max: 2)
    |> ignore(string("-"))
    |> integer(min: 1, max: 2)
    |> ignore(string("-"))
    |> integer(4)
    |> tag(:year_last_date)

  date_form =
    choice([year_first_dash, year_first_slash, year_last_slash, year_last_dash])

  # ── Boundaries ────────────────────────────────────────────────────────
  boundary_beginning =
    ignore(string("beginning of"))
    |> concat(ws1)
    |> concat(duration_combinator)
    |> tag(:beginning_of)

  boundary_end =
    ignore(string("end of"))
    |> concat(ws1)
    |> concat(duration_combinator)
    |> tag(:end_of)

  # ── Expression (top-level) ────────────────────────────────────────────
  # Ordering matters: longer/more-specific literals before shorter ones;
  # duration_combinator before bare time_combinator (digits disambiguate).
  expression =
    choice([
      boundary_beginning,
      boundary_end,
      tonight,
      last_night,
      this_period_alias,
      this_tod,
      tomorrow_tod,
      yesterday_tod,
      literal_day_after_tomorrow,
      literal_day_before_yesterday,
      literal_tomorrow,
      literal_yesterday,
      literal_now,
      at_time_prefix,
      date_form,
      word_date,
      duration_combinator,
      time_combinator
    ])
    |> eos()

  # ── Public parsers ────────────────────────────────────────────────────
  defparsec :time, time_combinator |> eos()
  defparsec :duration, duration_combinator |> eos()
  defparsec :expression, expression

  # ── Post-traverse helpers ─────────────────────────────────────────────
  @doc false
  def parse_number_string(rest, [str], context, _line, _offset) do
    cleaned =
      str
      |> String.replace(",", "")
      |> ensure_leading_zero()

    cond do
      String.contains?(cleaned, ".") ->
        case Float.parse(cleaned) do
          {n, ""} -> {rest, [n], context}
          _ -> {:error, {:chronix_error, "invalid number: #{str}"}}
        end

      true ->
        case Integer.parse(cleaned) do
          {n, ""} -> {rest, [n], context}
          _ -> {:error, {:chronix_error, "invalid number: #{str}"}}
        end
    end
  end

  defp ensure_leading_zero("." <> _ = s), do: "0" <> s
  defp ensure_leading_zero(s), do: s

  @doc false
  def sum_compound_number(rest, [singles, tens], context, _line, _offset) do
    {rest, [tens + singles], context}
  end
end
