defmodule ForgeNexus.Plugins.Nodes.Tournament.GetMatchup do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    tournament_id = Map.get(inputs, :tournament_id) || Map.get(inputs, "tournament_id")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    match = ForgeNexus.Tournaments.get_current_matchup(tournament_id, user_id)
    ctx = Sandbox.increment_db_ops(ctx)

    case match do
      nil ->
        {:ok, %{match: nil, has_match: false}, ctx}

      match ->
        {:ok,
         %{
           match: %{
             match_id: match.id,
             opponent: match.opponent_id,
             round: match.round,
             status: match.status
           },
           has_match: true
         }, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "tournament/get_matchup",
      category: "tournament",
      label: "Get Matchup",
      description: "Retrieves the current match for a user in a tournament.",
      inputs: [
        %{name: "tournament_id", type: "string", required: true},
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "match", type: "map"}
      ],
      config_fields: []
    }
  end
end
