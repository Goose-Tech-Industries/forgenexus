defmodule ForgeNexus.Plugins.Nodes.UserManagement.SetUserGroup do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    group_id = Map.get(inputs, :group_id) || Map.get(inputs, "group_id")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        previous_group = Map.get(user, :group_id) |> to_string()

        user
        |> Ecto.Changeset.change(%{group_id: group_id})
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true, previous_group: previous_group}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "user_management/set_user_group",
      category: "user_management",
      label: "Set User Group",
      description: "Changes a user's primary group assignment.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "group_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "previous_group", type: "string"}
      ],
      config_fields: []
    }
  end
end
