defmodule ForgeNexus.Plugins.Nodes.Tournament.AwardPlacement do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    tournament_id = Map.get(inputs, :tournament_id) || Map.get(inputs, "tournament_id")

    prizes =
      case Map.get(config, "prizes", %{}) do
        p when is_binary(p) ->
          case Jason.decode(p) do
            {:ok, parsed} -> parsed
            _ -> %{}
          end

        p when is_map(p) ->
          p

        _ ->
          %{}
      end

    standings =
      try do
        ForgeNexus.Tournaments.get_standings(tournament_id)
      rescue
        _ -> []
      end

    awards_given =
      Enum.reduce(prizes, 0, fn {place_str, points}, acc ->
        place = if is_binary(place_str), do: String.to_integer(place_str), else: place_str

        case Enum.at(standings, place - 1) do
          nil ->
            acc

          standing ->
            user_id = Map.get(standing, :user_id) || Map.get(standing, "user_id")

            if user_id do
              ForgeNexus.Reputation.give_reputation(%{
                from_user_id: nil,
                to_user_id: user_id,
                amount: points,
                type: "positive"
              })

              acc + 1
            else
              acc
            end
        end
      end)

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{awards_given: awards_given, success: true}, ctx}
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "prizes") do
      nil ->
        :ok

      p when is_map(p) ->
        :ok

      p when is_binary(p) ->
        case Jason.decode(p) do
          {:ok, _} -> :ok
          {:error, _} -> {:error, ["prizes must be valid JSON"]}
        end

      _ ->
        {:error, ["prizes must be a JSON object mapping place to points"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "tournament/award_placement",
      category: "tournament",
      label: "Award Placement",
      description: "Awards points to tournament participants based on their final placement.",
      inputs: [%{name: "tournament_id", type: "string", required: true}],
      outputs: [
        %{name: "awards_given", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "prizes",
          type: "json",
          default: "{\"1\":1000,\"2\":500,\"3\":250}",
          description: "JSON mapping of place to points"
        }
      ]
    }
  end
end
