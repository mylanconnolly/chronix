defmodule Chronix.Parser do
  @moduledoc """
  Core parsing logic for Chronix. Prefer the top-level `Chronix` API.
  """

  alias Chronix.Duration

  @type result :: {:ok, DateTime.t()} | {:error, String.t()}

  @doc """
  Parses a natural-language date string and resolves it to a `DateTime`.

  Returns `{:ok, datetime}` on success or `{:error, reason}` on failure.
  Never raises.

  ## Options

    * `:reference_date` — a `DateTime` used as the "now" for all relative
      expressions, including `"today"` and `"now"`. Defaults to
      `DateTime.utc_now/0`.
  """
  @spec parse_expression(String.t(), keyword) :: result
  def parse_expression(date_string, opts \\ [])

  def parse_expression(date_string, opts) when is_binary(date_string) do
    date_string
    |> String.downcase()
    |> String.trim()
    |> do_parse(opts)
  end

  def parse_expression(_, _), do: {:error, "expected a string"}

  defp ref(opts), do: Keyword.get(opts, :reference_date, DateTime.utc_now())

  defp do_parse("", _opts), do: {:error, "empty expression"}
  defp do_parse("today", opts), do: {:ok, ref(opts)}
  defp do_parse("now", opts), do: {:ok, ref(opts)}
  defp do_parse("tomorrow", opts), do: {:ok, DateTime.shift(ref(opts), [{:day, 1}])}
  defp do_parse("yesterday", opts), do: {:ok, DateTime.shift(ref(opts), [{:day, -1}])}

  defp do_parse("beginning of " <> rest, opts) do
    with {:ok, duration} <- Duration.parse(rest, opts) do
      shifted = DateTime.shift(ref(opts), [duration])
      {:ok, beginning_of(shifted, duration)}
    end
  end

  defp do_parse("end of " <> rest, opts) do
    with {:ok, duration} <- Duration.parse(rest, opts) do
      shifted = DateTime.shift(ref(opts), [duration])
      {:ok, end_of(shifted, duration)}
    end
  end

  defp do_parse(
         <<month::binary-size(2), "/", day::binary-size(2), "/", year::binary-size(4)>> = str,
         _opts
       ) do
    parse_ymd(year, month, day, str)
  end

  defp do_parse(
         <<year::binary-size(4), "-", month::binary-size(2), "-", day::binary-size(2)>> = str,
         _opts
       ) do
    parse_ymd(year, month, day, str)
  end

  defp do_parse(str, opts) do
    with {:ok, duration} <- Duration.parse(str, opts) do
      {:ok, DateTime.shift(ref(opts), [duration])}
    end
  end

  defp parse_ymd(year_str, month_str, day_str, original) do
    with {year, ""} <- Integer.parse(year_str),
         {month, ""} <- Integer.parse(month_str),
         {day, ""} <- Integer.parse(day_str),
         {:ok, date} <- Date.new(year, month, day),
         {:ok, dt} <- DateTime.new(date, ~T[00:00:00], "Etc/UTC") do
      {:ok, dt}
    else
      _ -> {:error, "invalid date: #{original}"}
    end
  end

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
