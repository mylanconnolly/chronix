defmodule Chronix do
  @regex ~r/now|today|in \d+ (second|minute|hour|day|week|month|year)s?|(beginning of )?\d+ (second|minute|hour|day|week|month|year)s? from now|(beginning of )?\d+ (second|minute|hour|day|week|month|year)s? ago|(beginning of )?next (monday|tuesday|wednesday|thursday|friday|saturday|sunday)|(beginning of )?last (monday|tuesday|wednesday|thursday|friday|saturday|sunday)|(beginning of )?next (week|month|year)|(beginning of )?last (week|month|year)/i

  def parse(date_string, opts \\ []), do: Chronix.Parser.parse(date_string, opts)

  def expression?(date_string), do: Regex.match?(@regex, date_string)
end
