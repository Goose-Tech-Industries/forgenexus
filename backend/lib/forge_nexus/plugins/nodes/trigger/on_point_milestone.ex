defmodule ForgeNexus.Plugins.Nodes.Trigger.OnPointMilestone do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, _inputs, ctx) do
    td = ctx.trigger_data
    milestones = parse_milestones(Map.get(config, "milestone_values", "100,500,1000,5000,10000"))
    balance = Map.get(td, :balance, Map.get(td, "balance"))
    milestone = Map.get(td, :milestone, Map.get(td, "milestone"))

    current_milestone = milestone || Enum.find(Enum.sort(milestones, :desc), &(&1 <= balance))

    {:ok,
     %{
       user: Map.get(td, :user, Map.get(td, "user")),
       currency: Map.get(td, :currency, Map.get(td, "currency")),
       balance: balance,
       milestone: current_milestone
     }, ctx}
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "milestone_values") do
      nil ->
        :ok

      val when is_binary(val) ->
        parts = String.split(val, ",", trim: true)

        if Enum.all?(parts, fn p ->
             case Integer.parse(String.trim(p)) do
               {_, ""} -> true
               _ -> false
             end
           end) do
          :ok
        else
          {:error, ["milestone_values must be comma-separated integers"]}
        end

      _ ->
        {:error, ["milestone_values must be a string"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "trigger/on_point_milestone",
      category: "trigger",
      label: "On Point Milestone",
      description: "Triggers when a user reaches a point balance milestone.",
      inputs: [],
      outputs: [
        %{name: "user", type: "map"},
        %{name: "currency", type: "string"},
        %{name: "balance", type: "number"},
        %{name: "milestone", type: "number"}
      ],
      config_fields: [
        %{
          name: "milestone_values",
          type: "string",
          default: "100,500,1000,5000,10000",
          description: "Comma-separated milestone values"
        }
      ]
    }
  end

  defp parse_milestones(str) when is_binary(str) do
    str
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(fn p ->
      case Integer.parse(p) do
        {n, ""} -> [n]
        _ -> []
      end
    end)
  end

  defp parse_milestones(_), do: [100, 500, 1000, 5000, 10000]
end
