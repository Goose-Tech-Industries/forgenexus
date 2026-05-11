defmodule ForgeNexusWeb.ThreadChatController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Channels

  def create(conn, %{"channel_slug" => slug, "message_id" => message_id, "name" => name}) do
    user = Guardian.Plug.current_resource(conn)

    case Channels.get_channel_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Channel not found"})

      channel ->
        if Channels.can_post_in_channel?(user, channel) do
          case Channels.create_thread(channel.id, message_id, user.id, name) do
            {:ok, thread} ->
              conn |> put_status(:created) |> json(%{thread: thread_json(thread)})

            {:error, _} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to create thread"})
          end
        else
          conn |> put_status(:forbidden) |> json(%{error: "Cannot create threads here"})
        end
    end
  end

  def show(conn, %{"id" => id}) do
    case Channels.get_thread(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Thread not found"})

      thread ->
        messages = Channels.list_thread_messages(thread.id, limit: 50)

        conn
        |> json(%{
          thread: thread_json(thread),
          messages: Enum.map(messages, &thread_message_json/1)
        })
    end
  end

  def index(conn, %{"channel_slug" => slug}) do
    case Channels.get_channel_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Channel not found"})

      channel ->
        threads = Channels.list_threads(channel.id)
        conn |> json(%{threads: Enum.map(threads, &thread_json/1)})
    end
  end

  def messages(conn, %{"id" => id} = params) do
    opts = []
    opts = if params["before"], do: [{:before_id, params["before"]} | opts], else: opts
    opts = if params["limit"], do: [{:limit, safe_to_integer(params["limit"], 50)} | opts], else: opts

    messages = Channels.list_thread_messages(id, opts)
    conn |> json(%{messages: Enum.map(messages, &thread_message_json/1)})
  end

  def create_message(conn, %{"id" => id, "body" => body}) do
    user = Guardian.Plug.current_resource(conn)

    thread = Channels.get_thread(id)

    cond do
      thread == nil ->
        conn |> put_status(:not_found) |> json(%{error: "Thread not found"})

      thread.is_locked ->
        conn |> put_status(:forbidden) |> json(%{error: "Thread is locked"})

      thread.is_archived ->
        conn |> put_status(:forbidden) |> json(%{error: "Thread is archived"})

      true ->
        case Channels.create_thread_message(id, user.id, body) do
          {:ok, message} ->
            ForgeNexusWeb.Endpoint.broadcast("thread:#{id}", "new_message", thread_message_json(message))
            conn |> put_status(:created) |> json(%{message: thread_message_json(message)})

          {:error, _} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to send message"})
        end
    end
  end

  defp thread_json(thread) do
    %{
      id: thread.id,
      name: thread.name,
      channel_id: thread.channel_id,
      parent_message_id: thread.parent_message_id,
      is_archived: thread.is_archived,
      is_locked: thread.is_locked,
      message_count: thread.message_count,
      last_message_at: thread.last_message_at,
      auto_archive_minutes: thread.auto_archive_minutes,
      created_by: thread.created_by && %{
        id: thread.created_by.id,
        username: thread.created_by.username,
        avatar_url: thread.created_by.avatar_url
      },
      inserted_at: thread.inserted_at
    }
  end

  defp thread_message_json(message) do
    user = message.user
    group = user && user.primary_group

    %{
      id: message.id,
      body: message.body,
      thread_id: message.thread_id,
      user: user && %{
        id: user.id,
        username: user.username,
        slug: user.slug,
        avatar_url: user.avatar_url,
        username_color: user.username_color || (group && group.username_color) || (group && group.color),
        username_effect: user.username_effect || (group && group.username_effect) || "none",
        avatar_frame: user.avatar_frame,
        custom_title: user.custom_title
      },
      is_edited: message.is_edited,
      edited_at: message.edited_at,
      is_deleted: message.is_deleted,
      inserted_at: message.inserted_at
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
