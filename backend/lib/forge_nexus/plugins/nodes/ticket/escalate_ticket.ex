defmodule ForgeNexus.Plugins.Nodes.Ticket.EscalateTicket do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    ticket_id = Map.get(inputs, :ticket_id) || Map.get(inputs, "ticket_id")
    reason = Map.get(config, "reason", "")

    case ForgeNexus.Tickets.escalate_ticket(ticket_id, reason) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to escalate: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "ticket/escalate_ticket",
      category: "ticket",
      label: "Escalate Ticket",
      description: "Escalates a ticket to higher-level support with a reason.",
      inputs: [%{name: "ticket_id", type: "string", required: true}],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: [
        %{name: "reason", type: "string", default: "", description: "Reason for escalation"}
      ]
    }
  end
end
