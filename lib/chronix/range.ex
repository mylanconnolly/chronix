defmodule Chronix.Range do
  @moduledoc """
  Resolves a Chronix expression into the inclusive `{start, finish}`
  interval it denotes. Prefer the top-level `Chronix.parse_range/2`.

  Accepts exactly the expressions `Chronix.parse/2` accepts and
  classifies each parsed AST into one of three interval shapes:

  - **Calendar periods** — `last/this/next week|month|year` expand to the
    full calendar bounds of that period relative to the reference date
    (ISO weeks run Monday through Sunday). Note that this differs from
    `Chronix.parse/2`, where `"this week"` resolves to the bare reference
    date: as a range it means the current week's calendar bounds.
  - **Whole days** — expressions that denote a day without a time-of-day:
    `today`, `yesterday`, `tomorrow`, day-offset aliases, explicit dates
    (`7/1/2026`, `2026-07-01`), word dates (`January 1, 2025`), weekday
    expressions (`next monday`), and relative shifts in day-or-coarser
    integer units (`3 days ago`, `in 2 weeks`). These expand from
    00:00:00.000000 to 23:59:59.999999 of the day the expression
    resolves to.
  - **Instants** — everything carrying a time-of-day or resolving to a
    point in time: `now`, `noon`, `3 hours ago`, `tomorrow at 3pm`,
    ISO-8601 timestamps, `beginning of`/`end of` boundaries, and
    fractional day-unit shifts (`1.5 days ago`). These become zero-width
    ranges `{instant, instant}`.

  The end of every non-instant range is the last representable microsecond
  of the period, matching the `"end of ..."` boundary semantics.

  All arithmetic happens in whatever time zone the reference date carries;
  callers are responsible for normalizing zones beforehand.
  """

  alias Chronix.{Evaluator, Grammar, Parser}

  @type t :: {DateTime.t(), DateTime.t()}
  @type result :: {:ok, t} | {:error, String.t()}

  # Units of a day or coarser, as they appear in the grammar's shift AST
  # (fortnight/quarter/decade/century arrive pre-mapped onto these).
  @day_or_coarser [:day, :week, :month, :year]

  @doc """
  Parses `date_string` and resolves it to an inclusive
  `{start, finish}` interval. See the module docs for the
  classification rules and `Chronix.parse_range/2` for examples.
  """
  @spec parse(String.t(), keyword) :: result
  def parse(date_string, opts \\ [])

  def parse(date_string, opts) when is_binary(date_string) do
    trimmed = String.trim(date_string)

    cond do
      trimmed == "" ->
        {:error, "empty expression"}

      true ->
        case DateTime.from_iso8601(trimmed) do
          {:ok, dt, _offset} -> {:ok, {dt, dt}}
          _ -> parse_relative(String.downcase(trimmed), opts)
        end
    end
  end

  def parse(_, _), do: {:error, "expected a string"}

  # ── After normalization ───────────────────────────────────────────────

  defp parse_relative(normalized, opts) do
    if String.contains?(normalized, " at ") do
      # A composed "<date> at <time>" always carries a time-of-day.
      instant(normalized, opts)
    else
      case Grammar.expression(normalized) do
        {:ok, [ast], _, _, _, _} ->
          resolve_range(ast, normalized, opts)

        _ ->
          # Delegate grammar failures so error messages stay identical
          # to Chronix.parse/2 (including its boundary-prefix fallbacks).
          instant(normalized, opts)
      end
    end
  end

  defp resolve_range(ast, normalized, opts) do
    case classify(ast) do
      {:calendar_period, period, offset} -> period_range(period, offset, opts)
      :whole_day -> whole_day(normalized, opts)
      :instant -> instant(normalized, opts)
    end
  end

  # ── AST classification ────────────────────────────────────────────────
  # Anything not explicitly a calendar period or a whole day falls through
  # to :instant, which delegates to the point parser — so every expression
  # parse/2 accepts also resolves here (and every error matches).

  defp classify({:this_period, period}), do: {:calendar_period, period, 0}
  defp classify({:next_period, [period]}), do: {:calendar_period, period, 1}
  defp classify({:last_period, [period]}), do: {:calendar_period, period, -1}

  defp classify({:day_offset, _}), do: :whole_day
  defp classify({:year_first_date, _}), do: :whole_day
  defp classify({:year_last_date, _}), do: :whole_day
  defp classify({:word_date_month_first, _}), do: :whole_day
  defp classify({:word_date_day_first, _}), do: :whole_day
  defp classify({:next_weekday, _}), do: :whole_day
  defp classify({:last_weekday, _}), do: :whole_day
  defp classify({:upcoming_weekday, _}), do: :whole_day

  defp classify({:future_shift, [n, {unit, _mult}]}) when unit in @day_or_coarser,
    do: shift_granularity(n)

  defp classify({:past_shift, [n, {unit, _mult}]}) when unit in @day_or_coarser,
    do: shift_granularity(n)

  defp classify(_), do: :instant

  # A day-or-coarser shift is a whole day only when the amount is integral;
  # fractional amounts ("1.5 days ago") carry sub-day precision.
  defp shift_granularity(n) when is_integer(n), do: :whole_day

  defp shift_granularity(n) when is_float(n) do
    if n == Float.floor(n), do: :whole_day, else: :instant
  end

  defp shift_granularity(_), do: :instant

  # ── Range construction ────────────────────────────────────────────────

  defp period_range(period, offset, opts) do
    ref = Keyword.get(opts, :reference_date, DateTime.utc_now())
    anchor = if offset == 0, do: ref, else: DateTime.shift(ref, [{period, offset}])
    {:ok, {Evaluator.beginning_of(anchor, {period, 1}), Evaluator.end_of(anchor, {period, 1})}}
  end

  defp whole_day(normalized, opts) do
    with {:ok, dt} <- Parser.parse_expression(normalized, opts) do
      {:ok, {Evaluator.beginning_of(dt, {:day, 1}), Evaluator.end_of(dt, {:day, 1})}}
    end
  end

  defp instant(normalized, opts) do
    with {:ok, dt} <- Parser.parse_expression(normalized, opts) do
      {:ok, {dt, dt}}
    end
  end
end
