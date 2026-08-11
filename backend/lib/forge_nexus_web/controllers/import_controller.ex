defmodule ForgeNexusWeb.ImportController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Importer

  # GET /api/admin/import/sources
  def available_sources(conn, _params) do
    json(conn, %{sources: Importer.available_sources()})
  end

  # POST /api/admin/import/start
  def start_import(conn, params) do
    admin = Guardian.Plug.current_resource(conn)

    with {:ok, data} <- parse_import_data(params),
         source when is_binary(source) <- Map.get(params, "source"),
         config <- %{"source" => source, "data" => data},
         :ok <- Importer.validate_config(config),
         opts <- build_opts(params),
         {:ok, import_id} <- Importer.run_import(config, opts) do
      ForgeNexus.Admin.log_admin_action(admin.id, %{
        action: "import_started",
        category: "data",
        description: "Started #{source} import (ID: #{import_id})"
      })

      json(conn, %{ok: true, import_id: import_id})
    else
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: reason})

      nil ->
        conn |> put_status(:bad_request) |> json(%{error: "Missing 'source' field"})
    end
  end

  # POST /api/admin/import/preview
  def preview(conn, params) do
    case parse_import_data(params) do
      {:ok, data} ->
        counts = Importer.preview(data)
        json(conn, %{preview: counts})

      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: reason})
    end
  end

  # GET /api/admin/import/status/:id
  def import_status(conn, %{"id" => import_id}) do
    case Importer.get_status(import_id) do
      {:ok, status} ->
        json(conn, %{
          status: status.status,
          current_step: status.current_step,
          steps_completed: status.steps_completed,
          total: status.total,
          processed: status.processed,
          errors:
            Enum.map(status.errors, fn e ->
              %{message: e.message, timestamp: DateTime.to_iso8601(e.timestamp)}
            end),
          started_at: status.started_at && DateTime.to_iso8601(status.started_at),
          completed_at: status.completed_at && DateTime.to_iso8601(status.completed_at),
          stats: status.stats
        })

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Import not found"})
    end
  end

  # POST /api/admin/import/cancel/:id
  def cancel_import(conn, %{"id" => import_id}) do
    case Importer.get_status(import_id) do
      {:ok, %{status: :running}} ->
        Importer.cancel(import_id)
        json(conn, %{ok: true})

      {:ok, _} ->
        conn |> put_status(:bad_request) |> json(%{error: "Import is not running"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Import not found"})
    end
  end

  # --- Private ---

  defp parse_import_data(%{"file" => %Plug.Upload{path: path, content_type: ct}}) do
    if ct in ["application/json", "text/json", "application/octet-stream"] ||
         String.ends_with?(path, ".json") do
      case File.read(path) do
        {:ok, contents} ->
          case Jason.decode(contents) do
            {:ok, data} when is_map(data) -> {:ok, data}
            {:ok, _} -> {:error, "JSON must be an object, not an array"}
            {:error, _} -> {:error, "Invalid JSON in uploaded file"}
          end

        {:error, reason} ->
          {:error, "Could not read uploaded file: #{inspect(reason)}"}
      end
    else
      {:error, "File must be JSON (got #{ct})"}
    end
  end

  defp parse_import_data(%{"data" => data}) when is_map(data) do
    {:ok, data}
  end

  defp parse_import_data(%{"data" => data}) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed} when is_map(parsed) -> {:ok, parsed}
      _ -> {:error, "Invalid JSON in 'data' field"}
    end
  end

  defp parse_import_data(_) do
    {:error, "Must provide either a JSON file upload or a 'data' field"}
  end

  defp build_opts(params) do
    %{
      "import_users" => params["import_users"] != "false" && params["import_users"] != false,
      "import_posts" => params["import_posts"] != "false" && params["import_posts"] != false
    }
  end
end
