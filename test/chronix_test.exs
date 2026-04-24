defmodule ChronixTest do
  use ExUnit.Case, async: true

  describe "parse/2" do
    test "returns {:ok, datetime} on success" do
      ref = ~U[2025-01-27 00:00:00Z]

      assert Chronix.parse("in 1 day", reference_date: ref) ==
               {:ok, DateTime.add(ref, 86_400, :second)}
    end

    test "returns {:error, reason} on failure" do
      assert {:error, _} = Chronix.parse("not a date")
      assert {:error, _} = Chronix.parse("")
      assert {:error, _} = Chronix.parse("in 2 seconds ago")
    end

    test "honors reference_date for 'today' and 'now'" do
      ref = ~U[2025-01-27 12:00:00Z]
      assert Chronix.parse("today", reference_date: ref) == {:ok, ref}
      assert Chronix.parse("now", reference_date: ref) == {:ok, ref}
    end
  end

  describe "parse!/2" do
    test "returns the DateTime directly on success" do
      ref = ~U[2025-01-27 00:00:00Z]
      assert Chronix.parse!("in 1 day", reference_date: ref) == DateTime.add(ref, 86_400, :second)
    end

    test "raises ArgumentError on failure" do
      assert_raise ArgumentError, fn -> Chronix.parse!("not a date") end
      assert_raise ArgumentError, fn -> Chronix.parse!("in 2 seconds ago") end
    end
  end

  describe "expression?/1" do
    test "identifies simple time expressions" do
      assert Chronix.expression?("now")
      assert Chronix.expression?("today")
      assert Chronix.expression?("NOW")
      assert Chronix.expression?("TODAY")
    end

    test "identifies 'X time' expressions" do
      assert Chronix.expression?("5 seconds")
      assert Chronix.expression?("10 minutes")
      assert Chronix.expression?("2 hours")
      assert Chronix.expression?("3 days")
      assert Chronix.expression?("4 weeks")
      assert Chronix.expression?("6 months")
      assert Chronix.expression?("1 year")
      assert Chronix.expression?("100 years")
    end

    test "identifies 'in X time' expressions" do
      assert Chronix.expression?("in 5 seconds")
      assert Chronix.expression?("in 10 minutes")
      assert Chronix.expression?("in 2 hours")
      assert Chronix.expression?("in 3 days")
      assert Chronix.expression?("in 4 weeks")
      assert Chronix.expression?("in 6 months")
      assert Chronix.expression?("in 1 year")
      assert Chronix.expression?("in 100 years")
    end

    test "identifies 'X time from now' expressions" do
      assert Chronix.expression?("5 seconds from now")
      assert Chronix.expression?("10 minutes from now")
      assert Chronix.expression?("2 hours from now")
      assert Chronix.expression?("3 days from now")
      assert Chronix.expression?("4 weeks from now")
      assert Chronix.expression?("6 months from now")
      assert Chronix.expression?("1 year from now")
    end

    test "identifies 'X time ago' expressions" do
      assert Chronix.expression?("5 seconds ago")
      assert Chronix.expression?("10 minutes ago")
      assert Chronix.expression?("2 hours ago")
      assert Chronix.expression?("3 days ago")
      assert Chronix.expression?("4 weeks ago")
      assert Chronix.expression?("6 months ago")
      assert Chronix.expression?("1 year ago")
    end

    test "identifies expressions with 'beginning of'" do
      assert Chronix.expression?("beginning of 5 days from now")
      assert Chronix.expression?("beginning of 2 weeks from now")
      assert Chronix.expression?("beginning of 3 months from now")
      assert Chronix.expression?("beginning of 1 year from now")
      assert Chronix.expression?("beginning of 5 days ago")
      assert Chronix.expression?("beginning of 2 weeks ago")
    end

    test "identifies expressions with 'end of'" do
      assert Chronix.expression?("end of 5 days from now")
      assert Chronix.expression?("end of 2 weeks from now")
      assert Chronix.expression?("end of 1 year ago")
    end

    test "identifies day-of-week expressions" do
      for weekday <- ~w(monday tuesday wednesday thursday friday saturday sunday) do
        assert Chronix.expression?("next #{weekday}")
        assert Chronix.expression?("last #{weekday}")
      end
    end

    test "identifies time period expressions" do
      assert Chronix.expression?("next week")
      assert Chronix.expression?("next month")
      assert Chronix.expression?("next year")
      assert Chronix.expression?("last week")
      assert Chronix.expression?("last month")
      assert Chronix.expression?("last year")
    end

    test "identifies explicit-date formats" do
      assert Chronix.expression?("2023-01-01")
      assert Chronix.expression?("01/01/2023")
      assert Chronix.expression?("1/5/2024")
      assert Chronix.expression?("2024-1-5")
      assert Chronix.expression?("12-25-2024")
      assert Chronix.expression?("2024/12/25")
      assert Chronix.expression?("2024-12-25T15:30:00Z")
      assert Chronix.expression?("2024-12-25T15:30:00+02:00")
    end

    test "identifies tomorrow and yesterday" do
      assert Chronix.expression?("tomorrow")
      assert Chronix.expression?("yesterday")
      assert Chronix.expression?("TOMORROW")
      assert Chronix.expression?("  yesterday  ")
    end

    test "identifies 'the day after tomorrow' / 'the day before yesterday'" do
      assert Chronix.expression?("the day after tomorrow")
      assert Chronix.expression?("day after tomorrow")
      assert Chronix.expression?("the day before yesterday")
      assert Chronix.expression?("day before yesterday")
      assert Chronix.expression?("THE DAY AFTER TOMORROW")
    end

    test "identifies 'a' and 'an' quantifier expressions" do
      assert Chronix.expression?("in a week")
      assert Chronix.expression?("an hour ago")
      assert Chronix.expression?("a year from now")
      assert Chronix.expression?("a day")
    end

    test "identifies extra units (quarter, fortnight, decade, century)" do
      assert Chronix.expression?("in 1 quarter")
      assert Chronix.expression?("2 quarters ago")
      assert Chronix.expression?("in a fortnight")
      assert Chronix.expression?("in 1 decade")
      assert Chronix.expression?("in 2 centuries")
      assert Chronix.expression?("in 0.5 decades")
    end

    test "identifies pleonasms ('this week', 'tonight', 'tomorrow morning', etc.)" do
      assert Chronix.expression?("this week")
      assert Chronix.expression?("this month")
      assert Chronix.expression?("this year")
      assert Chronix.expression?("this morning")
      assert Chronix.expression?("this afternoon")
      assert Chronix.expression?("this evening")
      assert Chronix.expression?("tonight")
      assert Chronix.expression?("last night")
      assert Chronix.expression?("tomorrow morning")
      assert Chronix.expression?("yesterday evening")
      assert Chronix.expression?("on monday")
      assert Chronix.expression?("this friday")
    end

    test "identifies time-of-day expressions" do
      assert Chronix.expression?("noon")
      assert Chronix.expression?("midnight")
      assert Chronix.expression?("3pm")
      assert Chronix.expression?("3:15pm")
      assert Chronix.expression?("15:30")
      assert Chronix.expression?("at 3pm")
      refute Chronix.expression?("25:00")
      refute Chronix.expression?("13pm")
    end

    test "identifies combined date+time expressions" do
      assert Chronix.expression?("tomorrow at 3pm")
      assert Chronix.expression?("next monday at noon")
      assert Chronix.expression?("yesterday at 9:30am")
      assert Chronix.expression?("2024-12-25 at 3pm")
      assert Chronix.expression?("in 3 days at 8am")
      refute Chronix.expression?("tomorrow at nothing")
    end

    test "identifies numeric-word durations" do
      assert Chronix.expression?("in five days")
      assert Chronix.expression?("twenty years ago")
      assert Chronix.expression?("in twenty one hours")
      assert Chronix.expression?("thirty-five minutes from now")
    end

    test "identifies word-date expressions" do
      assert Chronix.expression?("January 1, 2025")
      assert Chronix.expression?("Jan 1 2025")
      assert Chronix.expression?("1 Jan 2025")
      assert Chronix.expression?("the 1st of January")
      assert Chronix.expression?("December 31st, 2024")
      assert Chronix.expression?("March 15")
      refute Chronix.expression?("Jan 32 2025")
      refute Chronix.expression?("Notamonth 1 2025")
    end

    test "identifies fractional durations" do
      assert Chronix.expression?("in 1.5 hours")
      assert Chronix.expression?("0.5 days ago")
      assert Chronix.expression?("2.5 weeks from now")
      refute Chronix.expression?("in 1.5 months")
      refute Chronix.expression?("in 0.5 years")
    end

    test "rejects invalid expressions" do
      refute Chronix.expression?("next")
      refute Chronix.expression?("last")
      refute Chronix.expression?("in days")
      refute Chronix.expression?("in 5")
      refute Chronix.expression?("ago")
      refute Chronix.expression?("beginning")
      refute Chronix.expression?("beginning of")
      refute Chronix.expression?("random text")
      refute Chronix.expression?("")
      refute Chronix.expression?("    ")
    end

    test "is anchored — rejects strings that merely contain a valid expression" do
      refute Chronix.expression?("garbage in 2 days garbage")
      refute Chronix.expression?("todayyy")
      refute Chronix.expression?("nowhere")
      refute Chronix.expression?("5 seconds and some text")
    end

    test "rejects contradictions like 'in X Y ago'" do
      refute Chronix.expression?("in 2 seconds ago")
      refute Chronix.expression?("in 5 days ago")
    end

    test "rejects non-binary input" do
      refute Chronix.expression?(nil)
      refute Chronix.expression?(123)
      refute Chronix.expression?(:atom)
    end
  end
end
