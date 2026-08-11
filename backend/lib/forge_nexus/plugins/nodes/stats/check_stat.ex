defmodule ForgeNexus.Plugins.Nodes.Stats.CheckStat do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    stat_key = Map.get(inputs, :stat_key) || Map.get(inputs, "stat_key")
    _operator = Map.get(config, "operator", "gte")
    threshold = Map.get(config, "threshold", 0)

    result = ForgeNexus.UserStats.check_stat(user_id, stat_key, threshold)
    value = ForgeNexus.UserStats.get_stat(user_id, stat_key)
    ctx = Sandbox.increment_db_ops(ctx)

    port = if result, do: "true", else: "false"
    {:branch, port, %{value: value, result: result}, ctx}
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        op = Map.get(config, "operator", "gte")

        if op in ~w(eq gt gte lt lte),
          do: e,
          else: ["operator must be one of: eq, gt, gte, lt, lte" | e]
      end)
      |> then(fn e ->
        t = Map.get(config, "threshold")
        if is_nil(t) or is_number(t), do: e, else: ["threshold must be a number" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "stats/check_stat",
      category: "stats",
      label: "Check Stat",
      description: "Branches based on comparing a user stat against a threshold.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "stat_key", type: "string", required: true}
      ],
      outputs: [
        %{name: "true", type: "number"},
        %{name: "false", type: "number"}
      ],
      config_fields: [
        %{
          name: "operator",
          type: "select",
          options: ~w(eq gt gte lt lte),
          default: "gte",
          description: "Comparison operator"
        },
        %{name: "threshold", type: "number", default: 0, description: "Value to compare against"}
      ]
    }
  end
end
