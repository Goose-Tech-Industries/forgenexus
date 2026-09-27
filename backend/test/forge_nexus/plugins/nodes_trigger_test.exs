defmodule ForgeNexus.Plugins.NodesTriggerTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Plugins.Engine.Context
  alias ForgeNexus.Plugins.Nodes.Trigger

  @triggers [
    {"trigger/manual", Trigger.Manual},
    {"trigger/scheduled", Trigger.Scheduled},
    {"trigger/webhook_received", Trigger.WebhookReceived},
    {"trigger/on_achievement_unlocked", Trigger.OnAchievementUnlocked},
    {"trigger/on_chat_message", Trigger.OnChatMessage},
    {"trigger/on_collection_completed", Trigger.OnCollectionCompleted},
    {"trigger/on_cooldown_expired", Trigger.OnCooldownExpired},
    {"trigger/on_custom_event", Trigger.OnCustomEvent},
    {"trigger/on_payment_received", Trigger.OnPaymentReceived},
    {"trigger/on_point_milestone", Trigger.OnPointMilestone},
    {"trigger/on_poll_voted", Trigger.OnPollVoted},
    {"trigger/on_post_created", Trigger.OnPostCreated},
    {"trigger/on_post_edited", Trigger.OnPostEdited},
    {"trigger/on_reaction_added", Trigger.OnReactionAdded},
    {"trigger/on_report_created", Trigger.OnReportCreated},
    {"trigger/on_slash_command", Trigger.OnSlashCommand},
    {"trigger/on_streak_milestone", Trigger.OnStreakMilestone},
    {"trigger/on_subscription_changed", Trigger.OnSubscriptionChanged},
    {"trigger/on_thread_created", Trigger.OnThreadCreated},
    {"trigger/on_thread_solved", Trigger.OnThreadSolved},
    {"trigger/on_user_banned", Trigger.OnUserBanned},
    {"trigger/on_user_birthday", Trigger.OnUserBirthday},
    {"trigger/on_user_joined", Trigger.OnUserJoined},
    {"trigger/on_user_left", Trigger.OnUserLeft}
  ]

  defp base_string_td do
    %{
      "user" => %{"id" => "u1", "username" => "alice"},
      "post" => %{"id" => "p1", "body" => "hello"},
      "thread" => %{"id" => "t1", "title" => "Thread 1"},
      "reaction" => "like",
      "message" => %{"id" => "m1", "content" => "chat"},
      "channel_id" => "c1",
      "report" => %{"id" => "r1", "reason" => "spam"},
      "achievement" => %{"id" => "a1", "title" => "Winner"},
      "collection" => %{"id" => "col1", "name" => "Cards"},
      "amount" => 100,
      "currency" => "points",
      "payment_type" => "tip",
      "metadata" => %{"item" => "sword"},
      "subscription" => %{"id" => "s1", "tier" => "gold"},
      "previous_tier" => "silver",
      "new_tier" => "gold",
      "action_key" => "daily_spin",
      "expired_at" => "2026-09-26T00:00:00Z",
      "poll" => %{"id" => "pol1"},
      "option_id" => "opt1",
      "count" => 30,
      "streak_type" => "daily_login",
      "balance" => 500,
      "milestone" => 500,
      "command_name" => "ban",
      "args" => "user1",
      "args_list" => ["user1"],
      "raw_input" => "/ban user1",
      "event_name" => "user_leveled_up",
      "payload" => %{"level" => 5},
      "emitter_flow_id" => "flow-999",
      "method" => "POST",
      "headers" => %{"content-type" => "application/json"},
      "body" => %{"data" => "test"},
      "query" => %{"ref" => "google"}
    }
  end

  defp base_atom_td do
    %{
      user: %{id: "u1", username: "alice"},
      post: %{id: "p1", body: "hello"},
      thread: %{id: "t1", title: "Thread 1"},
      reaction: "like",
      message: %{id: "m1", content: "chat"},
      channel_id: "c1",
      report: %{id: "r1", reason: "spam"},
      achievement: %{id: "a1", title: "Winner"},
      collection: %{id: "col1", name: "Cards"},
      amount: 100,
      currency: "points",
      payment_type: "tip",
      metadata: %{item: "sword"},
      subscription: %{id: "s1", tier: "gold"},
      previous_tier: "silver",
      new_tier: "gold",
      action_key: "daily_spin",
      expired_at: "2026-09-26T00:00:00Z",
      poll: %{id: "pol1"},
      option_id: "opt1",
      count: 30,
      streak_type: "daily_login",
      balance: 500,
      milestone: 500,
      command_name: "ban",
      args: "user1",
      args_list: ["user1"],
      raw_input: "/ban user1",
      event_name: "user_leveled_up",
      payload: %{level: 5},
      emitter_flow_id: "flow-999",
      method: "POST",
      headers: %{"content-type" => "application/json"},
      body: %{data: "test"},
      query: %{ref: "google"}
    }
  end

  describe "All 24 Trigger Nodes" do
    test "schema and validation contracts hold for all trigger nodes" do
      for {expected_type, mod} <- @triggers do
        schema = mod.schema()
        assert is_map(schema)
        assert schema.type == expected_type
        assert schema.category == "trigger"
        assert is_list(schema.inputs)
        assert is_list(schema.outputs)
        assert is_list(schema.config_fields)
        assert mod.validate_config(%{}) == :ok
      end
    end

    test "execution with string trigger_data keys" do
      ctx = %Context{
        flow_id: "flow-123",
        trigger_data: base_string_td()
      }

      for {_type, mod} <- @triggers do
        assert {:ok, result, ^ctx} = mod.execute(%{}, %{}, ctx)
        assert is_map(result)
      end
    end

    test "execution with atom trigger_data keys" do
      ctx = %Context{
        flow_id: "flow-123",
        trigger_data: base_atom_td()
      }

      for {_type, mod} <- @triggers do
        assert {:ok, result, ^ctx} = mod.execute(%{}, %{}, ctx)
        assert is_map(result)
      end
    end

    test "execution with empty trigger_data" do
      ctx = %Context{
        flow_id: "flow-123",
        trigger_data: %{}
      }

      for {_type, mod} <- @triggers do
        assert {:ok, result, ^ctx} = mod.execute(%{}, %{}, ctx)
        assert is_map(result)
      end
    end
  end

  describe "Nodes.Trigger.OnPointMilestone" do
    test "milestone calculation, configuration validation, and fallbacks" do
      ctx_calc = %Context{
        trigger_data: %{
          "balance" => 2500,
          "milestone" => nil,
          "user" => "user-1",
          "currency" => "coins"
        }
      }

      assert {:ok, res, _} =
               Trigger.OnPointMilestone.execute(
                 %{"milestone_values" => "100,500,1000,2000,5000"},
                 %{},
                 ctx_calc
               )

      assert res.milestone == 2000
      assert res.balance == 2500

      # non-integer part in milestone_values string to hit _ -> []
      assert {:ok, res_mixed, _} =
               Trigger.OnPointMilestone.execute(
                 %{"milestone_values" => "100,abc,500,1000"},
                 %{},
                 ctx_calc
               )

      assert res_mixed.milestone == 1000

      # fallback when milestone_values is not string
      assert {:ok, res_fallback, _} =
               Trigger.OnPointMilestone.execute(%{"milestone_values" => 123}, %{}, ctx_calc)

      assert res_fallback.milestone == 1000

      # validate_config
      assert Trigger.OnPointMilestone.validate_config(%{"milestone_values" => "10,20,30"}) == :ok

      assert Trigger.OnPointMilestone.validate_config(%{"milestone_values" => "10,invalid,30"}) ==
               {:error, ["milestone_values must be comma-separated integers"]}

      assert Trigger.OnPointMilestone.validate_config(%{"milestone_values" => 12345}) ==
               {:error, ["milestone_values must be a string"]}
    end
  end

  describe "Nodes.Trigger.OnStreakMilestone" do
    test "streak milestone calculation, configuration validation, and fallbacks" do
      ctx_calc = %Context{
        trigger_data: %{
          "count" => 45,
          "milestone" => nil,
          "user" => "user-1",
          "streak_type" => "daily"
        }
      }

      assert {:ok, res, _} =
               Trigger.OnStreakMilestone.execute(
                 %{"milestone_values" => "7,14,30,60,100"},
                 %{},
                 ctx_calc
               )

      assert res.milestone == 30
      assert res.count == 45

      # non-integer part in milestone_values string to hit _ -> []
      assert {:ok, res_mixed, _} =
               Trigger.OnStreakMilestone.execute(
                 %{"milestone_values" => "7,bad,14,30"},
                 %{},
                 ctx_calc
               )

      assert res_mixed.milestone == 30

      # fallback when milestone_values is not string
      assert {:ok, res_fallback, _} =
               Trigger.OnStreakMilestone.execute(%{"milestone_values" => 999}, %{}, ctx_calc)

      assert res_fallback.milestone == 30

      # validate_config
      assert Trigger.OnStreakMilestone.validate_config(%{"milestone_values" => "7,30,100"}) == :ok

      assert Trigger.OnStreakMilestone.validate_config(%{"milestone_values" => "7,bad,100"}) ==
               {:error, ["milestone_values must be comma-separated integers"]}

      assert Trigger.OnStreakMilestone.validate_config(%{"milestone_values" => 777}) ==
               {:error, ["milestone_values must be a string"]}
    end
  end
end
