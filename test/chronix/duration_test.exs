defmodule Chronix.DurationTest do
  use ExUnit.Case, async: true

  alias Chronix.Duration

  describe "parse/2" do
    test "parses future duration formats" do
      assert Duration.parse("in 2 seconds") == {:ok, {:second, 2}}
      assert Duration.parse("in 1 minute") == {:ok, {:minute, 1}}
      assert Duration.parse("in 24 hours") == {:ok, {:hour, 24}}
      assert Duration.parse("in 7 days") == {:ok, {:day, 7}}
      assert Duration.parse("in 4 weeks") == {:ok, {:week, 4}}
      assert Duration.parse("in 3 months") == {:ok, {:month, 3}}
      assert Duration.parse("in 1 year") == {:ok, {:year, 1}}

      assert Duration.parse("2 seconds") == {:ok, {:second, 2}}
      assert Duration.parse("1 minute") == {:ok, {:minute, 1}}
      assert Duration.parse("24 hours") == {:ok, {:hour, 24}}
      assert Duration.parse("7 days") == {:ok, {:day, 7}}
      assert Duration.parse("4 weeks") == {:ok, {:week, 4}}
      assert Duration.parse("3 months") == {:ok, {:month, 3}}
      assert Duration.parse("1 year") == {:ok, {:year, 1}}

      assert Duration.parse("2 seconds from now") == {:ok, {:second, 2}}
      assert Duration.parse("1 minute from now") == {:ok, {:minute, 1}}
      assert Duration.parse("24 hours from now") == {:ok, {:hour, 24}}
      assert Duration.parse("7 days from now") == {:ok, {:day, 7}}
      assert Duration.parse("4 weeks from now") == {:ok, {:week, 4}}
      assert Duration.parse("3 months from now") == {:ok, {:month, 3}}
      assert Duration.parse("1 year from now") == {:ok, {:year, 1}}
    end

    test "parses past duration formats" do
      assert Duration.parse("2 seconds ago") == {:ok, {:second, -2}}
      assert Duration.parse("1 minute ago") == {:ok, {:minute, -1}}
      assert Duration.parse("24 hours ago") == {:ok, {:hour, -24}}
      assert Duration.parse("7 days ago") == {:ok, {:day, -7}}
      assert Duration.parse("4 weeks ago") == {:ok, {:week, -4}}
      assert Duration.parse("3 months ago") == {:ok, {:month, -3}}
      assert Duration.parse("1 year ago") == {:ok, {:year, -1}}
    end

    test "parses next weekday formats" do
      monday = ~U[2025-01-27 00:00:00Z]
      assert Duration.parse("next monday", reference_date: monday) == {:ok, {:day, 7}}
      assert Duration.parse("next tuesday", reference_date: monday) == {:ok, {:day, 1}}
      assert Duration.parse("next wednesday", reference_date: monday) == {:ok, {:day, 2}}
      assert Duration.parse("next thursday", reference_date: monday) == {:ok, {:day, 3}}
      assert Duration.parse("next friday", reference_date: monday) == {:ok, {:day, 4}}
      assert Duration.parse("next saturday", reference_date: monday) == {:ok, {:day, 5}}
      assert Duration.parse("next sunday", reference_date: monday) == {:ok, {:day, 6}}

      assert Duration.parse("next MONDAY", reference_date: monday) == {:ok, {:day, 7}}
      assert Duration.parse("next Monday", reference_date: monday) == {:ok, {:day, 7}}
    end

    test "parses last weekday formats" do
      monday = ~U[2025-01-27 00:00:00Z]
      assert Duration.parse("last monday", reference_date: monday) == {:ok, {:day, -7}}
      assert Duration.parse("last tuesday", reference_date: monday) == {:ok, {:day, -6}}
      assert Duration.parse("last wednesday", reference_date: monday) == {:ok, {:day, -5}}
      assert Duration.parse("last thursday", reference_date: monday) == {:ok, {:day, -4}}
      assert Duration.parse("last friday", reference_date: monday) == {:ok, {:day, -3}}
      assert Duration.parse("last saturday", reference_date: monday) == {:ok, {:day, -2}}
      assert Duration.parse("last sunday", reference_date: monday) == {:ok, {:day, -1}}

      assert Duration.parse("last MONDAY", reference_date: monday) == {:ok, {:day, -7}}
      assert Duration.parse("last Monday", reference_date: monday) == {:ok, {:day, -7}}
    end

    test "parses next/last time period formats" do
      assert Duration.parse("next week") == {:ok, {:week, 1}}
      assert Duration.parse("next month") == {:ok, {:month, 1}}
      assert Duration.parse("next year") == {:ok, {:year, 1}}

      assert Duration.parse("last week") == {:ok, {:week, -1}}
      assert Duration.parse("last month") == {:ok, {:month, -1}}
      assert Duration.parse("last year") == {:ok, {:year, -1}}
    end

    test "handles numbers with commas" do
      assert Duration.parse("in 1,000 seconds") == {:ok, {:second, 1000}}
      assert Duration.parse("1,000 seconds ago") == {:ok, {:second, -1000}}
      assert Duration.parse("1,000 seconds from now") == {:ok, {:second, 1000}}
    end

    test "treats 'a' and 'an' as 1" do
      assert Duration.parse("in a week") == {:ok, {:week, 1}}
      assert Duration.parse("in an hour") == {:ok, {:hour, 1}}
      assert Duration.parse("a year from now") == {:ok, {:year, 1}}
      assert Duration.parse("an hour from now") == {:ok, {:hour, 1}}
      assert Duration.parse("a minute ago") == {:ok, {:minute, -1}}
      assert Duration.parse("an hour ago") == {:ok, {:hour, -1}}
      assert Duration.parse("a day") == {:ok, {:day, 1}}
      assert Duration.parse("an hour") == {:ok, {:hour, 1}}

      # 'a'/'an' are interchangeable — we don't enforce grammar
      assert Duration.parse("a hour ago") == {:ok, {:hour, -1}}
      assert Duration.parse("an week from now") == {:ok, {:week, 1}}
    end

    test "returns errors for invalid formats" do
      assert Duration.parse("invalid") == {:error, "unsupported duration format: invalid"}
      assert Duration.parse("in 1 invalid") == {:error, "unsupported unit: invalid"}
      assert Duration.parse("1 invalid ago") == {:error, "unsupported unit: invalid"}
      assert Duration.parse("1 invalid from now") == {:error, "unsupported unit: invalid"}
      assert Duration.parse("next invalid") == {:error, "unsupported weekday: invalid"}
      assert Duration.parse("last invalid") == {:error, "unsupported weekday: invalid"}
    end

    test "rejects mixing 'in' with 'ago'" do
      assert Duration.parse("in 2 seconds ago") == {:error, "cannot combine 'in' and 'ago'"}
      assert Duration.parse("in 5 days ago") == {:error, "cannot combine 'in' and 'ago'"}
    end

    test "rejects unit-like garbage that used to prefix-match" do
      assert Duration.parse("in 1 secondly") == {:error, "unsupported unit: secondly"}
      assert Duration.parse("in 1 yearz") == {:error, "unsupported unit: yearz"}
      assert Duration.parse("in 1 dayzz") == {:error, "unsupported unit: dayzz"}
    end

    test "rejects non-integer numbers" do
      assert Duration.parse("in 1.5 hours") == {:error, "invalid number: 1.5"}
      assert Duration.parse("in abc hours") == {:error, "invalid number: abc"}
    end
  end
end
