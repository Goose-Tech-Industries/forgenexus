defmodule ForgeNexus.Forums.ThreadSubscriptionTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Forums.ThreadSubscription

  describe "ThreadSubscription schema & changesets" do
    @uid Ecto.UUID.generate()
    @tid Ecto.UUID.generate()

    test "valid changeset with default notification_level" do
      cs = ThreadSubscription.changeset(%ThreadSubscription{}, %{user_id: @uid, thread_id: @tid})
      assert cs.valid?
      assert get_field(cs, :notification_level) == "watching"
      assert get_field(cs, :user_id) == @uid
      assert get_field(cs, :thread_id) == @tid
    end

    test "valid changeset with explicit notification levels" do
      for level <- ~w(watching tracking muted) do
        cs =
          ThreadSubscription.changeset(%ThreadSubscription{}, %{
            user_id: @uid,
            thread_id: @tid,
            notification_level: level
          })

        assert cs.valid?
        assert get_field(cs, :notification_level) == level
      end
    end

    test "requires user_id and thread_id" do
      cs = ThreadSubscription.changeset(%ThreadSubscription{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).user_id
      assert "can't be blank" in errors_on(cs).thread_id
    end

    test "validates notification_level inclusion" do
      cs =
        ThreadSubscription.changeset(%ThreadSubscription{}, %{
          user_id: @uid,
          thread_id: @tid,
          notification_level: "invalid_level"
        })

      refute cs.valid?
      assert "is invalid" in errors_on(cs).notification_level
    end
  end
end
