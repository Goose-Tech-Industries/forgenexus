defmodule ForgeNexus.Forums.ReputationEventTest do
  use ExUnit.Case, async: true

  alias ForgeNexus.Forums.ReputationEvent

  describe "ReputationEvent.changeset/2 validations" do
    @valid_attrs %{
      user_id: "00000000-0000-0000-0000-000000000001",
      event_type: "user_given",
      points: 2,
      source_type: "post",
      source_id: "00000000-0000-0000-0000-000000000002"
    }

    test "valid attributes produce a valid changeset" do
      changeset = ReputationEvent.changeset(%ReputationEvent{}, @valid_attrs)
      assert changeset.valid?
    end

    test "accepts all allowed event types" do
      allowed =
        ~w(post_liked achievement_earned thread_created best_answer user_given user_taken post_created manual)

      for event_type <- allowed do
        changeset =
          ReputationEvent.changeset(
            %ReputationEvent{},
            Map.put(@valid_attrs, :event_type, event_type)
          )

        assert changeset.valid?, "expected #{event_type} to be valid"
      end
    end

    test "rejects unauthorized event types" do
      changeset =
        ReputationEvent.changeset(
          %ReputationEvent{},
          Map.put(@valid_attrs, :event_type, "invalid_type_xyz")
        )

      refute changeset.valid?
    end

    test "requires user_id, event_type, and points" do
      changeset = ReputationEvent.changeset(%ReputationEvent{}, %{})
      refute changeset.valid?
      errors = errors_on_changeset(changeset)
      assert errors[:user_id] != nil
      assert errors[:event_type] != nil
      assert errors[:points] != nil
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
