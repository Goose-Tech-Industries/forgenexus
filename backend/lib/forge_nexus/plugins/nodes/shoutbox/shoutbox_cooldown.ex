defmodule ForgeNexus.Plugins.Nodes.Shoutbox.ShoutboxCooldown do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Cooldowns
  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    cooldown_seconds = Map.get(config, "cooldown_seconds", 5)

    case Cooldowns.check_cooldown(user_id, "shoutbox") do
      :ok ->
        Cooldowns.set_cooldown(user_id, "shoutbox", cooldown_seconds)
        ctx = Sandbox.increment_db_ops(ctx)
        {:branch, "allowed", inputs, ctx}

      {:error, _remaining} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:branch, "cooldown", inputs, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    seconds = Map.get(config, "cooldown_seconds", 5)

    if is_number(seconds) and seconds > 0 do
      :ok
    else
      {:error, ["cooldown_seconds must be a positive number"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "shoutbox/shoutbox_cooldown",
      category: "shoutbox",
      label: "Shoutbox Cooldown",
      description:
        "Checks if a user is on shoutbox cooldown. Branches to 'allowed' or 'cooldown'.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "allowed", type: "any"},
        %{name: "cooldown", type: "any"}
      ],
      config_fields: [
        %{
          name: "cooldown_seconds",
          type: "number",
          default: 5,
          description: "Cooldown duration in seconds between shouts"
        }
      ]
    }
  end
end
