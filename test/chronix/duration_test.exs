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

    test "parses extra units: quarter, fortnight, decade, century" do
      assert Duration.parse("in 1 quarter") == {:ok, {:month, 3}}
      assert Duration.parse("2 quarters ago") == {:ok, {:month, -6}}
      assert Duration.parse("in a fortnight") == {:ok, {:day, 14}}
      assert Duration.parse("3 fortnights from now") == {:ok, {:day, 42}}
      assert Duration.parse("in 1 decade") == {:ok, {:year, 10}}
      assert Duration.parse("a decade ago") == {:ok, {:year, -10}}
      assert Duration.parse("in 1 century") == {:ok, {:year, 100}}
      assert Duration.parse("2 centuries ago") == {:ok, {:year, -200}}
    end

    test "treats integer-valued fractionals as integers" do
      # 0.5 decades = 5 years exactly — should NOT be rejected as fractional
      assert Duration.parse("in 0.5 decades") == {:ok, {:year, 5}}
      # 1.5 decades = 15 years exactly
      assert Duration.parse("1.5 decades from now") == {:ok, {:year, 15}}
      # 0.5 quarters = 1.5 months (non-integer) — rejected
      assert Duration.parse("in 0.5 quarters") ==
               {:error, "fractional months are not supported"}

      # 5.0 hours collapses to {:hour, 5} (was {:microsecond, ...} before)
      assert Duration.parse("in 5.0 hours") == {:ok, {:hour, 5}}
    end

    test "parses 'this <weekday>' as upcoming including today" do
      monday = ~U[2025-01-27 00:00:00Z]
      assert Duration.parse("this monday", reference_date: monday) == {:ok, {:day, 0}}
      assert Duration.parse("this tuesday", reference_date: monday) == {:ok, {:day, 1}}
      assert Duration.parse("this sunday", reference_date: monday) == {:ok, {:day, 6}}

      # From a Wednesday, "this monday" has already passed → next Monday
      wednesday = ~U[2025-01-29 00:00:00Z]
      assert Duration.parse("this monday", reference_date: wednesday) == {:ok, {:day, 5}}
    end

    test "parses 'on <weekday>' equivalently to 'this <weekday>'" do
      monday = ~U[2025-01-27 00:00:00Z]
      assert Duration.parse("on monday", reference_date: monday) == {:ok, {:day, 0}}
      assert Duration.parse("on friday", reference_date: monday) == {:ok, {:day, 4}}
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

    test "rejects non-numeric tokens" do
      assert Duration.parse("in abc hours") == {:error, "invalid number: abc"}
      assert Duration.parse("in 1.2.3 hours") == {:error, "invalid number: 1.2.3"}
    end

    test "parses fractional durations for fixed-duration units" do
      assert Duration.parse("in 1.5 hours") == {:ok, {:microsecond, 5_400_000_000}}
      assert Duration.parse("1.5 hours ago") == {:ok, {:microsecond, -5_400_000_000}}
      assert Duration.parse("0.5 days") == {:ok, {:microsecond, 43_200_000_000}}
      assert Duration.parse("in 2.5 weeks") == {:ok, {:microsecond, 1_512_000_000_000}}
      assert Duration.parse("in .5 minutes") == {:ok, {:microsecond, 30_000_000}}
      assert Duration.parse("in 1.5 seconds") == {:ok, {:microsecond, 1_500_000}}
    end

    test "rejects fractional months and years" do
      assert Duration.parse("in 1.5 months") == {:error, "fractional months are not supported"}
      assert Duration.parse("1.5 months ago") == {:error, "fractional months are not supported"}
      assert Duration.parse("in 0.5 years") == {:error, "fractional years are not supported"}
    end
  end
end
