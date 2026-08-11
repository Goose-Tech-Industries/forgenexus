defmodule ForgeNexusWeb.BookmarkController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Channels

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    bookmarks = Channels.list_bookmarks(user.id)

    conn
    |> json(%{
      bookmarks:
        Enum.map(bookmarks, fn b ->
          msg = b.message
          user_data = msg.user
          group = user_data && user_data.primary_group

          %{
            id: b.id,
            note: b.note,
            bookmarked_at: b.inserted_at,
            message: %{
              id: msg.id,
              body: msg.body,
              channel_id: msg.channel_id,
              channel_name: msg.channel && msg.channel.name,
              channel_slug: msg.channel && msg.channel.slug,
              user:
                user_data &&
                  %{
                    id: user_data.id,
                    username: user_data.username,
                    avatar_url: user_data.avatar_url,
                    username_color:
                      user_data.username_color || (group && group.username_color) ||
                        (group && group.color)
                  },
              inserted_at: msg.inserted_at
            }
          }
        end)
    })
  end

  def toggle(conn, %{"message_id" => message_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    case Channels.toggle_bookmark(message_id, user.id, params["note"]) do
      {:ok, bookmark} ->
        conn |> json(%{bookmarked: true, id: bookmark.id})

      {:error, _} ->
        # toggle_bookmark deletes and returns {:error, _} is unlikely; deletion returns {:ok, _}
        conn |> json(%{bookmarked: false})
    end
  end

  def bookmark_ids(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    ids = Channels.get_bookmark_ids(user.id) |> MapSet.to_list()
    conn |> json(%{message_ids: ids})
  end
end
