defmodule Chronix.Parser do
  def parse(date_string, opts \\ [])

  def parse(date_string, opts) do
    str =
      date_string
      |> String.downcase()
      |> String.trim()

    parse_date(str, opts)
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
