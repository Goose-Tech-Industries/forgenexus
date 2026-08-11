defmodule ForgeNexus.Plugins.Nodes.Scheduling.HolidayTheme do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  require Logger

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    theme_name = Map.get(config, "theme_name", "")
    duration_hours = Map.get(config, "duration_hours", 24) |> to_number()

    active_until =
      DateTime.utc_now()
      |> DateTime.add(trunc(duration_hours * 3600), :second)
      |> DateTime.to_iso8601()

    # Store in flow_global_store; frontend can check for active theme effects
    Logger.info(
      "[PluginFlow] scheduling/holiday_theme: theme=#{theme_name}, until=#{active_until}"
    )

    flow_global = Map.get(ctx, :flow_global_store, %{})
    theme_data = %{theme_name: theme_name, active_until: active_until}
    flow_global = Map.put(flow_global, "active_theme", theme_data)
    ctx = Map.put(ctx, :flow_global_store, flow_global)

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{success: true, active_until: active_until}, ctx}
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
        case Map.get(config, "theme_name") do
          nil -> ["theme_name is required" | e]
          "" -> ["theme_name is required" | e]
          _ -> e
        end
      end)
      |> then(fn e ->
        case Map.get(config, "duration_hours") do
          nil ->
            ["duration_hours is required" | e]

          val when is_number(val) and val > 0 ->
            e

          val when is_binary(val) ->
            case Float.parse(val) do
              {n, _} when n > 0 -> e
              _ -> ["duration_hours must be a positive number" | e]
            end

          _ ->
            ["duration_hours must be a positive number" | e]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "scheduling/holiday_theme",
      category: "scheduling",
      label: "Holiday Theme",
      description: "Activates a seasonal or holiday theme for the community for a set duration.",
      inputs: [],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "active_until", type: "string"}
      ],
      config_fields: [
        %{
          name: "theme_name",
          type: "string",
          default: "",
          description: "Theme name (e.g. winter, halloween, summer)"
        },
        %{
          name: "duration_hours",
          type: "number",
          default: 24,
          description: "Duration the theme stays active (hours)"
        }
      ]
    }
  end
end
