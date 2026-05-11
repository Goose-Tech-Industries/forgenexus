defmodule ForgeNexus.Plugins.SlashCommands do
  @moduledoc "Context module for managing and executing slash commands."

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Plugins.SlashCommand
  alias ForgeNexus.Plugins.Engine.Executor
  alias ForgeNexus.Economy

  require Logger

  # -- Queries ---------------------------------------------------------------

  def list_commands do
    from(c in SlashCommand,
      where: c.enabled == true,
      order_by: [asc: c.category, asc: c.name]
    )
    |> Repo.all()
  end

  def get_command!(id), do: Repo.get!(SlashCommand, id)

  def get_command_by_name(name) do
    name = name |> String.trim_leading("/") |> String.downcase()
    Repo.get_by(SlashCommand, name: name)
  end

  # -- CRUD ------------------------------------------------------------------

  def create_command(attrs) do
    %SlashCommand{}
    |> SlashCommand.changeset(attrs)
    |> Repo.insert()
  end

  def update_command(%SlashCommand{} = command, attrs) do
    command
    |> SlashCommand.changeset(attrs)
    |> Repo.update()
  end

  def delete_command(%SlashCommand{is_built_in: true}),
    do: {:error, :cannot_delete_built_in}

  def delete_command(%SlashCommand{} = command),
    do: Repo.delete(command)

  # -- Execution -------------------------------------------------------------

  def execute_command(command_name, args_string, user) do
    name = command_name |> String.trim_leading("/") |> String.downcase()
    args_string = args_string || ""
    args_list = args_string |> String.trim() |> String.split(~r/\s+/, trim: true)

    case get_command_by_name(name) do
      nil ->
        {:error, :unknown_command}

      %SlashCommand{enabled: false} ->
        {:error, :command_disabled}

      command ->
        with :ok <- check_permission(command, user),
             :ok <- check_cooldown(command, user) do
          from(c in SlashCommand, where: c.id == ^command.id)
          |> Repo.update_all(inc: [usage_count: 1])

          trigger_data = %{
            command_name: name,
            args: args_string,
            args_list: args_list,
            user: %{id: user.id, username: user.username},
            raw_input: "/#{name} #{args_string}" |> String.trim()
          }

          result =
            if command.is_built_in do
              execute_built_in(name, args_string, args_list, user)
            else
              execute_custom(command, trigger_data, user)
            end

          if command.cooldown_seconds > 0 do
            set_cooldown(command, user, command.cooldown_seconds)
          end

          result
        end
    end
  end

  # -- Permission check ------------------------------------------------------

  defp check_permission(%SlashCommand{permission_level: "everyone"}, _user), do: :ok

  defp check_permission(%SlashCommand{permission_level: level}, user) do
    user_level = get_user_level(user)
    levels = %{"member" => 1, "moderator" => 2, "admin" => 3}
    required = Map.get(levels, level, 0)
    actual = Map.get(levels, user_level, 0)
    if actual >= required, do: :ok, else: {:error, :insufficient_permission}
  end

  defp get_user_level(user) do
    cond do
      Map.get(user, :is_admin, false) -> "admin"
      Map.get(user, :is_moderator, false) -> "moderator"
      true -> "member"
    end
  end

  # -- Cooldown --------------------------------------------------------------

  def check_cooldown(%SlashCommand{cooldown_seconds: 0}, _user), do: :ok

  def check_cooldown(%SlashCommand{} = command, user) do
    key = "slash:#{command.name}:#{user.id}"
    case ForgeNexus.Cache.get(key) do
      {:ok, nil} -> :ok
      {:ok, expires_at} ->
        remaining = DateTime.diff(expires_at, DateTime.utc_now())
        if remaining > 0, do: {:error, {:cooldown, remaining}}, else: :ok
      _ -> :ok
    end
  end

  def set_cooldown(%SlashCommand{} = command, user, seconds) do
    key = "slash:#{command.name}:#{user.id}"
    expires_at = DateTime.add(DateTime.utc_now(), seconds, :second)
    ForgeNexus.Cache.put(key, expires_at, ttl_ms: :timer.seconds(seconds))
  end

  # -- Custom command execution (via flows) ----------------------------------

  defp execute_custom(%SlashCommand{flow_id: nil}, _trigger_data, _user),
    do: {:error, :no_flow_linked}

  defp execute_custom(%SlashCommand{flow_id: flow_id}, trigger_data, user) do
    case Executor.execute_flow(flow_id, trigger_data, user.id) do
      {:completed, result} -> {:ok, %{type: "flow", result: result}}
      {:failed, reason} -> {:error, {:flow_failed, reason}}
      other -> other
    end
  end

  # -- Built-in command handlers ---------------------------------------------

  defp execute_built_in("daily", _args, _args_list, user) do
    key = "daily:#{user.id}"
    case ForgeNexus.Cache.get(key) do
      {:ok, nil} ->
        Economy.award_points(user.id, "daily_login", amount: 100, description: "Daily reward")
        ForgeNexus.Cache.put(key, true, ttl_ms: :timer.hours(24))
        {:ok, %{type: "economy", message: "You claimed your daily reward of 100 points!", points: 100}}
      {:ok, _} ->
        {:ok, %{type: "economy", message: "You already claimed your daily reward. Come back tomorrow!"}}
    end
  end

  defp execute_built_in("balance", _args, _args_list, user) do
    points = Economy.get_points(user.id)
    {:ok, %{type: "economy", message: "Your balance: #{points} points", points: points}}
  end

  defp execute_built_in("pay", _args, args_list, user) do
    case args_list do
      [target_username, amount_str | _] ->
        case Integer.parse(amount_str) do
          {amount, _} when amount > 0 ->
            case ForgeNexus.Repo.get_by(ForgeNexus.Accounts.User, username: target_username) do
              nil ->
                {:ok, %{type: "error", message: "User not found."}}
              target when target.id == user.id ->
                {:ok, %{type: "error", message: "You cannot pay yourself!"}}
              target ->
                case Economy.deduct_points(user.id, amount, "transfer_out", description: "Paid #{target_username}") do
                  {:ok, _} ->
                    Economy.award_points(target.id, "transfer_in", amount: amount, description: "Received from #{user.username}")
                    {:ok, %{type: "economy", message: "Sent #{amount} points to #{target_username}."}}
                  {:error, :insufficient_points} ->
                    {:ok, %{type: "error", message: "Insufficient points."}}
                end
            end
          _ ->
            {:ok, %{type: "error", message: "Invalid amount. Usage: /pay <username> <amount>"}}
        end
      _ ->
        {:ok, %{type: "error", message: "Usage: /pay <username> <amount>"}}
    end
  end

  defp execute_built_in("roll", _args, args_list, _user) do
    {count, sides} = parse_dice(List.first(args_list, "1d6"))
    rolls = for _ <- 1..count, do: :rand.uniform(sides)
    total = Enum.sum(rolls)
    {:ok, %{type: "fun", message: "Rolled #{count}d#{sides}: [#{Enum.join(rolls, ", ")}] = #{total}", rolls: rolls, total: total}}
  end

  defp execute_built_in("flip", _args, _args_list, _user) do
    result = Enum.random(["Heads", "Tails"])
    {:ok, %{type: "fun", message: "Coin flip: #{result}!", result: result}}
  end

  defp execute_built_in("8ball", _args, _args_list, _user) do
    responses = [
      "It is certain.", "It is decidedly so.", "Without a doubt.",
      "Yes, definitely.", "You may rely on it.", "As I see it, yes.",
      "Most likely.", "Outlook good.", "Yes.", "Signs point to yes.",
      "Reply hazy, try again.", "Ask again later.", "Better not tell you now.",
      "Cannot predict now.", "Concentrate and ask again.",
      "Do not count on it.", "My reply is no.", "My sources say no.",
      "Outlook not so good.", "Very doubtful."
    ]
    answer = Enum.random(responses)
    {:ok, %{type: "fun", message: answer}}
  end

  defp execute_built_in("poll", args, _args_list, _user), do: {:ok, %{type: "utility", message: "Poll created!", question: args}}
  defp execute_built_in("remind", args, _args_list, user), do: {:ok, %{type: "utility", message: "Reminder set: #{args}", user_id: user.id}}

  defp execute_built_in("stats", _args, _args_list, user) do
    points = Economy.get_points(user.id)
    {:ok, %{type: "profile", message: "Stats for #{user.username}", stats: %{points: points, username: user.username, id: user.id}}}
  end

  defp execute_built_in("inventory", _args, _args_list, user), do: {:ok, %{type: "rpg", message: "Inventory for #{user.username}", user_id: user.id, items: []}}
  defp execute_built_in("equip", args, _args_list, user), do: {:ok, %{type: "rpg", message: "Equip: #{args}", user_id: user.id}}
  defp execute_built_in("pet", _args, _args_list, user), do: {:ok, %{type: "rpg", message: "Pet info for #{user.username}", user_id: user.id}}
  defp execute_built_in("quest", _args, _args_list, user), do: {:ok, %{type: "rpg", message: "Active quests for #{user.username}", user_id: user.id, quests: []}}

  defp execute_built_in("rank", _args, _args_list, user) do
    points = Economy.get_points(user.id)
    {:ok, %{type: "economy", message: "Your points: #{points}", points: points, user_id: user.id}}
  end

  defp execute_built_in("rep", _args, args_list, user) do
    case args_list do
      [target_username | _] ->
        case ForgeNexus.Repo.get_by(ForgeNexus.Accounts.User, username: target_username) do
          nil -> {:ok, %{type: "error", message: "User not found."}}
          target when target.id == user.id -> {:ok, %{type: "error", message: "You cannot rep yourself!"}}
          target -> {:ok, %{type: "social", message: "You gave +1 rep to #{target.username}.", target_id: target.id}}
        end
      _ -> {:ok, %{type: "error", message: "Usage: /rep <username>"}}
    end
  end

  defp execute_built_in("profile", _args, args_list, user) do
    target = List.first(args_list)
    profile_user = if target, do: ForgeNexus.Repo.get_by(ForgeNexus.Accounts.User, username: target), else: user
    case profile_user do
      nil -> {:ok, %{type: "error", message: "User not found."}}
      u -> {:ok, %{type: "profile", message: "Profile: #{u.username}", user: %{id: u.id, username: u.username}}}
    end
  end

  defp execute_built_in("help", _args, _args_list, _user) do
    commands = list_commands()
    grouped = Enum.group_by(commands, & &1.category)
    categories = Enum.map(grouped, fn {cat, cmds} ->
      %{category: cat, commands: Enum.map(cmds, fn c -> %{name: c.name, description: c.description} end)}
    end)
    {:ok, %{type: "utility", message: "Available commands", categories: categories}}
  end

  defp execute_built_in("ticket", args, _args_list, user), do: {:ok, %{type: "utility", message: "Support ticket created.", subject: args, user_id: user.id}}
  defp execute_built_in("suggest", args, _args_list, user), do: {:ok, %{type: "utility", message: "Suggestion submitted!", suggestion: args, user_id: user.id}}
  defp execute_built_in("streak", _args, _args_list, user), do: {:ok, %{type: "profile", message: "Streaks for #{user.username}", user_id: user.id, streaks: %{}}}
  defp execute_built_in(name, _args, _args_list, _user), do: {:error, {:unhandled_built_in, name}}

  # -- Dice parser -----------------------------------------------------------

  defp parse_dice(input) do
    case Regex.run(~r/^(\d+)?d(\d+)$/i, input || "1d6") do
      [_, count_str, sides_str] ->
        count = safe_int(count_str, 1) |> min(100) |> max(1)
        sides = safe_int(sides_str, 6) |> min(1000) |> max(2)
        {count, sides}
      _ -> {1, 6}
    end
  end

  defp safe_int("", default), do: default
  defp safe_int(str, default) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end

  # -- Seed built-in commands ------------------------------------------------

  def seed_built_in_commands do
    built_ins = [
      %{name: "daily", description: "Claim your daily reward", category: "economy"},
      %{name: "balance", description: "Check your point balance", category: "economy"},
      %{name: "pay", description: "Transfer points to another user", category: "economy"},
      %{name: "roll", description: "Roll dice, e.g. /roll 2d6", category: "fun"},
      %{name: "flip", description: "Flip a coin", category: "fun"},
      %{name: "8ball", description: "Ask the Magic 8-Ball a question", category: "fun"},
      %{name: "poll", description: "Create a quick poll", category: "utility"},
      %{name: "remind", description: "Set a reminder", category: "utility"},
      %{name: "stats", description: "View your stats", category: "profile"},
      %{name: "inventory", description: "View your inventory", category: "rpg"},
      %{name: "equip", description: "Equip an item", category: "rpg"},
      %{name: "pet", description: "View or interact with your pet", category: "rpg"},
      %{name: "quest", description: "View your active quests", category: "rpg"},
      %{name: "rank", description: "View your leaderboard position", category: "economy"},
      %{name: "rep", description: "Give reputation to a user", category: "social"},
      %{name: "profile", description: "View a profile card", category: "profile"},
      %{name: "help", description: "List all available commands", category: "utility"},
      %{name: "ticket", description: "Open a support ticket", category: "utility"},
      %{name: "suggest", description: "Submit a suggestion", category: "utility"},
      %{name: "streak", description: "View your activity streaks", category: "profile"}
    ]

    Enum.each(built_ins, fn cmd_attrs ->
      attrs = Map.merge(cmd_attrs, %{is_built_in: true, enabled: true})
      case get_command_by_name(cmd_attrs.name) do
        nil -> create_command(attrs)
        existing -> update_command(existing, attrs)
      end
    end)

    :ok
  end
end
