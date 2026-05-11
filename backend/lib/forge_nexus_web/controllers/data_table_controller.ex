defmodule ForgeNexusWeb.DataTableController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Plugins.DataManager

  # Tables

  def list_tables(conn, params) do
    opts = [limit: parse_int(params, "limit", 25), offset: parse_int(params, "offset", 0)]
    tables = DataManager.list_tables(opts)
    conn |> json(%{tables: Enum.map(tables, &table_json/1)})
  end

  def show_table(conn, %{"id" => id}) do
    table = DataManager.get_table!(id)
    conn |> json(%{table: table_json(table)})
  end

  def create_table(conn, %{"table" => params}) do
    user = Guardian.Plug.current_resource(conn)
    slug = params |> Map.get("name", "") |> Slug.slugify()

    attrs = %{
      name: Map.fetch!(params, "name"),
      slug: slug,
      description: Map.get(params, "description"),
      scope: Map.get(params, "scope", "global"),
      max_rows: parse_int(params, "max_rows", 10000),
      created_by_id: user.id
    }

    case DataManager.create_table(attrs) do
      {:ok, table} ->
        # Create columns if provided
        columns = Map.get(params, "columns", [])
        for {col, i} <- Enum.with_index(columns) do
          col_slug = col |> Map.get("name", "") |> Slug.slugify()
          DataManager.add_column(%{
            table_id: table.id,
            name: Map.fetch!(col, "name"),
            slug: col_slug,
            data_type: Map.fetch!(col, "data_type"),
            default_value: Map.get(col, "default_value"),
            is_required: Map.get(col, "is_required", false),
            position: i
          })
        end

        table = DataManager.get_table!(table.id)
        conn |> put_status(:created) |> json(%{table: table_json(table)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def update_table(conn, %{"id" => id, "table" => params}) do
    case DataManager.update_table(id, Map.take(params, ["name", "description", "max_rows"]) |> atomize_keys()) do
      {:ok, table} ->
        table = DataManager.get_table!(table.id)
        conn |> json(%{table: table_json(table)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def delete_table(conn, %{"id" => id}) do
    case DataManager.delete_table(id) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  # Columns

  def add_column(conn, %{"table_id" => table_id, "column" => params}) do
    slug = params |> Map.get("name", "") |> Slug.slugify()
    attrs = params |> atomize_keys() |> Map.merge(%{table_id: table_id, slug: slug})

    case DataManager.add_column(attrs) do
      {:ok, col} -> conn |> put_status(:created) |> json(%{column: column_json(col)})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def update_column(conn, %{"id" => col_id, "column" => params}) do
    case DataManager.update_column(col_id, atomize_keys(params)) do
      {:ok, col} -> conn |> json(%{column: column_json(col)})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def delete_column(conn, %{"id" => col_id}) do
    case DataManager.remove_column(col_id) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  # Rows

  def list_rows(conn, %{"table_id" => table_id} = params) do
    scope_id = Map.get(params, "scope_id")
    opts = [limit: parse_int(params, "limit", 25), offset: parse_int(params, "offset", 0)]
    result = DataManager.query_rows(table_id, scope_id, [], opts)
    conn |> json(%{rows: Enum.map(result.rows, &row_json/1), count: result.count})
  end

  def show_row(conn, %{"id" => row_id}) do
    row = DataManager.get_row!(row_id)
    conn |> json(%{row: row_json(row)})
  end

  def create_row(conn, %{"table_id" => table_id, "row" => params}) do
    scope_id = Map.get(params, "scope_id")
    data = Map.get(params, "data", %{})

    case DataManager.insert_row(table_id, scope_id, data) do
      {:ok, row} -> conn |> put_status(:created) |> json(%{row: row_json(row)})
      {:error, :max_rows_exceeded} -> conn |> put_status(:conflict) |> json(%{error: "Max rows exceeded"})
      {:error, errors} when is_list(errors) -> conn |> put_status(:unprocessable_entity) |> json(%{error: errors})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def update_row(conn, %{"id" => row_id, "row" => params}) do
    data = Map.get(params, "data", %{})

    case DataManager.update_row(row_id, data) do
      {:ok, row} -> conn |> json(%{row: row_json(row)})
      {:error, errors} when is_list(errors) -> conn |> put_status(:unprocessable_entity) |> json(%{error: errors})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def delete_row(conn, %{"id" => row_id}) do
    case DataManager.delete_row(row_id) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  # JSON Helpers

  defp table_json(table) do
    %{
      id: table.id,
      name: table.name,
      slug: table.slug,
      description: table.description,
      scope: table.scope,
      max_rows: table.max_rows,
      inserted_at: table.inserted_at,
      columns: if(Ecto.assoc_loaded?(table.columns), do: Enum.map(table.columns, &column_json/1), else: [])
    }
  end

  defp column_json(col) do
    %{
      id: col.id,
      name: col.name,
      slug: col.slug,
      data_type: col.data_type,
      default_value: col.default_value,
      is_required: col.is_required,
      is_indexed: col.is_indexed,
      is_unique: col.is_unique,
      position: col.position
    }
  end

  defp row_json(row) do
    %{id: row.id, table_id: row.table_id, scope_id: row.scope_id, data: row.data, version: row.version, inserted_at: row.inserted_at, updated_at: row.updated_at}
  end

  defp parse_int(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      val when is_binary(val) -> safe_to_integer(val, default)
      val when is_integer(val) -> val
    end
  end

  defp changeset_errors(%Ecto.Changeset{} = cs), do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
  defp changeset_errors(err), do: inspect(err)

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        try do
          {String.to_existing_atom(k), v}
        rescue
          _ -> {String.to_atom(k), v}
        end
      {k, v} -> {k, v}
    end)
  end

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end
  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default
end

