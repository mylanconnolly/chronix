defmodule Chronix.Time do
  @moduledoc """
  Parses time-of-day expressions into `Time` structs.

  Supported forms:

  - `"noon"` → 12:00:00
  - `"midnight"` → 00:00:00
  - Meridiem: `"3pm"`, `"3 pm"`, `"3 p.m."`, `"3:15pm"`, `"3:15:30pm"`
  - 24-hour: `"15:30"`, `"15:30:45"`
  """

  @meridiem ~r/^\s*(\d{1,2})(?::(\d{2})(?::(\d{2}))?)?\s*(a\.m\.|p\.m\.|am|pm)\s*$/
  @h_m_s ~r/^\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*$/

  @type result :: {:ok, Time.t()} | {:error, String.t()}

  @spec parse(String.t()) :: result
  def parse(str) when is_binary(str) do
    normalized = str |> String.downcase() |> String.trim()

    cond do
      normalized == "noon" -> {:ok, ~T[12:00:00.000000]}
      normalized == "midnight" -> {:ok, ~T[00:00:00.000000]}
      parts = Regex.run(@meridiem, normalized) -> build_meridiem(parts, str)
      parts = Regex.run(@h_m_s, normalized) -> build_24h(parts, str)
      true -> {:error, "invalid time: #{str}"}
    end
  end

  def parse(_), do: {:error, "expected a string"}

  defp build_meridiem([_, h, mer], original), do: build_meridiem(h, "", "", mer, original)
  defp build_meridiem([_, h, m, mer], original), do: build_meridiem(h, m, "", mer, original)

  defp build_meridiem([_, h, m, s, mer], original),
    do: build_meridiem(h, m, s, mer, original)

  defp build_meridiem(h, m, s, mer, original) do
    hour = to_int(h)
    minute = to_int_or(m, 0)
    second = to_int_or(s, 0)

    cond do
      hour < 1 or hour > 12 ->
        {:error, "invalid time: #{original}"}

      minute > 59 or second > 59 ->
        {:error, "invalid time: #{original}"}

      true ->
        Time.new(to_24h(hour, mer), minute, second, {0, 6})
    end
  end

  defp build_24h([_, h, m], original), do: build_24h(h, m, "", original)
  defp build_24h([_, h, m, s], original), do: build_24h(h, m, s, original)

  defp build_24h(h, m, s, original) do
    hour = to_int(h)
    minute = to_int(m)
    second = to_int_or(s, 0)

    cond do
      hour > 23 or minute > 59 or second > 59 ->
        {:error, "invalid time: #{original}"}

      true ->
        Time.new(hour, minute, second, {0, 6})
    end
  end

  defp to_24h(12, mer) when mer in ["am", "a.m."], do: 0
  defp to_24h(hour, mer) when mer in ["am", "a.m."], do: hour
  defp to_24h(12, mer) when mer in ["pm", "p.m."], do: 12
  defp to_24h(hour, mer) when mer in ["pm", "p.m."], do: hour + 12

  defp to_int(str) do
    {n, _} = Integer.parse(str)
    n
  end

  defp to_int_or("", default), do: default
  defp to_int_or(str, _default), do: to_int(str)
end
