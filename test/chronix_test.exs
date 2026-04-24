defmodule ChronixTest do
  use ExUnit.Case, async: true

  describe "parse/2" do
    test "returns {:ok, datetime} on success" do
      ref = ~U[2025-01-27 00:00:00Z]

      assert Chronix.parse("in 1 day", reference_date: ref) ==
               {:ok, DateTime.add(ref, 86_400, :second)}
    end

    test "returns {:error, reason} on failure" do
      assert {:error, _} = Chronix.parse("tomorrow")
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
      assert_raise ArgumentError, fn -> Chronix.parse!("tomorrow") end
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
    end

    test "rejects invalid expressions" do
      refute Chronix.expression?("tomorrow")
      refute Chronix.expression?("yesterday")
      refute Chronix.expression?("next")
      refute Chronix.expression?("last")
      refute Chronix.expression?("in days")
      refute Chronix.expression?("in 5")
      refute Chronix.expression?("ago")
      refute Chronix.expression?("beginning")
      refute Chronix.expression?("beginning of")
      refute Chronix.expression?("January 1st, 2023")
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
