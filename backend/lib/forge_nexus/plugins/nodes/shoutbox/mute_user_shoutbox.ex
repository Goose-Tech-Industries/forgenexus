defmodule ForgeNexus.Plugins.Nodes.Shoutbox.MuteUserShoutbox do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Cooldowns
  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    duration = Map.get(config, "duration_seconds", 300)

    Cooldowns.set_cooldown(user_id, "shoutbox_mute", duration)

    muted_until =
      DateTime.utc_now()
      |> DateTime.add(duration, :second)
      |> DateTime.to_iso8601()

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{success: true, muted_until: muted_until}, ctx}
  end

  @impl true
  def validate_config(config) do
    seconds = Map.get(config, "duration_seconds", 300)

    if is_number(seconds) and seconds > 0 do
      :ok
    else
      {:error, ["duration_seconds must be a positive number"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "shoutbox/mute_user_shoutbox",
      category: "shoutbox",
      label: "Mute User (Shoutbox)",
      description: "Mutes a user from the shoutbox for a specified duration.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "muted_until", type: "string"}
      ],
      config_fields: [
        %{
          name: "duration_seconds",
          type: "number",
          default: 300,
          description: "Mute duration in seconds (default 5 minutes)"
        }
      ]
    }
  end
end
