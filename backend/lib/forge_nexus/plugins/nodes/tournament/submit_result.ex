defmodule ForgeNexus.Plugins.Nodes.Tournament.SubmitResult do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    match_id = Map.get(inputs, :match_id) || Map.get(inputs, "match_id")
    winner_id = Map.get(inputs, :winner_id) || Map.get(inputs, "winner_id")
    player1_score = Map.get(config, "player1_score", 0)
    player2_score = Map.get(config, "player2_score", 0)

    scores = %{player1_score: player1_score, player2_score: player2_score}

    case ForgeNexus.Tournaments.submit_result(match_id, winner_id, scores) do
      {:ok, :ok} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to submit result: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "tournament/submit_result",
      category: "tournament",
      label: "Submit Result",
      description: "Submits the result of a tournament match with scores.",
      inputs: [
        %{name: "match_id", type: "string", required: true},
        %{name: "winner_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "player1_score", type: "number", default: 0, description: "Score for player 1"},
        %{name: "player2_score", type: "number", default: 0, description: "Score for player 2"}
      ]
    }
  end
end
