defmodule Chronix do
  @moduledoc """
  Natural-language date parser inspired by Ruby's Chronic.

  The primary entry points are `parse/2`, `parse!/2`, and `expression?/1`.
  All of them share the same notion of a valid Chronix expression via
  `Chronix.Parser.parse_expression/2`.
  """

  @doc """
  Parses `date_string` and returns `{:ok, datetime}` on success or
  `{:error, reason}` on failure.

  ## Options

    * `:reference_date` — the `DateTime` that anchors relative expressions
      (including `"today"` and `"now"`). Defaults to `DateTime.utc_now/0`.

  ## Examples

      iex> match?({:ok, %DateTime{}}, Chronix.parse("now"))
      true

      iex> {:ok, dt} = Chronix.parse("in 1 day", reference_date: ~U[2025-01-27 00:00:00Z])
      iex> dt
      ~U[2025-01-28 00:00:00Z]

      iex> Chronix.parse("in 2 seconds ago")
      {:error, "cannot combine 'in' and 'ago'"}
  """
  @spec parse(String.t(), keyword) :: {:ok, DateTime.t()} | {:error, String.t()}
  def parse(date_string, opts \\ []), do: Chronix.Parser.parse_expression(date_string, opts)

  @doc """
  Same as `parse/2` but returns the `DateTime` directly and raises
  `ArgumentError` on failure.
  """
  @spec parse!(String.t(), keyword) :: DateTime.t()
  def parse!(date_string, opts \\ []) do
    case parse(date_string, opts) do
      {:ok, dt} -> dt
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Returns `true` if `date_string` is a valid Chronix expression — i.e. if
  `parse/2` would succeed on it.

  Returns `false` for non-binary input.
  """
  @spec expression?(any) :: boolean
  def expression?(date_string) when is_binary(date_string) do
    match?({:ok, _}, parse(date_string))
  end

  def expression?(_), do: false
end
