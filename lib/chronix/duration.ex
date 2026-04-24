defmodule Chronix.Duration do
  @moduledoc """
  Parses duration expressions into `{unit, n}` tuples suitable for
  `DateTime.shift/2`.
  """

  @weekdays %{
    "monday" => 1,
    "tuesday" => 2,
    "wednesday" => 3,
    "thursday" => 4,
    "friday" => 5,
    "saturday" => 6,
    "sunday" => 7
  }

  @units %{
    "second" => :second,
    "seconds" => :second,
    "minute" => :minute,
    "minutes" => :minute,
    "hour" => :hour,
    "hours" => :hour,
    "day" => :day,
    "days" => :day,
    "week" => :week,
    "weeks" => :week,
    "month" => :month,
    "months" => :month,
    "year" => :year,
    "years" => :year
  }

  @type unit :: :second | :minute | :hour | :day | :week | :month | :year
  @type duration :: {unit, integer}
  @type result :: {:ok, duration} | {:error, String.t()}

  @doc """
  Parses a duration string and returns `{:ok, {unit, n}}` or `{:error, reason}`.

  Supported formats:

  - `"in X units"` — future (e.g. `"in 2 seconds"`)
  - `"X units from now"` — future
  - `"X units ago"` — past
  - `"X units"` — future (bare form)
  - `"next monday"` / `"last friday"` — resolved to a `{:day, n}` shift
  - `"next week"` / `"last month"` / `"next year"` etc.

  Units accept singular or plural forms exactly (`second`/`seconds`, etc.).
  Numbers may include commas (`"1,000 seconds"`).

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
  @spec parse(String.t(), keyword) :: result
  def parse(str, opts \\ []) when is_binary(str) do
    str
    |> String.downcase()
    |> String.trim()
    |> do_parse(opts)
  end

  defp do_parse("next week", _opts), do: {:ok, {:week, 1}}
  defp do_parse("next month", _opts), do: {:ok, {:month, 1}}
  defp do_parse("next year", _opts), do: {:ok, {:year, 1}}
  defp do_parse("last week", _opts), do: {:ok, {:week, -1}}
  defp do_parse("last month", _opts), do: {:ok, {:month, -1}}
  defp do_parse("last year", _opts), do: {:ok, {:year, -1}}

  defp do_parse("next " <> weekday, opts) do
    with {:ok, target} <- lookup_weekday(weekday) do
      current = current_weekday(opts)
      days = if target <= current, do: 7 - current + target, else: target - current
      {:ok, {:day, days}}
    end
  end

  defp do_parse("last " <> weekday, opts) do
    with {:ok, target} <- lookup_weekday(weekday) do
      current = current_weekday(opts)
      days = if target >= current, do: -(7 - (target - current)), else: -(current - target)
      {:ok, {:day, days}}
    end
  end

  defp do_parse("in " <> rest, _opts) do
    case String.split(rest, " ") do
      [_num, _unit, "ago"] ->
        {:error, "cannot combine 'in' and 'ago'"}

      [num, unit, "from", "now"] ->
        build(num, unit, 1)

      [num, unit] ->
        build(num, unit, 1)

      _ ->
        {:error, "unsupported duration format: in #{rest}"}
    end
  end

  defp do_parse(str, _opts) do
    case String.split(str, " ") do
      [num, unit, "ago"] -> build(num, unit, -1)
      [num, unit, "from", "now"] -> build(num, unit, 1)
      [num, unit] -> build(num, unit, 1)
      _ -> {:error, "unsupported duration format: #{str}"}
    end
  end

  defp build(num_str, unit_str, sign) do
    with {:ok, n} <- parse_number(num_str),
         {:ok, u} <- parse_unit(unit_str) do
      {:ok, {u, n * sign}}
    end
  end

  defp parse_number(str) do
    cleaned = String.replace(str, ",", "")

    case Integer.parse(cleaned) do
      {n, ""} -> {:ok, n}
      _ -> {:error, "invalid number: #{str}"}
    end
  end

  defp parse_unit(str) do
    case Map.fetch(@units, str) do
      {:ok, u} -> {:ok, u}
      :error -> {:error, "unsupported unit: #{str}"}
    end
  end

  defp lookup_weekday(str) do
    case Map.fetch(@weekdays, str) do
      {:ok, n} -> {:ok, n}
      :error -> {:error, "unsupported weekday: #{str}"}
    end
  end

  defp current_weekday(opts) do
    opts
    |> Keyword.get(:reference_date, DateTime.utc_now())
    |> DateTime.to_date()
    |> Date.day_of_week()
  end
end
