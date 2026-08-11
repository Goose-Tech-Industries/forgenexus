defmodule ForgeNexusWeb.ThreadSubscriptionController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Forums

  # GET /api/threads/:slug/subscription
  def show(conn, %{"slug" => slug}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread_by_slug!(slug)

    case Forums.get_thread_subscription(thread.id, user.id) do
      nil -> conn |> json(%{subscription: nil})
      sub -> conn |> json(%{subscription: %{notification_level: sub.notification_level}})
    end
  end

  # PUT /api/threads/:slug/subscription
  def update(conn, %{"slug" => slug, "notification_level" => level}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread_by_slug!(slug)

    case Forums.subscribe_thread(thread.id, user.id, level) do
      {:ok, sub} ->
        conn |> json(%{subscription: %{notification_level: sub.notification_level}})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Invalid subscription"})
    end
  end

  # DELETE /api/threads/:slug/subscription
  def delete(conn, %{"slug" => slug}) do
    user = Guardian.Plug.current_resource(conn)
    thread = Forums.get_thread_by_slug!(slug)
    Forums.unsubscribe_thread(thread.id, user.id)
    conn |> json(%{status: "ok"})
  end
end
