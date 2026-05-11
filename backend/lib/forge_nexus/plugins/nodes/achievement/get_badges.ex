defmodule ForgeNexus.Plugins.Nodes.Achievement.GetBadges do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    case ForgeNexus.Achievements.get_user_badges(user_id) do
      {:ok, badges} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{badges: badges, count: length(badges)}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to get badges: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "achievement/get_badges",
      category: "achievement",
      label: "Get Badges",
      description: "Retrieves all badges earned by a user.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "badges", type: "list"},
        %{name: "count", type: "number"}
      ],
      config_fields: []
    }
  end
end
