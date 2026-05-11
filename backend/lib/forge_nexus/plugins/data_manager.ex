defmodule ForgeNexus.Plugins.DataManager do
  @moduledoc """
  Manages custom data tables, columns, and rows with validation.
  Provides a safe query builder for plugin nodes to access data.
  """

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Plugins.{CustomDataTable, CustomDataColumn, CustomDataRow}

  @max_query_limit 100

  # =====================
  # Tables
  # =====================

  def create_table(attrs) do
    %CustomDataTable{}
    |> CustomDataTable.changeset(attrs)
    |> Repo.insert()
  end

  def update_table(table_id, attrs) do
    Repo.get!(CustomDataTable, table_id)
    |> CustomDataTable.changeset(attrs)
    |> Repo.update()
  end

  def delete_table(table_id) do
    Repo.get!(CustomDataTable, table_id) |> Repo.delete()
  end

  def get_table!(id) do
    Repo.get!(CustomDataTable, id) |> Repo.preload(:columns)
  end

  def get_table_by_slug!(slug) do
    Repo.get_by!(CustomDataTable, slug: slug) |> Repo.preload(:columns)
  end

  def list_tables(opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    Repo.all(
      from t in CustomDataTable,
        order_by: [desc: :inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:columns]
    )
  end

  # =====================
  # Columns
  # =====================

  def add_column(attrs) do
    %CustomDataColumn{}
    |> CustomDataColumn.changeset(attrs)
    |> Repo.insert()
  end

  def update_column(column_id, attrs) do
    Repo.get!(CustomDataColumn, column_id)
    |> CustomDataColumn.changeset(attrs)
    |> Repo.update()
  end

  def remove_column(column_id) do
    Repo.get!(CustomDataColumn, column_id) |> Repo.delete()
  end

  def get_columns(table_id) do
    Repo.all(
      from c in CustomDataColumn,
        where: c.table_id == ^table_id,
        order_by: [asc: :position]
    )
  end

  # =====================
  # Rows
  # =====================

  def insert_row(table_id, scope_id, data) do
    table = get_table!(table_id)

    # Check max rows
    current_count = count_rows(table_id, scope_id)

    if current_count >= table.max_rows do
      {:error, :max_rows_exceeded}
    else
      case validate_row_data(table.columns, data) do
        :ok ->
          %CustomDataRow{}
          |> CustomDataRow.changeset(%{table_id: table_id, scope_id: scope_id, data: data})
          |> Repo.insert()

        {:error, _} = error ->
          error
      end
    end
  end

  def update_row(row_id, data) do
    row = Repo.get!(CustomDataRow, row_id)
    table = get_table!(row.table_id)

    case validate_row_data(table.columns, data) do
      :ok ->
        row
        |> CustomDataRow.update_changeset(%{data: data})
        |> Repo.update()

      {:error, _} = error ->
        error
    end
  end

  def delete_row(row_id) do
    Repo.get!(CustomDataRow, row_id) |> Repo.delete()
  end

  def get_row!(id) do
    Repo.get!(CustomDataRow, id)
  end

  def count_rows(table_id, scope_id) do
    query = from r in CustomDataRow, where: r.table_id == ^table_id

    query =
      if scope_id do
        where(query, [r], r.scope_id == ^scope_id)
      else
        where(query, [r], is_nil(r.scope_id))
      end

    Repo.one(from r in query, select: count(r.id))
  end

  @doc """
  Safe query builder for custom data rows.

  Filters: list of {column_slug, operator, value}
  Operators: :eq, :neq, :gt, :gte, :lt, :lte, :contains, :in

  Since data is stored as JSONB, we use Postgres JSON operators.
  """
  def query_rows(table_id, scope_id, filters \\ [], opts \\ []) do
    limit = min(Keyword.get(opts, :limit, 25), @max_query_limit)
    offset = Keyword.get(opts, :offset, 0)
    order_by = Keyword.get(opts, :order_by)

    query = from r in CustomDataRow, where: r.table_id == ^table_id

    query =
      if scope_id do
        where(query, [r], r.scope_id == ^scope_id)
      else
        query
      end

    # Apply filters using JSONB operators
    query =
      Enum.reduce(filters, query, fn {column_slug, operator, value}, q ->
        apply_filter(q, column_slug, operator, value)
      end)

    # Apply ordering
    query =
      case order_by do
        nil -> query |> order_by([r], desc: :inserted_at)
        "inserted_at_asc" -> query |> order_by([r], asc: :inserted_at)
        "inserted_at_desc" -> query |> order_by([r], desc: :inserted_at)
        "updated_at_desc" -> query |> order_by([r], desc: :updated_at)
        _ -> query |> order_by([r], desc: :inserted_at)
      end

    rows =
      query
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    count = Repo.one(from r in query, select: count(r.id))

    %{rows: rows, count: count}
  end

  defp apply_filter(query, column_slug, :eq, value) do
    where(query, [r], fragment("?->? = ?::jsonb", r.data, ^column_slug, ^Jason.encode!(value)))
  end

  defp apply_filter(query, column_slug, :neq, value) do
    where(query, [r], fragment("?->? != ?::jsonb", r.data, ^column_slug, ^Jason.encode!(value)))
  end

  defp apply_filter(query, column_slug, :gt, value) do
    where(query, [r], fragment("(?->>?)::numeric > ?", r.data, ^column_slug, ^value))
  end

  defp apply_filter(query, column_slug, :gte, value) do
    where(query, [r], fragment("(?->>?)::numeric >= ?", r.data, ^column_slug, ^value))
  end

  defp apply_filter(query, column_slug, :lt, value) do
    where(query, [r], fragment("(?->>?)::numeric < ?", r.data, ^column_slug, ^value))
  end

  defp apply_filter(query, column_slug, :lte, value) do
    where(query, [r], fragment("(?->>?)::numeric <= ?", r.data, ^column_slug, ^value))
  end

  defp apply_filter(query, column_slug, :contains, value) do
    where(query, [r], fragment("?->>? ILIKE ?", r.data, ^column_slug, ^"%#{value}%"))
  end

  defp apply_filter(query, column_slug, :in, values) when is_list(values) do
    json_values = Enum.map(values, &Jason.encode!/1)
    where(query, [r], fragment("?->? IN (SELECT jsonb_array_elements_text(?::jsonb))", r.data, ^column_slug, ^Jason.encode!(json_values)))
  end

  defp apply_filter(query, _column_slug, _operator, _value), do: query

  # =====================
  # Row Validation
  # =====================

  defp validate_row_data(columns, data) when is_list(columns) do
    errors =
      Enum.reduce(columns, [], fn col, acc ->
        value = Map.get(data, col.slug)

        cond do
          col.is_required and is_nil(value) ->
            ["#{col.name} is required" | acc]

          not is_nil(value) and not valid_type?(col.data_type, value) ->
            ["#{col.name} must be of type #{col.data_type}" | acc]

          true ->
            acc
        end
      end)

    if errors == [], do: :ok, else: {:error, Enum.reverse(errors)}
  end

  defp validate_row_data(_columns, _data), do: :ok

  defp valid_type?("string", value), do: is_binary(value)
  defp valid_type?("integer", value), do: is_integer(value)
  defp valid_type?("float", value), do: is_float(value) or is_integer(value)
  defp valid_type?("boolean", value), do: is_boolean(value)
  defp valid_type?("json", _value), do: true
  defp valid_type?("datetime", value), do: is_binary(value)
  defp valid_type?(_, _), do: true
end
