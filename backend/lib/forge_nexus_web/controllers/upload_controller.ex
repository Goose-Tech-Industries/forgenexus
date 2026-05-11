defmodule ForgeNexusWeb.UploadController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Uploads

  @max_daily_uploads 50

  # POST /api/uploads
  def create(conn, %{"file" => upload, "attachable_type" => type, "attachable_id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    # Rate limit
    if Uploads.user_upload_count_today(user.id) >= @max_daily_uploads do
      conn |> put_status(:too_many_requests) |> json(%{error: "Daily upload limit reached (#{@max_daily_uploads} files)"})
    else
      case Uploads.upload_file(upload, user.id, type, id) do
        {:ok, attachment} ->
          conn
          |> put_status(:created)
          |> json(%{attachment: attachment_json(attachment)})

        {:error, :invalid_type} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "File type not allowed"})

        {:error, :too_large} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "File too large (max 10MB)"})

        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
      end
    end
  end

  # POST /api/uploads (inline — no attachable_type/id, for editor image embeds)
  def create(conn, %{"file" => upload}) do
    user = Guardian.Plug.current_resource(conn)

    if Uploads.user_upload_count_today(user.id) >= @max_daily_uploads do
      conn |> put_status(:too_many_requests) |> json(%{error: "Daily upload limit reached"})
    else
      case Uploads.upload_inline(upload, user.id) do
        {:ok, attachment} ->
          conn
          |> put_status(:created)
          |> json(%{attachment: attachment_json(attachment)})

        {:error, :invalid_type} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Only images are allowed (jpg, png, gif, webp)"})

        {:error, :too_large} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "File too large (max 5MB)"})

        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
      end
    end
  end

  # GET /api/uploads/:type/:id
  def index(conn, %{"attachable_type" => type, "attachable_id" => id}) do
    attachments = Uploads.list_attachments(type, id)
    conn |> json(%{attachments: Enum.map(attachments, &attachment_json/1)})
  end

  # DELETE /api/uploads/:id
  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Uploads.delete_attachment(id, user.id) do
      {:ok, _} -> conn |> json(%{status: "ok"})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Attachment not found"})
    end
  end

  defp attachment_json(a) do
    %{
      id: a.id,
      filename: a.filename,
      content_type: a.content_type,
      size: a.size,
      url: a.url,
      thumbnail_url: a.thumbnail_url,
      width: a.width,
      height: a.height,
      inserted_at: a.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
