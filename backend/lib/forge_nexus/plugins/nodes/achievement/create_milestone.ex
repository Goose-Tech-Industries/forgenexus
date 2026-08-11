defmodule ForgeNexus.Plugins.Nodes.Achievement.CreateMilestone do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    stat_type = Map.get(config, "stat_type", "")
    milestones_str = Map.get(config, "milestones", "")
    reward_points_per = Map.get(config, "reward_points_per", 0)

    milestones =
      milestones_str
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.map(fn s ->
        case Integer.parse(s) do
          {n, _} -> n
          :error -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    case ForgeNexus.Achievements.create_milestones(%{
           stat_type: stat_type,
           milestones: milestones,
           reward_points_per: reward_points_per,
           community_id: ctx.community_id
         }) do
      {:ok, count} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{milestones_created: count, success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create milestones: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        st = Map.get(config, "stat_type")
        if is_binary(st) and st != "", do: e, else: ["stat_type is required" | e]
      end)
      |> then(fn e ->
        ms = Map.get(config, "milestones")

        if is_binary(ms) and ms != "",
          do: e,
          else: ["milestones is required (comma-separated numbers)" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "achievement/create_milestone",
      category: "achievement",
      label: "Create Milestone",
      description: "Creates milestone achievements for a stat type at specified thresholds.",
      inputs: [],
      outputs: [
        %{name: "milestones_created", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "stat_type",
          type: "string",
          default: "",
          description: "The stat type to create milestones for"
        },
        %{
          name: "milestones",
          type: "string",
          default: "10,50,100,500,1000",
          description: "Comma-separated milestone thresholds"
        },
        %{
          name: "reward_points_per",
          type: "number",
          default: 0,
          description: "Points awarded per milestone reached"
        }
      ]
    }
  end
end
