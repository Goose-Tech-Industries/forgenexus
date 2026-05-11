defmodule ForgeNexus.Plugins.Nodes.Action.AddToGroup do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, inputs, ctx) do
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    group_id = Map.get(inputs, :group_id) || Map.get(inputs, "group_id")

    case ForgeNexus.Accounts.add_user_to_group(user_id, group_id) do
      {:ok, _} -> {:ok, %{added: true}, ctx}
      _ -> {:ok, %{added: false}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "action/add_to_group",
      category: "action",
      label: "Add to Group",
      description: "Adds a user to a group.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "group_id", type: "string", required: true}
      ],
      outputs: [%{name: "added", type: "boolean"}],
      config_fields: []
    }
  end
end
