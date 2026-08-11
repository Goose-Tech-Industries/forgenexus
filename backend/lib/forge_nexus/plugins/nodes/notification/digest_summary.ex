defmodule ForgeNexus.Plugins.Nodes.Notification.DigestSummary do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    period = Map.get(config, "period", "daily")

    since =
      case period do
        "weekly" -> DateTime.add(DateTime.utc_now(), -7, :day)
        _ -> DateTime.add(DateTime.utc_now(), -1, :day)
      end

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      _user ->
        # Build summary data — counts would come from actual tables
        # For now, build a skeleton that downstream nodes can use
        summary = %{
          user_id: user_id,
          period: period,
          since: to_string(since),
          post_count: 0,
          new_threads: 0,
          mentions: 0,
          reactions_received: 0,
          new_followers: 0
        }

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{summary: summary}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "period", "daily") do
      p when p in ~w(daily weekly) -> :ok
      _ -> {:error, ["period must be daily or weekly"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "notification/digest_summary",
      category: "notification",
      label: "Digest Summary",
      description: "Builds a digest summary of activity for a user over a time period.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "summary", type: "map"}
      ],
      config_fields: [
        %{
          name: "period",
          type: "select",
          options: ~w(daily weekly),
          default: "daily",
          description: "Summary time period"
        }
      ]
    }
  end
end
