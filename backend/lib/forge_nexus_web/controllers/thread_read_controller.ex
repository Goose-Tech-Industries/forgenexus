defmodule ForgeNexusWeb.ThreadReadController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Forums

  # PUT /api/threads/:slug/read
  def mark_read(conn, %{"slug" => slug}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread_by_slug!(slug)
    Forums.mark_thread_read(thread.id, user.id)
    conn |> json(%{status: "ok"})
  end

  # PUT /api/forums/:slug/read
  def mark_forum_read(conn, %{"slug" => slug}) do
    user = Guardian.Plug.current_resource(conn)
    forum = Forums.get_forum_by_slug!(slug)
    Forums.mark_forum_read(forum.id, user.id)
    conn |> json(%{status: "ok"})
  end

  # GET /api/forums/unread-counts
  def unread_counts(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    counts = Forums.unread_counts_by_forum(user.id)
    conn |> json(%{unread_counts: counts})
  end
end
