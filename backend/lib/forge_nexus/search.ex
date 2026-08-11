defmodule ForgeNexus.Search do
  @moduledoc """
  Meilisearch integration for full-text search.
  Uses the Req HTTP client to talk to Meilisearch REST API.
  """

  @index_threads "threads"
  @index_posts "posts"

  defp base_url, do: Application.get_env(:forge_nexus, :meilisearch_url, "http://localhost:7700")
  defp api_key, do: Application.get_env(:forge_nexus, :meilisearch_key, "forge_nexus_dev_key")

  defp headers,
    do: [{"Authorization", "Bearer #{api_key()}"}, {"Content-Type", "application/json"}]

  # === Index Management ===

  def setup_indexes do
    # Create indexes
    post_json("/indexes", %{uid: @index_threads, primaryKey: "id"})
    post_json("/indexes", %{uid: @index_posts, primaryKey: "id"})

    # Configure searchable and filterable attributes
    put_json("/indexes/#{@index_threads}/settings", %{
      searchableAttributes: ["title", "tags"],
      filterableAttributes: ["forum_id", "user_id", "is_pinned", "is_locked"],
      sortableAttributes: ["inserted_at", "last_post_at", "reply_count", "view_count"]
    })

    put_json("/indexes/#{@index_posts}/settings", %{
      searchableAttributes: ["body"],
      filterableAttributes: ["thread_id", "user_id"],
      sortableAttributes: ["inserted_at", "position"]
    })

    :ok
  end

  @doc """
  One-shot bulk reindex of all existing threads and posts.
  Useful after a fresh install, a schema change, or Meilisearch reset.
  """
  def reindex_all do
    setup_indexes()

    import Ecto.Query
    alias ForgeNexus.Repo

    threads =
      from(t in ForgeNexus.Forums.Thread)
      |> Repo.all()

    posts =
      from(p in ForgeNexus.Forums.Post, where: p.is_hidden == false)
      |> Repo.all()

    Enum.each(threads, &index_thread/1)
    Enum.each(posts, &index_post/1)

    %{threads_indexed: length(threads), posts_indexed: length(posts)}
  end

  # === Indexing ===

  def index_thread(thread) do
    doc = %{
      id: thread.id,
      title: thread.title,
      slug: thread.slug,
      tags: thread.tags || [],
      forum_id: thread.forum_id,
      user_id: thread.user_id,
      is_pinned: thread.is_pinned,
      is_locked: thread.is_locked,
      reply_count: thread.reply_count,
      view_count: thread.view_count,
      inserted_at: to_unix(thread.inserted_at),
      last_post_at: to_unix(thread.last_post_at)
    }

    post_json("/indexes/#{@index_threads}/documents", [doc])
  end

  def index_post(post) do
    doc = %{
      id: post.id,
      body: post.body,
      thread_id: post.thread_id,
      user_id: post.user_id,
      position: post.position,
      inserted_at: to_unix(post.inserted_at)
    }

    post_json("/indexes/#{@index_posts}/documents", [doc])
  end

  defp to_unix(nil), do: nil
  defp to_unix(%DateTime{} = dt), do: DateTime.to_unix(dt)

  defp to_unix(%NaiveDateTime{} = ndt),
    do: ndt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

  def delete_thread(thread_id) do
    delete_json("/indexes/#{@index_threads}/documents/#{thread_id}")
  end

  def delete_post(post_id) do
    delete_json("/indexes/#{@index_posts}/documents/#{post_id}")
  end

  # === Searching ===

  def search(query, opts \\ []) do
    index = Keyword.get(opts, :index, "threads")
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)
    filter = Keyword.get(opts, :filter)
    sort = Keyword.get(opts, :sort)

    body = %{q: query, limit: limit, offset: offset}
    body = if filter, do: Map.put(body, :filter, filter), else: body
    body = if sort, do: Map.put(body, :sort, sort), else: body

    case post_json("/indexes/#{index}/search", body) do
      {:ok, %{"hits" => hits, "estimatedTotalHits" => total}} ->
        {:ok, %{hits: hits, total: total}}

      {:ok, %{"hits" => hits}} ->
        {:ok, %{hits: hits, total: length(hits)}}

      error ->
        error
    end
  end

  def search_threads(query, opts \\ []) do
    search(query, Keyword.merge(opts, index: @index_threads))
  end

  def search_posts(query, opts \\ []) do
    search(query, Keyword.merge(opts, index: @index_posts))
  end

  def search_by_author(query, username, opts \\ []) do
    alias ForgeNexus.Accounts

    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok, %{hits: [], total: 0}}

      user ->
        filter = "user_id = \"#{user.id}\""
        search_posts(query, Keyword.put(opts, :filter, filter))
    end
  end

  # === Bulk Reindex ===

  def reindex_all do
    alias ForgeNexus.Repo
    alias ForgeNexus.Forums.{Thread, Post}
    import Ecto.Query

    setup_indexes()

    # Index all threads in batches
    Thread
    |> where([t], t.is_hidden == false)
    |> Repo.all()
    |> Enum.chunk_every(100)
    |> Enum.each(fn batch ->
      docs =
        Enum.map(batch, fn t ->
          %{
            id: t.id,
            title: t.title,
            slug: t.slug,
            tags: t.tags || [],
            forum_id: t.forum_id,
            user_id: t.user_id,
            is_pinned: t.is_pinned,
            is_locked: t.is_locked,
            reply_count: t.reply_count,
            view_count: t.view_count,
            inserted_at: t.inserted_at && DateTime.to_unix(t.inserted_at),
            last_post_at: t.last_post_at && DateTime.to_unix(t.last_post_at)
          }
        end)

      post_json("/indexes/#{@index_threads}/documents", docs)
    end)

    # Index all posts in batches
    Post
    |> where([p], p.is_hidden == false)
    |> Repo.all()
    |> Enum.chunk_every(100)
    |> Enum.each(fn batch ->
      docs =
        Enum.map(batch, fn p ->
          %{
            id: p.id,
            body: p.body,
            thread_id: p.thread_id,
            user_id: p.user_id,
            position: p.position,
            inserted_at: p.inserted_at && DateTime.to_unix(p.inserted_at)
          }
        end)

      post_json("/indexes/#{@index_posts}/documents", docs)
    end)

    :ok
  end

  # === HTTP Helpers ===

  defp post_json(path, body) do
    case Req.post("#{base_url()}#{path}", json: body, headers: headers()) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: 202, body: body}} -> {:ok, body}
      {:ok, %{body: body}} -> {:error, body}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :meilisearch_unavailable}
  end

  defp put_json(path, body) do
    case Req.put("#{base_url()}#{path}", json: body, headers: headers()) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: 202, body: body}} -> {:ok, body}
      {:ok, %{body: body}} -> {:error, body}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :meilisearch_unavailable}
  end

  defp delete_json(path) do
    case Req.delete("#{base_url()}#{path}", headers: headers()) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: 202}} -> :ok
      {:ok, %{body: body}} -> {:error, body}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :meilisearch_unavailable}
  end
end
