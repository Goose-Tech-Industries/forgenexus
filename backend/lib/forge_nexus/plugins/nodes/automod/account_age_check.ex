defmodule ForgeNexus.Plugins.Nodes.Automod.AccountAgeCheck do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    min_days = Map.get(config, "min_days", 7) |> to_number()

    account_age_days =
      case ForgeNexus.Repo.get(ForgeNexus.Accounts.User, user_id) do
        nil ->
          0

        user ->
          NaiveDateTime.diff(NaiveDateTime.utc_now(), user.inserted_at, :second) / 86_400
      end

    ctx = Sandbox.increment_db_ops(ctx)

    if account_age_days >= min_days do
      {:branch, "mature", %{account_age_days: Float.round(account_age_days * 1.0, 2)}, ctx}
    else
      {:branch, "new", %{account_age_days: Float.round(account_age_days * 1.0, 2)}, ctx}
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
    case Map.get(config, "min_days") do
      nil ->
        {:error, ["min_days is required"]}

      val when is_number(val) and val >= 0 ->
        :ok

      val when is_binary(val) ->
        case Float.parse(val) do
          {n, _} when n >= 0 -> :ok
          _ -> {:error, ["min_days must be a non-negative number"]}
        end

      _ ->
        {:error, ["min_days must be a non-negative number"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "automod/account_age_check",
      category: "automod",
      label: "Account Age Check",
      description: "Branches based on whether a user's account meets a minimum age requirement.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [
        %{name: "mature", type: "branch", fields: [%{name: "account_age_days", type: "number"}]},
        %{name: "new", type: "branch", fields: [%{name: "account_age_days", type: "number"}]}
      ],
      config_fields: [%{name: "min_days", type: "number", default: 7, description: "Minimum account age in days"}]
    }
  end
end
