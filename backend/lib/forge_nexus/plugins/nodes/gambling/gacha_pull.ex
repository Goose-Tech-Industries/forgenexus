defmodule ForgeNexus.Plugins.Nodes.Gambling.GachaPull do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Plugins.FlowGlobalStore
  alias ForgeNexus.Repo

  import Ecto.Query

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    rates = parse_json(Map.get(config, "rates", "{}"))
    pity_threshold = Map.get(config, "pity_threshold", 100) |> to_integer()
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    # Get pity counter from flow global store
    pity_key = "gacha_pity:#{user_id}"

    pity_record =
      from(s in FlowGlobalStore,
        where: s.flow_id == ^ctx.flow_id and s.key == ^pity_key
      )
      |> Repo.one()

    ctx = Sandbox.increment_db_ops(ctx)

    pull_count =
      case pity_record do
        nil -> 1
        %FlowGlobalStore{value: val} ->
          case val do
            n when is_integer(n) -> n + 1
            n when is_binary(n) ->
              case Integer.parse(n) do
                {v, _} -> v + 1
                :error -> 1
              end
            _ -> 1
          end
      end

    is_pity = pull_count >= pity_threshold

    rarity =
      if is_pity do
        # Pity: give the rarest item
        rates
        |> Enum.min_by(fn {_rarity, weight} -> weight end, fn -> {"common", 1} end)
        |> elem(0)
      else
        weighted_pick(rates)
      end

    # Reset or increment pity counter
    Sandbox.check_db_limit!(ctx)

    new_count = if is_pity, do: 0, else: pull_count

    if pity_record do
      from(s in FlowGlobalStore,
        where: s.flow_id == ^ctx.flow_id and s.key == ^pity_key
      )
      |> Repo.update_all(set: [value: new_count])
    else
      %FlowGlobalStore{}
      |> FlowGlobalStore.changeset(%{flow_id: ctx.flow_id, key: pity_key, value: new_count})
      |> Repo.insert()
    end

    ctx = Sandbox.increment_db_ops(ctx)

    {:ok, %{rarity: rarity, pull_count: pull_count, is_pity: is_pity}, ctx}
  end

  defp weighted_pick(rates) when is_map(rates) and map_size(rates) > 0 do
    total = Enum.reduce(rates, 0, fn {_k, v}, acc -> acc + to_number(v) end)
    roll = :rand.uniform() * total

    Enum.reduce_while(rates, 0, fn {rarity, weight}, cumulative ->
      cumulative = cumulative + to_number(weight)

      if roll <= cumulative do
        {:halt, rarity}
      else
        {:cont, cumulative}
      end
    end)
    |> then(fn
      result when is_binary(result) -> result
      _ -> "common"
    end)
  end

  defp weighted_pick(_), do: "common"

  defp parse_json(val) when is_map(val), do: val

  defp parse_json(val) when is_binary(val) do
    case Jason.decode(val) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp parse_json(_), do: %{}

  defp to_number(val) when is_number(val), do: val

  defp to_number(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp to_number(_), do: 0

  defp to_integer(val) when is_integer(val), do: val
  defp to_integer(val) when is_float(val), do: trunc(val)

  defp to_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 100
    end
  end

  defp to_integer(_), do: 100

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        rates = parse_json(Map.get(config, "rates", "{}"))
        if map_size(rates) > 0, do: e, else: ["rates must be a non-empty map of rarity => weight" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "gambling/gacha_pull",
      category: "gambling",
      label: "Gacha Pull",
      description: "Performs a gacha pull with rarity weights and pity system.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "rarity", type: "string"},
        %{name: "pull_count", type: "number"},
        %{name: "is_pity", type: "boolean"}
      ],
      config_fields: [
        %{name: "rates", type: "json", default: "{}", description: "JSON map of rarity => weight (e.g. {\"common\":70,\"rare\":25,\"epic\":4,\"legendary\":1})"},
        %{name: "pity_threshold", type: "number", default: 100, description: "Number of pulls before guaranteed rare drop"}
      ]
    }
  end
end
