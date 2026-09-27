defmodule ForgeNexus.Plugins.SlashCommandsTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Economy
  alias ForgeNexus.Plugins.{Flow, FlowEdge, FlowNode, SlashCommand, SlashCommands}
  alias ForgeNexus.Repo

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "user_#{unique_suffix}",
      email: "user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      defaults
      |> Map.merge(Enum.into(attrs, %{}))
      |> Accounts.register_user()

    user
  end

  defp create_test_flow(user, attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      name: "Test Flow #{unique_suffix}",
      slug: "test-flow-#{unique_suffix}",
      description: "Flow for executor tests",
      trigger_type: "manual",
      status: "active",
      created_by_id: user.id
    }

    %Flow{}
    |> Flow.changeset(Map.merge(defaults, Enum.into(attrs, %{})))
    |> Repo.insert!()
  end

  describe "Queries & CRUD" do
    test "create_command/1, get_command!/1, update_command/2, list_commands/0, delete_command/1" do
      attrs = %{
        name: "testcommand",
        description: "A test slash command",
        category: "custom",
        permission_level: "everyone"
      }

      assert {:ok, %SlashCommand{} = cmd} = SlashCommands.create_command(attrs)
      assert cmd.name == "testcommand"
      assert cmd.enabled == true

      # get_command!
      fetched = SlashCommands.get_command!(cmd.id)
      assert fetched.id == cmd.id

      # get_command_by_name with leading slash and uppercase
      assert SlashCommands.get_command_by_name("/TestCommand").id == cmd.id
      assert SlashCommands.get_command_by_name("testcommand").id == cmd.id
      assert SlashCommands.get_command_by_name("nonexistent") == nil

      # update_command
      assert {:ok, updated} =
               SlashCommands.update_command(cmd, %{description: "Updated description"})

      assert updated.description == "Updated description"

      # list_commands orders by category, name and filters enabled
      {:ok, disabled_cmd} = SlashCommands.create_command(%{name: "disabledcmd", enabled: false})
      listed = SlashCommands.list_commands()
      assert Enum.any?(listed, &(&1.id == cmd.id))
      refute Enum.any?(listed, &(&1.id == disabled_cmd.id))

      # delete_command on custom command
      assert {:ok, _deleted} = SlashCommands.delete_command(updated)
      assert SlashCommands.get_command_by_name("testcommand") == nil

      # delete_command on built_in command returns error
      {:ok, built_in} =
        SlashCommands.create_command(%{name: "builtin_del", is_built_in: true})

      assert {:error, :cannot_delete_built_in} = SlashCommands.delete_command(built_in)
    end
  end

  describe "execute_command/3 basic gates and permissions" do
    setup do
      user = create_user()
      {:ok, user: user}
    end

    test "returns {:error, :unknown_command} when command is not found", %{user: user} do
      assert {:error, :unknown_command} = SlashCommands.execute_command("/unknown", "", user)
    end

    test "returns {:error, :command_disabled} when command is disabled", %{user: user} do
      {:ok, _cmd} =
        SlashCommands.create_command(%{
          name: "disabled_cmd",
          enabled: false
        })

      assert {:error, :command_disabled} = SlashCommands.execute_command("disabled_cmd", "", user)
    end

    test "permission checks for everyone, member, moderator, admin", %{user: user} do
      {:ok, _cmd_everyone} =
        SlashCommands.create_command(%{
          name: "perm_everyone",
          permission_level: "everyone",
          is_built_in: true
        })

      {:ok, _cmd_member} =
        SlashCommands.create_command(%{
          name: "perm_member",
          permission_level: "member",
          is_built_in: true
        })

      {:ok, _cmd_mod} =
        SlashCommands.create_command(%{
          name: "perm_mod",
          permission_level: "moderator",
          is_built_in: true
        })

      {:ok, _cmd_admin} =
        SlashCommands.create_command(%{
          name: "perm_admin",
          permission_level: "admin",
          is_built_in: true
        })

      # Everyone level passes
      assert {:error, {:unhandled_built_in, "perm_everyone"}} =
               SlashCommands.execute_command("perm_everyone", "", user)

      # Member level passes for normal user
      assert {:error, {:unhandled_built_in, "perm_member"}} =
               SlashCommands.execute_command("perm_member", "", user)

      # Mod level fails for normal member, passes for moderator or admin
      assert {:error, :insufficient_permission} =
               SlashCommands.execute_command("perm_mod", "", user)

      mod_user = Map.put(user, :is_moderator, true)

      assert {:error, {:unhandled_built_in, "perm_mod"}} =
               SlashCommands.execute_command("perm_mod", "", mod_user)

      admin_user = Map.put(user, :is_admin, true)

      assert {:error, {:unhandled_built_in, "perm_mod"}} =
               SlashCommands.execute_command("perm_mod", "", admin_user)

      # Admin level fails for moderator, passes for admin
      assert {:error, :insufficient_permission} =
               SlashCommands.execute_command("perm_admin", "", mod_user)

      assert {:error, {:unhandled_built_in, "perm_admin"}} =
               SlashCommands.execute_command("perm_admin", "", admin_user)
    end

    test "cooldown logic enforces delay and tracks expiration", %{user: user} do
      {:ok, cmd} =
        SlashCommands.create_command(%{
          name: "cooldown_test",
          cooldown_seconds: 60,
          is_built_in: true
        })

      # First call succeeds (reaches unhandled_built_in handler) and sets cooldown
      assert {:error, {:unhandled_built_in, "cooldown_test"}} =
               SlashCommands.execute_command("cooldown_test", "", user)

      # Second immediate call returns cooldown error
      assert {:error, {:cooldown, remaining}} =
               SlashCommands.execute_command("cooldown_test", "", user)

      assert remaining > 0

      # check_cooldown directly with zero cooldown
      zero_cooldown_cmd = %{cmd | cooldown_seconds: 0}
      assert :ok = SlashCommands.check_cooldown(zero_cooldown_cmd, user)

      # check_cooldown when expired in cache (past timestamp)
      past_key = "slash:cooldown_past:#{user.id}"
      ForgeNexus.Cache.put(past_key, DateTime.add(DateTime.utc_now(), -10, :second))
      past_cmd = %{cmd | name: "cooldown_past"}
      assert :ok = SlashCommands.check_cooldown(past_cmd, user)
    end
  end

  describe "Custom command execution" do
    setup do
      user = create_user()
      {:ok, user: user}
    end

    test "returns {:error, :no_flow_linked} when flow_id is nil", %{user: user} do
      {:ok, _cmd} =
        SlashCommands.create_command(%{
          name: "noflow",
          is_built_in: false,
          flow_id: nil
        })

      assert {:error, :no_flow_linked} = SlashCommands.execute_command("noflow", "", user)
    end

    test "executes custom flow linked to command on success", %{user: user} do
      flow = create_test_flow(user)

      # Trigger node
      trigger_node =
        %FlowNode{}
        |> FlowNode.changeset(%{
          flow_id: flow.id,
          type: "trigger/manual",
          category: "trigger",
          label: "Trigger"
        })
        |> Repo.insert!()

      # Text contains node
      contains_node =
        %FlowNode{}
        |> FlowNode.changeset(%{
          flow_id: flow.id,
          type: "text/contains",
          category: "text",
          label: "Contains",
          config: %{"case_sensitive" => false}
        })
        |> Repo.insert!()

      # Edge
      %FlowEdge{}
      |> FlowEdge.changeset(%{
        flow_id: flow.id,
        source_node_id: trigger_node.id,
        target_node_id: contains_node.id,
        source_port: "output",
        target_port: "input"
      })
      |> Repo.insert!()

      {:ok, _cmd} =
        SlashCommands.create_command(%{
          name: "custom_text",
          is_built_in: false,
          flow_id: flow.id
        })

      assert {:ok, %{type: "flow", result: result}} =
               SlashCommands.execute_command("custom_text", "hello world", user)

      assert is_map(result)
    end

    test "handles custom flow execution failure", %{user: user} do
      # Flow with no trigger node fails
      flow = create_test_flow(user)

      {:ok, _cmd} =
        SlashCommands.create_command(%{
          name: "custom_fail",
          is_built_in: false,
          flow_id: flow.id
        })

      assert {:error, {:flow_failed, %{error: "No trigger node found in flow"}}} =
               SlashCommands.execute_command("custom_fail", "", user)
    end
  end

  describe "Built-in commands" do
    setup do
      user = create_user()
      {:ok, user: user}
    end

    test "daily command awards points then enforces once-per-day restriction", %{user: user} do
      {:ok, _} = SlashCommands.create_command(%{name: "daily", is_built_in: true})

      assert {:ok, %{type: "economy", points: 100}} =
               SlashCommands.execute_command("daily", "", user)

      assert Economy.get_points(user.id) >= 100

      assert {:ok,
              %{
                type: "economy",
                message: "You already claimed your daily reward. Come back tomorrow!"
              }} =
               SlashCommands.execute_command("daily", "", user)
    end

    test "balance command returns user point balance", %{user: user} do
      {:ok, _} = SlashCommands.create_command(%{name: "balance", is_built_in: true})
      Economy.award_points(user.id, "bonus", amount: 250, description: "test")

      assert {:ok, %{type: "economy", points: 250}} =
               SlashCommands.execute_command("balance", "", user)
    end

    test "pay command handles validations, self-pay, insufficient balance, and success", %{
      user: user
    } do
      {:ok, _} = SlashCommands.create_command(%{name: "pay", is_built_in: true})
      target = create_user()

      # Usage error
      assert {:ok, %{type: "error", message: "Usage: /pay <username> <amount>"}} =
               SlashCommands.execute_command("pay", "", user)

      # Invalid amount
      assert {:ok, %{type: "error", message: "Invalid amount. Usage: /pay <username> <amount>"}} =
               SlashCommands.execute_command("pay", "#{target.username} not_a_number", user)

      # Negative / zero amount
      assert {:ok, %{type: "error", message: "Invalid amount. Usage: /pay <username> <amount>"}} =
               SlashCommands.execute_command("pay", "#{target.username} 0", user)

      # User not found
      assert {:ok, %{type: "error", message: "User not found."}} =
               SlashCommands.execute_command("pay", "nonexistent_target_user 50", user)

      # Paying self
      assert {:ok, %{type: "error", message: "You cannot pay yourself!"}} =
               SlashCommands.execute_command("pay", "#{user.username} 50", user)

      # Insufficient balance
      assert {:ok, %{type: "error", message: "Insufficient points."}} =
               SlashCommands.execute_command("pay", "#{target.username} 500", user)

      # Success
      Economy.award_points(user.id, "grant", amount: 300, description: "fund")

      assert {:ok, %{type: "economy", message: "Sent 50 points to " <> _}} =
               SlashCommands.execute_command("pay", "#{target.username} 50", user)

      assert Economy.get_points(user.id) == 250
      assert Economy.get_points(target.id) == 50
    end

    test "roll command parses dice notation, clamped bounds, and default fallback", %{user: user} do
      {:ok, _} = SlashCommands.create_command(%{name: "roll", is_built_in: true})

      # Default
      assert {:ok, %{type: "fun", rolls: [r], total: r}} =
               SlashCommands.execute_command("roll", "", user)

      assert r in 1..6

      # Explicit 2d20
      assert {:ok, %{type: "fun", rolls: rolls, total: total}} =
               SlashCommands.execute_command("roll", "2d20", user)

      assert length(rolls) == 2
      assert total == Enum.sum(rolls)

      # Notation with omitted count, e.g. "d10"
      assert {:ok, %{type: "fun", rolls: [roll_d10]}} =
               SlashCommands.execute_command("roll", "d10", user)

      assert roll_d10 in 1..10

      # Notation clamping (exceeding maximums)
      assert {:ok, %{type: "fun", rolls: rolls_max}} =
               SlashCommands.execute_command("roll", "500d5000", user)

      assert length(rolls_max) == 100

      # Invalid dice format falls back to 1d6
      assert {:ok, %{type: "fun", rolls: [fallback_roll]}} =
               SlashCommands.execute_command("roll", "invalid_syntax", user)

      assert fallback_roll in 1..6
    end

    test "flip, 8ball, poll, remind, stats, inventory, equip, pet, quest, rank", %{user: user} do
      {:ok, _} = SlashCommands.create_command(%{name: "flip", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "8ball", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "poll", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "remind", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "stats", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "inventory", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "equip", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "pet", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "quest", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "rank", is_built_in: true})

      # flip
      assert {:ok, %{type: "fun", result: res}} = SlashCommands.execute_command("flip", "", user)
      assert res in ["Heads", "Tails"]

      # 8ball
      assert {:ok, %{type: "fun", message: msg}} =
               SlashCommands.execute_command("8ball", "Is today good?", user)

      assert is_binary(msg) and byte_size(msg) > 0

      # poll
      assert {:ok, %{type: "utility", question: "Favorite color?"}} =
               SlashCommands.execute_command("poll", "Favorite color?", user)

      # remind
      assert {:ok, %{type: "utility", message: "Reminder set: Take a break"}} =
               SlashCommands.execute_command("remind", "Take a break", user)

      # stats
      assert {:ok, %{type: "profile", stats: %{username: uname}}} =
               SlashCommands.execute_command("stats", "", user)

      assert uname == user.username

      # inventory
      assert {:ok, %{type: "rpg", items: []}} =
               SlashCommands.execute_command("inventory", "", user)

      # equip
      assert {:ok, %{type: "rpg", message: "Equip: iron_sword"}} =
               SlashCommands.execute_command("equip", "iron_sword", user)

      # pet
      assert {:ok, %{type: "rpg", message: "Pet info for " <> _}} =
               SlashCommands.execute_command("pet", "", user)

      # quest
      assert {:ok, %{type: "rpg", quests: []}} =
               SlashCommands.execute_command("quest", "", user)

      # rank
      assert {:ok, %{type: "economy", points: _}} =
               SlashCommands.execute_command("rank", "", user)
    end

    test "rep command validates arguments, target user, and self-rep", %{user: user} do
      {:ok, _} = SlashCommands.create_command(%{name: "rep", is_built_in: true})
      target = create_user()

      # Usage error
      assert {:ok, %{type: "error", message: "Usage: /rep <username>"}} =
               SlashCommands.execute_command("rep", "", user)

      # Target not found
      assert {:ok, %{type: "error", message: "User not found."}} =
               SlashCommands.execute_command("rep", "nonexistent_rep_target", user)

      # Cannot rep self
      assert {:ok, %{type: "error", message: "You cannot rep yourself!"}} =
               SlashCommands.execute_command("rep", user.username, user)

      # Successful rep
      assert {:ok, %{type: "social", message: "You gave +1 rep to " <> _, target_id: tid}} =
               SlashCommands.execute_command("rep", target.username, user)

      assert tid == target.id
    end

    test "profile command handles self profile, target user profile, and user not found", %{
      user: user
    } do
      {:ok, _} = SlashCommands.create_command(%{name: "profile", is_built_in: true})
      target = create_user()

      # Self profile (no target arg)
      assert {:ok, %{type: "profile", user: %{username: uname}}} =
               SlashCommands.execute_command("profile", "", user)

      assert uname == user.username

      # Target profile
      assert {:ok, %{type: "profile", user: %{username: target_uname}}} =
               SlashCommands.execute_command("profile", target.username, user)

      assert target_uname == target.username

      # Target not found
      assert {:ok, %{type: "error", message: "User not found."}} =
               SlashCommands.execute_command("profile", "unknown_profile_target", user)
    end

    test "help, ticket, suggest, streak commands", %{user: user} do
      {:ok, _} =
        SlashCommands.create_command(%{name: "help", category: "utility", is_built_in: true})

      {:ok, _} = SlashCommands.create_command(%{name: "ticket", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "suggest", is_built_in: true})
      {:ok, _} = SlashCommands.create_command(%{name: "streak", is_built_in: true})

      # help
      assert {:ok, %{type: "utility", categories: cats}} =
               SlashCommands.execute_command("help", "", user)

      assert is_list(cats)

      # ticket
      assert {:ok, %{type: "utility", subject: "Server lag", message: "Support ticket created."}} =
               SlashCommands.execute_command("ticket", "Server lag", user)

      # suggest
      assert {:ok, %{type: "utility", suggestion: "Add emojis", message: "Suggestion submitted!"}} =
               SlashCommands.execute_command("suggest", "Add emojis", user)

      # streak
      assert {:ok, %{type: "profile", message: "Streaks for " <> _}} =
               SlashCommands.execute_command("streak", "", user)
    end

    test "seed_built_in_commands/0 creates commands and updates on subsequent runs" do
      assert :ok = SlashCommands.seed_built_in_commands()

      # Verify created commands exist
      assert %SlashCommand{} = SlashCommands.get_command_by_name("daily")
      assert %SlashCommand{} = SlashCommands.get_command_by_name("roll")

      # Running a second time exercises the update branch
      assert :ok = SlashCommands.seed_built_in_commands()
    end
  end
end
