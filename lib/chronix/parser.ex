defmodule Chronix.Parser do
  def parse(date_string, opts \\ [])

  def parse(date_string, opts) do
    str =
      date_string
      |> String.downcase()
      |> String.trim()

    parse_date(str, opts)
  end

  defp parse_date("beginning of " <> rest, opts) do
    ref = Keyword.get(opts, :reference_date, DateTime.utc_now())
    duration = Chronix.Duration.parse(rest, reference_date: ref)
    val = DateTime.shift(ref, [duration])

    case duration do
      {:second, _} ->
        %{val | microsecond: {0, 6}}

      {:minute, _} ->
        %{val | second: 0, microsecond: {0, 6}}

      {:hour, _} ->
        %{val | minute: 0, second: 0, microsecond: {0, 6}}

      {:day, _} ->
        %{val | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}

      {:week, _} ->
        val
        |> DateTime.add(-((Date.day_of_week(val) - 1) * 24 * 60 * 60), :second)
        |> then(&%{&1 | hour: 0, minute: 0, second: 0, microsecond: {0, 6}})

      {:month, _} ->
        %{val | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 6}}

      {:year, _} ->
        %{val | month: 1, day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 6}}
    end
  end

  defp parse_date("end of " <> rest, opts) do
    ref = Keyword.get(opts, :reference_date, DateTime.utc_now())
    duration = Chronix.Duration.parse(rest, reference_date: ref)
    val = DateTime.shift(ref, [duration])

    case duration do
      {:second, _} ->
        %{val | microsecond: {999_999, 6}}

      {:minute, _} ->
        %{val | second: 59, microsecond: {999_999, 6}}

      {:hour, _} ->
        %{val | minute: 59, second: 59, microsecond: {999_999, 6}}

      {:day, _} ->
        %{val | hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}

      {:week, _} ->
        val
        |> DateTime.add(((7 - Date.day_of_week(val)) * 24 * 60 * 60), :second)
        |> then(&%{&1 | hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}})

      {:month, _} ->
        days_in_month = Calendar.ISO.days_in_month(val.year, val.month)
        %{val | day: days_in_month, hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}

      {:year, _} ->
        %{val | month: 12, day: 31, hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
    end
  end

  # Handle mm/dd/yyyy format
  defp parse_date(
         <<month::binary-size(2), "/", day::binary-size(2), "/", year::binary-size(4)>> = str,
         _opts
       ) do
    with {month, _} <- Integer.parse(month),
         {day, _} <- Integer.parse(day),
         {year, _} <- Integer.parse(year),
         {:ok, date} <- Date.new(year, month, day) do
      NaiveDateTime.new(date, ~T[00:00:00])
    else
      _ -> {:error, "Invalid date format: #{str}"}
    end
  end

  # Handle yyyy-mm-dd format
  defp parse_date(
         <<year::binary-size(4), "-", month::binary-size(2), "-", day::binary-size(2)>> = str,
         _opts
       ) do
    with {year, _} <- Integer.parse(year),
         {month, _} <- Integer.parse(month),
         {day, _} <- Integer.parse(day),
         {:ok, date} <- Date.new(year, month, day) do
      NaiveDateTime.new(date, ~T[00:00:00])
    else
      _ -> {:error, "Invalid date format: #{str}"}
    end
  end

  # Handle duration-based parsing as before
  defp parse_date(str, opts) do
    ref = Keyword.get(opts, :reference_date, DateTime.utc_now())
    duration = Chronix.Duration.parse(str, reference_date: ref)
    DateTime.shift(ref, [duration])
  end
end
