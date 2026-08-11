defmodule ForgeNexus.Plugins.Nodes.Achievement.DisplayBadge do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    badge_id = Map.get(inputs, :badge_id) || Map.get(inputs, "badge_id")
    position = Map.get(config, "position", "primary")

    case ForgeNexus.Achievements.set_badge_display(user_id, badge_id, position) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to set badge display: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    position = Map.get(config, "position", "primary")

    if position in ~w(primary secondary hidden) do
      :ok
    else
      {:error, ["position must be one of: primary, secondary, hidden"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "achievement/display_badge",
      category: "achievement",
      label: "Display Badge",
      description: "Sets the display position of a badge on a user's profile.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "badge_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "position",
          type: "select",
          options: ~w(primary secondary hidden),
          default: "primary",
          description: "Where to display the badge on the profile"
        }
      ]
    }
  end
end
