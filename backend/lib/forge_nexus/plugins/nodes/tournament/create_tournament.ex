defmodule ForgeNexus.Plugins.Nodes.Tournament.CreateTournament do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    name = Map.get(inputs, :name) || Map.get(inputs, "name")
    description = Map.get(inputs, :description) || Map.get(inputs, "description")
    format = Map.get(config, "format", "single_elimination")
    max_participants = Map.get(config, "max_participants", 16)

    case ForgeNexus.Tournaments.create_tournament(%{
           name: name,
           description: description,
           format: format,
           max_participants: max_participants,
           community_id: ctx.community_id
         }) do
      {:ok, tournament} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{tournament_id: tournament.id, success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create tournament: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        if Map.get(config, "format") in ~w(single_elimination double_elimination round_robin swiss),
          do: e,
          else: [
            "format must be one of: single_elimination, double_elimination, round_robin, swiss"
            | e
          ]
      end)
      |> then(fn e ->
        max = Map.get(config, "max_participants")

        if is_nil(max) or (is_number(max) and max > 0),
          do: e,
          else: ["max_participants must be a positive number" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "tournament/create_tournament",
      category: "tournament",
      label: "Create Tournament",
      description: "Creates a new tournament with the specified format and participant limit.",
      inputs: [
        %{name: "name", type: "string", required: true},
        %{name: "description", type: "string", required: false}
      ],
      outputs: [
        %{name: "tournament_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "format",
          type: "select",
          options: ~w(single_elimination double_elimination round_robin swiss),
          default: "single_elimination",
          description: "Tournament bracket format"
        },
        %{
          name: "max_participants",
          type: "number",
          default: 16,
          description: "Maximum number of participants"
        }
      ]
    }
  end
end
