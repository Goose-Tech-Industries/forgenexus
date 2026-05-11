defmodule ForgeNexus.Plugins.Nodes.UserManagement.PromoteUser do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    target_group_id = Map.get(config, "target_group_id")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        user
        |> Ecto.Changeset.change(%{group_id: target_group_id})
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true, new_group: to_string(target_group_id)}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    if Map.has_key?(config, "target_group_id"),
      do: :ok,
      else: {:error, ["target_group_id is required"]}
  end

  @impl true
  def schema do
    %{
      type: "user_management/promote_user",
      category: "user_management",
      label: "Promote User",
      description: "Promotes a user to a higher group.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "new_group", type: "string"}
      ],
      config_fields: [
        %{name: "target_group_id", type: "string", default: "", description: "Group ID to promote the user to"}
      ]
    }
  end
end
