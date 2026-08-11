defmodule ForgeNexus.Plugins.Nodes.Collection.DefineSet do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Collections

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    attrs = %{
      name: Map.get(inputs, :name) || Map.get(inputs, "name"),
      description: Map.get(inputs, :description) || Map.get(inputs, "description") || "",
      icon: Map.get(config, "icon", ""),
      reward_points: Map.get(config, "reward_points", 0),
      reward_badge_id: Map.get(config, "reward_badge_id")
    }

    case Collections.define_set(attrs) do
      {:ok, set} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{set_id: set.id, success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, reason, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "collection/define_set",
      category: "collection",
      label: "Define Set",
      description: "Creates a new collection set definition.",
      inputs: [
        %{name: "name", type: "string", required: true},
        %{name: "description", type: "string", required: false}
      ],
      outputs: [
        %{name: "set_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "icon", type: "string", default: "", description: "Icon identifier or URL"},
        %{
          name: "reward_points",
          type: "number",
          default: 0,
          description: "Points awarded on set completion"
        },
        %{
          name: "reward_badge_id",
          type: "string",
          default: "",
          description: "Badge ID awarded on set completion"
        }
      ]
    }
  end
end
