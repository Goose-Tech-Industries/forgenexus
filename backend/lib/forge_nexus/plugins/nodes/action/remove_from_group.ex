defmodule ForgeNexus.Plugins.Nodes.Action.RemoveFromGroup do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour
  import Ecto.Query

  @impl true
  def execute(_config, inputs, ctx) do
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    group_id = Map.get(inputs, :group_id) || Map.get(inputs, "group_id")

    {n, _} =
      from(m in ForgeNexus.Accounts.UserGroupMembership,
        where: m.user_id == ^user_id and m.group_id == ^group_id
      )
      |> ForgeNexus.Repo.delete_all()

    {:ok, %{removed: n > 0}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "action/remove_from_group",
      category: "action",
      label: "Remove from Group",
      description: "Removes a user from a group.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "group_id", type: "string", required: true}
      ],
      outputs: [%{name: "removed", type: "boolean"}],
      config_fields: []
    }
  end
end
