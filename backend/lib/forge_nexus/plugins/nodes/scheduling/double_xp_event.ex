defmodule ForgeNexus.Plugins.Nodes.Scheduling.DoubleXpEvent do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  require Logger

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    multiplier = Map.get(config, "multiplier", 2.0) |> to_number()
    duration_hours = Map.get(config, "duration_hours", 24) |> to_number()
    stat_key = Map.get(config, "stat_key", "xp")

    ends_at =
      DateTime.utc_now()
      |> DateTime.add(trunc(duration_hours * 3600), :second)
      |> DateTime.to_iso8601()

    # Store multiplier in flow_global_store so XP-granting flows can check it
    Logger.info("[PluginFlow] scheduling/double_xp_event: multiplier=#{multiplier}, stat=#{stat_key}, ends=#{ends_at}")

    flow_global = Map.get(ctx, :flow_global_store, %{})
    xp_event = %{multiplier: multiplier, stat_key: stat_key, ends_at: ends_at}
    flow_global = Map.put(flow_global, "active_xp_event", xp_event)
    ctx = Map.put(ctx, :flow_global_store, flow_global)

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{success: true, ends_at: ends_at}, ctx}
  end

  defp to_number(val) when is_number(val), do: val

  defp to_number(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp to_number(_), do: 0

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        case Map.get(config, "duration_hours") do
          nil -> ["duration_hours is required" | e]
          val when is_number(val) and val > 0 -> e
          val when is_binary(val) ->
            case Float.parse(val) do
              {n, _} when n > 0 -> e
              _ -> ["duration_hours must be a positive number" | e]
            end
          _ -> ["duration_hours must be a positive number" | e]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "scheduling/double_xp_event",
      category: "scheduling",
      label: "Double XP Event",
      description: "Activates an XP multiplier event for a specified duration.",
      inputs: [],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "ends_at", type: "string"}
      ],
      config_fields: [
        %{name: "multiplier", type: "number", default: 2.0, description: "XP multiplier (e.g. 2.0 for double XP)"},
        %{name: "duration_hours", type: "number", default: 24, description: "Duration of the event in hours"},
        %{name: "stat_key", type: "string", default: "xp", description: "Stat key to apply multiplier to"}
      ]
    }
  end
end
