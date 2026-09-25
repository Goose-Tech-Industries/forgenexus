defmodule ForgeNexus.Social.SocialSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Social.{
    CommunityTemplate,
    GiftCard,
    GiftTier,
    Icebreaker,
    Poke,
    Referral,
    StatusPost,
    StatusPostComment,
    StatusPostLike,
    UserPremium,
    WatchAlong
  }

  describe "CommunityTemplate" do
    test "valid changeset, categories/0 and inclusion" do
      categories = CommunityTemplate.categories()
      assert "gaming" in categories
      assert "tech" in categories

      for cat <- categories do
        cs =
          CommunityTemplate.changeset(%CommunityTemplate{}, %{
            name: "Template #{cat}",
            category: cat,
            template_data: %{"channels" => ["general"]}
          })

        assert cs.valid?
        assert get_field(cs, :category) == cat
      end

      # Required fields
      req_cs = CommunityTemplate.changeset(%CommunityTemplate{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).template_data

      # Invalid category
      bad_cat_cs =
        CommunityTemplate.changeset(%CommunityTemplate{}, %{
          name: "Bad",
          template_data: %{},
          category: "outer_space"
        })

      refute bad_cat_cs.valid?
      assert "is invalid" in errors_on(bad_cat_cs).category
    end
  end

  describe "GiftCard" do
    test "valid changeset, generate_code/0 and inclusions" do
      code = GiftCard.generate_code()
      assert is_binary(code)
      assert byte_size(code) > 5

      for type <- ~w(points money premium_time) do
        for status <- ~w(active redeemed expired) do
          cs =
            GiftCard.changeset(%GiftCard{}, %{
              code: "GIFT-1234",
              type: type,
              status: status
            })

          assert cs.valid?
          assert get_field(cs, :type) == type
          assert get_field(cs, :status) == status
        end
      end

      # Required code
      req_cs = GiftCard.changeset(%GiftCard{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).code

      # Invalid inclusions
      bad_cs =
        GiftCard.changeset(%GiftCard{}, %{
          code: "TEST",
          type: "gold",
          status: "destroyed"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).type
      assert "is invalid" in errors_on(bad_cs).status
    end
  end

  describe "GiftTier" do
    test "valid changeset, tiers/0, default_gifts/0 and validations" do
      tiers = GiftTier.tiers()
      assert "legendary" in tiers

      default_gifts = GiftTier.default_gifts()
      assert is_list(default_gifts)
      assert length(default_gifts) > 0

      for tier <- tiers do
        cs =
          GiftTier.changeset(%GiftTier{}, %{
            name: "Gift #{tier}",
            tier: tier,
            cost: 100,
            animation_type: "float_up"
          })

        assert cs.valid?
      end

      # Required fields
      req_cs = GiftTier.changeset(%GiftTier{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).tier
      assert "can't be blank" in errors_on(req_cs).cost

      # Invalid tier, animation, cost <= 0
      bad_cs =
        GiftTier.changeset(%GiftTier{}, %{
          name: "Bad",
          tier: "mythic",
          cost: 0,
          animation_type: "teleport"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).tier
      assert "is invalid" in errors_on(bad_cs).animation_type
      assert "must be greater than 0" in errors_on(bad_cs).cost
    end
  end

  describe "Icebreaker" do
    @uid1 Ecto.UUID.generate()
    @uid2 Ecto.UUID.generate()

    test "valid changeset, types/0, random_questions/0 and validations" do
      types = Icebreaker.types()
      assert "would_you_rather" in types

      questions = Icebreaker.random_questions()
      assert is_map(questions)
      assert map_size(questions) > 0

      for type <- types do
        cs =
          Icebreaker.changeset(%Icebreaker{}, %{
            sender_id: @uid1,
            recipient_id: @uid2,
            type: type,
            question: "Do you like cats?",
            status: "pending"
          })

        assert cs.valid?
      end

      # Required fields
      req_cs = Icebreaker.changeset(%Icebreaker{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).sender_id
      assert "can't be blank" in errors_on(req_cs).recipient_id
      assert "can't be blank" in errors_on(req_cs).type
      assert "can't be blank" in errors_on(req_cs).question

      # Invalid type and status
      bad_cs =
        Icebreaker.changeset(%Icebreaker{}, %{
          sender_id: @uid1,
          recipient_id: @uid2,
          type: "guess_number",
          question: "Q",
          status: "lost"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).type
      assert "is invalid" in errors_on(bad_cs).status
    end
  end

  describe "Poke" do
    @uid1 Ecto.UUID.generate()
    @uid2 Ecto.UUID.generate()

    test "valid changeset, types/0 and validations" do
      types = Poke.types()
      assert "high_five" in types

      for type <- types do
        cs =
          Poke.changeset(%Poke{}, %{
            sender_id: @uid1,
            recipient_id: @uid2,
            type: type,
            message: "Hey there!"
          })

        assert cs.valid?
      end

      req_cs = Poke.changeset(%Poke{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).sender_id
      assert "can't be blank" in errors_on(req_cs).recipient_id

      # Invalid type and message too long
      long_msg = String.duplicate("p", 201)

      bad_cs =
        Poke.changeset(%Poke{}, %{
          sender_id: @uid1,
          recipient_id: @uid2,
          type: "punch",
          message: long_msg
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).type
      assert "should be at most 200 character(s)" in errors_on(bad_cs).message
    end
  end

  describe "Referral" do
    @uid Ecto.UUID.generate()

    test "valid changeset and generate_code/1" do
      code = Referral.generate_code(@uid)
      assert is_binary(code)

      cs =
        Referral.changeset(%Referral{}, %{
          referrer_id: @uid,
          code: code,
          commission_rate: 0.20,
          commission_duration_months: 6,
          status: "active"
        })

      assert cs.valid?
      assert get_field(cs, :referrer_id) == @uid

      req_cs = Referral.changeset(%Referral{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).referrer_id
      assert "can't be blank" in errors_on(req_cs).code
    end
  end

  describe "StatusPost" do
    @uid Ecto.UUID.generate()

    test "valid changeset and validations" do
      for vis <- ~w(public friends_only private) do
        for mtype <- ~w(text image video poll clip_share thread_share) do
          cs =
            StatusPost.changeset(%StatusPost{}, %{
              user_id: @uid,
              body: "A fine post",
              visibility: vis,
              media_type: mtype
            })

          assert cs.valid?
          assert get_field(cs, :visibility) == vis
          assert get_field(cs, :media_type) == mtype
        end
      end

      # Required fields
      req_cs = StatusPost.changeset(%StatusPost{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).body

      # Length validations
      long_body = String.duplicate("s", 501)

      long_cs =
        StatusPost.changeset(%StatusPost{}, %{
          user_id: @uid,
          body: long_body
        })

      refute long_cs.valid?
      assert "should be at most 500 character(s)" in errors_on(long_cs).body

      # Invalid inclusions
      bad_cs =
        StatusPost.changeset(%StatusPost{}, %{
          user_id: @uid,
          body: "Hello",
          visibility: "secret",
          media_type: "hologram"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).visibility
      assert "is invalid" in errors_on(bad_cs).media_type
    end
  end

  describe "StatusPostComment and StatusPostLike structs" do
    test "struct instantiation" do
      assert %StatusPostComment{body: "Nice post!"}.body == "Nice post!"
      assert %StatusPostLike{}.id == nil
    end
  end

  describe "UserPremium" do
    @uid Ecto.UUID.generate()

    test "valid changeset, plans/0, plan_features/0, features_for_plan/1" do
      plans = UserPremium.plans()
      assert "pro" in plans

      plan_features = UserPremium.plan_features()
      assert is_map(plan_features)

      for plan <- plans do
        features = UserPremium.features_for_plan(plan)
        assert is_map(features)

        cs =
          UserPremium.changeset(%UserPremium{}, %{
            user_id: @uid,
            plan: plan,
            status: "active"
          })

        assert cs.valid?
        assert get_field(cs, :plan) == plan
      end

      # Required fields
      req_cs = UserPremium.changeset(%UserPremium{}, %{plan: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).plan

      # Invalid plan and status
      bad_cs =
        UserPremium.changeset(%UserPremium{}, %{
          user_id: @uid,
          plan: "diamond",
          status: "terminated"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).plan
      assert "is invalid" in errors_on(bad_cs).status
    end
  end

  describe "WatchAlong" do
    test "valid changeset, show_types/0, example_wrestling_segments/0 and validations" do
      show_types = WatchAlong.show_types()
      assert "wrestling" in show_types

      segments = WatchAlong.example_wrestling_segments()
      assert is_list(segments)
      assert length(segments) > 0

      start_time = ~U[2026-04-01 20:00:00Z]

      for stype <- show_types do
        for status <- ~w(upcoming live completed cancelled) do
          cs =
            WatchAlong.changeset(%WatchAlong{}, %{
              title: "Royal Rumble Watch Party",
              show_type: stype,
              starts_at: start_time,
              status: status
            })

          assert cs.valid?
          assert get_field(cs, :show_type) == stype
          assert get_field(cs, :status) == status
        end
      end

      # Required fields
      req_cs = WatchAlong.changeset(%WatchAlong{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
      assert "can't be blank" in errors_on(req_cs).starts_at

      # Invalid show_type and status
      bad_cs =
        WatchAlong.changeset(%WatchAlong{}, %{
          title: "Bad Party",
          starts_at: start_time,
          show_type: "amateur_video",
          status: "postponed"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).show_type
      assert "is invalid" in errors_on(bad_cs).status
    end
  end
end
