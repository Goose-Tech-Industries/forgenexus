defmodule ForgeNexusWeb.SearchController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Search
  alias ForgeNexus.Forums

  # GET /api/search?q=...&type=threads|posts&page=1&author=username
  def search(conn, params) do
    query = Map.get(params, "q", "")
    type = Map.get(params, "type", "threads")
    page = Map.get(params, "page", "1") |> safe_to_integer(1)
    author = Map.get(params, "author")
    forum_id = Map.get(params, "forum_id")
    limit = 25
    offset = (page - 1) * limit

    if String.length(query) < 2 do
      conn |> put_status(:bad_request) |> json(%{error: "Query must be at least 2 characters"})
    else
      opts = [limit: limit, offset: offset]

      # Build filter
      filter = cond do
        forum_id && type == "threads" -> "forum_id = \"#{forum_id}\""
        true -> nil
      end
      opts = if filter, do: Keyword.put(opts, :filter, filter), else: opts

      result = cond do
        author -> Search.search_by_author(query, author, opts)
        type == "posts" -> Search.search_posts(query, opts)
        true -> Search.search_threads(query, opts)
      end

      case result do
        {:ok, %{hits: hits, total: total}} ->
          # Hydrate thread hits with full data
          enriched = if type == "threads" do
            thread_ids = Enum.map(hits, & &1["id"])
            threads = Enum.map(thread_ids, fn id ->
              try do
                thread = Forums.get_thread!(id)
                thread_json(thread)
              rescue
                _ -> nil
              end
            end) |> Enum.reject(&is_nil/1)
            threads
          else
            hits
          end

          conn |> json(%{results: enriched, total: total, page: page, type: type})

        {:error, _} ->
          # Fallback to pg_trgm search
          if type == "threads" do
            threads = Forums.find_similar_threads(query, forum_id, limit)
            conn |> json(%{
              results: Enum.map(threads, &thread_json/1),
              total: length(threads),
              page: 1,
              type: "threads",
              fallback: true
            })
          else
            conn |> json(%{results: [], total: 0, page: page, type: type})
          end
      end
    end
  end

  defp thread_json(thread) do
    %{
      id: thread.id,
      title: thread.title,
      slug: thread.slug,
      reply_count: thread.reply_count,
      view_count: thread.view_count,
      inserted_at: thread.inserted_at,
      last_post_at: thread.last_post_at,
      forum: if(Ecto.assoc_loaded?(thread.forum), do: %{id: thread.forum.id, name: thread.forum.name, slug: thread.forum.slug}),
      user: if(Ecto.assoc_loaded?(thread.user), do: %{id: thread.user.id, username: thread.user.username, slug: thread.user.slug})
    }
  end

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end
  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default

end
