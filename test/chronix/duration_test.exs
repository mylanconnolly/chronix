defmodule Chronix.DurationTest do
  use ExUnit.Case, async: true

  alias Chronix.Duration

  describe "parse/2" do
    test "parses future duration formats" do
      assert Duration.parse("in 2 seconds") == {:second, 2}
      assert Duration.parse("in 1 minute") == {:minute, 1}
      assert Duration.parse("in 24 hours") == {:hour, 24}
      assert Duration.parse("in 7 days") == {:day, 7}
      assert Duration.parse("in 4 weeks") == {:week, 4}
      assert Duration.parse("in 3 months") == {:month, 3}
      assert Duration.parse("in 1 year") == {:year, 1}
      assert Duration.parse("2 seconds") == {:second, 2}
      assert Duration.parse("1 minute") == {:minute, 1}
      assert Duration.parse("24 hours") == {:hour, 24}
      assert Duration.parse("7 days") == {:day, 7}
      assert Duration.parse("4 weeks") == {:week, 4}
      assert Duration.parse("3 months") == {:month, 3}
      assert Duration.parse("1 year") == {:year, 1}

      # Test "from now" format
      assert Duration.parse("2 seconds from now") == {:second, 2}
      assert Duration.parse("1 minute from now") == {:minute, 1}
      assert Duration.parse("24 hours from now") == {:hour, 24}
      assert Duration.parse("7 days from now") == {:day, 7}
      assert Duration.parse("4 weeks from now") == {:week, 4}
      assert Duration.parse("3 months from now") == {:month, 3}
      assert Duration.parse("1 year from now") == {:year, 1}
    end

    test "parses past duration formats" do
      assert Duration.parse("2 seconds ago") == {:second, -2}
      assert Duration.parse("1 minute ago") == {:minute, -1}
      assert Duration.parse("24 hours ago") == {:hour, -24}
      assert Duration.parse("7 days ago") == {:day, -7}
      assert Duration.parse("4 weeks ago") == {:week, -4}
      assert Duration.parse("3 months ago") == {:month, -3}
      assert Duration.parse("1 year ago") == {:year, -1}
    end

    test "parses next weekday formats" do
      # Monday is day 1, so from Monday to next Monday should be 7 days
      # This is a Monday
      monday = ~U[2025-01-27 00:00:00Z]
      assert Duration.parse("next monday", reference_date: monday) == {:day, 7}
      assert Duration.parse("next tuesday", reference_date: monday) == {:day, 1}
      assert Duration.parse("next wednesday", reference_date: monday) == {:day, 2}
      assert Duration.parse("next thursday", reference_date: monday) == {:day, 3}
      assert Duration.parse("next friday", reference_date: monday) == {:day, 4}
      assert Duration.parse("next saturday", reference_date: monday) == {:day, 5}
      assert Duration.parse("next sunday", reference_date: monday) == {:day, 6}

      # Test case insensitivity
      assert Duration.parse("next MONDAY", reference_date: monday) == {:day, 7}
      assert Duration.parse("next Monday", reference_date: monday) == {:day, 7}
    end

    test "parses last weekday formats" do
      # Monday is day 1, so from Monday to last Monday should be -7 days
      # This is a Monday
      monday = ~U[2025-01-27 00:00:00Z]
      assert Duration.parse("last monday", reference_date: monday) == {:day, -7}
      assert Duration.parse("last tuesday", reference_date: monday) == {:day, -6}
      assert Duration.parse("last wednesday", reference_date: monday) == {:day, -5}
      assert Duration.parse("last thursday", reference_date: monday) == {:day, -4}
      assert Duration.parse("last friday", reference_date: monday) == {:day, -3}
      assert Duration.parse("last saturday", reference_date: monday) == {:day, -2}
      assert Duration.parse("last sunday", reference_date: monday) == {:day, -1}

      # Test case insensitivity
      assert Duration.parse("last MONDAY", reference_date: monday) == {:day, -7}
      assert Duration.parse("last Monday", reference_date: monday) == {:day, -7}
    end

    test "parses next/last time period formats" do
      assert Duration.parse("next week") == {:week, 1}
      assert Duration.parse("next month") == {:month, 1}
      assert Duration.parse("next year") == {:year, 1}

      assert Duration.parse("last week") == {:week, -1}
      assert Duration.parse("last month") == {:month, -1}
      assert Duration.parse("last year") == {:year, -1}
    end

    test "handles numbers with commas" do
      assert Duration.parse("in 1,000 seconds") == {:second, 1000}
      assert Duration.parse("1,000 seconds ago") == {:second, -1000}
      assert Duration.parse("1,000 seconds from now") == {:second, 1000}
    end

    test "raises on invalid formats" do
      assert_raise ArgumentError, "unsupported duration format: invalid", fn ->
        Duration.parse("invalid")
      end

      assert_raise ArgumentError, "unsupported unit: invalid", fn ->
        Duration.parse("in 1 invalid")
      end

      assert_raise ArgumentError, "unsupported unit: invalid", fn ->
        Duration.parse("1 invalid ago")
      end

      assert_raise ArgumentError, "unsupported unit: invalid", fn ->
        Duration.parse("1 invalid from now")
      end

      assert_raise ArgumentError, "unsupported weekday: invalid", fn ->
        Duration.parse("next invalid")
      end

      assert_raise ArgumentError, "unsupported weekday: invalid", fn ->
        Duration.parse("last invalid")
      end
    end
  end
end
