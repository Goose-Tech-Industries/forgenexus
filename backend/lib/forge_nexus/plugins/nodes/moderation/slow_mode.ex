defmodule ForgeNexus.Plugins.Nodes.Moderation.SlowMode do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    forum_id = Map.get(inputs, :forum_id) || Map.get(inputs, "forum_id")
    seconds_in = Map.get(inputs, :seconds) || Map.get(inputs, "seconds", 0)
    seconds = if is_integer(seconds_in), do: seconds_in, else: trunc(seconds_in)

    if forum_id do
      case ForgeNexus.Forums.set_forum_slow_mode(forum_id, seconds) do
        {:ok, _} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{success: true}, ctx}

        {:error, err} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:error, "Failed to set slow mode: #{inspect(err)}", ctx}
      end
    else
      {:error, "forum_id is required (channel_id not yet supported)", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "moderation/slow_mode",
      category: "moderation",
      label: "Slow Mode",
      description: "Sets a slow mode delay on a forum or channel.",
      inputs: [
        %{name: "forum_id", type: "string", required: false},
        %{name: "channel_id", type: "string", required: false},
        %{name: "seconds", type: "number", required: true}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
