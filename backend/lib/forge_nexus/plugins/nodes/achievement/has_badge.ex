defmodule ForgeNexus.Plugins.Nodes.Achievement.HasBadge do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    badge_id = Map.get(inputs, :badge_id) || Map.get(inputs, "badge_id")

    ctx = Sandbox.increment_db_ops(ctx)

    try do
      if ForgeNexus.Achievements.has_badge?(user_id, badge_id) do
        badge = ForgeNexus.Repo.get(ForgeNexus.Forums.Badge, badge_id)
        {:branch, "yes", %{badge: badge}, ctx}
      else
        {:branch, "no", %{badge: nil}, ctx}
      end
    rescue
      e -> {:error, "Failed to check badge: #{Exception.message(e)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "achievement/has_badge",
      category: "achievement",
      label: "Has Badge?",
      description: "Branches based on whether a user has a specific badge.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "badge_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "yes", type: "map"},
        %{name: "no", type: "map"}
      ],
      config_fields: []
    }
  end
end
