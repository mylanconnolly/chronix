defmodule Chronix.ParserTest do
  use ExUnit.Case, async: true

  alias Chronix.Parser

  describe "parse/2" do
    test "parses future dates" do
      ref = ~U[2025-01-27 00:00:00Z]
      
      assert Parser.parse("in 2 seconds", reference_date: ref) ==
               DateTime.add(ref, 2, :second)
               
      assert Parser.parse("in 1 minute", reference_date: ref) ==
               DateTime.add(ref, 60, :second)
               
      assert Parser.parse("in 24 hours", reference_date: ref) ==
               DateTime.add(ref, 24 * 60 * 60, :second)
    end

    test "parses past dates" do
      ref = ~U[2025-01-27 00:00:00Z]
      
      assert Parser.parse("2 seconds ago", reference_date: ref) ==
               DateTime.add(ref, -2, :second)
               
      assert Parser.parse("1 minute ago", reference_date: ref) ==
               DateTime.add(ref, -60, :second)
               
      assert Parser.parse("24 hours ago", reference_date: ref) ==
               DateTime.add(ref, -24 * 60 * 60, :second)
    end

    test "handles string normalization" do
      ref = ~U[2025-01-27 00:00:00Z]
      
      # Test case insensitivity
      assert Parser.parse("IN 2 SECONDS", reference_date: ref) ==
               Parser.parse("in 2 seconds", reference_date: ref)
               
      # Test whitespace trimming
      assert Parser.parse("  in 2 seconds  ", reference_date: ref) ==
               Parser.parse("in 2 seconds", reference_date: ref)
    end

    test "uses current time when no reference date is provided" do
      # Since we can't predict exact current time in test, we'll verify
      # that the result is within an expected range
      result = Parser.parse("in 1 minute")
      now = DateTime.utc_now()
      
      # Result should be approximately 1 minute in the future
      assert DateTime.diff(result, now) in 59..61
    end

    test "parses next weekday dates" do
      monday = ~U[2025-01-27 00:00:00Z]  # This is a Monday
      
      # Next Monday should be 7 days later
      assert Parser.parse("next monday", reference_date: monday) ==
               DateTime.add(monday, 7 * 24 * 60 * 60, :second)
               
      # Next Tuesday should be 1 day later
      assert Parser.parse("next tuesday", reference_date: monday) ==
               DateTime.add(monday, 1 * 24 * 60 * 60, :second)
    end

    test "parses last weekday dates" do
      monday = ~U[2025-01-27 00:00:00Z]  # This is a Monday
      
      # Last Monday should be 7 days ago
      assert Parser.parse("last monday", reference_date: monday) ==
               DateTime.add(monday, -7 * 24 * 60 * 60, :second)
               
      # Last Sunday should be 1 day ago
      assert Parser.parse("last sunday", reference_date: monday) ==
               DateTime.add(monday, -1 * 24 * 60 * 60, :second)
    end
  end
end
