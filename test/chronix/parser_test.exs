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
      # This is a Monday
      monday = ~U[2025-01-27 00:00:00Z]

      # Next Monday should be 7 days later
      assert Parser.parse("next monday", reference_date: monday) ==
               DateTime.add(monday, 7 * 24 * 60 * 60, :second)

      # Next Tuesday should be 1 day later
      assert Parser.parse("next tuesday", reference_date: monday) ==
               DateTime.add(monday, 1 * 24 * 60 * 60, :second)
    end

    test "parses last weekday dates" do
      # This is a Monday
      monday = ~U[2025-01-27 00:00:00Z]

      # Last Monday should be 7 days ago
      assert Parser.parse("last monday", reference_date: monday) ==
               DateTime.add(monday, -7 * 24 * 60 * 60, :second)

      # Last Sunday should be 1 day ago
      assert Parser.parse("last sunday", reference_date: monday) ==
               DateTime.add(monday, -1 * 24 * 60 * 60, :second)
    end

    test "parses mm/dd/yyyy format" do
      {:ok, expected} = NaiveDateTime.new(2024, 12, 25, 0, 0, 0)
      assert Parser.parse("12/25/2024") == {:ok, expected}

      {:ok, expected} = NaiveDateTime.new(2025, 1, 1, 0, 0, 0)
      assert Parser.parse("01/01/2025") == {:ok, expected}

      # Invalid dates should return error
      assert Parser.parse("13/01/2024") == {:error, "Invalid date format: 13/01/2024"}
      assert Parser.parse("01/32/2024") == {:error, "Invalid date format: 01/32/2024"}
      assert Parser.parse("02/30/2024") == {:error, "Invalid date format: 02/30/2024"}
    end

    test "parses yyyy-mm-dd format" do
      {:ok, expected} = NaiveDateTime.new(2024, 12, 25, 0, 0, 0)
      assert Parser.parse("2024-12-25") == {:ok, expected}

      {:ok, expected} = NaiveDateTime.new(2025, 1, 1, 0, 0, 0)
      assert Parser.parse("2025-01-01") == {:ok, expected}

      # Invalid dates should return error
      assert Parser.parse("2024-13-01") == {:error, "Invalid date format: 2024-13-01"}
      assert Parser.parse("2024-01-32") == {:error, "Invalid date format: 2024-01-32"}
      assert Parser.parse("2024-02-30") == {:error, "Invalid date format: 2024-02-30"}
    end

    test "parses beginning of durations" do
      ref = ~U[2025-01-27 13:45:30.123456Z]

      # Test beginning of second
      assert Parser.parse("beginning of 2 seconds from now", reference_date: ref) ==
               %{DateTime.add(ref, 2, :second) | microsecond: {0, 6}}

      # Test beginning of minute
      assert Parser.parse("beginning of 3 minutes from now", reference_date: ref) ==
               %{DateTime.add(ref, 3 * 60, :second) | second: 0, microsecond: {0, 6}}

      # Test beginning of hour
      assert Parser.parse("beginning of 4 hours from now", reference_date: ref) ==
               %{DateTime.add(ref, 4 * 3600, :second) | minute: 0, second: 0, microsecond: {0, 6}}

      # Test beginning of day
      assert Parser.parse("beginning of 2 days from now", reference_date: ref) ==
               %{
                 DateTime.add(ref, 2 * 86400, :second)
                 | hour: 0,
                   minute: 0,
                   second: 0,
                   microsecond: {0, 6}
               }

      # Test beginning of week (should be Monday)
      future = DateTime.add(ref, 2 * 7 * 86400, :second)
      monday = future |> DateTime.add(-((Date.day_of_week(future) - 1) * 86400), :second)

      assert Parser.parse("beginning of 2 weeks from now", reference_date: ref) ==
               %{monday | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}

      # Test beginning of month
      assert Parser.parse("beginning of 3 months from now", reference_date: ref) ==
               %{
                 DateTime.add(ref, 3 * 30 * 86400, :second)
                 | day: 1,
                   hour: 0,
                   minute: 0,
                   second: 0,
                   microsecond: {0, 6}
               }

      # Test beginning of year
      assert Parser.parse("beginning of 2 years from now", reference_date: ref) ==
               %{
                 DateTime.add(ref, 2 * 365 * 86400, :second)
                 | month: 1,
                   day: 1,
                   hour: 0,
                   minute: 0,
                   second: 0,
                   microsecond: {0, 6}
               }
    end

    test "parses end of durations" do
      ref = ~U[2025-01-27 13:45:30.123456Z]
      
      # Test end of second
      assert Parser.parse("end of 2 seconds from now", reference_date: ref) ==
               %{DateTime.add(ref, 2, :second) | microsecond: {999_999, 6}}
               
      # Test end of minute
      assert Parser.parse("end of 3 minutes from now", reference_date: ref) ==
               %{DateTime.add(ref, 3 * 60, :second) | second: 59, microsecond: {999_999, 6}}
               
      # Test end of hour
      assert Parser.parse("end of 4 hours from now", reference_date: ref) ==
               %{DateTime.add(ref, 4 * 3600, :second) | minute: 59, second: 59, microsecond: {999_999, 6}}
               
      # Test end of day
      assert Parser.parse("end of 2 days from now", reference_date: ref) ==
               %{DateTime.add(ref, 2 * 86400, :second) | hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
               
      # Test end of week (should be Sunday)
      future = DateTime.add(ref, 2 * 7 * 86400, :second)
      sunday = future |> DateTime.add((7 - Date.day_of_week(future)) * 86400, :second)
      assert Parser.parse("end of 2 weeks from now", reference_date: ref) ==
               %{sunday | hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
               
      # Test end of month
      future_month = DateTime.add(ref, 3 * 30 * 86400, :second)
      days_in_month = Calendar.ISO.days_in_month(future_month.year, future_month.month)
      assert Parser.parse("end of 3 months from now", reference_date: ref) ==
               %{future_month | day: days_in_month, hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
               
      # Test end of year
      assert Parser.parse("end of 2 years from now", reference_date: ref) ==
               %{DateTime.add(ref, 2 * 365 * 86400, :second) | month: 12, day: 31, hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
    end
  end
end
