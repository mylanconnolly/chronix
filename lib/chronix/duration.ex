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
    "second" => {:second, 1},
    "seconds" => {:second, 1},
    "minute" => {:minute, 1},
    "minutes" => {:minute, 1},
    "hour" => {:hour, 1},
    "hours" => {:hour, 1},
    "day" => {:day, 1},
    "days" => {:day, 1},
    "week" => {:week, 1},
    "weeks" => {:week, 1},
    "fortnight" => {:day, 14},
    "fortnights" => {:day, 14},
    "month" => {:month, 1},
    "months" => {:month, 1},
    "quarter" => {:month, 3},
    "quarters" => {:month, 3},
    "year" => {:year, 1},
    "years" => {:year, 1},
    "decade" => {:year, 10},
    "decades" => {:year, 10},
    "century" => {:year, 100},
    "centuries" => {:year, 100}
  }

  @type unit :: :second | :minute | :hour | :day | :week | :month | :year | :microsecond
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

  defp do_parse("this " <> weekday, opts), do: upcoming_weekday(weekday, opts)
  defp do_parse("on " <> weekday, opts), do: upcoming_weekday(weekday, opts)

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

  defp upcoming_weekday(weekday, opts) do
    with {:ok, target} <- lookup_weekday(weekday) do
      current = current_weekday(opts)
      days = if target >= current, do: target - current, else: 7 - current + target
      {:ok, {:day, days}}
    end
  end

  defp build(num_str, unit_str, sign) do
    with {:ok, n} <- parse_number(num_str),
         {:ok, {u, mult}} <- parse_unit(unit_str) do
      normalize(u, n * sign * mult)
    end
  end

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

  defp normalize_fractional(unit, n) do
    {:ok, {:microsecond, round(n * unit_in_microseconds(unit))}}
  end

  defp unit_in_microseconds(:second), do: 1_000_000
  defp unit_in_microseconds(:minute), do: 60 * 1_000_000
  defp unit_in_microseconds(:hour), do: 3_600 * 1_000_000
  defp unit_in_microseconds(:day), do: 86_400 * 1_000_000
  defp unit_in_microseconds(:week), do: 7 * 86_400 * 1_000_000

  defp parse_number("a"), do: {:ok, 1}
  defp parse_number("an"), do: {:ok, 1}

  defp parse_number(str) do
    cleaned = str |> String.replace(",", "") |> leading_zero()

    cond do
      String.contains?(cleaned, ".") ->
        case Float.parse(cleaned) do
          {n, ""} -> {:ok, n}
          _ -> {:error, "invalid number: #{str}"}
        end

      true ->
        case Integer.parse(cleaned) do
          {n, ""} -> {:ok, n}
          _ -> {:error, "invalid number: #{str}"}
        end
    end
  end

  defp leading_zero("." <> _ = s), do: "0" <> s
  defp leading_zero(s), do: s

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
