defmodule ForgeNexus.Plugins.Nodes.Data.SetGlobalData do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Plugins.FlowGlobalStore
  alias ForgeNexus.Repo

  import Ecto.Query

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    key = Map.get(config, "key")
    value = Map.get(inputs, :value) || Map.get(inputs, "value")
    store_key = "global:#{key}"

    existing =
      from(s in FlowGlobalStore,
        where: s.flow_id == ^ctx.flow_id and s.key == ^store_key
      )
      |> Repo.one()

    case existing do
      nil ->
        %FlowGlobalStore{}
        |> FlowGlobalStore.changeset(%{
          flow_id: ctx.flow_id,
          key: store_key,
          value: wrap_value(value)
        })
        |> Repo.insert!()

      record ->
        record
        |> FlowGlobalStore.changeset(%{value: wrap_value(value)})
        |> Repo.update!()
    end

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{saved: true}, ctx}
  end

  defp wrap_value(val) when is_map(val), do: val
  defp wrap_value(val), do: %{"_value" => val}

  @impl true
  def validate_config(config) do
    if Map.has_key?(config, "key"), do: :ok, else: {:error, ["key is required"]}
  end

  @impl true
  def schema do
    %{
      type: "data/set_global_data",
      category: "data",
      label: "Set Global Data",
      description: "Stores a value in the flow's global key-value store.",
      inputs: [%{name: "value", type: "any", required: true}],
      outputs: [%{name: "saved", type: "boolean"}],
      config_fields: [
        %{name: "key", type: "string", default: "", description: "Storage key name"}
      ]
    }
  end
end
