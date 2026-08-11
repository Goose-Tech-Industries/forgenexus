defmodule ForgeNexus.Plugins.Nodes.UserManagement.CheckUserGroup do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    group_id = Map.get(config, "group_id")

    case Repo.get(User, user_id) |> Repo.preload(:groups) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        ctx = Sandbox.increment_db_ops(ctx)
        user_groups = Enum.map(user.groups, & &1.id) |> Enum.map(&to_string/1)
        is_member = to_string(group_id) in user_groups

        port = if is_member, do: "member", else: "not_member"
        {:branch, port, %{user_groups: user_groups}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    if Map.has_key?(config, "group_id"),
      do: :ok,
      else: {:error, ["group_id is required"]}
  end

  @impl true
  def schema do
    %{
      type: "user_management/check_user_group",
      category: "user_management",
      label: "Check User Group",
      description: "Branches based on whether a user belongs to a specific group.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "member", type: "list", description: "User is in the group"},
        %{name: "not_member", type: "list", description: "User is not in the group"}
      ],
      config_fields: [
        %{
          name: "group_id",
          type: "string",
          default: "",
          description: "Group ID to check membership for"
        }
      ]
    }
  end
end
