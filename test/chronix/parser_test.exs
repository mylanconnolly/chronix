defmodule Chronix.ParserTest do
  use ExUnit.Case, async: true

  alias Chronix.Parser

  describe "parse_expression/2" do
    test "parses 'today' honoring reference_date" do
      ref = ~U[2025-01-27 12:00:00Z]
      assert Parser.parse_expression("today", reference_date: ref) == {:ok, ref}
    end

    test "parses 'now' honoring reference_date" do
      ref = ~U[2025-01-27 12:00:00Z]
      assert Parser.parse_expression("now", reference_date: ref) == {:ok, ref}
    end

    test "falls back to current time when no reference_date is given" do
      before = DateTime.utc_now()
      {:ok, result} = Parser.parse_expression("now")
      after_time = DateTime.utc_now()

      assert DateTime.compare(before, result) in [:lt, :eq]
      assert DateTime.compare(result, after_time) in [:lt, :eq]
    end

    test "parses future dates" do
      ref = ~U[2025-01-27 00:00:00Z]

      assert Parser.parse_expression("in 2 seconds", reference_date: ref) ==
               {:ok, DateTime.add(ref, 2, :second)}

      assert Parser.parse_expression("in 1 minute", reference_date: ref) ==
               {:ok, DateTime.add(ref, 60, :second)}

      assert Parser.parse_expression("in 24 hours", reference_date: ref) ==
               {:ok, DateTime.add(ref, 24 * 60 * 60, :second)}
    end

    test "parses past dates" do
      ref = ~U[2025-01-27 00:00:00Z]

      assert Parser.parse_expression("2 seconds ago", reference_date: ref) ==
               {:ok, DateTime.add(ref, -2, :second)}

      assert Parser.parse_expression("1 minute ago", reference_date: ref) ==
               {:ok, DateTime.add(ref, -60, :second)}

      assert Parser.parse_expression("24 hours ago", reference_date: ref) ==
               {:ok, DateTime.add(ref, -24 * 60 * 60, :second)}
    end

    test "rejects 'in X Y ago'" do
      ref = ~U[2025-01-27 00:00:00Z]

      assert Parser.parse_expression("in 5 seconds ago", reference_date: ref) ==
               {:error, "cannot combine 'in' and 'ago'"}
    end

    test "handles string normalization" do
      ref = ~U[2025-01-27 00:00:00Z]

      assert Parser.parse_expression("IN 2 SECONDS", reference_date: ref) ==
               Parser.parse_expression("in 2 seconds", reference_date: ref)

      assert Parser.parse_expression("  in 2 seconds  ", reference_date: ref) ==
               Parser.parse_expression("in 2 seconds", reference_date: ref)
    end

    test "uses current time when no reference date is provided" do
      {:ok, result} = Parser.parse_expression("in 1 minute")
      now = DateTime.utc_now()

      assert DateTime.diff(result, now) in 59..61
    end

    test "parses next weekday dates" do
      monday = ~U[2025-01-27 00:00:00Z]

      assert Parser.parse_expression("next monday", reference_date: monday) ==
               {:ok, DateTime.add(monday, 7 * 24 * 60 * 60, :second)}

      assert Parser.parse_expression("next tuesday", reference_date: monday) ==
               {:ok, DateTime.add(monday, 1 * 24 * 60 * 60, :second)}
    end

    test "parses last weekday dates" do
      monday = ~U[2025-01-27 00:00:00Z]

      assert Parser.parse_expression("last monday", reference_date: monday) ==
               {:ok, DateTime.add(monday, -7 * 24 * 60 * 60, :second)}

      assert Parser.parse_expression("last sunday", reference_date: monday) ==
               {:ok, DateTime.add(monday, -1 * 24 * 60 * 60, :second)}
    end

    test "parses mm/dd/yyyy format as UTC DateTime at midnight" do
      assert Parser.parse_expression("12/25/2024") == {:ok, ~U[2024-12-25 00:00:00Z]}
      assert Parser.parse_expression("01/01/2025") == {:ok, ~U[2025-01-01 00:00:00Z]}

      assert Parser.parse_expression("13/01/2024") == {:error, "invalid date: 13/01/2024"}
      assert Parser.parse_expression("01/32/2024") == {:error, "invalid date: 01/32/2024"}
      assert Parser.parse_expression("02/30/2024") == {:error, "invalid date: 02/30/2024"}
    end

    test "parses yyyy-mm-dd format as UTC DateTime at midnight" do
      assert Parser.parse_expression("2024-12-25") == {:ok, ~U[2024-12-25 00:00:00Z]}
      assert Parser.parse_expression("2025-01-01") == {:ok, ~U[2025-01-01 00:00:00Z]}

      assert Parser.parse_expression("2024-13-01") == {:error, "invalid date: 2024-13-01"}
      assert Parser.parse_expression("2024-01-32") == {:error, "invalid date: 2024-01-32"}
      assert Parser.parse_expression("2024-02-30") == {:error, "invalid date: 2024-02-30"}
    end

    test "returns error for empty or blank input" do
      assert Parser.parse_expression("") == {:error, "empty expression"}
      assert Parser.parse_expression("    ") == {:error, "empty expression"}
    end

    test "returns error for non-string input" do
      assert Parser.parse_expression(nil) == {:error, "expected a string"}
      assert Parser.parse_expression(123) == {:error, "expected a string"}
    end

    test "parses beginning of durations" do
      ref = ~U[2025-01-27 13:45:30.123456Z]

      assert Parser.parse_expression("beginning of 2 seconds from now", reference_date: ref) ==
               {:ok, %{DateTime.add(ref, 2, :second) | microsecond: {0, 6}}}

      assert Parser.parse_expression("beginning of 3 minutes from now", reference_date: ref) ==
               {:ok, %{DateTime.add(ref, 3 * 60, :second) | second: 0, microsecond: {0, 6}}}

      assert Parser.parse_expression("beginning of 4 hours from now", reference_date: ref) ==
               {:ok,
                %{DateTime.add(ref, 4 * 3600, :second) | minute: 0, second: 0, microsecond: {0, 6}}}

      assert Parser.parse_expression("beginning of 2 days from now", reference_date: ref) ==
               {:ok,
                %{
                  DateTime.add(ref, 2 * 86400, :second)
                  | hour: 0,
                    minute: 0,
                    second: 0,
                    microsecond: {0, 6}
                }}

      future = DateTime.add(ref, 2 * 7 * 86400, :second)
      monday = DateTime.add(future, -((Date.day_of_week(future) - 1) * 86400), :second)

      assert Parser.parse_expression("beginning of 2 weeks from now", reference_date: ref) ==
               {:ok, %{monday | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}}

      future_month = DateTime.shift(ref, [{:month, 3}])

      assert Parser.parse_expression("beginning of 3 months from now", reference_date: ref) ==
               {:ok,
                %{future_month | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 6}}}

      future_year = DateTime.shift(ref, [{:year, 2}])

      assert Parser.parse_expression("beginning of 2 years from now", reference_date: ref) ==
               {:ok,
                %{
                  future_year
                  | month: 1,
                    day: 1,
                    hour: 0,
                    minute: 0,
                    second: 0,
                    microsecond: {0, 6}
                }}
    end

    test "parses end of durations" do
      ref = ~U[2025-01-27 13:45:30.123456Z]

      assert Parser.parse_expression("end of 2 seconds from now", reference_date: ref) ==
               {:ok, %{DateTime.add(ref, 2, :second) | microsecond: {999_999, 6}}}

      assert Parser.parse_expression("end of 3 minutes from now", reference_date: ref) ==
               {:ok,
                %{DateTime.add(ref, 3 * 60, :second) | second: 59, microsecond: {999_999, 6}}}

      assert Parser.parse_expression("end of 4 hours from now", reference_date: ref) ==
               {:ok,
                %{
                  DateTime.add(ref, 4 * 3600, :second)
                  | minute: 59,
                    second: 59,
                    microsecond: {999_999, 6}
                }}

      assert Parser.parse_expression("end of 2 days from now", reference_date: ref) ==
               {:ok,
                %{
                  DateTime.add(ref, 2 * 86400, :second)
                  | hour: 23,
                    minute: 59,
                    second: 59,
                    microsecond: {999_999, 6}
                }}

      future = DateTime.add(ref, 2 * 7 * 86400, :second)
      sunday = DateTime.add(future, (7 - Date.day_of_week(future)) * 86400, :second)

      assert Parser.parse_expression("end of 2 weeks from now", reference_date: ref) ==
               {:ok,
                %{sunday | hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}}

      future_month = DateTime.shift(ref, [{:month, 3}])
      days_in_month = Calendar.ISO.days_in_month(future_month.year, future_month.month)

      assert Parser.parse_expression("end of 3 months from now", reference_date: ref) ==
               {:ok,
                %{
                  future_month
                  | day: days_in_month,
                    hour: 23,
                    minute: 59,
                    second: 59,
                    microsecond: {999_999, 6}
                }}

      future_year = DateTime.shift(ref, [{:year, 2}])

      assert Parser.parse_expression("end of 2 years from now", reference_date: ref) ==
               {:ok,
                %{
                  future_year
                  | month: 12,
                    day: 31,
                    hour: 23,
                    minute: 59,
                    second: 59,
                    microsecond: {999_999, 6}
                }}
    end

    test "'beginning of' and 'end of' propagate duration errors" do
      assert {:ok, %DateTime{}} = Parser.parse_expression("beginning of 2 seconds ago")

      assert Parser.parse_expression("end of garbage") ==
               {:error, "unsupported duration format: garbage"}
    end
  end
end
