defmodule Chronix.Duration do
  @moduledoc """
  Handles parsing of duration strings into structured data.
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

  @doc """
  Parses a duration string into a tuple of {unit, value}.

  Currently supports the formats:
  - "in X units" - for future durations (e.g., "in 2 seconds")
  - "X units from now" - alternative future format (e.g., "2 seconds from now")
  - "X units ago" - for past durations (e.g., "2 seconds ago")
  - "next <weekday>" - for next occurrence of weekday (e.g., "next monday")
  - "last <weekday>" - for previous occurrence of weekday (e.g., "last monday")
  - "next week/month/year" - for next time period
  - "last week/month/year" - for previous time period

  where units can be:
  - seconds
  - minutes
  - hours
  - days
  - weeks
  - months
  - years

  Numbers can include commas for readability (e.g., "1,000 seconds ago").

  ## Examples

      iex> Chronix.Duration.parse("in 2 seconds")
      {:second, 2}

      iex> Chronix.Duration.parse("2 seconds from now")
      {:second, 2}

      iex> Chronix.Duration.parse("in 5 months")
      {:month, 5}

      iex> Chronix.Duration.parse("2 seconds ago")
      {:second, -2}

      iex> Chronix.Duration.parse("5 months ago")
      {:month, -5}

      iex> Chronix.Duration.parse("next monday", reference_date: ~U[2025-01-27 00:00:00Z])
      {:day, 7}

      iex> Chronix.Duration.parse("last monday", reference_date: ~U[2025-01-27 00:00:00Z])
      {:day, -7}

      iex> Chronix.Duration.parse("next week")
      {:week, 1}

      iex> Chronix.Duration.parse("last month")
      {:month, -1}
  """
  def parse(str, opts \\ [])

  def parse("next " <> period, _opts) when period in ["week", "month", "year"] do
    unit = String.to_atom(period)
    {unit, 1}
  end

  def parse("last " <> period, _opts) when period in ["week", "month", "year"] do
    unit = String.to_atom(period)
    {unit, -1}
  end

  def parse("last " <> weekday, opts) do
    ref_date = Keyword.get(opts, :reference_date, DateTime.utc_now())
    weekday = String.downcase(weekday)

    unless Map.has_key?(@weekdays, weekday) do
      raise ArgumentError, "unsupported weekday: #{weekday}"
    end

    target_day = @weekdays[weekday]
    current_day = Date.day_of_week(DateTime.to_date(ref_date))

    days_ago =
      if target_day >= current_day do
        -(7 - (target_day - current_day))
      else
        -(current_day - target_day)
      end

    {:day, days_ago}
  end

  def parse("next " <> weekday, opts) do
    ref_date = Keyword.get(opts, :reference_date, DateTime.utc_now())
    weekday = String.downcase(weekday)

    unless Map.has_key?(@weekdays, weekday) do
      raise ArgumentError, "unsupported weekday: #{weekday}"
    end

    target_day = @weekdays[weekday]
    current_day = Date.day_of_week(DateTime.to_date(ref_date))

    days_until =
      if target_day <= current_day do
        7 - current_day + target_day
      else
        target_day - current_day
      end

    {:day, days_until}
  end

  def parse("in " <> rest, _opts) do
    [number_str, unit] = String.split(rest, " ", parts: 2)

    number =
      number_str
      |> String.replace(",", "")
      |> String.to_integer()

    unit =
      case String.downcase(unit) do
        "second" <> _ -> :second
        "minute" <> _ -> :minute
        "hour" <> _ -> :hour
        "day" <> _ -> :day
        "week" <> _ -> :week
        "month" <> _ -> :month
        "year" <> _ -> :year
        _ -> raise ArgumentError, "unsupported unit: #{unit}"
      end

    {unit, number}
  end

  def parse(str, _opts) do
    case String.split(str, " ") do
      [number_str, unit, "ago"] ->
        number =
          number_str
          |> String.replace(",", "")
          |> String.to_integer()
          |> Kernel.*(-1)

        unit =
          case String.downcase(unit) do
            "second" <> _ -> :second
            "minute" <> _ -> :minute
            "hour" <> _ -> :hour
            "day" <> _ -> :day
            "week" <> _ -> :week
            "month" <> _ -> :month
            "year" <> _ -> :year
            _ -> raise ArgumentError, "unsupported unit: #{unit}"
          end

        {unit, number}

      [number_str, unit, "from", "now"] ->
        number =
          number_str
          |> String.replace(",", "")
          |> String.to_integer()

        unit =
          case String.downcase(unit) do
            "second" <> _ -> :second
            "minute" <> _ -> :minute
            "hour" <> _ -> :hour
            "day" <> _ -> :day
            "week" <> _ -> :week
            "month" <> _ -> :month
            "year" <> _ -> :year
            _ -> raise ArgumentError, "unsupported unit: #{unit}"
          end

        {unit, number}

      _ ->
        raise ArgumentError, "unsupported duration format: #{str}"
    end
  end
end
