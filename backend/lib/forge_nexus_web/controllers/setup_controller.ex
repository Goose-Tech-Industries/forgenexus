defmodule ForgeNexusWeb.SetupController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Setup
  alias ForgeNexus.Guardian

  @doc "GET /api/setup/status - Returns whether the site has been installed."
  def status(conn, _params) do
    json(conn, %{installed: Setup.installed?()})
  end

  @doc "GET /api/setup/preflight - Checks system health before installation."
  def preflight(conn, _params) do
    if Setup.installed?() do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Already installed"})
    else
      checks = Setup.preflight_checks()
      all_required_pass = Enum.all?(checks, fn c -> c.status == "ok" or c.optional end)

      json(conn, %{
        ready: all_required_pass,
        checks: checks
      })
    end
  end

  @upload_dir "priv/static/uploads"
  @allowed_logo_types ~w(image/jpeg image/png image/gif image/webp image/svg+xml)
  @max_logo_size 2_000_000

  @doc "POST /api/setup/upload-logo - Upload a logo during setup (before auth exists)."
  def upload_logo(conn, %{"file" => %Plug.Upload{} = upload}) do
    if Setup.installed?() do
      conn |> put_status(:forbidden) |> json(%{error: "Already installed"})
    else
      cond do
        upload.content_type not in @allowed_logo_types ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Invalid file type. Allowed: JPG, PNG, GIF, WebP, SVG"})

        File.stat!(upload.path).size > @max_logo_size ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "File too large (max 2MB)"})

        true ->
          ext = Path.extname(upload.filename)
          filename = "site-logo-#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}#{ext}"
          dir = Path.join(@upload_dir, "branding")
          File.mkdir_p!(dir)
          dest = Path.join(dir, filename)
          File.cp!(upload.path, dest)
          url = "/uploads/branding/#{filename}"

          conn |> put_status(:created) |> json(%{url: url})
      end
    end
  end

  def upload_logo(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "No file provided"})
  end

  @doc "POST /api/setup/install - Runs first-time setup with the provided config."
  def install(conn, params) do
    if Setup.installed?() do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Already installed", message: "Setup has already been completed."})
    else
      case Setup.run_setup(params) do
        {:ok, %{admin: admin, site_name: site_name}} ->
          {:ok, token, _claims} = Guardian.encode_and_sign(admin)

          conn
          |> put_status(:created)
          |> json(%{
            message: "Setup completed successfully!",
            site_name: site_name,
            token: token,
            user: %{
              id: admin.id,
              username: admin.username,
              email: admin.email,
              display_name: admin.display_name,
              slug: admin.slug,
              trust_level: admin.trust_level
            }
          })

        {:error, :already_installed} ->
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Already installed", message: "Setup has already been completed."})

        {:error, errors} when is_list(errors) ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Validation failed", errors: errors})

        {:error, {step, %Ecto.Changeset{} = changeset}} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            error: "Setup failed at step: #{step}",
            errors: format_changeset_errors(changeset)
          })

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Setup failed", reason: inspect(reason)})
      end
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
