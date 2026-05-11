defmodule ForgeNexus.Plugins.Nodes.Tournament.CreateSeason do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    name = Map.get(inputs, :name) || Map.get(inputs, "name")
    description = Map.get(inputs, :description) || Map.get(inputs, "description")
    duration_days = Map.get(config, "duration_days", 30) |> to_int()

    starts = DateTime.utc_now() |> DateTime.truncate(:second)
    ends = DateTime.add(starts, duration_days * 86_400, :second)

    attrs = %{
      name: name,
      description: description,
      starts_at: starts,
      ends_at: ends,
      status: "active",
      tournament_type: "season"
    }

    case ForgeNexus.Tournaments.create_tournament(attrs) do
      {:ok, season} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{season_id: season.id, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create season: #{inspect(err)}", ctx}
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

  defp to_int(_), do: 30

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        days = Map.get(config, "duration_days")
        if is_nil(days) or (is_number(days) and days > 0), do: e, else: ["duration_days must be a positive number" | e]
      end)
      |> then(fn e ->
        case Map.get(config, "reward_tiers") do
          nil ->
            e

          t when is_map(t) ->
            e

          t when is_binary(t) ->
            case Jason.decode(t) do
              {:ok, _} -> e
              {:error, _} -> ["reward_tiers must be valid JSON" | e]
            end

          _ ->
            ["reward_tiers must be a JSON object" | e]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "tournament/create_season",
      category: "tournament",
      label: "Create Season",
      description: "Creates a competitive season with a duration and tiered rewards.",
      inputs: [
        %{name: "name", type: "string", required: true},
        %{name: "description", type: "string", required: false}
      ],
      outputs: [
        %{name: "season_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "duration_days", type: "number", default: 30, description: "Season duration in days"},
        %{name: "reward_tiers", type: "json", default: "{}", description: "JSON object defining reward tiers"}
      ]
    }
  end
end
