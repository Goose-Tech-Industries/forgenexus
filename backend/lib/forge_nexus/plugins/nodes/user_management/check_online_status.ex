defmodule ForgeNexus.Plugins.Nodes.UserManagement.CheckOnlineStatus do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        ctx = Sandbox.increment_db_ops(ctx)
        last_seen_at = Map.get(user, :last_seen_at)

        is_online =
          case last_seen_at do
            nil -> false
            ts -> DateTime.diff(DateTime.utc_now(), ts, :minute) < 5
          end

        port = if is_online, do: "online", else: "offline"
        last_seen_str = if last_seen_at, do: to_string(last_seen_at), else: "never"

        {:branch, port, %{last_seen_at: last_seen_str}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "user_management/check_online_status",
      category: "user_management",
      label: "Check Online Status",
      description:
        "Branches based on whether a user is currently online (seen within 5 minutes).",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "online", type: "string", description: "User is online"},
        %{name: "offline", type: "string", description: "User is offline"}
      ],
      config_fields: []
    }
  end
end
