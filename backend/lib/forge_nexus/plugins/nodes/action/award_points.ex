defmodule ForgeNexus.Plugins.Nodes.Action.AwardPoints do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  import Ecto.Query

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    points = Map.get(inputs, :points) || Map.get(inputs, "points") || 0

    points =
      cond do
        is_number(points) ->
          trunc(points)

        is_binary(points) ->
          case Integer.parse(points) do
            {n, _} -> n
            :error -> 0
          end

        true ->
          0
      end

    {count, _} =
      from(u in User, where: u.id == ^user_id)
      |> Repo.update_all(inc: [reputation: points])

    ctx = Sandbox.increment_db_ops(ctx)

    if count > 0 do
      {:ok, %{awarded: true, points: points}, ctx}
    else
      {:error, "User not found: #{user_id}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "action/award_points",
      category: "action",
      label: "Award Points",
      description: "Atomically adds reputation points to a user.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "points", type: "number", required: true}
      ],
      outputs: [
        %{name: "awarded", type: "boolean"},
        %{name: "points", type: "number"}
      ],
      config_fields: []
    }
  end
end
