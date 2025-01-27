defmodule Chronix do
  def parse(date_string, opts \\ [])

  def parse(date_string, opts) do
    Chronix.Parser.parse(date_string, opts)
  end
end
