defmodule ForgeNexus.Plugins.Nodes.Achievement.DefineAchievement do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    name = Map.get(inputs, :name) || Map.get(inputs, "name")
    description = Map.get(inputs, :description) || Map.get(inputs, "description")
    criteria_type = Map.get(config, "criteria_type", "custom")
    criteria_value = Map.get(config, "criteria_value", 0)

    case ForgeNexus.Achievements.define_achievement(%{
           name: name,
           slug: slugify(name, ctx),
           description: description,
           icon: Map.get(config, "icon"),
           category: Map.get(config, "category"),
           points: Map.get(config, "points", 0),
           criteria: build_criteria(criteria_type, criteria_value),
           is_hidden: Map.get(config, "is_hidden", false)
         }) do
      {:ok, achievement} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{achievement_id: achievement.id, success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to define achievement: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        ct = Map.get(config, "criteria_type", "custom")

        if ct in ~w(post_count thread_count reputation streak collection level custom),
          do: e,
          else: ["criteria_type must be one of: post_count, thread_count, reputation, streak, collection, level, custom" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "achievement/define_achievement",
      category: "achievement",
      label: "Define Achievement",
      description: "Defines a new achievement with criteria and point value.",
      inputs: [
        %{name: "name", type: "string", required: true},
        %{name: "description", type: "string", required: false}
      ],
      outputs: [
        %{name: "achievement_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "icon", type: "string", default: "", description: "Icon identifier for the achievement"},
        %{name: "category", type: "string", default: "", description: "Achievement category"},
        %{name: "points", type: "number", default: 0, description: "Points awarded for earning this achievement"},
        %{name: "criteria_type", type: "select", options: ~w(post_count thread_count reputation streak collection level custom), default: "custom", description: "Type of criteria to check"},
        %{name: "criteria_value", type: "number", default: 0, description: "Target value for the criteria"},
        %{name: "is_hidden", type: "boolean", default: false, description: "Whether this achievement is hidden until earned"}
      ]
    }
  end

  defp slugify(nil, ctx), do: "achievement-#{ctx.community_id || "global"}-#{System.unique_integer([:positive])}"
  defp slugify(name, ctx) do
    base =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    scope = ctx.community_id || "global"
    "#{base}-#{scope}-#{System.unique_integer([:positive])}"
  end

  defp build_criteria("custom", _value), do: %{"type" => "custom"}
  defp build_criteria("post_count", value), do: %{"type" => "stat_threshold", "stat_key" => "post_count", "threshold" => value}
  defp build_criteria("thread_count", value), do: %{"type" => "stat_threshold", "stat_key" => "thread_count", "threshold" => value}
  defp build_criteria("reputation", value), do: %{"type" => "stat_threshold", "stat_key" => "reputation", "threshold" => value}
  defp build_criteria("streak", value), do: %{"type" => "stat_threshold", "stat_key" => "streak", "threshold" => value}
  defp build_criteria("level", value), do: %{"type" => "stat_threshold", "stat_key" => "level", "threshold" => value}
  defp build_criteria("collection", value), do: %{"type" => "count", "stat_key" => "collection", "target" => value}
  defp build_criteria(_, _), do: %{"type" => "custom"}
end
