defmodule ForgeNexus.Plugins.Nodes.Tournament.GetStandings do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    tournament_id = Map.get(inputs, :tournament_id) || Map.get(inputs, "tournament_id")
    _limit = Map.get(config, "limit", 20)

    standings = ForgeNexus.Tournaments.get_standings(tournament_id)
    ctx = Sandbox.increment_db_ops(ctx)

    formatted =
      Enum.map(standings, fn s ->
        %{
          user_id: s.user_id,
          username: s.username,
          wins: s.wins,
          losses: s.losses,
          points: s.points,
          is_eliminated: s.is_eliminated
        }
      end)

    {:ok, %{standings: formatted, count: length(formatted)}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "tournament/get_standings",
      category: "tournament",
      label: "Get Standings",
      description: "Retrieves the current standings for a tournament.",
      inputs: [
        %{name: "tournament_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "standings", type: "list"}
      ],
      config_fields: [
        %{
          name: "limit",
          type: "number",
          default: 20,
          description: "Maximum number of standings to return"
        }
      ]
    }
  end
end
