defmodule ForgeNexus.Plugins.Nodes.Stats.SetStat do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    stat_key = Map.get(inputs, :stat_key) || Map.get(inputs, "stat_key")
    value = Map.get(inputs, :value) || Map.get(inputs, "value") || 0

    value =
      cond do
        is_number(value) -> value
        is_binary(value) ->
          case Float.parse(value) do
            {n, _} -> n
            :error -> 0
          end
        true -> 0
      end

    case ForgeNexus.UserStats.set_stat(user_id, stat_key, value) do
      {:ok, stat} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{value: stat.value}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to set stat: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "stats/set_stat",
      category: "stats",
      label: "Set Stat",
      description: "Sets a user stat to a specific value, optionally clamped to min/max bounds.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "stat_key", type: "string", required: true},
        %{name: "value", type: "number", required: true}
      ],
      outputs: [
        %{name: "value", type: "number"},
        %{name: "was_clamped", type: "boolean"}
      ],
      config_fields: [
        %{name: "min_value", type: "number", default: nil, description: "Optional minimum value clamp"},
        %{name: "max_value", type: "number", default: nil, description: "Optional maximum value clamp"}
      ]
    }
  end
end
