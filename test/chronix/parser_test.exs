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

    test "parses 'tomorrow' as 1 day after the reference" do
      ref = ~U[2025-01-27 12:00:00Z]

      assert Parser.parse_expression("tomorrow", reference_date: ref) ==
               {:ok, ~U[2025-01-28 12:00:00Z]}
    end

    test "parses 'yesterday' as 1 day before the reference" do
      ref = ~U[2025-01-27 12:00:00Z]

      assert Parser.parse_expression("yesterday", reference_date: ref) ==
               {:ok, ~U[2025-01-26 12:00:00Z]}
    end

    test "parses 'the day after tomorrow' as 2 days after the reference" do
      ref = ~U[2025-01-27 12:00:00Z]

      assert Parser.parse_expression("the day after tomorrow", reference_date: ref) ==
               {:ok, ~U[2025-01-29 12:00:00Z]}

      assert Parser.parse_expression("day after tomorrow", reference_date: ref) ==
               {:ok, ~U[2025-01-29 12:00:00Z]}
    end

    test "parses 'the day before yesterday' as 2 days before the reference" do
      ref = ~U[2025-01-27 12:00:00Z]

      assert Parser.parse_expression("the day before yesterday", reference_date: ref) ==
               {:ok, ~U[2025-01-25 12:00:00Z]}

      assert Parser.parse_expression("day before yesterday", reference_date: ref) ==
               {:ok, ~U[2025-01-25 12:00:00Z]}
    end

    test "tomorrow/yesterday honor month and year boundaries" do
      ref = ~U[2025-01-31 09:00:00Z]

      assert Parser.parse_expression("tomorrow", reference_date: ref) ==
               {:ok, ~U[2025-02-01 09:00:00Z]}

      ref = ~U[2025-01-01 09:00:00Z]

      assert Parser.parse_expression("yesterday", reference_date: ref) ==
               {:ok, ~U[2024-12-31 09:00:00Z]}
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

    test "parses fractional durations" do
      ref = ~U[2025-01-27 00:00:00Z]

      assert Parser.parse_expression("in 1.5 hours", reference_date: ref) ==
               {:ok, DateTime.add(ref, 5_400_000_000, :microsecond)}

      assert Parser.parse_expression("1.5 hours ago", reference_date: ref) ==
               {:ok, DateTime.add(ref, -5_400_000_000, :microsecond)}

      assert Parser.parse_expression("0.5 days from now", reference_date: ref) ==
               {:ok, DateTime.add(ref, 43_200_000_000, :microsecond)}
    end

    test "rejects fractional durations in 'beginning of' / 'end of'" do
      err = {:error, "'beginning of' and 'end of' require an integer duration"}

      assert Parser.parse_expression("beginning of 1.5 hours from now") == err
      assert Parser.parse_expression("end of 0.5 days from now") == err
    end

    test "propagates fractional month/year rejection" do
      assert Parser.parse_expression("in 1.5 months") ==
               {:error, "fractional months are not supported"}

      assert Parser.parse_expression("in 0.5 years") ==
               {:error, "fractional years are not supported"}
    end

    test "parses 'this week/month/year' as the reference date" do
      ref = ~U[2025-01-27 12:00:00Z]

      assert Parser.parse_expression("this week", reference_date: ref) == {:ok, ref}
      assert Parser.parse_expression("this month", reference_date: ref) == {:ok, ref}
      assert Parser.parse_expression("this year", reference_date: ref) == {:ok, ref}
    end

    test "parses time-of-day pleonasms" do
      ref = ~U[2025-01-27 12:00:00Z]

      assert Parser.parse_expression("this morning", reference_date: ref) ==
               {:ok, ~U[2025-01-27 09:00:00.000000Z]}

      assert Parser.parse_expression("this afternoon", reference_date: ref) ==
               {:ok, ~U[2025-01-27 15:00:00.000000Z]}

      assert Parser.parse_expression("this evening", reference_date: ref) ==
               {:ok, ~U[2025-01-27 19:00:00.000000Z]}

      assert Parser.parse_expression("tonight", reference_date: ref) ==
               {:ok, ~U[2025-01-27 20:00:00.000000Z]}

      assert Parser.parse_expression("last night", reference_date: ref) ==
               {:ok, ~U[2025-01-26 20:00:00.000000Z]}

      assert Parser.parse_expression("tomorrow morning", reference_date: ref) ==
               {:ok, ~U[2025-01-28 09:00:00.000000Z]}

      assert Parser.parse_expression("tomorrow night", reference_date: ref) ==
               {:ok, ~U[2025-01-28 20:00:00.000000Z]}

      assert Parser.parse_expression("yesterday afternoon", reference_date: ref) ==
               {:ok, ~U[2025-01-26 15:00:00.000000Z]}
    end

    test "parses 'on <weekday>' and 'this <weekday>' through duration path" do
      # Reference is a Monday
      monday = ~U[2025-01-27 12:00:00Z]

      assert Parser.parse_expression("this monday", reference_date: monday) == {:ok, monday}
      assert Parser.parse_expression("on monday", reference_date: monday) == {:ok, monday}

      assert Parser.parse_expression("on friday", reference_date: monday) ==
               {:ok, DateTime.add(monday, 4 * 86_400, :second)}
    end

    test "parses bare time-of-day against the reference date" do
      ref = ~U[2025-01-27 10:30:45.000000Z]

      assert Parser.parse_expression("3pm", reference_date: ref) ==
               {:ok, ~U[2025-01-27 15:00:00.000000Z]}

      assert Parser.parse_expression("9:15am", reference_date: ref) ==
               {:ok, ~U[2025-01-27 09:15:00.000000Z]}

      assert Parser.parse_expression("noon", reference_date: ref) ==
               {:ok, ~U[2025-01-27 12:00:00.000000Z]}

      assert Parser.parse_expression("midnight", reference_date: ref) ==
               {:ok, ~U[2025-01-27 00:00:00.000000Z]}

      assert Parser.parse_expression("15:30", reference_date: ref) ==
               {:ok, ~U[2025-01-27 15:30:00.000000Z]}
    end

    test "parses 'at <time>' as today at that time" do
      ref = ~U[2025-01-27 10:30:45.000000Z]

      assert Parser.parse_expression("at 3pm", reference_date: ref) ==
               {:ok, ~U[2025-01-27 15:00:00.000000Z]}

      assert Parser.parse_expression("at noon", reference_date: ref) ==
               {:ok, ~U[2025-01-27 12:00:00.000000Z]}
    end

    test "parses '<date> at <time>' combinations" do
      ref = ~U[2025-01-27 10:30:45.000000Z]

      assert Parser.parse_expression("today at 3pm", reference_date: ref) ==
               {:ok, ~U[2025-01-27 15:00:00.000000Z]}

      assert Parser.parse_expression("tomorrow at 3pm", reference_date: ref) ==
               {:ok, ~U[2025-01-28 15:00:00.000000Z]}

      assert Parser.parse_expression("yesterday at noon", reference_date: ref) ==
               {:ok, ~U[2025-01-26 12:00:00.000000Z]}

      assert Parser.parse_expression("next monday at 9am", reference_date: ref) ==
               {:ok, ~U[2025-02-03 09:00:00.000000Z]}

      assert Parser.parse_expression("last friday at 5:30pm", reference_date: ref) ==
               {:ok, ~U[2025-01-24 17:30:00.000000Z]}

      assert Parser.parse_expression("in 3 days at 8am", reference_date: ref) ==
               {:ok, ~U[2025-01-30 08:00:00.000000Z]}

      assert Parser.parse_expression("2024-12-25 at 3pm") ==
               {:ok, ~U[2024-12-25 15:00:00.000000Z]}

      assert Parser.parse_expression("12/25/2024 at midnight") ==
               {:ok, ~U[2024-12-25 00:00:00.000000Z]}
    end

    test "reports error if the time portion is invalid" do
      assert {:error, _} = Parser.parse_expression("tomorrow at not-a-time")
      assert {:error, _} = Parser.parse_expression("tomorrow at 25:00")
    end

    test "reports error if the date portion is invalid" do
      assert {:error, _} = Parser.parse_expression("nonsense at 3pm")
      assert {:error, _} = Parser.parse_expression("2024-13-01 at noon")
    end

    test "parses 'a' / 'an' as a count of 1" do
      ref = ~U[2025-01-27 00:00:00Z]

      assert Parser.parse_expression("in a week", reference_date: ref) ==
               {:ok, DateTime.shift(ref, [{:week, 1}])}

      assert Parser.parse_expression("an hour ago", reference_date: ref) ==
               {:ok, DateTime.add(ref, -3600, :second)}

      assert Parser.parse_expression("a year from now", reference_date: ref) ==
               {:ok, DateTime.shift(ref, [{:year, 1}])}
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

    test "accepts unpadded mm/dd/yyyy components" do
      assert Parser.parse_expression("1/5/2024") == {:ok, ~U[2024-01-05 00:00:00Z]}
      assert Parser.parse_expression("1/15/2024") == {:ok, ~U[2024-01-15 00:00:00Z]}
      assert Parser.parse_expression("12/5/2024") == {:ok, ~U[2024-12-05 00:00:00Z]}
    end

    test "rejects slash dates with stray chars or bad widths" do
      # Two-digit year not supported
      assert {:error, _} = Parser.parse_expression("1/5/24")
      # Three-digit month
      assert {:error, _} = Parser.parse_expression("001/05/2024")
      # Trailing garbage
      assert {:error, _} = Parser.parse_expression("1/5/2024abc")
    end

    test "parses yyyy-mm-dd format as UTC DateTime at midnight" do
      assert Parser.parse_expression("2024-12-25") == {:ok, ~U[2024-12-25 00:00:00Z]}
      assert Parser.parse_expression("2025-01-01") == {:ok, ~U[2025-01-01 00:00:00Z]}

      assert Parser.parse_expression("2024-13-01") == {:error, "invalid date: 2024-13-01"}
      assert Parser.parse_expression("2024-01-32") == {:error, "invalid date: 2024-01-32"}
      assert Parser.parse_expression("2024-02-30") == {:error, "invalid date: 2024-02-30"}
    end

    test "parses ISO-8601 timestamps" do
      assert Parser.parse_expression("2024-12-25T15:30:00Z") ==
               {:ok, ~U[2024-12-25 15:30:00Z]}

      assert Parser.parse_expression("2024-12-25T15:30:00.123456Z") ==
               {:ok, ~U[2024-12-25 15:30:00.123456Z]}

      # Non-UTC offsets are converted to UTC
      assert Parser.parse_expression("2024-12-25T15:30:00+02:00") ==
               {:ok, ~U[2024-12-25 13:30:00Z]}

      # Space separator is accepted
      assert Parser.parse_expression("2024-12-25 15:30:00Z") ==
               {:ok, ~U[2024-12-25 15:30:00Z]}

      # Leading/trailing whitespace tolerated
      assert Parser.parse_expression("  2024-12-25T15:30:00Z  ") ==
               {:ok, ~U[2024-12-25 15:30:00Z]}
    end

    test "rejects ISO-like strings missing required parts" do
      # No offset
      assert {:error, _} = Parser.parse_expression("2024-12-25T15:30:00")
      # Lowercase T/Z not valid ISO — and won't match other patterns either
      assert {:error, _} = Parser.parse_expression("2024-12-25t15:30:00z")
    end

    test "parses yyyy/mm/dd (unambiguous year-first slash form)" do
      assert Parser.parse_expression("2024/12/25") == {:ok, ~U[2024-12-25 00:00:00Z]}
      assert Parser.parse_expression("2024/1/5") == {:ok, ~U[2024-01-05 00:00:00Z]}
    end

    test "parses mm-dd-yyyy as US-style by default" do
      assert Parser.parse_expression("12-25-2024") == {:ok, ~U[2024-12-25 00:00:00Z]}
      assert Parser.parse_expression("1-5-2024") == {:ok, ~U[2024-01-05 00:00:00Z]}
    end

    test "honors :endian for ambiguous three-component dates" do
      # Slash form
      assert Parser.parse_expression("05/01/2024", endian: :us) ==
               {:ok, ~U[2024-05-01 00:00:00Z]}

      assert Parser.parse_expression("05/01/2024", endian: :eu) ==
               {:ok, ~U[2024-01-05 00:00:00Z]}

      # Dash form
      assert Parser.parse_expression("05-01-2024", endian: :us) ==
               {:ok, ~U[2024-05-01 00:00:00Z]}

      assert Parser.parse_expression("05-01-2024", endian: :eu) ==
               {:ok, ~U[2024-01-05 00:00:00Z]}

      # Unambiguous year-first form is unaffected by :endian
      assert Parser.parse_expression("2024-05-01", endian: :eu) ==
               {:ok, ~U[2024-05-01 00:00:00Z]}
    end

    test "rejects an invalid :endian value" do
      assert {:error, reason} = Parser.parse_expression("05/01/2024", endian: :weird)
      assert reason =~ "invalid :endian"
    end

    test "parses month-first word dates" do
      ref = ~U[2025-06-15 12:00:00Z]

      assert Parser.parse_expression("January 1, 2025", reference_date: ref) ==
               {:ok, ~U[2025-01-01 00:00:00Z]}

      assert Parser.parse_expression("January 1st, 2025", reference_date: ref) ==
               {:ok, ~U[2025-01-01 00:00:00Z]}

      assert Parser.parse_expression("Jan 1 2025", reference_date: ref) ==
               {:ok, ~U[2025-01-01 00:00:00Z]}

      assert Parser.parse_expression("December 31st, 2024", reference_date: ref) ==
               {:ok, ~U[2024-12-31 00:00:00Z]}
    end

    test "month-first without year defaults to reference year" do
      ref = ~U[2025-06-15 12:00:00Z]

      assert Parser.parse_expression("Jan 1", reference_date: ref) ==
               {:ok, ~U[2025-01-01 00:00:00Z]}

      assert Parser.parse_expression("March 15", reference_date: ref) ==
               {:ok, ~U[2025-03-15 00:00:00Z]}
    end

    test "parses day-first word dates" do
      ref = ~U[2025-06-15 12:00:00Z]

      assert Parser.parse_expression("1 Jan 2025", reference_date: ref) ==
               {:ok, ~U[2025-01-01 00:00:00Z]}

      assert Parser.parse_expression("1st Jan, 2025", reference_date: ref) ==
               {:ok, ~U[2025-01-01 00:00:00Z]}

      assert Parser.parse_expression("15 March", reference_date: ref) ==
               {:ok, ~U[2025-03-15 00:00:00Z]}
    end

    test "parses 'the Nth of <month>' form" do
      ref = ~U[2025-06-15 12:00:00Z]

      assert Parser.parse_expression("the 1st of January", reference_date: ref) ==
               {:ok, ~U[2025-01-01 00:00:00Z]}

      assert Parser.parse_expression("the 15th of March 2024", reference_date: ref) ==
               {:ok, ~U[2024-03-15 00:00:00Z]}
    end

    test "word dates validate the calendar" do
      assert Parser.parse_expression("Jan 32 2025") == {:error, "invalid date: jan 32 2025"}
      assert Parser.parse_expression("Feb 30 2024") == {:error, "invalid date: feb 30 2024"}
    end

    test "word dates compose with 'at <time>'" do
      assert Parser.parse_expression("January 1, 2025 at 3pm") ==
               {:ok, ~U[2025-01-01 15:00:00.000000Z]}

      assert Parser.parse_expression("the 15th of March 2024 at noon") ==
               {:ok, ~U[2024-03-15 12:00:00.000000Z]}
    end

    test "accepts unpadded yyyy-mm-dd components" do
      assert Parser.parse_expression("2024-1-5") == {:ok, ~U[2024-01-05 00:00:00Z]}
      assert Parser.parse_expression("2024-1-15") == {:ok, ~U[2024-01-15 00:00:00Z]}
      assert Parser.parse_expression("2024-12-5") == {:ok, ~U[2024-12-05 00:00:00Z]}
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
