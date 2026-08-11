defmodule ForgeNexus.Plugins.Nodes.Tournament.AdvanceBracket do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    tournament_id = Map.get(inputs, :tournament_id) || Map.get(inputs, "tournament_id")

    case ForgeNexus.Tournaments.advance_bracket(tournament_id) do
      {:ok, :tournament_complete} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{tournament_complete: true, matches_created: 0, success: true}, ctx}

      {:ok, matches} when is_list(matches) ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{tournament_complete: false, matches_created: length(matches), success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to advance bracket: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "tournament/advance_bracket",
      category: "tournament",
      label: "Advance Bracket",
      description:
        "Advances the tournament to the next round, creating new matches from winners.",
      inputs: [
        %{name: "tournament_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "next_round", type: "number"},
        %{name: "matches_created", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
