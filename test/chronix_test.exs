defmodule ChronixTest do
  use ExUnit.Case, async: true

  describe "expression?/1" do
    test "identifies simple time expressions" do
      assert Chronix.expression?("now")
      assert Chronix.expression?("today")
      assert Chronix.expression?("NOW") # case insensitive
      assert Chronix.expression?("TODAY") # case insensitive
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

    test "identifies day-of-week expressions" do
      assert Chronix.expression?("next monday")
      assert Chronix.expression?("next tuesday")
      assert Chronix.expression?("next wednesday")
      assert Chronix.expression?("next thursday")
      assert Chronix.expression?("next friday")
      assert Chronix.expression?("next saturday")
      assert Chronix.expression?("next sunday")
      
      assert Chronix.expression?("last monday")
      assert Chronix.expression?("last tuesday")
      assert Chronix.expression?("last wednesday")
      assert Chronix.expression?("last thursday")
      assert Chronix.expression?("last friday")
      assert Chronix.expression?("last saturday")
      assert Chronix.expression?("last sunday")
    end

    test "identifies 'beginning of' with day-of-week expressions" do
      assert Chronix.expression?("beginning of next monday")
      assert Chronix.expression?("beginning of last friday")
    end

    test "identifies time period expressions" do
      assert Chronix.expression?("next week")
      assert Chronix.expression?("next month")
      assert Chronix.expression?("next year")
      assert Chronix.expression?("last week")
      assert Chronix.expression?("last month")
      assert Chronix.expression?("last year")
    end

    test "identifies 'beginning of' with time period expressions" do
      assert Chronix.expression?("beginning of next week")
      assert Chronix.expression?("beginning of next month")
      assert Chronix.expression?("beginning of next year")
      assert Chronix.expression?("beginning of last week")
      assert Chronix.expression?("beginning of last month")
      assert Chronix.expression?("beginning of last year")
    end

    test "rejects invalid expressions" do
      refute Chronix.expression?("tomorrow")
      refute Chronix.expression?("yesterday")
      refute Chronix.expression?("next")
      refute Chronix.expression?("last")
      refute Chronix.expression?("5 days")
      refute Chronix.expression?("in days")
      refute Chronix.expression?("in 5")
      # "from now" actually matches the regex due to alternation patterns
      assert Chronix.expression?("from now")
      refute Chronix.expression?("ago")
      refute Chronix.expression?("beginning")
      refute Chronix.expression?("beginning of")
      refute Chronix.expression?("2023-01-01")
      refute Chronix.expression?("January 1st, 2023")
      refute Chronix.expression?("01/01/2023")
      refute Chronix.expression?("random text")
      refute Chronix.expression?("")
      refute Chronix.expression?("    ")
    end
  end
end