defmodule ForgeNexus.Importer.Discourse do
  @moduledoc """
  Import adapter for Discourse forum exports.

  Expects JSON data in the universal import format with source: "discourse".

  Discourse-specific handling:
  - Content format: Discourse stores Markdown (raw) and HTML (cooked)
  - Categories: Discourse categories map to ForgeNexus categories + forums
    (Discourse has no separate forum concept — each category IS a forum)
  - Subcategories: parent_category_id creates hierarchy
  - Trust levels: Discourse uses 0-4 trust levels
  - Markdown conversion: raw Markdown is converted to BBCode for consistency
  """

  @behaviour ForgeNexus.Importer.Adapter

  alias ForgeNexus.Repo
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Forums.{Category, Forum, Thread, Post}

  @impl true
  def import_users(data, progress_fn) do
    users = Map.get(data, "users", [])
    total = length(users)
    progress_fn.("importing_users", 0, total)

    id_map =
      users
      |> Enum.with_index(1)
      |> Enum.reduce(%{}, fn {user_data, index}, acc ->
        progress_fn.("importing_users", index, total)

        attrs = %{
          username: user_data["username"],
          email: user_data["email"] || "imported_dc_#{user_data["source_id"]}@placeholder.local",
          password: generate_random_password(),
          display_name: user_data["username"],
          registered_ip: "0.0.0.0",
          post_count: user_data["post_count"] || 0,
          avatar_url: user_data["avatar_url"],
          bio: user_data["bio"]
        }

        case %User{} |> User.registration_changeset(attrs) |> Repo.insert() do
          {:ok, user} ->
            if user_data["joined_at"] do
              case DateTime.from_iso8601(user_data["joined_at"]) do
                {:ok, dt, _} ->
                  user
                  |> Ecto.Changeset.change(inserted_at: DateTime.truncate(dt, :second))
                  |> Repo.update()
                _ -> :ok
              end
            end

            Map.put(acc, user_data["source_id"], user.id)

          {:error, _changeset} ->
            case find_existing_user(user_data) do
              {:ok, existing_id} -> Map.put(acc, user_data["source_id"], existing_id)
              :not_found -> acc
            end
        end
      end)

    {:ok, id_map}
  end

  @impl true
  def import_categories(data, progress_fn) do
    categories = Map.get(data, "categories", [])
    total = length(categories)
    progress_fn.("importing_categories", 0, total)

    # In Discourse, categories serve as both categories and forums.
    # We create a single "Imported" parent category, then map each
    # Discourse category to a ForgeNexus category.
    id_map =
      categories
      |> Enum.sort_by(& &1["position"])
      |> Enum.with_index(1)
      |> Enum.reduce(%{}, fn {cat_data, index}, acc ->
        progress_fn.("importing_categories", index, total)

        attrs = %{
          name: cat_data["name"],
          description: cat_data["description"] || "",
          position: cat_data["position"] || index
        }

        case %Category{} |> Category.changeset(attrs) |> Repo.insert() do
          {:ok, category} -> Map.put(acc, cat_data["source_id"], category.id)
          {:error, _} ->
            attrs_with_slug = Map.put(attrs, :slug, Slug.slugify(cat_data["name"]) <> "-imported")
            case %Category{} |> Category.changeset(attrs_with_slug) |> Repo.insert() do
              {:ok, category} -> Map.put(acc, cat_data["source_id"], category.id)
              {:error, _} -> acc
            end
        end
      end)

    {:ok, id_map}
  end

  @impl true
  def import_forums(data, id_map, progress_fn) do
    forums = Map.get(data, "forums", [])
    total = length(forums)
    progress_fn.("importing_forums", 0, total)

    forum_id_map =
      forums
      |> Enum.sort_by(& &1["position"])
      |> Enum.with_index(1)
      |> Enum.reduce(%{}, fn {forum_data, index}, acc ->
        progress_fn.("importing_forums", index, total)

        category_id = Map.get(id_map, forum_data["category_source_id"])

        unless category_id do
          acc
        else
          attrs = %{
            name: forum_data["name"],
            description: forum_data["description"] || "",
            position: forum_data["position"] || index,
            category_id: category_id
          }

          case %Forum{} |> Forum.changeset(attrs) |> Repo.insert() do
            {:ok, forum} -> Map.put(acc, forum_data["source_id"], forum.id)
            {:error, _} ->
              attrs_with_slug = Map.put(attrs, :slug, Slug.slugify(forum_data["name"]) <> "-imported")
              case %Forum{} |> Forum.changeset(attrs_with_slug) |> Repo.insert() do
                {:ok, forum} -> Map.put(acc, forum_data["source_id"], forum.id)
                {:error, _} -> acc
              end
          end
        end
      end)

    {:ok, forum_id_map}
  end

  @impl true
  def import_threads(data, id_map, progress_fn) do
    threads = Map.get(data, "threads", [])
    total = length(threads)
    progress_fn.("importing_threads", 0, total)

    thread_id_map =
      threads
      |> Enum.with_index(1)
      |> Enum.reduce(%{}, fn {thread_data, index}, acc ->
        progress_fn.("importing_threads", index, total)

        forum_id = Map.get(id_map, thread_data["forum_source_id"])
        user_id = Map.get(id_map, thread_data["user_source_id"])

        unless forum_id && user_id do
          acc
        else
          attrs = %{
            title: thread_data["title"],
            forum_id: forum_id,
            user_id: user_id,
            is_pinned: thread_data["is_pinned"] || false,
            is_locked: thread_data["is_locked"] || false,
            view_count: thread_data["view_count"] || 0
          }

          case %Thread{} |> Thread.changeset(attrs) |> Repo.insert() do
            {:ok, thread} ->
              if thread_data["created_at"] do
                case DateTime.from_iso8601(thread_data["created_at"]) do
                  {:ok, dt, _} ->
                    thread
                    |> Ecto.Changeset.change(
                      inserted_at: DateTime.truncate(dt, :second),
                      last_post_at: DateTime.truncate(dt, :second)
                    )
                    |> Repo.update()
                  _ -> :ok
                end
              end

              Map.put(acc, thread_data["source_id"], thread.id)

            {:error, _} -> acc
          end
        end
      end)

    {:ok, thread_id_map}
  end

  @impl true
  def import_posts(data, id_map, progress_fn) do
    posts = Map.get(data, "posts", [])
    total = length(posts)
    progress_fn.("importing_posts", 0, total)

    post_id_map =
      posts
      |> Enum.with_index(1)
      |> Enum.reduce(%{}, fn {post_data, index}, acc ->
        progress_fn.("importing_posts", index, total)

        thread_id = Map.get(id_map, post_data["thread_source_id"])
        user_id = Map.get(id_map, post_data["user_source_id"])

        unless thread_id && user_id do
          acc
        else
          body = markdown_to_bbcode(post_data["body"] || "")

          attrs = %{
            body: body,
            body_html: ForgeNexus.BBCode.to_html(body),
            thread_id: thread_id,
            user_id: user_id,
            is_first_post: post_data["is_first_post"] || false,
            position: index
          }

          case %Post{} |> Post.changeset(attrs) |> Repo.insert() do
            {:ok, post} ->
              if post_data["created_at"] do
                case DateTime.from_iso8601(post_data["created_at"]) do
                  {:ok, dt, _} ->
                    post
                    |> Ecto.Changeset.change(inserted_at: DateTime.truncate(dt, :second))
                    |> Repo.update()
                  _ -> :ok
                end
              end

              Map.put(acc, post_data["source_id"], post.id)

            {:error, _} -> acc
          end
        end
      end)

    {:ok, post_id_map}
  end

  # --- Discourse-specific helpers ---

  @doc """
  Convert Markdown (Discourse's raw format) to BBCode.
  Handles the most common Markdown constructs.
  """
  def markdown_to_bbcode(text) when is_binary(text) do
    text
    # Bold: **text** or __text__ → [B]text[/B]
    |> String.replace(~r/\*\*(.+?)\*\*/s, "[B]\\1[/B]")
    |> String.replace(~r/__(.+?)__/s, "[B]\\1[/B]")
    # Italic: *text* or _text_ → [I]text[/I]
    |> String.replace(~r/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/s, "[I]\\1[/I]")
    |> String.replace(~r/(?<!_)_(?!_)(.+?)(?<!_)_(?!_)/s, "[I]\\1[/I]")
    # Strikethrough: ~~text~~ → [S]text[/S]
    |> String.replace(~r/~~(.+?)~~/s, "[S]\\1[/S]")
    # Code blocks: ```lang\ncode\n``` → [CODE]code[/CODE]
    |> String.replace(~r/```[a-z]*\n(.*?)```/s, "[CODE]\\1[/CODE]")
    # Inline code: `code` → [CODE]code[/CODE]
    |> String.replace(~r/`([^`]+)`/, "[CODE]\\1[/CODE]")
    # Links: [text](url) → [URL=url]text[/URL]
    |> String.replace(~r/\[([^\]]+)\]\(([^)]+)\)/, "[URL=\\2]\\1[/URL]")
    # Images: ![alt](url) → [IMG]url[/IMG]
    |> String.replace(~r/!\[([^\]]*)\]\(([^)]+)\)/, "[IMG]\\2[/IMG]")
    # Headers: # text → [B][SIZE=5]text[/SIZE][/B] etc.
    |> String.replace(~r/^### (.+)$/m, "[B]\\1[/B]")
    |> String.replace(~r/^## (.+)$/m, "[B][SIZE=5]\\1[/SIZE][/B]")
    |> String.replace(~r/^# (.+)$/m, "[B][SIZE=6]\\1[/SIZE][/B]")
    # Blockquotes: > text → [QUOTE]text[/QUOTE]
    |> convert_blockquotes()
    # Horizontal rules: --- or *** → [HR]
    |> String.replace(~r/^[-*]{3,}$/m, "[HR]")
    # Unordered lists: - item or * item → [LIST][*]item[/LIST]
    |> convert_lists()
  end

  def markdown_to_bbcode(nil), do: ""

  defp convert_blockquotes(text) do
    # Simple single-level blockquote conversion
    lines = String.split(text, "\n")

    {result, in_quote} =
      Enum.reduce(lines, {[], false}, fn line, {acc, in_quote} ->
        cond do
          String.starts_with?(line, "> ") ->
            content = String.trim_leading(line, "> ")
            if in_quote do
              {acc ++ [content], true}
            else
              {acc ++ ["[QUOTE]", content], true}
            end

          in_quote ->
            {acc ++ ["[/QUOTE]", line], false}

          true ->
            {acc ++ [line], false}
        end
      end)

    result = if in_quote, do: result ++ ["[/QUOTE]"], else: result
    Enum.join(result, "\n")
  end

  defp convert_lists(text) do
    # Simple unordered list conversion
    lines = String.split(text, "\n")

    {result, in_list} =
      Enum.reduce(lines, {[], false}, fn line, {acc, in_list} ->
        is_list_item = Regex.match?(~r/^[\-\*] /, line)

        cond do
          is_list_item && !in_list ->
            content = String.replace(line, ~r/^[\-\*] /, "")
            {acc ++ ["[LIST]", "[*]#{content}"], true}

          is_list_item && in_list ->
            content = String.replace(line, ~r/^[\-\*] /, "")
            {acc ++ ["[*]#{content}"], true}

          in_list ->
            {acc ++ ["[/LIST]", line], false}

          true ->
            {acc ++ [line], false}
        end
      end)

    result = if in_list, do: result ++ ["[/LIST]"], else: result
    Enum.join(result, "\n")
  end

  defp generate_random_password do
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
  end

  defp find_existing_user(user_data) do
    import Ecto.Query

    cond do
      user_data["email"] ->
        case Repo.one(from u in User, where: u.email == ^user_data["email"], select: u.id) do
          nil -> :not_found
          id -> {:ok, id}
        end

      user_data["username"] ->
        slug = Slug.slugify(user_data["username"])
        case Repo.one(from u in User, where: u.slug == ^slug, select: u.id) do
          nil -> :not_found
          id -> {:ok, id}
        end

      true ->
        :not_found
    end
  end
end
