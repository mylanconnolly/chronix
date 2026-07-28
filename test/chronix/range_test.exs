defmodule Chronix.RangeTest do
  use ExUnit.Case, async: true

  # Wednesday, January 15, 2025
  @ref ~U[2025-01-15 10:30:45.123456Z]

  defp range(expr, opts \\ []) do
    Chronix.parse_range(expr, Keyword.put_new(opts, :reference_date, @ref))
  end

  describe "calendar periods — weeks" do
    test "'this week' covers the current ISO week (Monday through Sunday)" do
      assert range("this week") ==
               {:ok, {~U[2025-01-13 00:00:00.000000Z], ~U[2025-01-19 23:59:59.999999Z]}}
    end

    test "'last week' covers the previous ISO week" do
      assert range("last week") ==
               {:ok, {~U[2025-01-06 00:00:00.000000Z], ~U[2025-01-12 23:59:59.999999Z]}}
    end

    test "'next week' covers the following ISO week" do
      assert range("next week") ==
               {:ok, {~U[2025-01-20 00:00:00.000000Z], ~U[2025-01-26 23:59:59.999999Z]}}
    end

    test "week ranges straddle a year boundary" do
      # Thursday, January 1, 2026 — its ISO week starts Monday 2025-12-29
      ref = ~U[2026-01-01 12:00:00Z]

      assert Chronix.parse_range("this week", reference_date: ref) ==
               {:ok, {~U[2025-12-29 00:00:00.000000Z], ~U[2026-01-04 23:59:59.999999Z]}}

      assert Chronix.parse_range("last week", reference_date: ref) ==
               {:ok, {~U[2025-12-22 00:00:00.000000Z], ~U[2025-12-28 23:59:59.999999Z]}}
    end

    test "week ranges straddle a month boundary" do
      # Saturday, March 1, 2025 — its ISO week starts Monday 2025-02-24
      ref = ~U[2025-03-01 08:00:00Z]

      assert Chronix.parse_range("this week", reference_date: ref) ==
               {:ok, {~U[2025-02-24 00:00:00.000000Z], ~U[2025-03-02 23:59:59.999999Z]}}
    end
  end

  describe "calendar periods — months" do
    test "'this month' covers the current calendar month" do
      assert range("this month") ==
               {:ok, {~U[2025-01-01 00:00:00.000000Z], ~U[2025-01-31 23:59:59.999999Z]}}
    end

    test "'last month' crosses into the previous year" do
      assert range("last month") ==
               {:ok, {~U[2024-12-01 00:00:00.000000Z], ~U[2024-12-31 23:59:59.999999Z]}}
    end

    test "'next month' respects month lengths" do
      assert range("next month") ==
               {:ok, {~U[2025-02-01 00:00:00.000000Z], ~U[2025-02-28 23:59:59.999999Z]}}
    end

    test "'next month' from the 31st still lands in the next calendar month" do
      ref = ~U[2025-01-31 12:00:00Z]

      assert Chronix.parse_range("next month", reference_date: ref) ==
               {:ok, {~U[2025-02-01 00:00:00.000000Z], ~U[2025-02-28 23:59:59.999999Z]}}
    end

    test "'last month' covers a leap February" do
      ref = ~U[2024-03-10 12:00:00Z]

      assert Chronix.parse_range("last month", reference_date: ref) ==
               {:ok, {~U[2024-02-01 00:00:00.000000Z], ~U[2024-02-29 23:59:59.999999Z]}}
    end
  end

  describe "calendar periods — years" do
    test "'this year' covers the current calendar year" do
      assert range("this year") ==
               {:ok, {~U[2025-01-01 00:00:00.000000Z], ~U[2025-12-31 23:59:59.999999Z]}}
    end

    test "'last year' covers the previous calendar year" do
      assert range("last year") ==
               {:ok, {~U[2024-01-01 00:00:00.000000Z], ~U[2024-12-31 23:59:59.999999Z]}}
    end

    test "'next year' covers the following calendar year" do
      assert range("next year") ==
               {:ok, {~U[2026-01-01 00:00:00.000000Z], ~U[2026-12-31 23:59:59.999999Z]}}
    end
  end

  describe "day-granularity expressions" do
    test "'today' covers the reference date's whole day" do
      assert range("today") ==
               {:ok, {~U[2025-01-15 00:00:00.000000Z], ~U[2025-01-15 23:59:59.999999Z]}}
    end

    test "'yesterday' and 'tomorrow' cover whole days" do
      assert range("yesterday") ==
               {:ok, {~U[2025-01-14 00:00:00.000000Z], ~U[2025-01-14 23:59:59.999999Z]}}

      assert range("tomorrow") ==
               {:ok, {~U[2025-01-16 00:00:00.000000Z], ~U[2025-01-16 23:59:59.999999Z]}}
    end

    test "'the day after tomorrow' covers a whole day" do
      assert range("the day after tomorrow") ==
               {:ok, {~U[2025-01-17 00:00:00.000000Z], ~U[2025-01-17 23:59:59.999999Z]}}
    end

    test "explicit dates cover the whole day" do
      assert range("7/1/2026") ==
               {:ok, {~U[2026-07-01 00:00:00.000000Z], ~U[2026-07-01 23:59:59.999999Z]}}

      assert range("2026-07-01") ==
               {:ok, {~U[2026-07-01 00:00:00.000000Z], ~U[2026-07-01 23:59:59.999999Z]}}
    end

    test "explicit dates honor :endian" do
      assert range("1/7/2026", endian: :eu) ==
               {:ok, {~U[2026-07-01 00:00:00.000000Z], ~U[2026-07-01 23:59:59.999999Z]}}

      assert range("1/7/2026", endian: :us) ==
               {:ok, {~U[2026-01-07 00:00:00.000000Z], ~U[2026-01-07 23:59:59.999999Z]}}
    end

    test "word dates cover the whole day" do
      assert range("January 1, 2025") ==
               {:ok, {~U[2025-01-01 00:00:00.000000Z], ~U[2025-01-01 23:59:59.999999Z]}}

      assert range("the 15th of March 2024") ==
               {:ok, {~U[2024-03-15 00:00:00.000000Z], ~U[2024-03-15 23:59:59.999999Z]}}
    end

    test "word dates without a year default to the reference year" do
      assert range("March 15") ==
               {:ok, {~U[2025-03-15 00:00:00.000000Z], ~U[2025-03-15 23:59:59.999999Z]}}
    end

    test "weekday expressions cover the whole day" do
      # Reference is a Wednesday, so next monday is January 20
      assert range("next monday") ==
               {:ok, {~U[2025-01-20 00:00:00.000000Z], ~U[2025-01-20 23:59:59.999999Z]}}

      # ... and last friday is January 10
      assert range("last friday") ==
               {:ok, {~U[2025-01-10 00:00:00.000000Z], ~U[2025-01-10 23:59:59.999999Z]}}

      # 'this wednesday' is the reference day itself
      assert range("this wednesday") ==
               {:ok, {~U[2025-01-15 00:00:00.000000Z], ~U[2025-01-15 23:59:59.999999Z]}}
    end
  end

  describe "relative durations" do
    test "day-or-coarser units cover the whole day the instant falls on" do
      assert range("3 days ago") ==
               {:ok, {~U[2025-01-12 00:00:00.000000Z], ~U[2025-01-12 23:59:59.999999Z]}}

      assert range("in 2 weeks") ==
               {:ok, {~U[2025-01-29 00:00:00.000000Z], ~U[2025-01-29 23:59:59.999999Z]}}

      assert range("in a fortnight") ==
               {:ok, {~U[2025-01-29 00:00:00.000000Z], ~U[2025-01-29 23:59:59.999999Z]}}

      assert range("in 6 months") ==
               {:ok, {~U[2025-07-15 00:00:00.000000Z], ~U[2025-07-15 23:59:59.999999Z]}}

      assert range("a year from now") ==
               {:ok, {~U[2026-01-15 00:00:00.000000Z], ~U[2026-01-15 23:59:59.999999Z]}}
    end

    test "sub-day units stay instants" do
      shifted = DateTime.add(@ref, -2 * 3600, :second)
      assert range("2 hours ago") == {:ok, {shifted, shifted}}

      shifted = DateTime.add(@ref, 90 * 60, :second)
      assert range("in 90 minutes") == {:ok, {shifted, shifted}}
    end

    test "fractional day-unit durations stay instants" do
      shifted = DateTime.add(@ref, 36 * 3600, :second)
      assert range("in 1.5 days") == {:ok, {shifted, shifted}}
    end

    test "numeric-word durations are classified like their digit forms" do
      assert range("three days ago") == range("3 days ago")
      assert range("in five hours") == range("in 5 hours")
    end
  end

  describe "instants" do
    test "'now' is a zero-width range at the reference date" do
      assert range("now") == {:ok, {@ref, @ref}}
    end

    test "bare times-of-day are zero-width ranges on the reference day" do
      noon = ~U[2025-01-15 12:00:00.000000Z]
      assert range("noon") == {:ok, {noon, noon}}

      three_pm = ~U[2025-01-15 15:00:00.000000Z]
      assert range("3pm") == {:ok, {three_pm, three_pm}}
    end

    test "combined '<date> at <time>' expressions are zero-width" do
      dt = ~U[2025-01-16 15:00:00.000000Z]
      assert range("tomorrow at 3pm") == {:ok, {dt, dt}}

      dt = ~U[2025-01-20 12:00:00.000000Z]
      assert range("next monday at noon") == {:ok, {dt, dt}}
    end

    test "time-of-day pleonasms are zero-width" do
      dt = ~U[2025-01-15 09:00:00.000000Z]
      assert range("this morning") == {:ok, {dt, dt}}

      dt = ~U[2025-01-15 20:00:00.000000Z]
      assert range("tonight") == {:ok, {dt, dt}}
    end

    test "ISO-8601 timestamps are zero-width" do
      dt = ~U[2024-12-25 15:30:00Z]
      assert range("2024-12-25T15:30:00Z") == {:ok, {dt, dt}}

      # Non-UTC offsets convert to UTC, same as parse/2
      dt = ~U[2024-12-25 13:30:00Z]
      assert range("2024-12-25T15:30:00+02:00") == {:ok, {dt, dt}}
    end

    test "'beginning of' / 'end of' boundaries are zero-width" do
      dt = ~U[2025-01-17 00:00:00.000000Z]
      assert range("beginning of 2 days from now") == {:ok, {dt, dt}}

      dt = ~U[2025-01-26 23:59:59.999999Z]
      assert range("end of 1 week from now") == {:ok, {dt, dt}}
    end
  end

  describe "parity with parse/2" do
    test "every expression parse/2 accepts, parse_range/2 accepts (and start <= end)" do
      expressions = [
        "now",
        "today",
        "tomorrow",
        "yesterday",
        "the day after tomorrow",
        "day before yesterday",
        "this week",
        "this month",
        "this year",
        "next week",
        "next month",
        "next year",
        "last week",
        "last month",
        "last year",
        "next monday",
        "last friday",
        "this friday",
        "on monday",
        "in 3 days",
        "3 days ago",
        "in 2 weeks",
        "in 6 months",
        "a year from now",
        "in a fortnight",
        "in 2 quarters",
        "in 1 decade",
        "2 hours ago",
        "in 90 minutes",
        "in 1.5 hours",
        "0.5 days ago",
        "in five days",
        "twenty years ago",
        "beginning of 2 days from now",
        "end of 1 week from now",
        "this morning",
        "this afternoon",
        "tonight",
        "last night",
        "tomorrow morning",
        "yesterday evening",
        "noon",
        "midnight",
        "3pm",
        "3:15pm",
        "15:30",
        "at 3pm",
        "tomorrow at 3pm",
        "next monday at noon",
        "in 3 days at 8am",
        "2024-12-25 at 3pm",
        "7/1/2026",
        "2026-07-01",
        "2024/12/25",
        "12-25-2024",
        "January 1, 2025",
        "Jan 1 2025",
        "1 Jan 2025",
        "the 15th of March 2024",
        "March 15",
        "2024-12-25T15:30:00Z",
        "2024-12-25T15:30:00+02:00"
      ]

      for expr <- expressions do
        assert {:ok, %DateTime{}} = Chronix.parse(expr, reference_date: @ref),
               "expected parse/2 to accept #{inspect(expr)}"

        assert {:ok, {start_dt, end_dt}} = Chronix.parse_range(expr, reference_date: @ref),
               "expected parse_range/2 to accept #{inspect(expr)}"

        assert DateTime.compare(start_dt, end_dt) in [:lt, :eq],
               "expected start <= end for #{inspect(expr)}"
      end
    end

    test "errors match parse/2 exactly" do
      for bad <- ["", "   ", "garbage", "in 2 seconds ago", "end of garbage", "in 1.5 months"] do
        assert Chronix.parse_range(bad, reference_date: @ref) ==
                 Chronix.parse(bad, reference_date: @ref)
      end
    end

    test "rejects non-binary input like parse/2" do
      assert Chronix.parse_range(nil) == {:error, "expected a string"}
      assert Chronix.parse_range(123) == {:error, "expected a string"}
    end
  end

  describe "parse_range!/2" do
    test "returns the range tuple directly on success" do
      assert Chronix.parse_range!("today", reference_date: @ref) ==
               {~U[2025-01-15 00:00:00.000000Z], ~U[2025-01-15 23:59:59.999999Z]}
    end

    test "raises ArgumentError on garbage" do
      assert_raise ArgumentError, fn -> Chronix.parse_range!("not a date") end
      assert_raise ArgumentError, fn -> Chronix.parse_range!("") end
      assert_raise ArgumentError, fn -> Chronix.parse_range!("in 2 seconds ago") end
    end
  end
end
