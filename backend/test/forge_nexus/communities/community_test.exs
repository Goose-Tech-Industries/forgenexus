defmodule ForgeNexus.Communities.CommunityTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Communities.{Community, CommunityMember}

  describe "Community schema & changesets" do
    @valid_attrs %{
      name: "Elixir Hub",
      slug: "elixir-hub",
      subdomain: "elixir-hub",
      custom_domain: "elixirhub.example.com",
      description: "A community for Elixir lovers",
      plan: "starter",
      plan_status: "active",
      feature_flags: %{"forums" => true, "chat" => true},
      limits: %{"storage_mb" => 5000},
      is_active: true,
      member_count: 42,
      monthly_fee_cents: 999,
      stripe_customer_id: "cus_12345",
      current_period_end: ~U[2026-12-31 23:59:59Z],
      cancel_at: nil
    }

    test "valid changeset succeeds with all attributes" do
      changeset = Community.changeset(%Community{}, @valid_attrs)
      assert changeset.valid?
      assert get_field(changeset, :name) == "Elixir Hub"
      assert get_field(changeset, :slug) == "elixir-hub"
      assert get_field(changeset, :plan) == "starter"
      assert get_field(changeset, :plan_status) == "active"
      assert get_field(changeset, :feature_flags) == %{"forums" => true, "chat" => true}
    end

    test "validates required fields: name and slug" do
      changeset = Community.changeset(%Community{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).slug
    end

    test "validates plan inclusion" do
      for valid_plan <- ~w(free starter social creator platform enterprise) do
        changeset = Community.changeset(%Community{}, Map.put(@valid_attrs, :plan, valid_plan))
        assert changeset.valid?
      end

      changeset = Community.changeset(%Community{}, Map.put(@valid_attrs, :plan, "invalid_plan"))
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).plan
    end

    test "validates plan_status inclusion" do
      for valid_status <- ~w(inactive active trialing past_due canceled unpaid) do
        changeset =
          Community.changeset(%Community{}, Map.put(@valid_attrs, :plan_status, valid_status))

        assert changeset.valid?
      end

      changeset =
        Community.changeset(%Community{}, Map.put(@valid_attrs, :plan_status, "destroyed"))

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).plan_status
    end

    test "validates slug format and length" do
      # Short slug (< 3 chars)
      short_cs = Community.changeset(%Community{}, Map.put(@valid_attrs, :slug, "ab"))
      refute short_cs.valid?
      assert errors_on(short_cs).slug != []

      # Long slug (> 63 chars)
      long_slug = String.duplicate("a", 64)
      long_cs = Community.changeset(%Community{}, Map.put(@valid_attrs, :slug, long_slug))
      refute long_cs.valid?
      assert errors_on(long_cs).slug != []

      # Invalid characters (uppercase or symbols)
      invalid_char_cs =
        Community.changeset(%Community{}, Map.put(@valid_attrs, :slug, "My Slug!"))

      refute invalid_char_cs.valid?
      assert "has invalid format" in errors_on(invalid_char_cs).slug
    end

    test "validates subdomain format" do
      invalid_sub =
        Community.changeset(%Community{}, Map.put(@valid_attrs, :subdomain, "bad_sub.domain!"))

      refute invalid_sub.valid?
      assert "has invalid format" in errors_on(invalid_sub).subdomain

      valid_sub =
        Community.changeset(%Community{}, Map.put(@valid_attrs, :subdomain, "my-sub-123"))

      assert valid_sub.valid?
    end

    test "plans/0 returns all supported plan tiers" do
      assert Community.plans() ==
               ~w(free forum community creator platform enterprise houses starter social)
    end

    test "default_features/0 returns the baseline features" do
      expected = %{
        "forums" => true,
        "profiles" => true,
        "chat" => false,
        "voice" => false,
        "streaming" => false,
        "economy" => false,
        "social_feed" => false,
        "automation" => false,
        "marketplace" => false,
        "white_label" => false
      }

      assert Community.default_features() == expected
    end

    test "has_feature?/2 checks specific flags and falls back to default_features" do
      comm_with_flags = %Community{
        feature_flags: %{"forums" => true, "voice" => true, "beta_tool" => false}
      }

      assert Community.has_feature?(comm_with_flags, "forums")
      assert Community.has_feature?(comm_with_flags, "voice")
      refute Community.has_feature?(comm_with_flags, "beta_tool")
      refute Community.has_feature?(comm_with_flags, "non_existent")

      # When feature_flags is nil, falls back to default_features
      comm_nil_flags = %Community{feature_flags: nil}
      assert Community.has_feature?(comm_nil_flags, "forums")
      assert Community.has_feature?(comm_nil_flags, "profiles")
      refute Community.has_feature?(comm_nil_flags, "voice")
    end

    test "plan_features/0 returns valid feature sets for all tiers" do
      features = Community.plan_features()
      assert is_map(features)
      assert Map.has_key?(features, "free")
      assert Map.has_key?(features, "starter")
      assert Map.has_key?(features, "social")
      assert Map.has_key?(features, "creator")
      assert Map.has_key?(features, "platform")
      assert Map.has_key?(features, "enterprise")
      assert features["enterprise"]["white_label"] == true
    end
  end

  describe "CommunityMember schema & changesets" do
    @cid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset with default and custom roles" do
      cs = CommunityMember.changeset(%CommunityMember{}, %{community_id: @cid, user_id: @uid})
      assert cs.valid?
      assert get_field(cs, :role) == "member"

      for role <- ~w(member moderator admin owner) do
        role_cs =
          CommunityMember.changeset(%CommunityMember{}, %{
            community_id: @cid,
            user_id: @uid,
            role: role
          })

        assert role_cs.valid?
        assert get_field(role_cs, :role) == role
      end
    end

    test "requires community_id and user_id" do
      cs = CommunityMember.changeset(%CommunityMember{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).community_id
      assert "can't be blank" in errors_on(cs).user_id
    end

    test "validates role inclusion" do
      cs =
        CommunityMember.changeset(%CommunityMember{}, %{
          community_id: @cid,
          user_id: @uid,
          role: "superhero"
        })

      refute cs.valid?
      assert "is invalid" in errors_on(cs).role
    end
  end
end
