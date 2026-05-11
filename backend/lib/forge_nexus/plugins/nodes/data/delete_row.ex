defmodule ForgeNexus.Plugins.Nodes.Data.DeleteRow do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Plugins.CustomDataRow
  alias ForgeNexus.Repo

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    row_id = Map.get(inputs, :row_id) || Map.get(inputs, "row_id")

    case Repo.get(CustomDataRow, row_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Row not found: #{row_id}", ctx}

      row ->
        Repo.delete!(row)
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{deleted: true}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "data/delete_row",
      category: "data",
      label: "Delete Row",
      description: "Deletes a single row from a custom data table.",
      inputs: [%{name: "row_id", type: "string", required: true}],
      outputs: [%{name: "deleted", type: "boolean"}],
      config_fields: [
        %{name: "table_slug", type: "string", default: "", description: "Table slug (for reference)"}
      ]
    }
  end
end
