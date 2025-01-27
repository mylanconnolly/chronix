defmodule Chronix.Parser do
  def parse(date_string, opts \\ [])

  def parse(date_string, opts) do
    str =
      date_string
      |> String.downcase()
      |> String.trim()

    parse_date(str, opts)
  end

  defp parse_date(str, opts) do
    ref = Keyword.get(opts, :reference_date, DateTime.utc_now())
    duration = Chronix.Duration.parse(str, reference_date: ref)
    DateTime.shift(ref, [duration])
  end
end
