defmodule ForgeNexus.Forums.ThreadRatingTest do
  use ExUnit.Case, async: true

  alias ForgeNexus.Forums.ThreadRating

  describe "ThreadRating.changeset/2 validations" do
    @valid_attrs %{
      rating: 5,
      user_id: "00000000-0000-0000-0000-000000000001",
      thread_id: "00000000-0000-0000-0000-000000000002"
    }

    test "valid attributes produce a valid changeset" do
      changeset = ThreadRating.changeset(%ThreadRating{}, @valid_attrs)
      assert changeset.valid?
    end

    test "accepts ratings from 1 to 5" do
      for r <- 1..5 do
        changeset = ThreadRating.changeset(%ThreadRating{}, Map.put(@valid_attrs, :rating, r))
        assert changeset.valid?, "expected rating #{r} to be valid"
      end
    end

    test "rejects rating lower than 1" do
      changeset = ThreadRating.changeset(%ThreadRating{}, Map.put(@valid_attrs, :rating, 0))
      refute changeset.valid?
      assert %{rating: ["must be greater than or equal to 1"]} = errors_on_changeset(changeset)
    end

    test "rejects rating greater than 5" do
      changeset = ThreadRating.changeset(%ThreadRating{}, Map.put(@valid_attrs, :rating, 6))
      refute changeset.valid?
      assert %{rating: ["must be less than or equal to 5"]} = errors_on_changeset(changeset)
    end

    test "requires user_id and thread_id" do
      changeset = ThreadRating.changeset(%ThreadRating{}, %{rating: 4})
      refute changeset.valid?
      errors = errors_on_changeset(changeset)
      assert errors[:user_id] != nil
      assert errors[:thread_id] != nil
    end
  end

  defp errors_on_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
