defmodule ForgeNexusWeb.AdminMaintenanceController do
  use ForgeNexusWeb, :controller

  require Logger

  def system_info(conn, _params) do
    info = %{
      elixir_version: System.version(),
      erlang_version: :erlang.system_info(:otp_release) |> to_string(),
      phoenix_version: Application.spec(:phoenix, :vsn) |> to_string(),
      ecto_version: Application.spec(:ecto, :vsn) |> to_string(),
      node: Node.self() |> to_string(),
      uptime_seconds: elem(:erlang.statistics(:wall_clock), 0) |> div(1000),
      memory_mb: :erlang.memory(:total) |> div(1024 * 1024),
      process_count: :erlang.system_info(:process_count),
      scheduler_count: :erlang.system_info(:schedulers_online),
      db_version: get_db_version(),
    }
    conn |> json(%{info: info})
  end

  def db_stats(conn, _params) do
    tables = ForgeNexus.Repo.query!("""
      SELECT tablename AS name,
             pg_size_pretty(pg_total_relation_size(quote_ident(tablename))) AS size,
             (SELECT count(*) FROM information_schema.columns WHERE table_name = tablename) AS columns
      FROM pg_tables
      WHERE schemaname = 'public'
      ORDER BY pg_total_relation_size(quote_ident(tablename)) DESC
    """)

    rows = Enum.map(tables.rows, fn [name, size, cols] ->
      row_count = try do
        ForgeNexus.Repo.query!("SELECT count(*) FROM \"#{name}\"").rows |> List.first() |> List.first()
      rescue
        _ -> 0
      end
      %{name: name, size: size, columns: cols, rows: row_count}
    end)

    conn |> json(%{tables: rows})
  end

  def clear_cache(conn, _params) do
    :ok = ForgeNexus.Cache.flush()
    admin = Guardian.Plug.current_resource(conn)
    ForgeNexus.Admin.log_admin_action(admin.id, %{action: "cache_cleared", category: "settings", description: "Cleared in-memory cache"})
    conn |> json(%{ok: true, message: "Cache cleared"})
  rescue
    e ->
      conn |> put_status(:unprocessable_entity) |> json(%{error: "Cache clear failed: #{Exception.message(e)}"})
  end

  def reindex_search(conn, _params) do
    admin = Guardian.Plug.current_resource(conn)
    Task.start(fn -> ForgeNexus.Search.reindex_all() end)
    ForgeNexus.Admin.log_admin_action(admin.id, %{action: "search_reindexed", category: "settings", description: "Triggered search reindex"})
    conn |> json(%{ok: true, message: "Search reindex triggered — indexing in background"})
  end

  defp get_db_version do
    case ForgeNexus.Repo.query("SELECT version()") do
      {:ok, result} ->
        result.rows |> List.first() |> List.first() |> String.split(",") |> List.first()
      _ -> "Unknown"
    end
  end
end
