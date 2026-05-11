defmodule ForgeNexus.Plugins.Nodes.Automod.KarmaCheck do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    min_karma = Map.get(config, "min_karma", 0) |> to_number()

    karma =
      case ForgeNexus.Reputation.get_reputation(user_id) do
        {:ok, n} when is_number(n) -> n
        n when is_number(n) -> n
        _ -> 0
      end

    ctx = Sandbox.increment_db_ops(ctx)

    if karma >= min_karma do
      {:branch, "above", %{karma: karma}, ctx}
    else
      {:branch, "below", %{karma: karma}, ctx}
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
    case Map.get(config, "min_karma") do
      nil ->
        {:error, ["min_karma is required"]}

      val when is_number(val) ->
        :ok

      val when is_binary(val) ->
        case Float.parse(val) do
          {_, _} -> :ok
          :error -> {:error, ["min_karma must be a number"]}
        end

      _ ->
        {:error, ["min_karma must be a number"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "automod/karma_check",
      category: "automod",
      label: "Karma Check",
      description: "Branches based on whether a user's karma meets the minimum threshold.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [
        %{name: "above", type: "branch", fields: [%{name: "karma", type: "number"}]},
        %{name: "below", type: "branch", fields: [%{name: "karma", type: "number"}]}
      ],
      config_fields: [%{name: "min_karma", type: "number", default: 0, description: "Minimum karma threshold"}]
    }
  end
end
