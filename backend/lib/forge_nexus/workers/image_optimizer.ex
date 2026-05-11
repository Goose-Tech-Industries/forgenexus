defmodule ForgeNexus.Workers.ImageOptimizer do
  @moduledoc """
  Oban worker that processes uploaded images asynchronously:
  - Resizes to max 2048px (preserves aspect ratio)
  - Generates 200px thumbnail
  - Converts to WebP for smaller file sizes
  - Strips EXIF metadata (privacy)

  Uses ImageMagick's `convert` command (must be installed on the server).
  Install: `apt install imagemagick`
  """
  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 300]

  require Logger

  alias ForgeNexus.Repo
  alias ForgeNexus.Forums.Attachment

  @upload_dir "priv/static/uploads"
  @max_dimension 2048
  @thumb_dimension 200
  @processable_types ~w(image/jpeg image/png image/gif image/webp)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"attachment_id" => attachment_id}}) do
    case Repo.get(Attachment, attachment_id) do
      nil ->
        Logger.warning("[ImageOptimizer] Attachment #{attachment_id} not found, skipping")
        :ok

      attachment ->
        if attachment.content_type in @processable_types do
          process_image(attachment)
        else
          :ok
        end
    end
  end

  defp process_image(attachment) do
    source_path = Path.join(@upload_dir, String.trim_leading(attachment.url, "/uploads/"))

    if File.exists?(source_path) do
      with :ok <- resize_original(source_path),
           :ok <- generate_thumbnail(source_path, attachment),
           :ok <- generate_webp(source_path, attachment),
           :ok <- strip_exif(source_path) do
        Logger.info("[ImageOptimizer] Processed #{attachment.filename}")
        :ok
      else
        {:error, reason} ->
          Logger.warning("[ImageOptimizer] Failed to process #{attachment.filename}: #{inspect(reason)}")
          :ok
      end
    else
      Logger.warning("[ImageOptimizer] File not found: #{source_path}")
      :ok
    end
  end

  # Resize if larger than max dimension (preserves aspect ratio)
  defp resize_original(path) do
    case System.cmd("identify", ["-format", "%wx%h", path], stderr_to_stdout: true) do
      {dimensions, 0} ->
        [w, h] = dimensions |> String.trim() |> String.split("x") |> Enum.map(&String.to_integer/1)

        if w > @max_dimension or h > @max_dimension do
          case System.cmd("convert", [
            path,
            "-resize", "#{@max_dimension}x#{@max_dimension}>",
            "-quality", "85",
            path
          ], stderr_to_stdout: true) do
            {_, 0} -> :ok
            {err, _} -> {:error, "resize failed: #{err}"}
          end
        else
          :ok
        end

      {err, _} ->
        {:error, "identify failed: #{err}"}
    end
  end

  # Generate thumbnail
  defp generate_thumbnail(source_path, attachment) do
    ext = Path.extname(source_path)
    thumb_name = Path.basename(source_path, ext) <> "_thumb" <> ext
    thumb_path = Path.join(Path.dirname(source_path), thumb_name)

    case System.cmd("convert", [
      source_path,
      "-thumbnail", "#{@thumb_dimension}x#{@thumb_dimension}^",
      "-gravity", "center",
      "-extent", "#{@thumb_dimension}x#{@thumb_dimension}",
      "-quality", "80",
      thumb_path
    ], stderr_to_stdout: true) do
      {_, 0} ->
        thumb_url = String.replace(attachment.url, Path.basename(attachment.url), thumb_name)
        attachment
        |> Ecto.Changeset.change(%{thumbnail_url: thumb_url})
        |> Repo.update()
        :ok

      {err, _} ->
        {:error, "thumbnail failed: #{err}"}
    end
  end

  # Generate WebP version (typically 25-35% smaller)
  defp generate_webp(source_path, attachment) do
    # Skip if already WebP
    if attachment.content_type == "image/webp" do
      :ok
    else
      webp_name = Path.basename(source_path, Path.extname(source_path)) <> ".webp"
      webp_path = Path.join(Path.dirname(source_path), webp_name)

      case System.cmd("convert", [
        source_path,
        "-quality", "82",
        webp_path
      ], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {err, _} -> {:error, "webp conversion failed: #{err}"}
      end
    end
  end

  # Strip EXIF metadata (GPS location, camera info, etc.)
  defp strip_exif(path) do
    case System.cmd("convert", [path, "-strip", path], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {err, _} -> {:error, "strip exif failed: #{err}"}
    end
  end

  # Enqueue a job for an attachment
  def enqueue(attachment_id) do
    %{attachment_id: attachment_id}
    |> new()
    |> Oban.insert()
  end
end
