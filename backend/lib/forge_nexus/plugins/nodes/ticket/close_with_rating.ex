defmodule ForgeNexus.Plugins.Nodes.Ticket.CloseWithRating do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    ticket_id = Map.get(inputs, :ticket_id) || Map.get(inputs, "ticket_id")
    rating_int = inputs |> Map.get(:rating, Map.get(inputs, "rating")) |> to_int()

    if rating_int < 1 or rating_int > 5 do
      {:error, "Rating must be between 1 and 5", ctx}
    else
      case ForgeNexus.Tickets.close_with_rating(ticket_id, rating_int) do
        {:ok, _} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{success: true}, ctx}

        {:error, err} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:error, "Failed to close: #{inspect(err)}", ctx}
      end
    end
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: trunc(v)

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_int(_), do: 0

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "ticket/close_with_rating",
      category: "ticket",
      label: "Close with Rating",
      description: "Closes a ticket and records a satisfaction rating (1-5).",
      inputs: [
        %{name: "ticket_id", type: "string", required: true},
        %{name: "rating", type: "number", required: true}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
