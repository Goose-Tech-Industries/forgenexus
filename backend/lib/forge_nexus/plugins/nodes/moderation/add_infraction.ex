defmodule ForgeNexus.Plugins.Nodes.Moderation.AddInfraction do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    points_in = Map.get(inputs, :points) || Map.get(inputs, "points", 0)
    points = if is_integer(points_in), do: points_in, else: trunc(points_in)
    reason = Map.get(inputs, :reason) || Map.get(inputs, "reason", "")

    case ForgeNexus.Moderation.add_infraction_points(user_id, points, reason) do
      {:ok, _w} ->
        total = ForgeNexus.Moderation.get_infraction_points(user_id)
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{total_points: total, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to add infraction: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "moderation/add_infraction",
      category: "moderation",
      label: "Add Infraction",
      description: "Adds infraction points to a user and creates a moderation log entry.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "points", type: "number", required: true},
        %{name: "reason", type: "string", required: false}
      ],
      outputs: [%{name: "total_points", type: "number"}, %{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
