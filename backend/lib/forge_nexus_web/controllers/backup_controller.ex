defmodule ForgeNexusWeb.BackupController do
  use ForgeNexusWeb, :controller

  # POST /api/admin/backup/create
  def create(conn, _params) do
    admin = Guardian.Plug.current_resource(conn)
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
    filename = "forgenexus_backup_#{timestamp}.sql"
    backup_dir = "priv/backups"
    File.mkdir_p!(backup_dir)
    path = Path.join(backup_dir, filename)

    db_config = Application.get_env(:forge_nexus, ForgeNexus.Repo)
    db_name = db_config[:database]
    db_user = db_config[:username]
    db_host = db_config[:hostname] || "localhost"

    case System.cmd("pg_dump", ["-h", db_host, "-U", db_user, "-Fc", db_name, "-f", path],
           env: [{"PGPASSWORD", db_config[:password] || ""}],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        %{size: size} = File.stat!(path)

        ForgeNexus.Admin.log_admin_action(admin.id, %{
          action: "backup_created",
          category: "maintenance",
          description: "Database backup: #{filename} (#{div(size, 1024)}KB)"
        })

        conn |> json(%{ok: true, filename: filename, size: size})

      {output, _} ->
        conn |> put_status(:internal_server_error) |> json(%{error: "Backup failed: #{output}"})
    end
  rescue
    e ->
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "Backup failed: #{Exception.message(e)}"})
  end

  # GET /api/admin/backup/list
  def list(conn, _params) do
    backup_dir = "priv/backups"
    File.mkdir_p!(backup_dir)

    backups =
      File.ls!(backup_dir)
      |> Enum.filter(&String.ends_with?(&1, ".sql"))
      |> Enum.sort(:desc)
      |> Enum.map(fn f ->
        path = Path.join(backup_dir, f)
        %{size: size} = File.stat!(path)
        %{filename: f, size: size, created_at: File.stat!(path).mtime}
      end)

    conn |> json(%{backups: backups})
  end

  # GET /api/admin/backup/download/:filename
  def download(conn, %{"filename" => filename}) do
    path = Path.join("priv/backups", filename)

    if File.exists?(path) and String.ends_with?(filename, ".sql") do
      conn
      |> put_resp_content_type("application/octet-stream")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_file(200, path)
    else
      conn |> put_status(:not_found) |> json(%{error: "Backup not found"})
    end
  end
end
