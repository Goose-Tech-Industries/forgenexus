defmodule ForgeNexus.Plugins.Nodes.Data.InsertRow do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Plugins.{CustomDataTable, CustomDataRow}
  alias ForgeNexus.Repo

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    table_slug = Map.get(config, "table_slug")
    column_mappings = Map.get(config, "column_mappings", %{})

    table = Repo.get_by(CustomDataTable, slug: table_slug)

    case table do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Table '#{table_slug}' not found", ctx}

      %CustomDataTable{id: table_id} ->
        # Build data from column mappings: maps table columns to input fields
        data =
          Enum.reduce(column_mappings, %{}, fn {col_name, input_field}, acc ->
            value =
              Map.get(inputs, input_field) ||
                Map.get(inputs, String.to_existing_atom(input_field))

            Map.put(acc, col_name, value)
          end)

        row =
          %CustomDataRow{}
          |> CustomDataRow.changeset(%{table_id: table_id, data: data})
          |> Repo.insert!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{row: row.data, row_id: row.id}, ctx}
    end
  rescue
    ArgumentError ->
      ctx = Sandbox.increment_db_ops(ctx)
      {:error, "Invalid input field reference in column mappings", ctx}
  end

  @impl true
  def validate_config(config) do
    if Map.has_key?(config, "table_slug"), do: :ok, else: {:error, ["table_slug is required"]}
  end

  @impl true
  def schema do
    %{
      type: "data/insert_row",
      category: "data",
      label: "Insert Row",
      description: "Inserts a new row into a custom data table.",
      inputs: [%{name: "data", type: "map", required: true}],
      outputs: [
        %{name: "row", type: "map"},
        %{name: "row_id", type: "string"}
      ],
      config_fields: [
        %{
          name: "table_slug",
          type: "string",
          default: "",
          description: "Table slug to insert into"
        },
        %{
          name: "column_mappings",
          type: "json",
          default: %{},
          description: "Maps table columns to input field names"
        }
      ]
    }
  end
end
