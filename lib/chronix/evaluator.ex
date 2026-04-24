defmodule Chronix.Evaluator do
  @moduledoc """
  Resolves a Chronix AST (produced by `Chronix.Grammar.expression/1`)
  into a `DateTime` against a reference date.

  Callers typically go through `Chronix.Parser.parse_expression/2`, which
  handles string normalization and the `" at "` composition before
  invoking `resolve/2`.

  ## Error contract

  On failure this module returns `{:error, reason}` where `reason` is one
  of:

  - a binary — a fully-formatted user-facing error message
  - `:invalid_date` — sentinel indicating the evaluator parsed valid
    integers but the combination isn't a real calendar date; the façade
    wraps this with the original input string

  See the module docs on `Chronix.Grammar` for the AST node shapes this
  module dispatches on.
  """

  alias Chronix.Duration
  alias Chronix.Time, as: TimeParser

  @type opts :: keyword
  @type result :: {:ok, DateTime.t()} | {:error, term}

  @spec resolve(term, opts) :: result
  def resolve(ast, opts \\ [])

  # ── Reference-date literals ───────────────────────────────────────────

  def resolve(:now, opts), do: {:ok, ref(opts)}
  def resolve({:day_offset, n}, opts), do: {:ok, DateTime.shift(ref(opts), [{:day, n}])}
  def resolve({:this_period, _period}, opts), do: {:ok, ref(opts)}

  # ── Time-of-day pleonasms ─────────────────────────────────────────────

  def resolve(:tonight, opts), do: day_at(opts, 0, ~T[20:00:00.000000])
  def resolve(:last_night, opts), do: day_at(opts, -1, ~T[20:00:00.000000])

  def resolve({:this_tod, time}, opts), do: day_at(opts, 0, time)
  def resolve({:tomorrow_tod, time}, opts), do: day_at(opts, 1, time)
  def resolve({:yesterday_tod, time}, opts), do: day_at(opts, -1, time)

  # ── "at <time>" ───────────────────────────────────────────────────────

  def resolve({:at_time, [time_ast]}, opts) do
    case TimeParser.from_ast(time_ast) do
      {:ok, time} -> {:ok, set_time(ref(opts), time)}
      {:error, _} -> {:error, :invalid_time}
    end
  end

  # ── Explicit dates ────────────────────────────────────────────────────

  def resolve({:year_first_date, [year, month, day]}, _opts),
    do: build_date(year, month, day)

  def resolve({:year_last_date, [a, b, year]}, opts) do
    case Keyword.get(opts, :endian, :us) do
      :us ->
        build_date(year, a, b)

      :eu ->
        build_date(year, b, a)

      other ->
        {:error, "invalid :endian option: #{inspect(other)} (expected :us or :eu)"}
    end
  end

  # ── Boundaries ────────────────────────────────────────────────────────

  def resolve({:beginning_of, [duration_ast]}, opts) do
    with {:ok, duration} <- Duration.resolve(duration_ast, opts),
         :ok <- require_integer_boundary(duration) do
      shifted = apply_shift(ref(opts), duration)
      {:ok, beginning_of(shifted, duration)}
    end
  end

  def resolve({:end_of, [duration_ast]}, opts) do
    with {:ok, duration} <- Duration.resolve(duration_ast, opts),
         :ok <- require_integer_boundary(duration) do
      shifted = apply_shift(ref(opts), duration)
      {:ok, end_of(shifted, duration)}
    end
  end

  # ── Duration AST (standalone shift forms) ─────────────────────────────

  def resolve(:in_ago_error, opts), do: Duration.resolve(:in_ago_error, opts)

  def resolve({tag, _} = ast, opts)
      when tag in [
             :future_shift,
             :past_shift,
             :next_period,
             :last_period,
             :next_weekday,
             :last_weekday,
             :upcoming_weekday
           ] do
    case Duration.resolve(ast, opts) do
      {:ok, duration} -> {:ok, apply_shift(ref(opts), duration)}
      {:error, _} = err -> err
    end
  end

  # ── Bare time ─────────────────────────────────────────────────────────

  def resolve(:noon, opts), do: time_at_ref(:noon, opts)
  def resolve(:midnight, opts), do: time_at_ref(:midnight, opts)
  def resolve({:time_12h, _} = ast, opts), do: time_at_ref(ast, opts)
  def resolve({:time_24h, _} = ast, opts), do: time_at_ref(ast, opts)

  defp time_at_ref(ast, opts) do
    case TimeParser.from_ast(ast) do
      {:ok, time} -> {:ok, set_time(ref(opts), time)}
      {:error, _} -> {:error, :invalid_time}
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  defp ref(opts), do: Keyword.get(opts, :reference_date, DateTime.utc_now())

  defp day_at(opts, offset, time) do
    shifted = DateTime.shift(ref(opts), [{:day, offset}])
    {:ok, set_time(shifted, time)}
  end

  defp set_time(dt, %Time{hour: h, minute: m, second: s, microsecond: us}) do
    %{dt | hour: h, minute: m, second: s, microsecond: us}
  end

  defp build_date(year, month, day) do
    with {:ok, date} <- Date.new(year, month, day),
         {:ok, dt} <- DateTime.new(date, ~T[00:00:00], "Etc/UTC") do
      {:ok, dt}
    else
      _ -> {:error, :invalid_date}
    end
  end

  defp apply_shift(dt, {:microsecond, n}), do: DateTime.add(dt, n, :microsecond)
  defp apply_shift(dt, shift), do: DateTime.shift(dt, [shift])

  defp require_integer_boundary({:microsecond, _}),
    do: {:error, "'beginning of' and 'end of' require an integer duration"}

  defp require_integer_boundary(_), do: :ok

  # ── Boundary truncation ───────────────────────────────────────────────

  defp beginning_of(dt, {:second, _}), do: %{dt | microsecond: {0, 6}}
  defp beginning_of(dt, {:minute, _}), do: %{dt | second: 0, microsecond: {0, 6}}
  defp beginning_of(dt, {:hour, _}), do: %{dt | minute: 0, second: 0, microsecond: {0, 6}}

  defp beginning_of(dt, {:day, _}),
    do: %{dt | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}

  defp beginning_of(dt, {:week, _}) do
    dt
    |> DateTime.add(-((Date.day_of_week(dt) - 1) * 86_400), :second)
    |> then(&%{&1 | hour: 0, minute: 0, second: 0, microsecond: {0, 6}})
  end

  defp beginning_of(dt, {:month, _}),
    do: %{dt | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 6}}

  defp beginning_of(dt, {:year, _}),
    do: %{dt | month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 6}}

  defp end_of(dt, {:second, _}), do: %{dt | microsecond: {999_999, 6}}
  defp end_of(dt, {:minute, _}), do: %{dt | second: 59, microsecond: {999_999, 6}}
  defp end_of(dt, {:hour, _}), do: %{dt | minute: 59, second: 59, microsecond: {999_999, 6}}

  defp end_of(dt, {:day, _}),
    do: %{dt | hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}

  defp end_of(dt, {:week, _}) do
    dt
    |> DateTime.add((7 - Date.day_of_week(dt)) * 86_400, :second)
    |> then(&%{&1 | hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}})
  end

  defp end_of(dt, {:month, _}) do
    days_in_month = Calendar.ISO.days_in_month(dt.year, dt.month)
    %{dt | day: days_in_month, hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
  end

  defp end_of(dt, {:year, _}),
    do: %{dt | month: 12, day: 31, hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
end
