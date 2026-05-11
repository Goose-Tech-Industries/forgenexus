defmodule ForgeNexus.Plugins.Nodes.Data.QueryTable do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Plugins.{CustomDataTable, CustomDataRow}
  alias ForgeNexus.Repo

  import Ecto.Query

  @max_limit 100

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    table_slug = Map.get(config, "table_slug")
    filters = Map.get(config, "filters", [])
    limit = min(Map.get(config, "limit", 50), @max_limit)
    order_by = Map.get(config, "order_by", "inserted_at")

    table = Repo.get_by(CustomDataTable, slug: table_slug)

    case table do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Table '#{table_slug}' not found", ctx}

      %CustomDataTable{id: table_id} ->
        query =
          from(r in CustomDataRow,
            where: r.table_id == ^table_id,
            limit: ^limit
          )

        query = apply_order(query, order_by)
        query = apply_filters(query, filters)

        rows = Repo.all(query)
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok, %{rows: Enum.map(rows, & &1.data), count: length(rows)}, ctx}
    end
  end

  defp apply_order(query, "inserted_at"), do: order_by(query, [r], desc: r.inserted_at)
  defp apply_order(query, "updated_at"), do: order_by(query, [r], desc: r.updated_at)
  defp apply_order(query, _), do: order_by(query, [r], desc: r.inserted_at)

  defp apply_filters(query, filters) when is_list(filters) do
    Enum.reduce(filters, query, fn filter, q ->
      field_name = Map.get(filter, "field")
      op = Map.get(filter, "operator", "eq")
      value = Map.get(filter, "value")

      case op do
        "eq" ->
          where(q, [r], fragment("?->? = ?", r.data, ^field_name, ^Jason.encode!(value)))

        _ ->
          q
      end
    end)
  end

  defp apply_filters(query, _), do: query

  @impl true
  def validate_config(config) do
    if Map.has_key?(config, "table_slug"), do: :ok, else: {:error, ["table_slug is required"]}
  end

  @impl true
  def schema do
    %{
      type: "data/query_table",
      category: "data",
      label: "Query Table",
      description: "Queries rows from a custom data table.",
      inputs: [],
      outputs: [
        %{name: "rows", type: "list"},
        %{name: "count", type: "number"}
      ],
      config_fields: [
        %{name: "table_slug", type: "string", default: "", description: "Table slug to query"},
        %{name: "filters", type: "json", default: [], description: "Filter conditions"},
        %{name: "limit", type: "number", default: 50, description: "Max rows to return (max 100)"},
        %{name: "order_by", type: "select", options: ~w(inserted_at updated_at), default: "inserted_at", description: "Sort order"}
      ]
    }
  end
end
