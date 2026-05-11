defmodule ForgeNexus.Plugins.Nodes.Data.GetUserData do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Plugins.FlowGlobalStore
  alias ForgeNexus.Repo

  import Ecto.Query

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    key = Map.get(config, "key")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    store_key = "user:#{user_id}:#{key}"

    result =
      from(s in FlowGlobalStore,
        where: s.flow_id == ^ctx.flow_id and s.key == ^store_key
      )
      |> Repo.one()

    ctx = Sandbox.increment_db_ops(ctx)

    value =
      case result do
        nil -> nil
        %FlowGlobalStore{value: val} -> val
      end

    {:ok, %{value: value}, ctx}
  end

  @impl true
  def validate_config(config) do
    if Map.has_key?(config, "key"), do: :ok, else: {:error, ["key is required"]}
  end

  @impl true
  def schema do
    %{
      type: "data/get_user_data",
      category: "data",
      label: "Get User Data",
      description: "Reads a value from the flow's key-value store scoped to a user.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [%{name: "value", type: "any"}],
      config_fields: [
        %{name: "key", type: "string", default: "", description: "Storage key name"}
      ]
    }
  end
end
