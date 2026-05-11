defmodule ForgeNexusWeb.NotificationController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Notifications

  def index(conn, params) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})

      user ->
        opts = [
          limit: to_int(params["limit"], 20),
          offset: to_int(params["offset"], 0),
          unread_only: params["unread_only"] == "true"
        ]

        notifications = Notifications.list_notifications(user.id, opts)
        conn |> json(%{notifications: Enum.map(notifications, &notification_json/1)})
    end
  end

  def count(conn, _params) do
    case Guardian.Plug.current_resource(conn) do
      nil -> conn |> json(%{count: 0})
      user ->
        count = Notifications.unread_count(user.id)
        conn |> json(%{count: count})
    end
  end

  def mark_read(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Notifications.mark_read(id, user.id) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Notification not found"})
    end
  end

  def mark_all_read(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    Notifications.mark_all_read(user.id)
    conn |> json(%{ok: true})
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Notifications.delete_notification(id, user.id) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Notification not found"})
    end
  end

  defp notification_json(notification) do
    actor = notification.actor

    %{
      id: notification.id,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      url: notification.url,
      is_read: notification.is_read,
      read_at: notification.read_at,
      metadata: notification.metadata,
      actor:
        if(actor,
          do: %{id: actor.id, username: actor.username, avatar_url: actor.avatar_url},
          else: nil
        ),
      inserted_at: notification.inserted_at
    }
  end

  defp to_int(nil, default), do: default
  defp to_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end
  defp to_int(val, _default) when is_integer(val), do: val
end
