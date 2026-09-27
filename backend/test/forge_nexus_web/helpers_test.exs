defmodule ForgeNexusWeb.HelpersTest do
  use ExUnit.Case, async: true

  alias ForgeNexusWeb.Helpers

  describe "safe_to_integer/2" do
    test "returns integer unchanged when passed an integer" do
      assert Helpers.safe_to_integer(42) == 42
      assert Helpers.safe_to_integer(-10, 100) == -10
      assert Helpers.safe_to_integer(0, 5) == 0
    end

    test "parses valid integer strings" do
      assert Helpers.safe_to_integer("123") == 123
      assert Helpers.safe_to_integer("-456") == -456
      assert Helpers.safe_to_integer("100px", 50) == 100
    end

    test "falls back to default when string parsing fails" do
      assert Helpers.safe_to_integer("not_a_number") == 0
      assert Helpers.safe_to_integer("abc", 50) == 50
      assert Helpers.safe_to_integer("", 99) == 99
    end

    test "falls back to default for non-integer, non-binary values" do
      assert Helpers.safe_to_integer(nil) == 0
      assert Helpers.safe_to_integer(nil, 42) == 42
      assert Helpers.safe_to_integer(:an_atom, 10) == 10
      assert Helpers.safe_to_integer([1, 2, 3], 7) == 7
      assert Helpers.safe_to_integer(%{a: 1}, -1) == -1
    end
  end
end
