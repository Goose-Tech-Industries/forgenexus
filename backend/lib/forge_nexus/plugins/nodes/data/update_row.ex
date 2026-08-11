defmodule ForgeNexus.Plugins.Nodes.Data.UpdateRow do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Plugins.CustomDataRow
  alias ForgeNexus.Repo

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    row_id = Map.get(inputs, :row_id) || Map.get(inputs, "row_id")
    data = Map.get(inputs, :data) || Map.get(inputs, "data", %{})

    case Repo.get(CustomDataRow, row_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Row not found: #{row_id}", ctx}

      row ->
        merged_data = Map.merge(row.data, data)

        row
        |> CustomDataRow.update_changeset(%{data: merged_data})
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{updated: true}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "data/update_row",
      category: "data",
      label: "Update Row",
      description: "Updates an existing row in a custom data table.",
      inputs: [
        %{name: "row_id", type: "string", required: true},
        %{name: "data", type: "map", required: true}
      ],
      outputs: [%{name: "updated", type: "boolean"}],
      config_fields: [
        %{
          name: "table_slug",
          type: "string",
          default: "",
          description: "Table slug (for reference)"
        }
      ]
    }
  end
end
