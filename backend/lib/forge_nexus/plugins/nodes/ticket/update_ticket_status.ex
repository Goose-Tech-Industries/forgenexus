defmodule ForgeNexus.Plugins.Nodes.Ticket.UpdateTicketStatus do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    ticket_id = Map.get(inputs, :ticket_id) || Map.get(inputs, "ticket_id")
    status = Map.get(config, "status", "open")

    previous_status =
      case ForgeNexus.Tickets.get_ticket(ticket_id) do
        {:ok, t} -> t.status
        _ -> nil
      end

    case ForgeNexus.Tickets.update_status(ticket_id, status) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true, previous_status: previous_status}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to update status: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    if Map.get(config, "status", "open") in ~w(open in_progress waiting resolved closed),
      do: :ok,
      else: {:error, ["status must be open, in_progress, waiting, resolved, or closed"]}
  end

  @impl true
  def schema do
    %{
      type: "ticket/update_ticket_status",
      category: "ticket",
      label: "Update Ticket Status",
      description: "Updates the status of a support ticket.",
      inputs: [%{name: "ticket_id", type: "string", required: true}],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "previous_status", type: "string"}
      ],
      config_fields: [
        %{
          name: "status",
          type: "select",
          options: ~w(open in_progress waiting resolved closed),
          default: "open",
          description: "New ticket status"
        }
      ]
    }
  end
end
