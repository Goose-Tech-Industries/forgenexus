defmodule ForgeNexus.Plugins.NodesProgressionTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Plugins.Engine.Context
  alias ForgeNexus.Accounts
  alias ForgeNexus.Forums
  alias ForgeNexus.Achievements
  alias ForgeNexus.Quests
  alias ForgeNexus.Collections
  alias ForgeNexus.Pets
  alias ForgeNexus.Inventory
  alias ForgeNexus.Repo

  # Achievement nodes (8)
  alias ForgeNexus.Plugins.Nodes.Achievement.{
    AwardBadge,
    CheckAchievement,
    CreateMilestone,
    DefineAchievement,
    DisplayBadge,
    GetBadges,
    HasBadge,
    RevokeBadge
  }

  # Quest nodes (8)
  alias ForgeNexus.Plugins.Nodes.Quest.{
    AdvanceQuest,
    CheckQuestStep,
    CompleteQuest,
    CreateDailyQuest,
    CreateQuestChain,
    DefineQuest,
    GetQuestProgress,
    StartQuest
  }

  # Collection nodes (6)
  alias ForgeNexus.Plugins.Nodes.Collection.{
    AddToSet,
    CheckCompletion,
    DefineSet,
    GetMissing,
    GetProgress,
    TradeCollectionItem
  }

  # Pet nodes (8)
  alias ForgeNexus.Plugins.Nodes.Pet.{
    BreedPets,
    CreatePet,
    GetPetStats,
    PetAction,
    PetBattle,
    PetCompete,
    PetDecay,
    PetEvolve
  }

  # Inventory nodes (12)
  alias ForgeNexus.Plugins.Nodes.Inventory.{
    ConsumeItem,
    CraftItem,
    DefineItem,
    EquipItem,
    GetInventory,
    GiveItem,
    HasItem,
    ItemDurability,
    ListForSale,
    OpenPack,
    RemoveItem,
    TransferItem
  }

  defp make_ctx do
    %Context{
      execution_id: Ecto.UUID.generate(),
      flow_id: Ecto.UUID.generate(),
      started_at: DateTime.utc_now()
    }
  end

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "prog_u_#{unique}",
        email: "prog_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_badge do
    unique = System.unique_integer([:positive])

    {:ok, badge} =
      Forums.create_badge(%{
        name: "Badge #{unique}",
        description: "A test badge",
        category: "achievement"
      })

    badge
  end

  defp create_pet_template do
    unique = System.unique_integer([:positive])

    %Pets.PetTemplate{}
    |> Pets.PetTemplate.changeset(%{
      name: "Dragon #{unique}",
      slug: "dragon-#{unique}",
      species: "dragon",
      description: "A fiery dragon",
      base_stats: %{"hunger" => 100, "happiness" => 100, "energy" => 100}
    })
    |> Repo.insert!()
  end

  defp create_item_template(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    defaults = %{
      name: "Item #{unique}",
      slug: "item-#{unique}",
      description: "Test item",
      rarity: "common",
      is_stackable: true,
      is_tradeable: true,
      is_consumable: false,
      category: "general",
      max_stack: 99
    }

    %Inventory.ItemTemplate{}
    |> Inventory.ItemTemplate.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # ============================================================================
  # ACHIEVEMENT NODES (8)
  # ============================================================================

  describe "Nodes.Achievement.AwardBadge" do
    test "awards a badge to a user and handles errors" do
      ctx = make_ctx()
      user = create_user()
      badge = create_badge()

      # Success path
      assert {:ok, %{success: true, was_new: true}, _} =
               AwardBadge.execute(%{}, %{"user_id" => user.id, "badge_id" => badge.id}, ctx)

      # Awarding again -> was_new: false
      assert {:ok, %{success: true, was_new: false}, _} =
               AwardBadge.execute(%{}, %{"user_id" => user.id, "badge_id" => badge.id}, ctx)

      # Error path (failed changeset)
      assert {:error, msg, _} =
               AwardBadge.execute(%{}, %{"user_id" => nil, "badge_id" => nil}, ctx)

      assert String.contains?(msg, "Failed to award badge")

      # Error path (invalid badge_id)
      assert {:error, msg, _} =
               AwardBadge.execute(
                 %{},
                 %{"user_id" => user.id, "badge_id" => Ecto.UUID.generate()},
                 ctx
               )

      assert String.contains?(msg, "Failed to award badge")

      assert :ok = AwardBadge.validate_config(%{})
      assert is_map(AwardBadge.schema())
    end
  end

  describe "Nodes.Achievement.CheckAchievement" do
    test "checks user progress and branches on earned / not_earned" do
      ctx = make_ctx()
      user = create_user()

      {:ok, achievement} =
        Achievements.define_achievement(%{
          name: "Test Post Achievement #{System.unique_integer()}",
          slug: "test-post-ach-#{System.unique_integer([:positive])}",
          criteria: %{"type" => "stat_threshold", "stat_key" => "post_count", "threshold" => 5}
        })

      # Not earned branch
      assert {:branch, "not_earned", %{progress: 0, target: 1, percentage: +0.0}, _} =
               CheckAchievement.execute(
                 %{},
                 %{"user_id" => user.id, "achievement_id" => achievement.id},
                 ctx
               )

      # Earned branch: user satisfies stat criteria
      ForgeNexus.UserStats.set_stat(user.id, "post_count", 10)

      assert {:branch, "earned", %{progress: _, target: _, percentage: _}, _} =
               CheckAchievement.execute(
                 %{},
                 %{"user_id" => user.id, "achievement_id" => achievement.id},
                 ctx
               )

      # Error branch (invalid achievement)
      assert {:error, msg, _} =
               CheckAchievement.execute(
                 %{},
                 %{"user_id" => user.id, "achievement_id" => Ecto.UUID.generate()},
                 ctx
               )

      assert String.contains?(msg, "Failed to check achievement")

      assert :ok = CheckAchievement.validate_config(%{})
      assert is_map(CheckAchievement.schema())
    end
  end

  describe "Nodes.Achievement.CreateMilestone" do
    test "creates milestones for stat type and validates config" do
      ctx = make_ctx()

      config = %{
        "stat_type" => "posts",
        "milestones" => "10, 50, invalid, 100",
        "reward_points_per" => 15
      }

      assert {:ok, %{milestones_created: 3, success: true}, _} =
               CreateMilestone.execute(config, %{}, ctx)

      # validate_config
      assert :ok =
               CreateMilestone.validate_config(%{"stat_type" => "posts", "milestones" => "10,20"})

      assert {:error, _} = CreateMilestone.validate_config(%{})
      assert {:error, _} = CreateMilestone.validate_config(%{"stat_type" => ""})

      assert {:error, _} =
               CreateMilestone.validate_config(%{"stat_type" => "posts", "milestones" => ""})

      assert is_map(CreateMilestone.schema())
    end
  end

  describe "Nodes.Achievement.DefineAchievement" do
    test "defines achievement with various criteria types and handles errors" do
      ctx = make_ctx()

      # Custom criteria
      assert {:ok, %{achievement_id: ach_id, success: true}, _} =
               DefineAchievement.execute(
                 %{"criteria_type" => "custom", "points" => 10},
                 %{"name" => "Custom Ach #{System.unique_integer()}", "description" => "A test"},
                 ctx
               )

      assert is_binary(ach_id)

      # All other criteria types: post_count, thread_count, reputation, streak, level, collection, other
      for ct <- ~w(post_count thread_count reputation streak level collection unknown) do
        assert {:ok, %{success: true}, _} =
                 DefineAchievement.execute(
                   %{"criteria_type" => ct, "criteria_value" => 10},
                   %{"name" => "#{ct} Ach #{System.unique_integer()}"},
                   ctx
                 )
      end

      # Error branch (nil name)
      assert {:error, msg, _} =
               DefineAchievement.execute(%{}, %{"name" => nil}, ctx)

      assert String.contains?(msg, "Failed to define achievement")

      # validate_config
      assert :ok = DefineAchievement.validate_config(%{"criteria_type" => "post_count"})
      assert {:error, _} = DefineAchievement.validate_config(%{"criteria_type" => "unsupported"})
      assert is_map(DefineAchievement.schema())
    end
  end

  describe "Nodes.Achievement.DisplayBadge" do
    test "sets badge display position and validates config" do
      ctx = make_ctx()
      user = create_user()
      badge = create_badge()

      Forums.award_badge(user.id, badge.id)

      # Success path
      assert {:ok, %{success: true}, _} =
               DisplayBadge.execute(
                 %{"position" => "primary"},
                 %{"user_id" => user.id, "badge_id" => badge.id},
                 ctx
               )

      # Error path (not found)
      assert {:error, msg, _} =
               DisplayBadge.execute(
                 %{"position" => "primary"},
                 %{"user_id" => user.id, "badge_id" => Ecto.UUID.generate()},
                 ctx
               )

      assert String.contains?(msg, "Failed to set badge display")

      # validate_config
      assert :ok = DisplayBadge.validate_config(%{"position" => "secondary"})
      assert :ok = DisplayBadge.validate_config(%{"position" => "hidden"})
      assert {:error, _} = DisplayBadge.validate_config(%{"position" => "invalid"})
      assert is_map(DisplayBadge.schema())
    end
  end

  describe "Nodes.Achievement.GetBadges" do
    test "retrieves user badges" do
      ctx = make_ctx()
      user = create_user()
      badge = create_badge()

      Forums.award_badge(user.id, badge.id)

      assert {:ok, %{badges: badges, count: count}, _} =
               GetBadges.execute(%{}, %{"user_id" => user.id}, ctx)

      assert count == 1
      assert length(badges) == 1

      assert :ok = GetBadges.validate_config(%{})
      assert is_map(GetBadges.schema())
    end
  end

  describe "Nodes.Achievement.HasBadge" do
    test "branches yes/no on badge possession" do
      ctx = make_ctx()
      user = create_user()
      badge = create_badge()

      # No branch
      assert {:branch, "no", %{badge: nil}, _} =
               HasBadge.execute(%{}, %{"user_id" => user.id, "badge_id" => badge.id}, ctx)

      # Yes branch
      Forums.award_badge(user.id, badge.id)

      assert {:branch, "yes", %{badge: found_badge}, _} =
               HasBadge.execute(%{}, %{"user_id" => user.id, "badge_id" => badge.id}, ctx)

      assert found_badge.id == badge.id

      # Rescue error branch on invalid input
      assert {:error, msg, _} =
               HasBadge.execute(%{}, %{"user_id" => 12345, "badge_id" => 12345}, ctx)

      assert String.contains?(msg, "Failed to check badge")

      assert :ok = HasBadge.validate_config(%{})
      assert is_map(HasBadge.schema())
    end
  end

  describe "Nodes.Achievement.RevokeBadge" do
    test "revokes a badge from a user and handles errors" do
      ctx = make_ctx()
      user = create_user()
      badge = create_badge()

      Forums.award_badge(user.id, badge.id)

      # Success path
      assert {:ok, %{success: true}, _} =
               RevokeBadge.execute(%{}, %{"user_id" => user.id, "badge_id" => badge.id}, ctx)

      # Error path (not found)
      assert {:error, msg, _} =
               RevokeBadge.execute(%{}, %{"user_id" => user.id, "badge_id" => badge.id}, ctx)

      assert String.contains?(msg, "Failed to revoke badge")

      assert :ok = RevokeBadge.validate_config(%{})
      assert is_map(RevokeBadge.schema())
    end
  end

  # ============================================================================
  # QUEST NODES (8)
  # ============================================================================

  describe "Nodes.Quest.AdvanceQuest" do
    test "advances user quest and handles errors" do
      ctx = make_ctx()
      user = create_user()

      quest =
        Repo.insert!(%Quests.Quest{
          name: "Advance Test Quest",
          quest_type: "standard",
          steps: [%{"type" => "count", "target" => 5}, %{"type" => "count", "target" => 10}]
        })

      {:ok, uq} = Quests.start_quest(user.id, quest.id)

      # Success path (next step)
      assert {:ok, %{success: true, current_step: 1, status: "active"}, _} =
               AdvanceQuest.execute(%{}, %{"user_quest_id" => uq.id}, ctx)

      # Advance to completion (step 2 reaches end of steps)
      assert {:ok, %{success: true, status: "completed", current_step: nil}, _} =
               AdvanceQuest.execute(%{}, %{"user_quest_id" => uq.id}, ctx)

      # Error path (not found)
      assert {:error, msg, _} =
               AdvanceQuest.execute(%{}, %{"user_quest_id" => Ecto.UUID.generate()}, ctx)

      assert String.contains?(msg, "Failed to advance quest")

      assert :ok = AdvanceQuest.validate_config(%{})
      assert is_map(AdvanceQuest.schema())
    end
  end

  describe "Nodes.Quest.CheckQuestStep" do
    test "checks step progress with numbers, string numbers and invalid inputs" do
      ctx = make_ctx()
      user = create_user()

      quest =
        Repo.insert!(%Quests.Quest{
          name: "Step Progress Quest",
          quest_type: "standard",
          steps: [%{"type" => "count", "target" => 5}]
        })

      {:ok, uq} = Quests.start_quest(user.id, quest.id)

      # Incomplete (less than target)
      assert {:branch, "incomplete", %{status: :in_progress}, _} =
               CheckQuestStep.execute(
                 %{},
                 %{"user_quest_id" => uq.id, "progress_value" => 3},
                 ctx
               )

      # Complete (string number parsed)
      assert {:branch, "complete", %{status: :step_complete}, _} =
               CheckQuestStep.execute(
                 %{},
                 %{"user_quest_id" => uq.id, "progress_value" => "5.0"},
                 ctx
               )

      # Fallbacks for string error and non-number
      assert {:branch, "incomplete", %{status: :in_progress}, _} =
               CheckQuestStep.execute(
                 %{},
                 %{"user_quest_id" => uq.id, "progress_value" => "invalid"},
                 ctx
               )

      assert {:branch, "incomplete", %{status: :in_progress}, _} =
               CheckQuestStep.execute(
                 %{},
                 %{"user_quest_id" => uq.id, "progress_value" => []},
                 ctx
               )

      # All steps complete branch (advance step past end)
      Repo.update_all(from(u in Quests.UserQuest, where: u.id == ^uq.id), set: [current_step: 99])

      assert {:branch, "complete", %{status: :all_steps_complete}, _} =
               CheckQuestStep.execute(
                 %{},
                 %{"user_quest_id" => uq.id, "progress_value" => 1},
                 ctx
               )

      # Error path (not found)
      assert {:error, msg, _} =
               CheckQuestStep.execute(%{}, %{"user_quest_id" => Ecto.UUID.generate()}, ctx)

      assert String.contains?(msg, "Failed to check quest step")

      assert :ok = CheckQuestStep.validate_config(%{})
      assert is_map(CheckQuestStep.schema())
    end
  end

  describe "Nodes.Quest.CompleteQuest" do
    test "completes quest and distributes rewards" do
      ctx = make_ctx()
      user = create_user()

      quest =
        Repo.insert!(%Quests.Quest{
          name: "Complete Quest Test",
          quest_type: "standard",
          steps: [%{"type" => "count", "target" => 1}],
          rewards: %{"points" => 50}
        })

      {:ok, uq} = Quests.start_quest(user.id, quest.id)

      # Success path
      assert {:ok, %{success: true, rewards: _}, _} =
               CompleteQuest.execute(%{}, %{"user_quest_id" => uq.id}, ctx)

      # Error path (not found)
      assert {:error, msg, _} =
               CompleteQuest.execute(%{}, %{"user_quest_id" => Ecto.UUID.generate()}, ctx)

      assert String.contains?(msg, "Failed to complete quest")

      assert :ok = CompleteQuest.validate_config(%{})
      assert is_map(CompleteQuest.schema())
    end
  end

  describe "Nodes.Quest.CreateDailyQuest" do
    test "assigns daily quests from pool and validates config" do
      ctx = make_ctx()
      user = create_user()

      # Create a daily quest in DB
      Repo.insert!(%Quests.Quest{
        name: "Daily Quest 1",
        quest_type: "daily",
        is_daily: true,
        steps: [%{"type" => "count", "target" => 1}]
      })

      assert {:ok, %{quests: quests, count: _count}, _} =
               CreateDailyQuest.execute(%{"pool_size" => 3}, %{"user_id" => user.id}, ctx)

      assert is_list(quests)

      # validate_config
      assert :ok = CreateDailyQuest.validate_config(%{"pool_size" => 5})
      assert :ok = CreateDailyQuest.validate_config(%{})
      assert {:error, _} = CreateDailyQuest.validate_config(%{"pool_size" => 0})
      assert {:error, _} = CreateDailyQuest.validate_config(%{"pool_size" => -1})
      assert is_map(CreateDailyQuest.schema())
    end
  end

  describe "Nodes.Quest.CreateQuestChain" do
    test "creates quest chains from list, comma-separated string, or fallback" do
      ctx = make_ctx()

      # List
      assert {:ok, %{chain_length: 3, success: true}, ctx2} =
               CreateQuestChain.execute(%{}, %{"quest_ids" => ["q1", "q2", "q3"]}, ctx)

      assert is_map(ctx2.flow_data)

      # String
      assert {:ok, %{chain_length: 2, success: true}, _} =
               CreateQuestChain.execute(%{}, %{"quest_ids" => "q4, q5"}, ctx)

      # Fallback (non-list, non-string)
      assert {:ok, %{chain_length: 0, success: true}, _} =
               CreateQuestChain.execute(%{}, %{"quest_ids" => 123}, ctx)

      assert :ok = CreateQuestChain.validate_config(%{})
      assert is_map(CreateQuestChain.schema())
    end
  end

  describe "Nodes.Quest.DefineQuest" do
    test "defines quest with various types and handles errors" do
      ctx = make_ctx()

      # Standard type
      assert {:ok, %{quest_id: qid, success: true}, _} =
               DefineQuest.execute(
                 %{"quest_type" => "side", "reward_points" => 10},
                 %{"name" => "Side Quest #{System.unique_integer()}"},
                 ctx
               )

      assert is_binary(qid)

      # Daily and weekly types
      for qt <- ~w(daily weekly) do
        assert {:ok, %{success: true}, _} =
                 DefineQuest.execute(%{"quest_type" => qt}, %{"name" => "#{qt} Quest"}, ctx)
      end

      # Error branch (nil name)
      assert {:error, msg, _} =
               DefineQuest.execute(%{}, %{"name" => nil}, ctx)

      assert String.contains?(msg, "Failed to define quest")

      # validate_config
      assert :ok = DefineQuest.validate_config(%{"quest_type" => "main"})
      assert :ok = DefineQuest.validate_config(%{"quest_type" => "daily"})
      assert {:error, _} = DefineQuest.validate_config(%{"quest_type" => "invalid"})
      assert is_map(DefineQuest.schema())
    end
  end

  describe "Nodes.Quest.GetQuestProgress" do
    test "retrieves user quests and validates config" do
      ctx = make_ctx()
      user = create_user()

      assert {:ok, %{quests: quests, count: 0}, _} =
               GetQuestProgress.execute(%{}, %{"user_id" => user.id}, ctx)

      assert is_list(quests)

      # validate_config
      assert :ok = GetQuestProgress.validate_config(%{"status_filter" => "all"})
      assert :ok = GetQuestProgress.validate_config(%{"status_filter" => "active"})
      assert :ok = GetQuestProgress.validate_config(%{"status_filter" => "completed"})
      assert {:error, _} = GetQuestProgress.validate_config(%{"status_filter" => "bad"})
      assert is_map(GetQuestProgress.schema())
    end
  end

  describe "Nodes.Quest.StartQuest" do
    test "starts quest for user and handles errors" do
      ctx = make_ctx()
      user = create_user()

      quest =
        Repo.insert!(%Quests.Quest{
          name: "Startable Quest",
          quest_type: "standard",
          steps: [%{"type" => "count", "target" => 1}]
        })

      # Success path
      assert {:ok, %{user_quest_id: uqid, success: true, first_step: _}, _} =
               StartQuest.execute(%{}, %{"user_id" => user.id, "quest_id" => quest.id}, ctx)

      assert is_binary(uqid)

      # Error path (already active)
      assert {:error, msg, _} =
               StartQuest.execute(%{}, %{"user_id" => user.id, "quest_id" => quest.id}, ctx)

      assert String.contains?(msg, "Failed to start quest")

      assert :ok = StartQuest.validate_config(%{})
      assert is_map(StartQuest.schema())
    end
  end

  # ============================================================================
  # COLLECTION NODES (6)
  # ============================================================================

  describe "Nodes.Collection.AddToSet" do
    test "adds item to user collection and handles errors" do
      ctx = make_ctx()
      user = create_user()

      {:ok, set} = Collections.define_set(%{name: "Gems #{System.unique_integer()}"})

      {:ok, item} =
        Collections.add_items_to_set(set.id, [%{name: "Ruby", rarity: "rare"}])

      [collection_item] = item

      # Success path
      assert {:ok, %{success: true, was_new: true, progress_count: 1, total_count: 1}, _} =
               AddToSet.execute(
                 %{},
                 %{"user_id" => user.id, "collection_item_id" => collection_item.id},
                 ctx
               )

      # Error path (already in collection returns {:error, :already_collected})
      assert {:error, :already_collected, _} =
               AddToSet.execute(
                 %{},
                 %{"user_id" => user.id, "collection_item_id" => collection_item.id},
                 ctx
               )

      assert :ok = AddToSet.validate_config(%{})
      assert is_map(AddToSet.schema())
    end
  end

  describe "Nodes.Collection.CheckCompletion" do
    test "branches complete or incomplete based on set completion" do
      ctx = make_ctx()
      user = create_user()

      {:ok, set} = Collections.define_set(%{name: "Stamps #{System.unique_integer()}"})
      {:ok, [item]} = Collections.add_items_to_set(set.id, [%{name: "Stamp A"}])

      # Incomplete branch
      assert {:branch, "incomplete", %{collected: 0, total: 1, percentage: +0.0}, _} =
               CheckCompletion.execute(%{}, %{"user_id" => user.id, "set_id" => set.id}, ctx)

      # Complete branch
      Collections.add_to_set(user.id, item.id)

      assert {:branch, "complete", %{collected: 1, total: 1, percentage: 100.0}, _} =
               CheckCompletion.execute(%{}, %{"user_id" => user.id, "set_id" => set.id}, ctx)

      # Empty set (0 total) -> percentage 0.0, incomplete
      {:ok, empty_set} = Collections.define_set(%{name: "Empty Set #{System.unique_integer()}"})

      assert {:branch, "incomplete", %{percentage: +0.0}, _} =
               CheckCompletion.execute(
                 %{},
                 %{"user_id" => user.id, "set_id" => empty_set.id},
                 ctx
               )

      assert :ok = CheckCompletion.validate_config(%{})
      assert is_map(CheckCompletion.schema())
    end
  end

  describe "Nodes.Collection.DefineSet" do
    test "defines collection set and handles error" do
      ctx = make_ctx()

      assert {:ok, %{set_id: sid, success: true}, _} =
               DefineSet.execute(
                 %{"icon" => "set-icon", "reward_points" => 50},
                 %{
                   "name" => "Artifacts #{System.unique_integer()}",
                   "description" => "Rare stuff"
                 },
                 ctx
               )

      assert is_binary(sid)

      # Error branch (nil name)
      assert {:error, changeset, _} =
               DefineSet.execute(%{}, %{"name" => nil}, ctx)

      assert changeset.errors[:name] != nil

      assert :ok = DefineSet.validate_config(%{})
      assert is_map(DefineSet.schema())
    end
  end

  describe "Nodes.Collection.GetMissing" do
    test "retrieves missing collection items" do
      ctx = make_ctx()
      user = create_user()

      {:ok, set} = Collections.define_set(%{name: "Coins #{System.unique_integer()}"})
      {:ok, [item]} = Collections.add_items_to_set(set.id, [%{name: "Gold Coin"}])

      assert {:ok, %{missing_items: [missing], count: 1}, _} =
               GetMissing.execute(%{}, %{"user_id" => user.id, "set_id" => set.id}, ctx)

      assert missing.id == item.id

      assert :ok = GetMissing.validate_config(%{})
      assert is_map(GetMissing.schema())
    end
  end

  describe "Nodes.Collection.GetProgress" do
    test "retrieves collection set progress" do
      ctx = make_ctx()
      user = create_user()

      {:ok, set} = Collections.define_set(%{name: "Figures #{System.unique_integer()}"})
      {:ok, [item]} = Collections.add_items_to_set(set.id, [%{name: "Figure 1"}])

      assert {:ok, %{collected: 0, total: 1, percentage: +0.0, items: [_]}, _} =
               GetProgress.execute(%{}, %{"user_id" => user.id, "set_id" => set.id}, ctx)

      Collections.add_to_set(user.id, item.id)

      assert {:ok, %{collected: 1, total: 1, percentage: 100.0}, _} =
               GetProgress.execute(%{}, %{"user_id" => user.id, "set_id" => set.id}, ctx)

      # Empty set progress
      {:ok, empty_set} = Collections.define_set(%{name: "Empty Fig #{System.unique_integer()}"})

      assert {:ok, %{percentage: +0.0}, _} =
               GetProgress.execute(%{}, %{"user_id" => user.id, "set_id" => empty_set.id}, ctx)

      assert :ok = GetProgress.validate_config(%{})
      assert is_map(GetProgress.schema())
    end
  end

  describe "Nodes.Collection.TradeCollectionItem" do
    test "trades collection item between users and handles errors" do
      ctx = make_ctx()
      user1 = create_user()
      user2 = create_user()

      {:ok, set} = Collections.define_set(%{name: "Trade Set #{System.unique_integer()}"})
      {:ok, [item]} = Collections.add_items_to_set(set.id, [%{name: "Tradeable Card"}])

      Collections.add_to_set(user1.id, item.id)

      # Success path
      assert {:ok, %{success: true}, _} =
               TradeCollectionItem.execute(
                 %{},
                 %{
                   "from_user_id" => user1.id,
                   "to_user_id" => user2.id,
                   "collection_item_id" => item.id
                 },
                 ctx
               )

      # Error path (user1 no longer owns the item)
      assert {:error, :not_owned, _} =
               TradeCollectionItem.execute(
                 %{},
                 %{
                   "from_user_id" => user1.id,
                   "to_user_id" => user2.id,
                   "collection_item_id" => item.id
                 },
                 ctx
               )

      assert :ok = TradeCollectionItem.validate_config(%{})
      assert is_map(TradeCollectionItem.schema())
    end
  end

  # ============================================================================
  # PET NODES (8)
  # ============================================================================

  describe "Nodes.Pet.CreatePet" do
    test "creates pet for user and handles errors" do
      ctx = make_ctx()
      user = create_user()
      template = create_pet_template()

      # Success path
      assert {:ok, %{pet_id: pid, pet: pmap, success: true}, _} =
               CreatePet.execute(
                 %{"nickname" => "Spike"},
                 %{"user_id" => user.id, "template_id" => template.id},
                 ctx
               )

      assert is_binary(pid)
      assert pmap.nickname == "Spike"

      # Error path (failed changeset / user_id nil)
      assert {:error, msg, _} =
               CreatePet.execute(%{}, %{"user_id" => nil, "template_id" => template.id}, ctx)

      assert String.contains?(msg, "Failed to create pet")

      # Error path (invalid template)
      assert {:error, msg, _} =
               CreatePet.execute(
                 %{},
                 %{"user_id" => user.id, "template_id" => Ecto.UUID.generate()},
                 ctx
               )

      assert String.contains?(msg, "Failed to create pet")

      assert :ok = CreatePet.validate_config(%{})
      assert is_map(CreatePet.schema())
    end
  end

  describe "Nodes.Pet.BreedPets" do
    test "breeds two pets and handles errors" do
      ctx = make_ctx()
      user = create_user()
      template = create_pet_template()

      {:ok, pet1} = Pets.create_pet(user.id, template.id, "Parent 1")
      {:ok, pet2} = Pets.create_pet(user.id, template.id, "Parent 2")

      # Success path
      assert {:ok, %{offspring: offspring, success: true}, _} =
               BreedPets.execute(
                 %{},
                 %{"pet1_id" => pet1.id, "pet2_id" => pet2.id, "user_id" => user.id},
                 ctx
               )

      assert offspring.level == 1

      # Error path (non-owner)
      user2 = create_user()

      assert {:error, msg, _} =
               BreedPets.execute(
                 %{},
                 %{"pet1_id" => pet1.id, "pet2_id" => pet2.id, "user_id" => user2.id},
                 ctx
               )

      assert String.contains?(msg, "Failed to breed pets")

      assert :ok = BreedPets.validate_config(%{})
      assert is_map(BreedPets.schema())
    end
  end

  describe "Nodes.Pet.GetPetStats" do
    test "retrieves pet stats and handles not found" do
      ctx = make_ctx()
      user = create_user()
      template = create_pet_template()
      {:ok, pet} = Pets.create_pet(user.id, template.id, "StatPet")

      # Success path
      assert {:ok, %{stats: stats, level: 1, nickname: "StatPet"}, _} =
               GetPetStats.execute(%{}, %{"pet_id" => pet.id}, ctx)

      assert stats.hunger == 100

      # Not found path
      assert {:error, "Pet not found", _} =
               GetPetStats.execute(%{}, %{"pet_id" => Ecto.UUID.generate()}, ctx)

      assert :ok = GetPetStats.validate_config(%{})
      assert is_map(GetPetStats.schema())
    end
  end

  describe "Nodes.Pet.PetAction" do
    test "performs actions on pets and validates config" do
      ctx = make_ctx()
      user = create_user()
      template = create_pet_template()
      {:ok, pet} = Pets.create_pet(user.id, template.id, "ActionPet")

      # Success paths for actions
      for act <- ~w(feed play clean rest heal) do
        assert {:ok, %{success: true, pet: _}, _} =
                 PetAction.execute(
                   %{"action" => act},
                   %{"pet_id" => pet.id, "user_id" => user.id},
                   ctx
                 )
      end

      # Error path (unauthorized user)
      user2 = create_user()

      assert {:error, msg, _} =
               PetAction.execute(
                 %{"action" => "feed"},
                 %{"pet_id" => pet.id, "user_id" => user2.id},
                 ctx
               )

      assert String.contains?(msg, "Failed to perform pet action")

      # validate_config
      assert :ok = PetAction.validate_config(%{"action" => "play"})
      assert {:error, _} = PetAction.validate_config(%{"action" => "bad_action"})
      assert is_map(PetAction.schema())
    end
  end

  describe "Nodes.Pet.PetBattle" do
    test "runs a battle between two pets and handles not found" do
      ctx = make_ctx()
      user = create_user()
      template = create_pet_template()

      {:ok, pet1} = Pets.create_pet(user.id, template.id, "Fighter 1")
      {:ok, pet2} = Pets.create_pet(user.id, template.id, "Fighter 2")

      # Success path: pet1 score >= pet2 score
      assert {:ok, %{winner_id: wid, battle_log: log, stats_comparison: stats}, _} =
               PetBattle.execute(%{}, %{"pet1_id" => pet1.id, "pet2_id" => pet2.id}, ctx)

      assert is_binary(wid)
      assert length(log) == 2
      assert is_map(stats)

      # Pet2 wins by having higher level
      Repo.update_all(from(p in Pets.Pet, where: p.id == ^pet2.id), set: [level: 10])
      pet2_id = pet2.id

      assert {:ok, %{winner_id: ^pet2_id}, _} =
               PetBattle.execute(%{}, %{"pet1_id" => pet1.id, "pet2_id" => pet2.id}, ctx)

      # Error path (not found)
      assert {:error, "One or both pets not found", _} =
               PetBattle.execute(
                 %{},
                 %{"pet1_id" => pet1.id, "pet2_id" => Ecto.UUID.generate()},
                 ctx
               )

      assert :ok = PetBattle.validate_config(%{})
      assert is_map(PetBattle.schema())
    end
  end

  describe "Nodes.Pet.PetCompete" do
    test "enters pet into competition and validates config" do
      ctx = make_ctx()
      user = create_user()
      template = create_pet_template()
      {:ok, pet} = Pets.create_pet(user.id, template.id, "Competitor")

      for ct <- ~w(beauty strength speed overall) do
        assert {:ok, %{score: score, pet: _}, _} =
                 PetCompete.execute(%{"competition_type" => ct}, %{"pet_id" => pet.id}, ctx)

        assert is_number(score)
      end

      # Not found path
      assert {:error, "Pet not found", _} =
               PetCompete.execute(%{}, %{"pet_id" => Ecto.UUID.generate()}, ctx)

      # validate_config
      assert :ok = PetCompete.validate_config(%{"competition_type" => "beauty"})
      assert {:error, _} = PetCompete.validate_config(%{"competition_type" => "dance"})
      assert is_map(PetCompete.schema())
    end
  end

  describe "Nodes.Pet.PetDecay" do
    test "decays pet stats and validates config" do
      ctx = make_ctx()

      assert {:ok, %{pets_affected: count}, _} =
               PetDecay.execute(%{}, %{}, ctx)

      assert is_integer(count)

      # validate_config
      assert :ok = PetDecay.validate_config(%{"hunger_rate" => 5, "happiness_rate" => 3})
      assert {:error, _} = PetDecay.validate_config(%{"hunger_rate" => -1})
      assert {:error, _} = PetDecay.validate_config(%{"happiness_rate" => "bad"})
      assert is_map(PetDecay.schema())
    end
  end

  describe "Nodes.Pet.PetEvolve" do
    test "checks evolution and branches evolved or not_ready" do
      ctx = make_ctx()
      user = create_user()
      template = create_pet_template()

      # Pet template without evolution -> :no_evolution -> not_ready
      {:ok, pet} = Pets.create_pet(user.id, template.id, "BasePet")

      assert {:branch, "not_ready", %{evolved: false, reason: :no_evolution}, _} =
               PetEvolve.execute(%{}, %{"pet_id" => pet.id}, ctx)

      # Pet template with evolution target but pet level < threshold -> :not_ready -> not_ready
      evolved_template = create_pet_template()

      Repo.update_all(
        from(t in Pets.PetTemplate, where: t.id == ^template.id),
        set: [evolution_threshold: 5, evolves_into_id: evolved_template.id]
      )

      assert {:branch, "not_ready", %{evolved: false, reason: :not_ready}, _} =
               PetEvolve.execute(%{}, %{"pet_id" => pet.id}, ctx)

      # Pet experience reaches threshold -> evolved
      Repo.update_all(from(p in Pets.Pet, where: p.id == ^pet.id), set: [experience: 10])

      assert {:branch, "evolved", %{evolved: true, pet: epet}, _} =
               PetEvolve.execute(%{}, %{"pet_id" => pet.id}, ctx)

      assert epet.template_id == evolved_template.id

      # Error path (not found)
      assert {:error, msg, _} =
               PetEvolve.execute(%{}, %{"pet_id" => Ecto.UUID.generate()}, ctx)

      assert String.contains?(msg, "Failed to check evolution")

      assert :ok = PetEvolve.validate_config(%{})
      assert is_map(PetEvolve.schema())
    end
  end

  # ============================================================================
  # INVENTORY NODES (12)
  # ============================================================================

  describe "Nodes.Inventory.DefineItem" do
    test "defines item template and handles errors" do
      ctx = make_ctx()

      assert {:ok, %{item_template_id: tid, success: true}, _} =
               DefineItem.execute(%{}, %{"name" => "Iron Sword #{System.unique_integer()}"}, ctx)

      assert is_binary(tid)

      # Error branch (nil name)
      assert {:error, changeset, _} =
               DefineItem.execute(%{}, %{"name" => nil}, ctx)

      assert changeset.errors[:name] != nil

      assert :ok = DefineItem.validate_config(%{})
      assert is_map(DefineItem.schema())
    end
  end

  describe "Nodes.Inventory.GiveItem" do
    test "gives item to user with integer, float, string quantity and fallbacks" do
      ctx = make_ctx()
      user = create_user()
      template = create_item_template()

      # Integer quantity
      assert {:ok, %{success: true, quantity: 2}, _} =
               GiveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id, "quantity" => 2},
                 ctx
               )

      # Float quantity
      assert {:ok, %{success: true, quantity: 3}, _} =
               GiveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id, "quantity" => 3.5},
                 ctx
               )

      # String quantity and bad string fallback
      assert {:ok, %{success: true, quantity: 4}, _} =
               GiveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id, "quantity" => "4"},
                 ctx
               )

      assert {:ok, %{success: true, quantity: 1}, _} =
               GiveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id, "quantity" => "bad"},
                 ctx
               )

      assert {:ok, %{success: true, quantity: 1}, _} =
               GiveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id, "quantity" => nil},
                 ctx
               )

      # Error branch (invalid template id)
      assert {:error, :item_not_found, _} =
               GiveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => Ecto.UUID.generate()},
                 ctx
               )

      assert :ok = GiveItem.validate_config(%{})
      assert is_map(GiveItem.schema())
    end
  end

  describe "Nodes.Inventory.HasItem" do
    test "branches yes/no on item presence" do
      ctx = make_ctx()
      user = create_user()
      template = create_item_template()

      # No branch
      assert {:branch, "no", %{has_item: false, quantity: 0}, _} =
               HasItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id},
                 ctx
               )

      # Yes branch
      Inventory.give_item(user.id, template.id, 1)

      assert {:branch, "yes", %{has_item: true, quantity: 1}, _} =
               HasItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id},
                 ctx
               )

      assert :ok = HasItem.validate_config(%{})
      assert is_map(HasItem.schema())
    end
  end

  describe "Nodes.Inventory.GetInventory" do
    test "retrieves user inventory items" do
      ctx = make_ctx()
      user = create_user()
      template = create_item_template()

      Inventory.give_item(user.id, template.id, 5)

      assert {:ok, %{items: items, total_count: 1}, _} =
               GetInventory.execute(%{}, %{"user_id" => user.id}, ctx)

      assert length(items) == 1

      assert :ok = GetInventory.validate_config(%{})
      assert is_map(GetInventory.schema())
    end
  end

  describe "Nodes.Inventory.RemoveItem" do
    test "removes item quantity and handles errors" do
      ctx = make_ctx()
      user = create_user()
      template = create_item_template()

      Inventory.give_item(user.id, template.id, 10)

      # Success path (with string quantity and to_integer fallbacks)
      assert {:ok, %{success: true, quantity_removed: 3}, _} =
               RemoveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id, "quantity" => "3"},
                 ctx
               )

      assert {:ok, %{success: true, quantity_removed: 2}, _} =
               RemoveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id, "quantity" => 2.0},
                 ctx
               )

      assert {:ok, %{success: true, quantity_removed: 1}, _} =
               RemoveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id, "quantity" => "bad"},
                 ctx
               )

      assert {:ok, %{success: true, quantity_removed: 1}, _} =
               RemoveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template.id, "quantity" => nil},
                 ctx
               )

      # Error path (item not in inventory)
      template2 = create_item_template()

      assert {:error, :item_not_found, _} =
               RemoveItem.execute(
                 %{},
                 %{"user_id" => user.id, "item_template_id" => template2.id, "quantity" => 1},
                 ctx
               )

      # Error path (invalid template)
      assert {:error, _, _} =
               RemoveItem.execute(
                 %{},
                 %{
                   "user_id" => user.id,
                   "item_template_id" => Ecto.UUID.generate(),
                   "quantity" => 1
                 },
                 ctx
               )

      assert :ok = RemoveItem.validate_config(%{})
      assert is_map(RemoveItem.schema())
    end
  end

  describe "Nodes.Inventory.TransferItem" do
    test "transfers item between users and handles errors" do
      ctx = make_ctx()
      user1 = create_user()
      user2 = create_user()
      template = create_item_template()

      Inventory.give_item(user1.id, template.id, 20)

      # Success path (with float & string quantity fallbacks)
      assert {:ok, %{success: true}, _} =
               TransferItem.execute(
                 %{},
                 %{
                   "from_user_id" => user1.id,
                   "to_user_id" => user2.id,
                   "item_template_id" => template.id,
                   "quantity" => 2
                 },
                 ctx
               )

      assert {:ok, %{success: true}, _} =
               TransferItem.execute(
                 %{},
                 %{
                   "from_user_id" => user1.id,
                   "to_user_id" => user2.id,
                   "item_template_id" => template.id,
                   "quantity" => "1"
                 },
                 ctx
               )

      assert {:ok, %{success: true}, _} =
               TransferItem.execute(
                 %{},
                 %{
                   "from_user_id" => user1.id,
                   "to_user_id" => user2.id,
                   "item_template_id" => template.id,
                   "quantity" => 1.5
                 },
                 ctx
               )

      assert {:ok, %{success: true}, _} =
               TransferItem.execute(
                 %{},
                 %{
                   "from_user_id" => user1.id,
                   "to_user_id" => user2.id,
                   "item_template_id" => template.id,
                   "quantity" => "bad"
                 },
                 ctx
               )

      assert {:ok, %{success: true}, _} =
               TransferItem.execute(
                 %{},
                 %{
                   "from_user_id" => user1.id,
                   "to_user_id" => user2.id,
                   "item_template_id" => template.id,
                   "quantity" => nil
                 },
                 ctx
               )

      # Error path (item not found)
      assert {:error, :item_not_found, _} =
               TransferItem.execute(
                 %{},
                 %{
                   "from_user_id" => user1.id,
                   "to_user_id" => user2.id,
                   "item_template_id" => Ecto.UUID.generate(),
                   "quantity" => 1
                 },
                 ctx
               )

      assert :ok = TransferItem.validate_config(%{})
      assert is_map(TransferItem.schema())
    end
  end

  describe "Nodes.Inventory.EquipItem" do
    test "equips item and handles errors" do
      ctx = make_ctx()
      user = create_user()
      template = create_item_template(%{is_equippable: true})

      {:ok, inv_item} = Inventory.give_item(user.id, template.id, 1)

      # Success path
      assert {:ok, %{success: true, item: item}, _} =
               EquipItem.execute(%{}, %{"user_id" => user.id, "inventory_id" => inv_item.id}, ctx)

      assert item.is_equipped == true

      # Error path (item not found)
      assert {:error, :item_not_found, _} =
               EquipItem.execute(
                 %{},
                 %{"user_id" => user.id, "inventory_id" => Ecto.UUID.generate()},
                 ctx
               )

      assert :ok = EquipItem.validate_config(%{})
      assert is_map(EquipItem.schema())
    end
  end

  describe "Nodes.Inventory.ConsumeItem" do
    test "consumes item and handles errors" do
      ctx = make_ctx()
      user = create_user()
      template = create_item_template(%{is_consumable: true})

      {:ok, inv_item} = Inventory.give_item(user.id, template.id, 1)

      # Success path
      assert {:ok, %{success: true, item_template: consumed_tmpl}, _} =
               ConsumeItem.execute(
                 %{},
                 %{"user_id" => user.id, "inventory_id" => inv_item.id},
                 ctx
               )

      assert consumed_tmpl.id == template.id

      # Error path (already consumed / not found)
      assert {:error, :item_not_found, _} =
               ConsumeItem.execute(
                 %{},
                 %{"user_id" => user.id, "inventory_id" => inv_item.id},
                 ctx
               )

      assert :ok = ConsumeItem.validate_config(%{})
      assert is_map(ConsumeItem.schema())
    end
  end

  describe "Nodes.Inventory.CraftItem" do
    test "crafts item using recipe, handles failure and errors" do
      ctx = make_ctx()
      user = create_user()
      ingredient = create_item_template()
      result_tmpl = create_item_template()

      # Guaranteed recipe (1.0 success rate)
      recipe_100 =
        Repo.insert!(%Inventory.CraftingRecipe{
          name: "Sure Craft",
          result_item_id: result_tmpl.id,
          success_rate: 1.0,
          ingredients: [%{"item_template_id" => ingredient.id, "quantity" => 1}]
        })

      # Give ingredients to user
      Inventory.give_item(user.id, ingredient.id, 10)

      # Success path
      assert {:ok, %{success: true, crafted: true, result_item: _}, _} =
               CraftItem.execute(%{}, %{"user_id" => user.id, "recipe_id" => recipe_100.id}, ctx)

      # Failing recipe (success_rate 0.0)
      recipe_fail =
        Repo.insert!(%Inventory.CraftingRecipe{
          name: "Failing Craft",
          result_item_id: result_tmpl.id,
          success_rate: +0.0,
          ingredients: [%{"item_template_id" => ingredient.id, "quantity" => 1}]
        })

      assert {:ok, %{success: true, crafted: false, result_item: nil}, _} =
               CraftItem.execute(%{}, %{"user_id" => user.id, "recipe_id" => recipe_fail.id}, ctx)

      # Insufficient materials
      user_no_mats = create_user()

      assert {:error, :missing_ingredient, _} =
               CraftItem.execute(
                 %{},
                 %{"user_id" => user_no_mats.id, "recipe_id" => recipe_100.id},
                 ctx
               )

      # Error path (recipe not found)
      assert {:error, :recipe_not_found, _} =
               CraftItem.execute(
                 %{},
                 %{"user_id" => user.id, "recipe_id" => Ecto.UUID.generate()},
                 ctx
               )

      assert :ok = CraftItem.validate_config(%{})
      assert is_map(CraftItem.schema())
    end
  end

  describe "Nodes.Inventory.ItemDurability" do
    test "applies wear and branches intact or broken" do
      ctx = make_ctx()
      inv_id = Ecto.UUID.generate()

      # Intact branch (wear 20 from 100 -> 80)
      assert {:branch, "intact", %{durability: 80, max_durability: 100}, ctx2} =
               ItemDurability.execute(%{}, %{"inventory_id" => inv_id, "wear_amount" => 20}, ctx)

      # Float wear amount
      assert {:branch, "intact", %{durability: 60}, ctx3} =
               ItemDurability.execute(
                 %{},
                 %{"inventory_id" => inv_id, "wear_amount" => 20.5},
                 ctx2
               )

      # Broken branch (wear 100 -> 0)
      assert {:branch, "broken", %{durability: 0, max_durability: 100}, _} =
               ItemDurability.execute(
                 %{},
                 %{"inventory_id" => inv_id, "wear_amount" => 100},
                 ctx3
               )

      assert :ok = ItemDurability.validate_config(%{})
      assert is_map(ItemDurability.schema())
    end
  end

  describe "Nodes.Inventory.ListForSale" do
    test "creates marketplace listing in flow data" do
      ctx = make_ctx()
      user = create_user()
      inv_id = Ecto.UUID.generate()

      assert {:ok, %{listing_id: lid, success: true}, ctx2} =
               ListForSale.execute(
                 %{"currency_slug" => "gold"},
                 %{"user_id" => user.id, "inventory_id" => inv_id, "price" => 100},
                 ctx
               )

      assert is_binary(lid)
      assert ctx2.flow_data["marketplace_listings"][lid]["currency_slug"] == "gold"

      assert :ok = ListForSale.validate_config(%{})
      assert is_map(ListForSale.schema())
    end
  end

  describe "Nodes.Inventory.OpenPack" do
    test "consumes pack item, awards random items and handles fallbacks" do
      ctx = make_ctx()
      user = create_user()
      pack_template = create_item_template(%{is_consumable: true})
      _other_item = create_item_template()

      {:ok, pack_item} = Inventory.give_item(user.id, pack_template.id, 1)

      # Success path
      assert {:ok, %{items: items, success: true}, _} =
               OpenPack.execute(
                 %{"items_count" => 3},
                 %{"user_id" => user.id, "pack_template_id" => pack_item.id},
                 ctx
               )

      assert length(items) == 3

      # to_int fallbacks in OpenPack: float, string int, bad string, other
      {:ok, pack_item2} = Inventory.give_item(user.id, pack_template.id, 1)

      assert {:ok, %{items: items2}, _} =
               OpenPack.execute(
                 %{"items_count" => 2.5},
                 %{"user_id" => user.id, "pack_template_id" => pack_item2.id},
                 ctx
               )

      assert length(items2) == 2

      {:ok, pack_item3} = Inventory.give_item(user.id, pack_template.id, 1)

      assert {:ok, %{items: items3}, _} =
               OpenPack.execute(
                 %{"items_count" => "2"},
                 %{"user_id" => user.id, "pack_template_id" => pack_item3.id},
                 ctx
               )

      assert length(items3) == 2

      {:ok, pack_item4} = Inventory.give_item(user.id, pack_template.id, 1)

      assert {:ok, %{items: items4}, _} =
               OpenPack.execute(
                 %{"items_count" => "bad"},
                 %{"user_id" => user.id, "pack_template_id" => pack_item4.id},
                 ctx
               )

      assert length(items4) == 5

      {:ok, pack_item5} = Inventory.give_item(user.id, pack_template.id, 1)

      assert {:ok, %{items: items5}, _} =
               OpenPack.execute(
                 %{"items_count" => nil},
                 %{"user_id" => user.id, "pack_template_id" => pack_item5.id},
                 ctx
               )

      assert length(items5) == 5

      # Error path (item not in inventory)
      assert {:error, msg, _} =
               OpenPack.execute(
                 %{},
                 %{"user_id" => user.id, "pack_template_id" => Ecto.UUID.generate()},
                 ctx
               )

      assert String.contains?(msg, "Failed to open pack")

      assert :ok = OpenPack.validate_config(%{})
      assert is_map(OpenPack.schema())
    end
  end
end
