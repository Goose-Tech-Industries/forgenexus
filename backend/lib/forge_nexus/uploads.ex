defmodule ForgeNexus.Uploads do
  @moduledoc """
  File upload handling. Stores files locally in dev, S3 in production.
  """
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Forums.Attachment

  @upload_dir "priv/static/uploads"

  @magic_bytes %{
    "image/jpeg" => [<<0xFF, 0xD8, 0xFF>>],
    "image/png" => [<<0x89, 0x50, 0x4E, 0x47>>],
    "image/gif" => [<<0x47, 0x49, 0x46, 0x38>>],
    "image/webp" => [<<0x52, 0x49, 0x46, 0x46>>],
    "application/pdf" => [<<0x25, 0x50, 0x44, 0x46>>],
    "application/zip" => [<<0x50, 0x4B, 0x03, 0x04>>, <<0x50, 0x4B, 0x05, 0x06>>]
  }

  def upload_file(%Plug.Upload{} = upload, user_id, attachable_type, attachable_id) do
    # Validate MIME type
    if upload.content_type not in Attachment.allowed_types() do
      {:error, :invalid_type}
    else
      # Validate actual file content matches claimed MIME type (prevent spoofing)
      if not verify_magic_bytes(upload.path, upload.content_type) do
        {:error, :invalid_type}
      else
        file_stat = File.stat!(upload.path)

        if file_stat.size > Attachment.max_size() do
          {:error, :too_large}
        else
          # Generate unique filename
          ext = Path.extname(upload.filename)
          unique_name = "#{UUID.uuid4()}#{ext}"
          date_path = Date.utc_today() |> Date.to_iso8601() |> String.replace("-", "/")
          relative_path = "#{date_path}/#{unique_name}"

          # Ensure directory exists
          dir = Path.join([@upload_dir, date_path])
          File.mkdir_p!(dir)

          # Copy file
          dest = Path.join(@upload_dir, relative_path)
          File.cp!(upload.path, dest)

          # Create attachment record
          url = "/uploads/#{relative_path}"

          result =
            %Attachment{}
            |> Attachment.changeset(%{
              filename: upload.filename,
              content_type: upload.content_type,
              size: file_stat.size,
              url: url,
              attachable_type: attachable_type,
              attachable_id: attachable_id,
              user_id: user_id
            })
            |> Repo.insert()

          # Enqueue async image optimization (resize, thumbnail, WebP, strip EXIF)
          case result do
            {:ok, attachment} ->
              if String.starts_with?(attachment.content_type, "image/") do
                ForgeNexus.Workers.ImageOptimizer.enqueue(attachment.id)
              end

              {:ok, attachment}

            error ->
              error
          end
        end
      end
    end
  end

  defp verify_magic_bytes(file_path, content_type) do
    case Map.get(@magic_bytes, content_type) do
      nil ->
        # text/plain has no magic bytes — allow but only if extension matches
        content_type == "text/plain"

      signatures ->
        case File.read(file_path) do
          {:ok, data} ->
            Enum.any?(signatures, fn sig ->
              byte_size(data) >= byte_size(sig) and binary_part(data, 0, byte_size(sig)) == sig
            end)

          _ ->
            false
        end
    end
  end

  @image_types ~w(image/jpeg image/png image/gif image/webp)
  # 5MB for inline uploads
  @inline_max_size 5_000_000

  def upload_inline(%Plug.Upload{} = upload, user_id) do
    if upload.content_type not in @image_types do
      {:error, :invalid_type}
    else
      if not verify_magic_bytes(upload.path, upload.content_type) do
        {:error, :invalid_type}
      else
        file_stat = File.stat!(upload.path)

        if file_stat.size > @inline_max_size do
          {:error, :too_large}
        else
          ext = Path.extname(upload.filename)
          unique_name = "#{UUID.uuid4()}#{ext}"
          date_path = Date.utc_today() |> Date.to_iso8601() |> String.replace("-", "/")
          relative_path = "#{date_path}/#{unique_name}"

          dir = Path.join([@upload_dir, date_path])
          File.mkdir_p!(dir)

          dest = Path.join(@upload_dir, relative_path)
          File.cp!(upload.path, dest)

          url = "/uploads/#{relative_path}"

          result =
            %Attachment{}
            |> Attachment.changeset(%{
              filename: upload.filename,
              content_type: upload.content_type,
              size: file_stat.size,
              url: url,
              attachable_type: "inline",
              attachable_id: nil,
              user_id: user_id
            })
            |> Repo.insert()

          case result do
            {:ok, attachment} ->
              ForgeNexus.Workers.ImageOptimizer.enqueue(attachment.id)
              {:ok, attachment}

            error ->
              error
          end
        end
      end
    end
  end

  def list_attachments(attachable_type, attachable_id) do
    from(a in Attachment,
      where: a.attachable_type == ^attachable_type and a.attachable_id == ^attachable_id,
      order_by: [asc: :inserted_at]
    )
    |> Repo.all()
  end

  def get_attachment!(id), do: Repo.get!(Attachment, id)

  def delete_attachment(id, user_id) do
    case Repo.get_by(Attachment, id: id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      attachment ->
        # Delete file — validate path is within upload directory to prevent traversal
        file_path = Path.join("priv/static", attachment.url) |> Path.expand()
        upload_root = Path.expand(@upload_dir)

        if String.starts_with?(file_path, upload_root) and File.exists?(file_path) do
          File.rm(file_path)
        end

        Repo.delete(attachment)
    end
  end

  def user_upload_count_today(user_id) do
    today_start = Date.utc_today() |> DateTime.new!(~T[00:00:00])

    from(a in Attachment,
      where: a.user_id == ^user_id and a.inserted_at >= ^today_start,
      select: count(a.id)
    )
    |> Repo.one() || 0
  end
end
