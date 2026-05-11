defmodule ForgeNexus.Plugins.Nodes.Ticket.AddInternalNote do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    ticket_id = Map.get(inputs, :ticket_id) || Map.get(inputs, "ticket_id")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    body = Map.get(inputs, :body) || Map.get(inputs, "body")

    attrs = %{ticket_id: ticket_id, user_id: user_id, body: body, is_internal: true}

    case ForgeNexus.Tickets.add_message(attrs) do
      {:ok, msg} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{message_id: msg.id, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to add note: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "ticket/add_internal_note",
      category: "ticket",
      label: "Add Internal Note",
      description: "Adds a staff-only internal note to a ticket.",
      inputs: [
        %{name: "ticket_id", type: "string", required: true},
        %{name: "user_id", type: "string", required: true},
        %{name: "body", type: "string", required: true}
      ],
      outputs: [
        %{name: "message_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
