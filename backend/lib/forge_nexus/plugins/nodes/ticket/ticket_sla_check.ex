defmodule ForgeNexus.Plugins.Nodes.Ticket.TicketSlaCheck do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    ticket_id = Map.get(inputs, :ticket_id) || Map.get(inputs, "ticket_id")
    max_response_hours = Map.get(config, "max_response_hours", 24) |> to_number()

    hours_elapsed =
      case ForgeNexus.Tickets.get_ticket(ticket_id) do
        {:ok, t} -> NaiveDateTime.diff(NaiveDateTime.utc_now(), t.inserted_at) / 3600.0
        _ -> 0.0
      end

    ctx = Sandbox.increment_db_ops(ctx)
    outputs = %{hours_elapsed: Float.round(hours_elapsed, 2), threshold: max_response_hours}

    if hours_elapsed > max_response_hours do
      {:branch, "breached", outputs, ctx}
    else
      {:branch, "within_sla", outputs, ctx}
    end
  end

  defp to_number(v) when is_number(v), do: v

  defp to_number(v) when is_binary(v) do
    case Float.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_number(_), do: 0

  @impl true
  def validate_config(config) do
    case Map.get(config, "max_response_hours") do
      nil ->
        :ok

      v when is_number(v) and v > 0 ->
        :ok

      v when is_binary(v) ->
        case Float.parse(v) do
          {n, _} when n > 0 -> :ok
          _ -> {:error, ["max_response_hours must be a positive number"]}
        end

      _ ->
        {:error, ["max_response_hours must be a positive number"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "ticket/ticket_sla_check",
      category: "ticket",
      label: "Ticket SLA Check",
      description: "Branches based on whether a ticket response time is within SLA or breached.",
      inputs: [%{name: "ticket_id", type: "string", required: true}],
      outputs: [
        %{name: "within_sla", type: "branch", fields: [%{name: "hours_elapsed", type: "number"}, %{name: "threshold", type: "number"}]},
        %{name: "breached", type: "branch", fields: [%{name: "hours_elapsed", type: "number"}, %{name: "threshold", type: "number"}]}
      ],
      config_fields: [
        %{name: "max_response_hours", type: "number", default: 24, description: "Maximum hours before SLA is considered breached"}
      ]
    }
  end
end
