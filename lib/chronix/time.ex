defmodule Chronix.Time do
  @moduledoc """
  Parses time-of-day expressions into `Time` structs.

  Supported forms:

  - `"noon"` → 12:00:00
  - `"midnight"` → 00:00:00
  - Meridiem: `"3pm"`, `"3 pm"`, `"3 p.m."`, `"3:15pm"`, `"3:15:30pm"`
  - 24-hour: `"15:30"`, `"15:30:45"`
  """

  alias Chronix.Grammar

  @type result :: {:ok, Time.t()} | {:error, String.t()}

  @spec parse(String.t()) :: result
  def parse(str) when is_binary(str) do
    normalized = str |> String.trim() |> String.downcase()

    case Grammar.time(normalized) do
      {:ok, [ast], _, _, _, _} ->
        case from_ast(ast) do
          {:ok, _} = ok -> ok
          {:error, _} -> {:error, "invalid time: #{str}"}
        end

      _ ->
        {:error, "invalid time: #{str}"}
    end
  end

  def parse(_), do: {:error, "expected a string"}

  @doc """
  Converts a raw time AST node (produced by `Chronix.Grammar.time/1`) into
  a `Time` struct.

  Returns `{:ok, %Time{}}` on success or `{:error, :invalid_time}` when
  the parsed components are out of range. Callers that need a specific
  error message should wrap this themselves.
  """
  @spec from_ast(term) :: {:ok, Time.t()} | {:error, :invalid_time}
  def from_ast(:noon), do: {:ok, ~T[12:00:00.000000]}
  def from_ast(:midnight), do: {:ok, ~T[00:00:00.000000]}
  def from_ast({:time_12h, fields}), do: build_12h(fields)
  def from_ast({:time_24h, fields}), do: build_24h(fields)
  def from_ast(_), do: {:error, :invalid_time}

  defp build_12h(fields) do
    hour = Keyword.fetch!(fields, :hour)
    minute = Keyword.get(fields, :minute, 0)
    second = Keyword.get(fields, :second, 0)
    meridiem = Keyword.fetch!(fields, :meridiem)

    cond do
      hour < 1 or hour > 12 -> {:error, :invalid_time}
      minute > 59 or second > 59 -> {:error, :invalid_time}
      true -> wrap_time(Time.new(to_24h(hour, meridiem), minute, second, {0, 6}))
    end
  end

  defp build_24h(fields) do
    hour = Keyword.fetch!(fields, :hour)
    minute = Keyword.fetch!(fields, :minute)
    second = Keyword.get(fields, :second, 0)

    cond do
      hour > 23 or minute > 59 or second > 59 -> {:error, :invalid_time}
      true -> wrap_time(Time.new(hour, minute, second, {0, 6}))
    end
  end

  defp wrap_time({:ok, _} = ok), do: ok
  defp wrap_time({:error, _}), do: {:error, :invalid_time}

  defp to_24h(12, :am), do: 0
  defp to_24h(hour, :am), do: hour
  defp to_24h(12, :pm), do: 12
  defp to_24h(hour, :pm), do: hour + 12
end
