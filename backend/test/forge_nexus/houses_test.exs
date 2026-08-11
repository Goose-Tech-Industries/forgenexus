defmodule ForgeNexus.HousesTest do
  use ExUnit.Case, async: true

  alias ForgeNexus.Houses

  describe "monthly_cents/1" do
    test "no invited creators is just the base price" do
      assert Houses.monthly_cents(0) == 14_900
    end

    test "one invited creator is still just the base price — the first creator slot is included" do
      assert Houses.monthly_cents(1) == 14_900
    end

    test "a second invited creator is where the per-creator add-on starts" do
      assert Houses.monthly_cents(2) == 14_900 + 2_500
    end

    test "each additional creator beyond the first adds the per-creator rate" do
      assert Houses.monthly_cents(3) == 14_900 + 2 * 2_500
      assert Houses.monthly_cents(5) == 14_900 + 4 * 2_500
    end
  end
end
