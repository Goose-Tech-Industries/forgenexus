defmodule ForgeNexus.Plugins.Nodes.Ticket.CreateTicket do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    title = Map.get(inputs, :title) || Map.get(inputs, "title")
    description = Map.get(inputs, :description) || Map.get(inputs, "description")
    priority = Map.get(config, "priority", "normal")
    category = Map.get(config, "category", "")

    attrs = %{
      user_id: user_id,
      title: title,
      description: description,
      priority: priority,
      category: category,
      status: "open"
    }

    case ForgeNexus.Tickets.create_ticket(attrs) do
      {:ok, ticket} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{ticket_id: ticket.id, success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create ticket: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        if Map.get(config, "priority", "normal") in ~w(low normal high urgent),
          do: e,
          else: ["priority must be low, normal, high, or urgent" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "ticket/create_ticket",
      category: "ticket",
      label: "Create Ticket",
      description: "Creates a new support ticket with priority and category.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "title", type: "string", required: true},
        %{name: "description", type: "string", required: true}
      ],
      outputs: [
        %{name: "ticket_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "priority",
          type: "select",
          options: ~w(low normal high urgent),
          default: "normal",
          description: "Ticket priority level"
        },
        %{name: "category", type: "string", default: "", description: "Ticket category"}
      ]
    }
  end
end
