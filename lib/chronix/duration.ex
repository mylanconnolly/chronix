defmodule Chronix.Duration do
  @moduledoc """
  Parses duration expressions into `{unit, n}` tuples suitable for
  `DateTime.shift/2`.

  Supported formats:

  - `"in X units"` — future (e.g. `"in 2 seconds"`)
  - `"X units from now"` — future
  - `"X units ago"` — past
  - `"X units"` — future (bare form)
  - `"next monday"` / `"last friday"` — resolved to a `{:day, n}` shift
  - `"this monday"` / `"on friday"` — upcoming including today
  - `"next week"` / `"last month"` / `"next year"` etc.

  Units accept singular or plural forms exactly (`second`/`seconds`, etc.).
  Extra units: `fortnight` (= 14 days), `quarter` (= 3 months),
  `decade` (= 10 years), `century` (= 100 years).

  Numbers may include commas (`"1,000 seconds"`) and may be fractional
  (`"in 1.5 hours"`). Fractional durations are internally converted to a
  `{:microsecond, n}` tuple; fractional months and years are rejected
  because they have no unambiguous conversion.

  Weekday expressions are resolved against `:reference_date`, which
  defaults to `DateTime.utc_now/0`.

  ## Examples

      iex> Chronix.Duration.parse("in 2 seconds")
      {:ok, {:second, 2}}

      iex> Chronix.Duration.parse("2 seconds ago")
      {:ok, {:second, -2}}

      iex> Chronix.Duration.parse("5 months from now")
      {:ok, {:month, 5}}

      iex> Chronix.Duration.parse("next monday", reference_date: ~U[2025-01-27 00:00:00Z])
      {:ok, {:day, 7}}

      iex> Chronix.Duration.parse("in 2 seconds ago")
      {:error, "cannot combine 'in' and 'ago'"}
  """

  alias Chronix.Grammar

  @type unit :: :second | :minute | :hour | :day | :week | :month | :year | :microsecond
  @type duration :: {unit, integer}
  @type result :: {:ok, duration} | {:error, String.t()}

  @spec parse(String.t(), keyword) :: result
  def parse(str, opts \\ []) when is_binary(str) do
    normalized = str |> String.downcase() |> String.trim()

    case Grammar.duration(normalized) do
      {:ok, [ast], _, _, _, _} ->
        resolve(ast, opts)

      {:error, {:chronix_error, reason}, _, _, _, _} ->
        {:error, reason}

      _ ->
        {:error, "unsupported duration format: #{normalized}"}
    end
  end

  # ── AST resolution ────────────────────────────────────────────────────

  @doc false
  @spec resolve(term, keyword) :: result
  def resolve(ast, opts \\ [])

  def resolve(:in_ago_error, _opts),
    do: {:error, "cannot combine 'in' and 'ago'"}

  def resolve({:next_period, [period]}, _opts), do: {:ok, {period, 1}}
  def resolve({:last_period, [period]}, _opts), do: {:ok, {period, -1}}

  def resolve({:next_weekday, [{:unknown_weekday, word}]}, _opts),
    do: {:error, "unsupported weekday: #{word}"}

  def resolve({:next_weekday, [weekday]}, opts) do
    target = weekday_num(weekday)
    current = current_weekday(opts)
    days = if target <= current, do: 7 - current + target, else: target - current
    {:ok, {:day, days}}
  end

  def resolve({:last_weekday, [{:unknown_weekday, word}]}, _opts),
    do: {:error, "unsupported weekday: #{word}"}

  def resolve({:last_weekday, [weekday]}, opts) do
    target = weekday_num(weekday)
    current = current_weekday(opts)
    days = if target >= current, do: -(7 - (target - current)), else: -(current - target)
    {:ok, {:day, days}}
  end

  def resolve({:upcoming_weekday, [{:unknown_weekday, word}]}, _opts),
    do: {:error, "unsupported weekday: #{word}"}

  def resolve({:upcoming_weekday, [weekday]}, opts) do
    target = weekday_num(weekday)
    current = current_weekday(opts)
    days = if target >= current, do: target - current, else: 7 - current + target
    {:ok, {:day, days}}
  end

  def resolve({:future_shift, [{:unknown_number, word}, _unit]}, _opts),
    do: {:error, "invalid number: #{word}"}

  def resolve({:future_shift, [_n, {:unknown_unit, word}]}, _opts),
    do: {:error, "unsupported unit: #{word}"}

  def resolve({:future_shift, [n, {unit, mult}]}, _opts),
    do: normalize(unit, n * mult)

  def resolve({:past_shift, [{:unknown_number, word}, _unit]}, _opts),
    do: {:error, "invalid number: #{word}"}

  def resolve({:past_shift, [_n, {:unknown_unit, word}]}, _opts),
    do: {:error, "unsupported unit: #{word}"}

  def resolve({:past_shift, [n, {unit, mult}]}, _opts),
    do: normalize(unit, -n * mult)

  # ── Number → integer/fractional normalization ─────────────────────────

  defp normalize(unit, n) when is_integer(n), do: {:ok, {unit, n}}

  defp normalize(unit, n) when is_float(n) do
    if n == Float.floor(n) do
      normalize(unit, trunc(n))
    else
      normalize_fractional(unit, n)
    end
  end

  defp normalize_fractional(:month, _),
    do: {:error, "fractional months are not supported"}

  defp normalize_fractional(:year, _),
    do: {:error, "fractional years are not supported"}

  defp normalize_fractional(unit, n),
    do: {:ok, {:microsecond, round(n * unit_in_microseconds(unit))}}

  defp unit_in_microseconds(:second), do: 1_000_000
  defp unit_in_microseconds(:minute), do: 60 * 1_000_000
  defp unit_in_microseconds(:hour), do: 3_600 * 1_000_000
  defp unit_in_microseconds(:day), do: 86_400 * 1_000_000
  defp unit_in_microseconds(:week), do: 7 * 86_400 * 1_000_000

  # ── Weekday resolution ────────────────────────────────────────────────

  defp weekday_num(:monday), do: 1
  defp weekday_num(:tuesday), do: 2
  defp weekday_num(:wednesday), do: 3
  defp weekday_num(:thursday), do: 4
  defp weekday_num(:friday), do: 5
  defp weekday_num(:saturday), do: 6
  defp weekday_num(:sunday), do: 7

  defp current_weekday(opts) do
    opts
    |> Keyword.get(:reference_date, DateTime.utc_now())
    |> DateTime.to_date()
    |> Date.day_of_week()
  end
end
