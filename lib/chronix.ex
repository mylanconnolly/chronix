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
  Parses `date_string` and returns `{:ok, {start, finish}}` — the
  inclusive interval the expression denotes — or `{:error, reason}`.

  Accepts the same expressions and options as `parse/2`. The `finish`
  bound is the last microsecond of the period, matching the `"end of ..."`
  boundary semantics.

  How an expression expands depends on its shape:

  - Calendar periods (`"last week"`, `"this month"`, `"next year"`) cover
    the full calendar period relative to the reference date. ISO weeks run
    Monday through Sunday. Unlike `parse/2` — where `"this week"` resolves
    to the bare reference date — the range covers the whole current week.
  - Day-granularity expressions (`"today"`, `"tomorrow"`, `"7/1/2026"`,
    `"January 1, 2025"`, `"next monday"`, `"3 days ago"`, `"in 2 weeks"`)
    cover the whole day: 00:00:00.000000 to 23:59:59.999999.
  - Instants (`"now"`, `"noon"`, `"2 hours ago"`, `"tomorrow at 3pm"`,
    ISO-8601 timestamps) become zero-width ranges `{instant, instant}`.

  All arithmetic happens in the time zone the reference date carries;
  normalize zones before calling if you need a specific one.

  ## Examples

      iex> Chronix.parse_range("last week", reference_date: ~U[2025-01-15 10:30:00Z])
      {:ok, {~U[2025-01-06 00:00:00.000000Z], ~U[2025-01-12 23:59:59.999999Z]}}

      iex> Chronix.parse_range("today", reference_date: ~U[2025-01-15 10:30:00Z])
      {:ok, {~U[2025-01-15 00:00:00.000000Z], ~U[2025-01-15 23:59:59.999999Z]}}

      iex> Chronix.parse_range("now", reference_date: ~U[2025-01-15 10:30:00Z])
      {:ok, {~U[2025-01-15 10:30:00Z], ~U[2025-01-15 10:30:00Z]}}
  """
  @spec parse_range(String.t(), keyword) ::
          {:ok, {DateTime.t(), DateTime.t()}} | {:error, String.t()}
  def parse_range(date_string, opts \\ []), do: Chronix.Range.parse(date_string, opts)

  @doc """
  Same as `parse_range/2` but returns the `{start, finish}` tuple directly
  and raises `ArgumentError` on failure.
  """
  @spec parse_range!(String.t(), keyword) :: {DateTime.t(), DateTime.t()}
  def parse_range!(date_string, opts \\ []) do
    case parse_range(date_string, opts) do
      {:ok, range} -> range
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
