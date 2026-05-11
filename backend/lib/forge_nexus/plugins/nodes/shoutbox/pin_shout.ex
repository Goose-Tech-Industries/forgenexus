defmodule ForgeNexus.Plugins.Nodes.Shoutbox.PinShout do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Chat
  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    message_id = Map.get(inputs, :message_id) || Map.get(inputs, "message_id")

    case Chat.pin_shout(message_id) do
      {:ok, _message} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, :not_found} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: false}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "shoutbox/pin_shout",
      category: "shoutbox",
      label: "Pin Shout",
      description: "Pins a shoutbox message so it stays visible at the top.",
      inputs: [
        %{name: "message_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
