defmodule ForgeNexus.Plugins.Nodes.Stats.ModifyStat do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    stat_key = Map.get(inputs, :stat_key) || Map.get(inputs, "stat_key")
    delta = Map.get(inputs, :delta) || Map.get(inputs, "delta") || 0

    if is_nil(user_id) or is_nil(stat_key) do
      {:error, "user_id and stat_key are required", ctx}
    else
      delta =
        cond do
          is_number(delta) ->
            delta

          is_binary(delta) ->
            case Float.parse(delta) do
              {n, _} -> n
              :error -> 0
            end

          true ->
            0
        end

      old_value = ForgeNexus.UserStats.get_stat(user_id, stat_key)

      res =
        try do
          ForgeNexus.UserStats.modify_stat(user_id, stat_key, delta)
        rescue
          err -> {:error, Exception.message(err)}
        end

      case res do
        {:ok, stat} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{old_value: old_value, new_value: stat.value}, ctx}

        {:error, reason} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:error, "Failed to modify stat: #{inspect(reason)}", ctx}
      end
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "stats/modify_stat",
      category: "stats",
      label: "Modify Stat",
      description: "Adds or subtracts from a user stat with optional min/max clamping.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "stat_key", type: "string", required: true},
        %{name: "delta", type: "number", required: true}
      ],
      outputs: [
        %{name: "new_value", type: "number"},
        %{name: "old_value", type: "number"}
      ],
      config_fields: [
        %{
          name: "min_value",
          type: "number",
          default: nil,
          description: "Optional minimum value clamp"
        },
        %{
          name: "max_value",
          type: "number",
          default: nil,
          description: "Optional maximum value clamp"
        }
      ]
    }
  end
end
