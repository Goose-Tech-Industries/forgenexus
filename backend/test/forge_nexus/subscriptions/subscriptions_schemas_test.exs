defmodule ForgeNexus.Subscriptions.SubscriptionsSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Subscriptions.{SubscriptionTier, UserSubscription}

  describe "SubscriptionTier" do
    test "valid changeset" do
      cs =
        SubscriptionTier.changeset(%SubscriptionTier{}, %{
          name: "Gold Member",
          slug: "gold-member",
          tier_level: 2,
          price_monthly: Decimal.new("9.99"),
          upload_limit_mb: 50
        })

      assert cs.valid?
      assert get_field(cs, :tier_level) == 2

      req_cs = SubscriptionTier.changeset(%SubscriptionTier{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).tier_level

      bad_level_cs =
        SubscriptionTier.changeset(%SubscriptionTier{}, %{
          name: "Test",
          slug: "test",
          tier_level: 0
        })

      refute bad_level_cs.valid?
      assert "must be greater than 0" in errors_on(bad_level_cs).tier_level
    end
  end

  describe "UserSubscription" do
    @uid Ecto.UUID.generate()
    @tid Ecto.UUID.generate()

    test "valid changeset and status inclusions" do
      for status <- ["active", "cancelled", "expired", "trial", "paused"] do
        cs =
          UserSubscription.changeset(%UserSubscription{}, %{
            user_id: @uid,
            tier_id: @tid,
            status: status
          })

        assert cs.valid?
        assert get_field(cs, :status) == status
      end

      req_cs = UserSubscription.changeset(%UserSubscription{}, %{status: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).tier_id
      assert "can't be blank" in errors_on(req_cs).status

      bad_status_cs =
        UserSubscription.changeset(%UserSubscription{}, %{
          user_id: @uid,
          tier_id: @tid,
          status: "terminated"
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).status
    end
  end
end
