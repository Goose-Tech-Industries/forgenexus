defmodule ForgeNexusWeb.ContentIgnoreController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Forums

  # GET /api/ignores
  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    ignores = Forums.list_ignores(user.id)

    conn |> json(%{ignores: Enum.map(ignores, &ignore_json/1)})
  end

  # POST /api/ignores/forum/:forum_id
  def ignore_forum(conn, %{"forum_id" => forum_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.ignore_forum(user.id, forum_id) do
      {:ok, _} -> conn |> json(%{status: "ok"})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not mute forum"})
    end
  end

  # DELETE /api/ignores/forum/:forum_id
  def unignore_forum(conn, %{"forum_id" => forum_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.unignore_forum(user.id, forum_id) do
      {:ok, _} -> conn |> json(%{status: "ok"})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Not muted"})
    end
  end

  # POST /api/ignores/thread/:thread_id
  def ignore_thread(conn, %{"thread_id" => thread_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.ignore_thread(user.id, thread_id) do
      {:ok, _} -> conn |> json(%{status: "ok"})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not mute thread"})
    end
  end

  # DELETE /api/ignores/thread/:thread_id
  def unignore_thread(conn, %{"thread_id" => thread_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Forums.unignore_thread(user.id, thread_id) do
      {:ok, _} -> conn |> json(%{status: "ok"})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Not muted"})
    end
  end

  defp ignore_json(ignore) do
    %{
      id: ignore.id,
      forum: if(ignore.forum, do: %{id: ignore.forum.id, name: ignore.forum.name, slug: ignore.forum.slug}),
      thread: if(ignore.thread, do: %{id: ignore.thread.id, title: ignore.thread.title, slug: ignore.thread.slug}),
      inserted_at: ignore.inserted_at
    }
  end
end
