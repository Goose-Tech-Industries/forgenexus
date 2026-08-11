defmodule ForgeNexus.Plugins.Nodes.Verification.CheckAccountCriteria do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    criteria = %{
      min_age_days: Map.get(config, "min_age_days", 0) |> to_number(),
      min_posts: Map.get(config, "min_posts", 0) |> to_number(),
      require_avatar: Map.get(config, "require_avatar", false),
      require_bio: Map.get(config, "require_bio", false)
    }

    {:ok, results} = ForgeNexus.Verification.check_account_criteria(user_id, criteria)
    ctx = Sandbox.increment_db_ops(ctx)

    all_passed =
      results
      |> Map.values()
      |> Enum.all?(fn
        %{passed: p} -> p
        _ -> true
      end)

    if all_passed do
      {:branch, "passed", %{criteria_results: results}, ctx}
    else
      {:branch, "failed", %{criteria_results: results}, ctx}
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
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "verification/check_account_criteria",
      category: "verification",
      label: "Check Account Criteria",
      description:
        "Branches based on whether a user meets account age, post count, avatar, and bio requirements.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [
        %{name: "passed", type: "branch", fields: [%{name: "criteria_results", type: "map"}]},
        %{name: "failed", type: "branch", fields: [%{name: "criteria_results", type: "map"}]}
      ],
      config_fields: [
        %{
          name: "min_age_days",
          type: "number",
          default: 0,
          description: "Minimum account age in days"
        },
        %{name: "min_posts", type: "number", default: 0, description: "Minimum number of posts"},
        %{
          name: "require_avatar",
          type: "boolean",
          default: false,
          description: "Require user to have an avatar"
        },
        %{
          name: "require_bio",
          type: "boolean",
          default: false,
          description: "Require user to have a bio"
        }
      ]
    }
  end
end
