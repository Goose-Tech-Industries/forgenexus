defmodule ForgeNexus.Plugins.Nodes.Ticket.ClaimTicket do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    ticket_id = Map.get(inputs, :ticket_id) || Map.get(inputs, "ticket_id")
    staff_user_id = Map.get(inputs, :staff_user_id) || Map.get(inputs, "staff_user_id")

    case ForgeNexus.Tickets.claim_ticket(ticket_id, staff_user_id) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to claim ticket: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "ticket/claim_ticket",
      category: "ticket",
      label: "Claim Ticket",
      description: "Allows a staff member to claim an unassigned ticket.",
      inputs: [
        %{name: "ticket_id", type: "string", required: true},
        %{name: "staff_user_id", type: "string", required: true}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
