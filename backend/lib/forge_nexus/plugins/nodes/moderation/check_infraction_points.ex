defmodule ForgeNexus.Plugins.Nodes.Moderation.CheckInfractionPoints do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    threshold = Map.get(config, "threshold", 10) |> to_number()

    points = ForgeNexus.Moderation.get_infraction_points(user_id)
    ctx = Sandbox.increment_db_ops(ctx)

    if points >= threshold do
      {:branch, "above", %{points: points}, ctx}
    else
      {:branch, "below", %{points: points}, ctx}
    end
  end

  defp to_number(v) when is_number(v), do: v

  defp to_number(v) when is_binary(v) do
    case Float.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_number(_), do: 0

  @impl true
  def validate_config(config) do
    case Map.get(config, "threshold") do
      nil ->
        {:error, ["threshold is required"]}

      val when is_number(val) and val >= 0 ->
        :ok

      val when is_binary(val) ->
        case Float.parse(val) do
          {_, _} -> :ok
          :error -> {:error, ["threshold must be a number"]}
        end

      _ ->
        {:error, ["threshold must be a number"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "moderation/check_infraction_points",
      category: "moderation",
      label: "Check Infraction Points",
      description:
        "Branches based on whether a user's infraction points are above or below a threshold.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [
        %{name: "above", type: "branch", fields: [%{name: "points", type: "number"}]},
        %{name: "below", type: "branch", fields: [%{name: "points", type: "number"}]}
      ],
      config_fields: [
        %{
          name: "threshold",
          type: "number",
          default: 10,
          description: "Point threshold for branching"
        }
      ]
    }
  end
end
