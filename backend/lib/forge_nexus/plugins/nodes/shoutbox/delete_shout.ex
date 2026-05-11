defmodule ForgeNexus.Plugins.Nodes.Shoutbox.DeleteShout do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Chat
  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    message_id = Map.get(inputs, :message_id) || Map.get(inputs, "message_id")

    case Chat.delete_shout(message_id) do
      {:ok, _message} ->
        ForgeNexusWeb.Endpoint.broadcast("shoutbox:lobby", "shout_deleted", %{
          message_id: message_id
        })

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
      type: "shoutbox/delete_shout",
      category: "shoutbox",
      label: "Delete Shout",
      description: "Deletes a specific shoutbox message by ID.",
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
