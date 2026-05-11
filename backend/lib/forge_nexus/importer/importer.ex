defmodule ForgeNexus.Importer do
  @moduledoc """
  Main orchestrator for forum data imports.

  Supports importing from phpBB, vBulletin, and Discourse via a universal JSON format.
  Each source type has a dedicated adapter that handles source-specific data normalization.

  ## Usage

      config = %{"source" => "phpbb", "data" => parsed_json}
      {:ok, import_id} = ForgeNexus.Importer.run_import(config)
      {:ok, status} = ForgeNexus.Importer.get_status(import_id)

  ## Universal JSON Format

  The import expects JSON with these top-level keys:
  - source: "phpbb" | "vbulletin" | "discourse"
  - users: list of user objects
  - categories: list of category objects
  - forums: list of forum objects
  - threads: list of thread objects
  - posts: list of post objects
  """

  alias ForgeNexus.Importer.{Progress, PhpBB, VBulletin, Discourse}
  alias ForgeNexus.Repo

  @adapters %{
    "phpbb" => PhpBB,
    "vbulletin" => VBulletin,
    "discourse" => Discourse
  }

  @supported_sources Map.keys(@adapters)

  @doc "Returns list of supported import sources with metadata."
  def available_sources do
    [
      %{
        id: "phpbb",
        name: "phpBB",
        description: "Import from phpBB 3.x forums",
        version_hint: "3.x",
        format: "json"
      },
      %{
        id: "vbulletin",
        name: "vBulletin",
        description: "Import from vBulletin 3.x/4.x forums",
        version_hint: "3.x / 4.x",
        format: "json"
      },
      %{
        id: "discourse",
        name: "Discourse",
        description: "Import from Discourse forums",
        version_hint: "latest",
        format: "json"
      }
    ]
  end

  @doc "Validate import configuration before starting."
  def validate_config(config) do
    source = config["source"]
    data = config["data"]

    cond do
      is_nil(source) ->
        {:error, "Missing 'source' field"}

      source not in @supported_sources ->
        {:error, "Unsupported source: #{source}. Supported: #{Enum.join(@supported_sources, ", ")}"}

      is_nil(data) || !is_map(data) ->
        {:error, "Missing or invalid 'data' field — expected parsed JSON object"}

      true ->
        :ok
    end
  end

  @doc """
  Preview the import data — returns counts without importing anything.
  """
  def preview(data) do
    %{
      users: length(Map.get(data, "users", [])),
      categories: length(Map.get(data, "categories", [])),
      forums: length(Map.get(data, "forums", [])),
      threads: length(Map.get(data, "threads", [])),
      posts: length(Map.get(data, "posts", []))
    }
  end

  @doc """
  Start an import. Runs in a background Task.
  Returns {:ok, import_id} immediately.
  """
  def run_import(config, opts \\ %{}) do
    case validate_config(config) do
      :ok ->
        import_id = Ecto.UUID.generate()
        Progress.start_import(import_id)

        Task.start(fn ->
          do_import(import_id, config, opts)
        end)

        {:ok, import_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Get the status of an import."
  def get_status(import_id) do
    Progress.get_status(import_id)
  end

  @doc "Cancel a running import."
  def cancel(import_id) do
    Progress.cancel(import_id)
  end

  # --- Private ---

  defp do_import(import_id, config, opts) do
    source = config["source"]
    data = config["data"]
    adapter = @adapters[source]

    import_users? = Map.get(opts, "import_users", true)
    import_posts? = Map.get(opts, "import_posts", true)

    progress_fn = fn step, processed, total ->
      Progress.update(import_id, step, processed, total)
    end

    try do
      # Step 1: Import users (unless disabled)
      user_id_map =
        if import_users? do
          case adapter.import_users(data, progress_fn) do
            {:ok, map} -> map
            {:error, reason} ->
              Progress.add_error(import_id, "User import failed: #{inspect(reason)}")
              %{}
          end
        else
          %{}
        end

      # Step 2: Import categories
      {:ok, category_id_map} = adapter.import_categories(data, progress_fn)

      # Merge id maps for forum import
      combined_map = Map.merge(user_id_map, category_id_map)

      # Step 3: Import forums
      {:ok, forum_id_map} = adapter.import_forums(data, combined_map, progress_fn)

      # Merge all maps
      all_ids = combined_map |> Map.merge(forum_id_map)

      # Step 4: Import threads (if posts enabled)
      thread_id_map =
        if import_posts? do
          case adapter.import_threads(data, all_ids, progress_fn) do
            {:ok, map} -> map
            {:error, reason} ->
              Progress.add_error(import_id, "Thread import failed: #{inspect(reason)}")
              %{}
          end
        else
          %{}
        end

      all_ids = Map.merge(all_ids, thread_id_map)

      # Step 5: Import posts
      post_id_map =
        if import_posts? do
          case adapter.import_posts(data, all_ids, progress_fn) do
            {:ok, map} -> map
            {:error, reason} ->
              Progress.add_error(import_id, "Post import failed: #{inspect(reason)}")
              %{}
          end
        else
          %{}
        end

      # Step 6: Update forum/thread counters
      progress_fn.("updating_counters", 0, 1)
      update_counters(forum_id_map, thread_id_map)
      progress_fn.("updating_counters", 1, 1)

      # Done
      stats = %{
        users_imported: map_size(user_id_map),
        categories_imported: map_size(category_id_map),
        forums_imported: map_size(forum_id_map),
        threads_imported: map_size(thread_id_map),
        posts_imported: map_size(post_id_map)
      }

      Progress.complete(import_id, stats)

    rescue
      e ->
        Progress.fail(import_id, Exception.message(e))
    end
  end

  defp update_counters(forum_id_map, thread_id_map) do
    import Ecto.Query

    # Update thread reply counts
    for {_source_id, thread_id} <- thread_id_map do
      post_count =
        Repo.one(
          from p in ForgeNexus.Forums.Post,
            where: p.thread_id == ^thread_id,
            select: count(p.id)
        ) || 0

      reply_count = max(post_count - 1, 0)

      last_post =
        Repo.one(
          from p in ForgeNexus.Forums.Post,
            where: p.thread_id == ^thread_id,
            order_by: [desc: p.inserted_at],
            limit: 1
        )

      changes = %{reply_count: reply_count}

      changes =
        if last_post do
          Map.merge(changes, %{
            last_post_at: last_post.inserted_at,
            last_post_user_id: last_post.user_id
          })
        else
          changes
        end

      Repo.get(ForgeNexus.Forums.Thread, thread_id)
      |> Ecto.Changeset.change(changes)
      |> Repo.update()
    end

    # Update forum thread/post counts
    for {_source_id, forum_id} <- forum_id_map do
      thread_count =
        Repo.one(
          from t in ForgeNexus.Forums.Thread,
            where: t.forum_id == ^forum_id,
            select: count(t.id)
        ) || 0

      post_count =
        Repo.one(
          from p in ForgeNexus.Forums.Post,
            join: t in ForgeNexus.Forums.Thread,
            on: p.thread_id == t.id,
            where: t.forum_id == ^forum_id,
            select: count(p.id)
        ) || 0

      Repo.get(ForgeNexus.Forums.Forum, forum_id)
      |> Ecto.Changeset.change(%{thread_count: thread_count, post_count: post_count})
      |> Repo.update()
    end
  end
end
