defmodule ForgeNexus.Plugins.Nodes.Automod.RateLimitCheck do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    action_key = Map.get(config, "action_key", "default")
    max_count = Map.get(config, "max_count", 10) |> to_number()
    window_seconds = Map.get(config, "window_seconds", 60) |> to_number()

    ctx = Sandbox.increment_db_ops(ctx)

    case ForgeNexus.Cooldowns.check_cooldown(user_id, action_key) do
      {:ok, :ready} ->
        ForgeNexus.Cooldowns.set_cooldown(user_id, action_key, trunc(window_seconds))
        {:branch, "allowed", %{count: 1}, ctx}

      {:error, retry_after} ->
        {:branch, "limited", %{count: trunc(max_count), retry_after: retry_after}, ctx}
    end
  end

  defp to_number(v) when is_number(v), do: v

  defp to_number(v) when is_binary(v) do
    case Float.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_number(_), do: 0

  @impl true
  def validate_config(config) do
    case Map.get(config, "action_key") do
      nil -> {:error, ["action_key is required"]}
      "" -> {:error, ["action_key cannot be empty"]}
      _ -> :ok
    end
  end

  @impl true
  def schema do
    %{
      type: "automod/rate_limit_check",
      category: "automod",
      label: "Rate Limit Check",
      description: "Checks if a user has exceeded a rate limit for a given action.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [
        %{name: "allowed", type: "branch", fields: [%{name: "count", type: "number"}]},
        %{name: "limited", type: "branch", fields: [%{name: "count", type: "number"}, %{name: "retry_after", type: "number"}]}
      ],
      config_fields: [
        %{name: "action_key", type: "string", default: "default", description: "Unique key for this rate limit action"},
        %{name: "max_count", type: "number", default: 10, description: "Maximum actions allowed in window"},
        %{name: "window_seconds", type: "number", default: 60, description: "Time window in seconds"}
      ]
    }
  end
end
