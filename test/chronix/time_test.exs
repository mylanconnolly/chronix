defmodule Chronix.TimeTest do
  use ExUnit.Case, async: true

  alias Chronix.Time, as: CT

  describe "parse/1" do
    test "parses 'noon' and 'midnight'" do
      assert CT.parse("noon") == {:ok, ~T[12:00:00.000000]}
      assert CT.parse("midnight") == {:ok, ~T[00:00:00.000000]}
      assert CT.parse("NOON") == {:ok, ~T[12:00:00.000000]}
    end

    test "parses meridiem forms" do
      assert CT.parse("3pm") == {:ok, ~T[15:00:00.000000]}
      assert CT.parse("3 pm") == {:ok, ~T[15:00:00.000000]}
      assert CT.parse("3 PM") == {:ok, ~T[15:00:00.000000]}
      assert CT.parse("3 p.m.") == {:ok, ~T[15:00:00.000000]}
      assert CT.parse("3am") == {:ok, ~T[03:00:00.000000]}
      assert CT.parse("9:15am") == {:ok, ~T[09:15:00.000000]}
      assert CT.parse("9:15:30pm") == {:ok, ~T[21:15:30.000000]}
      assert CT.parse("  3pm  ") == {:ok, ~T[15:00:00.000000]}
    end

    test "handles 12am and 12pm correctly" do
      assert CT.parse("12am") == {:ok, ~T[00:00:00.000000]}
      assert CT.parse("12pm") == {:ok, ~T[12:00:00.000000]}
      assert CT.parse("12:30am") == {:ok, ~T[00:30:00.000000]}
      assert CT.parse("12:30pm") == {:ok, ~T[12:30:00.000000]}
    end

    test "parses 24-hour forms" do
      assert CT.parse("15:30") == {:ok, ~T[15:30:00.000000]}
      assert CT.parse("15:30:45") == {:ok, ~T[15:30:45.000000]}
      assert CT.parse("00:00") == {:ok, ~T[00:00:00.000000]}
      assert CT.parse("23:59:59") == {:ok, ~T[23:59:59.000000]}
      assert CT.parse("03:15") == {:ok, ~T[03:15:00.000000]}
    end

    test "rejects out-of-range components" do
      assert {:error, _} = CT.parse("25:00")
      assert {:error, _} = CT.parse("13pm")
      assert {:error, _} = CT.parse("0am")
      assert {:error, _} = CT.parse("15:60")
      assert {:error, _} = CT.parse("15:30:61")
    end

    test "rejects invalid shapes" do
      assert {:error, _} = CT.parse("")
      assert {:error, _} = CT.parse("not a time")
      assert {:error, _} = CT.parse("3")
      assert {:error, _} = CT.parse("3 hours")
      assert {:error, _} = CT.parse("3:15:30:45")
    end

    test "rejects non-binary input" do
      assert {:error, _} = CT.parse(nil)
      assert {:error, _} = CT.parse(123)
    end
  end
end
