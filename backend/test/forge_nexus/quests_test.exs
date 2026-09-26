defmodule ForgeNexus.QuestsTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Quests
  alias ForgeNexus.Quests.{Quest, UserQuest}
  alias ForgeNexus.Accounts

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "quest_u_#{unique}",
        email: "quest_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp quest_attrs(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Hero's Journey #{unique}",
      description: "Begin your quest",
      quest_type: "standard",
      steps: [
        %{"type" => "count", "target" => 3, "description" => "Defeat 3 foes"},
        %{"type" => "flag", "description" => "Speak to elder"}
      ],
      rewards: %{"xp" => 100, "coins" => 50},
      is_daily: false,
      is_active: true,
      sort_order: 10
    })
  end

  describe "quests CRUD and listing" do
    test "list_quests/0 and get_quest!/1" do
      {:ok, quest1} =
        %Quest{}
        |> Quest.changeset(quest_attrs(%{sort_order: 20, is_active: true}))
        |> ForgeNexus.Repo.insert()

      {:ok, quest2} =
        %Quest{}
        |> Quest.changeset(quest_attrs(%{sort_order: 5, is_active: true}))
        |> ForgeNexus.Repo.insert()

      {:ok, _inactive} =
        %Quest{}
        |> Quest.changeset(quest_attrs(%{sort_order: 1, is_active: false}))
        |> ForgeNexus.Repo.insert()

      quests = Quests.list_quests()
      ids = Enum.map(quests, & &1.id)

      assert quest1.id in ids
      assert quest2.id in ids
      refute Enum.any?(quests, fn q -> q.is_active == false end)

      pos1 = Enum.find_index(ids, &(&1 == quest1.id))
      pos2 = Enum.find_index(ids, &(&1 == quest2.id))
      assert pos2 < pos1

      assert %Quest{id: id} = Quests.get_quest!(quest1.id)
      assert id == quest1.id
    end
  end

  describe "start_quest/2 and get_user_quests/1" do
    test "starts quest and rejects duplicates if already active" do
      user = create_user()
      {:ok, quest} = %Quest{} |> Quest.changeset(quest_attrs()) |> ForgeNexus.Repo.insert()

      assert {:ok, %UserQuest{} = uq} = Quests.start_quest(user.id, quest.id)
      assert uq.status == "active"
      assert uq.current_step == 0

      # Cannot start again while active
      assert {:error, :quest_already_active} = Quests.start_quest(user.id, quest.id)

      # get_user_quests returns active quests
      user_quests = Quests.get_user_quests(user.id)
      assert length(user_quests) == 1
      assert hd(user_quests).quest.id == quest.id
    end
  end

  describe "check_step_progress/2 and advance_quest/1" do
    test "evaluates count, flag, and unknown steps" do
      user = create_user()
      {:ok, quest} = %Quest{} |> Quest.changeset(quest_attrs()) |> ForgeNexus.Repo.insert()
      {:ok, uq} = Quests.start_quest(user.id, quest.id)

      # Step 0 is "count" with target 3
      assert {:ok, :in_progress} = Quests.check_step_progress(uq.id, %{"count" => 2})
      assert {:ok, :step_complete} = Quests.check_step_progress(uq.id, %{"count" => 3})

      # Advance to Step 1
      assert {:ok, %UserQuest{current_step: 1}} = Quests.advance_quest(uq.id)

      # Step 1 is "flag"
      assert {:ok, :in_progress} = Quests.check_step_progress(uq.id, %{"completed" => false})
      assert {:ok, :step_complete} = Quests.check_step_progress(uq.id, %{"completed" => true})

      # Advancing past the final step completes the quest and returns rewards
      assert {:ok, rewards} = Quests.advance_quest(uq.id)
      assert rewards == %{"xp" => 100, "coins" => 50}

      completed_uq = ForgeNexus.Repo.get!(UserQuest, uq.id)
      assert completed_uq.status == "completed"
      assert completed_uq.completed_at != nil

      # When current_step exceeds steps list, check_step_progress returns :all_steps_complete
      uq_out_of_bounds =
        completed_uq |> UserQuest.changeset(%{current_step: 99}) |> ForgeNexus.Repo.update!()

      assert {:ok, :all_steps_complete} = Quests.check_step_progress(uq_out_of_bounds.id, %{})
    end

    test "handles unknown step type" do
      user = create_user()

      {:ok, quest} =
        %Quest{}
        |> Quest.changeset(
          quest_attrs(%{
            steps: [%{"type" => "custom_puzzle", "data" => "some"}]
          })
        )
        |> ForgeNexus.Repo.insert()

      {:ok, uq} = Quests.start_quest(user.id, quest.id)
      assert {:ok, :in_progress} = Quests.check_step_progress(uq.id, %{"solved" => true})
    end
  end

  describe "daily quests generation and abandon" do
    test "generate_daily_quests/1 selects active daily quests not yet active" do
      user = create_user()

      for i <- 1..5 do
        %Quest{}
        |> Quest.changeset(
          quest_attrs(%{
            name: "Daily Task #{i}",
            is_daily: true,
            is_active: true
          })
        )
        |> ForgeNexus.Repo.insert!()
      end

      daily_quests = Quests.generate_daily_quests(user.id)
      assert length(daily_quests) <= 3
      assert length(daily_quests) > 0

      # Running again shouldn't duplicate the already active ones
      new_dailies = Quests.generate_daily_quests(user.id)
      all_ids = Enum.map(daily_quests ++ new_dailies, & &1.quest_id)
      assert length(all_ids) == length(Enum.uniq(all_ids))
    end

    test "abandon_quest/1 updates status to abandoned" do
      user = create_user()
      {:ok, quest} = %Quest{} |> Quest.changeset(quest_attrs()) |> ForgeNexus.Repo.insert()
      {:ok, uq} = Quests.start_quest(user.id, quest.id)

      assert {:ok, updated} = Quests.abandon_quest(uq.id)
      assert updated.status == "abandoned"
      assert Quests.get_user_quests(user.id) == []
    end
  end
end
