defmodule ForgeNexus.Importer.PhpBB do
  @moduledoc """
  Import adapter for phpBB 3.x forum exports.

  Expects JSON data in the universal import format with source: "phpbb".

  phpBB-specific handling:
  - BBCode UID stripping: phpBB stores BBCode with UIDs like [b:1abc123], strips the :UID suffix
  - Forum types: forum_type 0 = category, forum_type 1 = forum
  - Timestamps: stored as Unix timestamps in phpBB database
  - Passwords: cannot be migrated — imported users get random passwords and must reset
  - Avatar paths: mapped from phpBB avatar directory structure
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
          email: user_data["email"] || "imported_#{user_data["source_id"]}@placeholder.local",
          password: generate_random_password(),
          display_name: user_data["username"],
          registered_ip: "0.0.0.0",
          post_count: user_data["post_count"] || 0,
          avatar_url: user_data["avatar_url"]
        }

        case %User{} |> User.registration_changeset(attrs) |> Repo.insert() do
          {:ok, user} ->
            # Set inserted_at to original join date if available
            if user_data["joined_at"] do
              case DateTime.from_iso8601(user_data["joined_at"]) do
                {:ok, dt, _} ->
                  user
                  |> Ecto.Changeset.change(inserted_at: DateTime.truncate(dt, :second))
                  |> Repo.update()

                _ ->
                  :ok
              end
            end

            Map.put(acc, user_data["source_id"], user.id)

          {:error, _changeset} ->
            # If username/email conflict, try to find existing user
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
          {:ok, category} ->
            Map.put(acc, cat_data["source_id"], category.id)

          {:error, _changeset} ->
            # Try with a modified slug to handle duplicates
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
            {:ok, forum} ->
              Map.put(acc, forum_data["source_id"], forum.id)

            {:error, _changeset} ->
              attrs_with_slug =
                Map.put(attrs, :slug, Slug.slugify(forum_data["name"]) <> "-imported")

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
              # Set original created_at timestamp
              if thread_data["created_at"] do
                case DateTime.from_iso8601(thread_data["created_at"]) do
                  {:ok, dt, _} ->
                    thread
                    |> Ecto.Changeset.change(
                      inserted_at: DateTime.truncate(dt, :second),
                      last_post_at: DateTime.truncate(dt, :second)
                    )
                    |> Repo.update()

                  _ ->
                    :ok
                end
              end

              Map.put(acc, thread_data["source_id"], thread.id)

            {:error, _changeset} ->
              acc
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
          body = strip_phpbb_bbcode_uids(post_data["body"] || "")

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
              # Set original created_at timestamp
              if post_data["created_at"] do
                case DateTime.from_iso8601(post_data["created_at"]) do
                  {:ok, dt, _} ->
                    post
                    |> Ecto.Changeset.change(inserted_at: DateTime.truncate(dt, :second))
                    |> Repo.update()

                  _ ->
                    :ok
                end
              end

              Map.put(acc, post_data["source_id"], post.id)

            {:error, _changeset} ->
              acc
          end
        end
      end)

    {:ok, post_id_map}
  end

  # --- phpBB-specific helpers ---

  @doc """
  Strip phpBB BBCode UIDs from post content.
  phpBB stores BBCode like [b:1abc123]text[/b:1abc123] — we strip the :UID part.
  """
  def strip_phpbb_bbcode_uids(text) when is_binary(text) do
    text
    |> String.replace(~r/\[(\/?[a-z*]+):[a-z0-9]+\]/i, "[\\1]")
    |> String.replace(~r/\[(\/?[a-z*]+)=([^\]]*?):[a-z0-9]+\]/i, "[\\1=\\2]")
    |> String.replace("<!-- s", "")
    |> String.replace(" --><img src=\"{SMILIES_PATH}", "")
    |> String.replace(~r/\" alt="[^"]*" title="[^"]*" \/><!-- [se][^>]* -->/, "")
  end

  def strip_phpbb_bbcode_uids(nil), do: ""

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
