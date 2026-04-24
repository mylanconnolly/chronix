defmodule Chronix.Parser do
  @moduledoc """
  Core parsing logic for Chronix. Prefer the top-level `Chronix` API.

  Orchestrates: normalize → (ISO-8601 short-circuit) → (" at " split for
  composed date+time) → grammar (`Chronix.Grammar.expression/1`) →
  evaluator (`Chronix.Evaluator.resolve/2`).
  """

  alias Chronix.{Duration, Evaluator, Grammar}
  alias Chronix.Time, as: TimeParser

  @type result :: {:ok, DateTime.t()} | {:error, String.t()}

  @doc """
  Parses a natural-language date string and resolves it to a `DateTime`.

  Returns `{:ok, datetime}` on success or `{:error, reason}` on failure.
  Never raises.

  ## Options

    * `:reference_date` — a `DateTime` used as the "now" for all relative
      expressions, including `"today"` and `"now"`. Defaults to
      `DateTime.utc_now/0`.

    * `:endian` — how to interpret ambiguous three-component dates like
      `"01/05/2024"` or `"01-05-2024"`. Accepts `:us` (default, month-first
      → January 5) or `:eu` (day-first → May 1). Unambiguous formats (year
      first, or full ISO-8601) are unaffected.
  """
  @spec parse_expression(String.t(), keyword) :: result
  def parse_expression(date_string, opts \\ [])

  def parse_expression(date_string, opts) when is_binary(date_string) do
    trimmed = String.trim(date_string)

    cond do
      trimmed == "" ->
        {:error, "empty expression"}

      true ->
        case DateTime.from_iso8601(trimmed) do
          {:ok, dt, _offset} -> {:ok, dt}
          _ -> parse_relative(String.downcase(trimmed), opts)
        end
    end
  end

  def parse_expression(_, _), do: {:error, "expected a string"}

  # ── After normalization ───────────────────────────────────────────────

  defp parse_relative(normalized, opts) do
    if String.contains?(normalized, " at ") do
      try_combined_at(normalized, opts)
    else
      parse_single(normalized, opts)
    end
  end

  defp parse_single(normalized, opts) do
    case Grammar.expression(normalized) do
      {:ok, [ast], _, _, _, _} ->
        finalize(Evaluator.resolve(ast, opts), normalized)

      {:error, {:chronix_error, reason}, _, _, _, _} ->
        {:error, reason}

      _ ->
        fallback_error(normalized, opts)
    end
  end

  # When the grammar fails, check whether a boundary prefix is present —
  # if so, surface the inner Duration error for a more specific message.
  defp fallback_error(normalized, opts) do
    cond do
      inner = extract_boundary_inner(normalized, "beginning of ") ->
        duration_fallback(inner, normalized, opts)

      inner = extract_boundary_inner(normalized, "end of ") ->
        duration_fallback(inner, normalized, opts)

      true ->
        {:error, "unsupported expression: #{normalized}"}
    end
  end

  defp extract_boundary_inner(normalized, prefix) do
    if String.starts_with?(normalized, prefix) do
      normalized |> String.replace_prefix(prefix, "") |> String.trim()
    end
  end

  defp duration_fallback(inner, normalized, opts) do
    case Duration.parse(inner, opts) do
      {:error, reason} -> {:error, reason}
      _ -> {:error, "unsupported expression: #{normalized}"}
    end
  end

  defp try_combined_at(normalized, opts) do
    [date_part, time_part] = String.split(normalized, " at ", parts: 2)

    with {:ok, dt} <- parse_relative(String.trim(date_part), opts),
         {:ok, time} <- TimeParser.parse(String.trim(time_part)) do
      {:ok, apply_time(dt, time)}
    end
  end

  # ── Error finalization ────────────────────────────────────────────────

  defp finalize({:ok, _} = ok, _normalized), do: ok

  defp finalize({:error, :invalid_date}, normalized),
    do: {:error, "invalid date: #{normalized}"}

  defp finalize({:error, :invalid_time}, normalized),
    do: {:error, "invalid time: #{normalized}"}

  defp finalize({:error, reason}, _normalized) when is_binary(reason),
    do: {:error, reason}

  # ── Helpers ───────────────────────────────────────────────────────────

  defp apply_time(dt, %Time{hour: h, minute: m, second: s, microsecond: us}) do
    %{dt | hour: h, minute: m, second: s, microsecond: us}
  end
end
