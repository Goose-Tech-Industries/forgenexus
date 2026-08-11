defmodule ForgeNexusWeb.ChatController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Chat

  def shoutbox(conn, params) do
    limit =
      case Map.get(params, "limit") do
        nil ->
          50

        val when is_binary(val) ->
          case Integer.parse(val) do
            {n, _} -> min(n, 100)
            :error -> 50
          end

        val when is_integer(val) ->
          min(val, 100)
      end

    messages = Chat.get_shoutbox_messages(limit: limit)
    pinned = Chat.get_pinned_shouts()

    conn
    |> json(%{
      messages: Enum.map(messages, &shoutbox_message_json/1),
      pinned: Enum.map(pinned, &shoutbox_message_json/1),
      total: length(messages)
    })
  end

  # POST /api/shoutbox — HTTP fallback if the Phoenix channel isn't connected.
  # The channel remains the primary path (real-time broadcast to other viewers).
  def send_shoutbox(conn, %{"body" => body}) when is_binary(body) do
    user = Guardian.Plug.current_resource(conn)
    body = String.trim(body)

    cond do
      user == nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})

      body == "" ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Body required"})

      String.length(body) > 500 ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Max 500 characters"})

      true ->
        case Chat.send_shoutbox_message(user.id, body) do
          {:ok, msg} ->
            msg = ForgeNexus.Repo.preload(msg, user: :primary_group)
            payload = shoutbox_message_json(msg)
            # Broadcast to Phoenix channel subscribers too
            ForgeNexusWeb.Endpoint.broadcast("shoutbox:lobby", "new_message", payload)
            conn |> put_status(:created) |> json(%{message: payload})

          {:error, _cs} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to send"})
        end
    end
  end

  def send_shoutbox(conn, _),
    do: conn |> put_status(:bad_request) |> json(%{error: "Missing body"})

  defp shoutbox_message_json(msg) do
    group =
      if Ecto.assoc_loaded?(msg.user) && Ecto.assoc_loaded?(msg.user.primary_group),
        do: msg.user.primary_group

    %{
      id: msg.id,
      body: msg.body,
      is_pinned: msg.is_pinned,
      is_system: msg.is_system,
      inserted_at: msg.inserted_at,
      user:
        if(Ecto.assoc_loaded?(msg.user) && msg.user,
          do: %{
            id: msg.user.id,
            username: msg.user.username,
            avatar_url: msg.user.avatar_url,
            username_color:
              msg.user.username_color || (group && group.username_color) || (group && group.color),
            username_effect:
              msg.user.username_effect || (group && group.username_effect) || "none"
          }
        )
    }
  end

  def friends_public(conn, _params) do
    case Guardian.Plug.current_resource(conn) do
      nil -> conn |> json(%{friends: []})
      _user -> friends(conn, %{})
    end
  end

  def conversations(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    conversations = Chat.list_conversations(user.id)

    conn
    |> json(%{conversations: Enum.map(conversations, &conversation_json(user.id, &1))})
  end

  def messages(conn, %{"id" => conversation_id} = params) do
    before = Map.get(params, "before")
    messages = Chat.list_messages(conversation_id, before: before)

    conn
    |> json(%{messages: Enum.map(messages, &message_json/1)})
  end

  def create_direct(conn, %{"user_id" => other_user_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Chat.get_or_create_direct_conversation(user.id, other_user_id) do
      {:ok, conversation} ->
        conn |> json(%{conversation: %{id: conversation.id, type: conversation.type}})

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create conversation"})
    end
  end

  # POST /api/chat/conversations/group
  #   { "title": "...", "participant_ids": ["uuid"|"username", ...] }
  def create_group(conn, %{"participant_ids" => raw_ids} = params) do
    user = Guardian.Plug.current_resource(conn)
    title = Map.get(params, "title", "")
    title = if is_binary(title) and String.trim(title) != "", do: title, else: nil

    participant_ids = resolve_user_refs(raw_ids) |> Enum.reject(&(&1 == user.id))

    if Enum.empty?(participant_ids) do
      conn |> put_status(:unprocessable_entity) |> json(%{error: "No valid recipients"})
    else
      case length(participant_ids) do
        1 ->
          # For a 2-person group, reuse a direct conversation
          case Chat.get_or_create_direct_conversation(user.id, List.first(participant_ids)) do
            {:ok, conv} ->
              conn |> put_status(:created) |> json(%{conversation: group_conversation_json(conv)})

            {:error, _} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
          end

        _ ->
          case Chat.create_group_conversation(user.id, title, participant_ids) do
            {:ok, conv} ->
              conn |> put_status(:created) |> json(%{conversation: group_conversation_json(conv)})

            {:error, _} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
          end
      end
    end
  end

  def create_group(conn, _),
    do: conn |> put_status(:bad_request) |> json(%{error: "Missing participant_ids"})

  # POST /api/chat/conversations/:id/messages
  def create_message(conn, %{"id" => conversation_id, "body" => body}) when is_binary(body) do
    user = Guardian.Plug.current_resource(conn)
    body = String.trim(body)

    cond do
      body == "" ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Message body is required"})

      not Chat.user_in_conversation?(user.id, conversation_id) ->
        conn |> put_status(:forbidden) |> json(%{error: "You're not in this conversation"})

      true ->
        case Chat.send_message(%{conversation_id: conversation_id, user_id: user.id, body: body}) do
          {:ok, message} ->
            conn |> put_status(:created) |> json(%{message: message_json(message)})

          {:error, _} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to send message"})
        end
    end
  end

  def create_message(conn, _),
    do: conn |> put_status(:bad_request) |> json(%{error: "Missing body"})

  # PUT /api/chat/conversations/:conversation_id/messages/:id
  def update_message(conn, %{"id" => message_id, "body" => body}) when is_binary(body) do
    user = Guardian.Plug.current_resource(conn)
    body = String.trim(body)

    if body == "" do
      conn |> put_status(:unprocessable_entity) |> json(%{error: "Message body is required"})
    else
      case Chat.edit_message(message_id, user.id, body) do
        {:ok, message} ->
          conn |> json(%{message: message_json(Repo.preload(message, :user))})

        {:error, :not_found} ->
          conn |> put_status(:not_found) |> json(%{error: "Message not found"})

        {:error, :unauthorized} ->
          conn |> put_status(:forbidden) |> json(%{error: "Not your message"})

        {:error, _} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
      end
    end
  end

  # DELETE /api/chat/conversations/:conversation_id/messages/:id
  def delete_message(conn, %{"id" => message_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Chat.delete_message(message_id, user.id) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Message not found"})

      {:error, :unauthorized} ->
        conn |> put_status(:forbidden) |> json(%{error: "Not your message"})
    end
  end

  # ----- internals -----

  defp resolve_user_refs(refs) when is_list(refs) do
    uuid_like? = fn s -> is_binary(s) and String.match?(s, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-/i) end

    {ids, handles} = Enum.split_with(refs, uuid_like?)

    handle_ids =
      handles
      |> Enum.reject(&(&1 == "" or is_nil(&1)))
      |> Enum.map(&lookup_user_id/1)
      |> Enum.reject(&is_nil/1)

    (ids ++ handle_ids) |> Enum.uniq()
  end

  defp resolve_user_refs(_), do: []

  defp lookup_user_id(handle) do
    import Ecto.Query
    alias ForgeNexus.Accounts.User

    Repo.one(
      from u in User,
        where: u.slug == ^String.downcase(handle) or ilike(u.username, ^handle),
        limit: 1,
        select: u.id
    )
  end

  defp group_conversation_json(conv) do
    participants =
      case conv.participants do
        %Ecto.Association.NotLoaded{} -> []
        list -> list
      end

    %{
      id: conv.id,
      type: conv.type,
      title: conv.title,
      last_message_at: conv.last_message_at,
      message_count: conv.message_count,
      participants:
        Enum.map(participants, fn p ->
          %{
            id: p.user.id,
            username: p.user.username,
            avatar_url: p.user.avatar_url,
            is_online: p.user.is_online
          }
        end)
    }
  end

  def friends(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    friends = Chat.list_friends(user.id)

    conn
    |> json(%{
      friends:
        Enum.map(friends, fn f ->
          %{
            id: f.id,
            username: f.username,
            slug: f.slug,
            avatar_url: f.avatar_url,
            is_online: f.is_online
          }
        end)
    })
  end

  def friend_requests(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    requests = Chat.pending_friend_requests(user.id)

    conn
    |> json(%{
      requests:
        Enum.map(requests, fn f ->
          %{
            id: f.id,
            user: %{id: f.user.id, username: f.user.username, avatar_url: f.user.avatar_url},
            inserted_at: f.inserted_at
          }
        end)
    })
  end

  def send_friend_request(conn, %{"user_id" => friend_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Chat.friendship_between(user.id, friend_id) do
      nil ->
        case Chat.send_friend_request(user.id, friend_id) do
          {:ok, f} ->
            conn |> put_status(:created) |> json(%{ok: true, id: f.id, status: "request_sent"})

          {:error, cs} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(cs.errors)})
        end

      _existing ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "A friendship already exists between you two"})
    end
  end

  def accept_friend(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Chat.get_friendship(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Request not found"})

      %{friend_id: target_id} = f when target_id == user.id ->
        case Chat.accept_friend_request(f) do
          {:ok, updated} -> conn |> json(%{ok: true, status: "friends", id: updated.id})
          {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
        end

      _ ->
        conn |> put_status(:forbidden) |> json(%{error: "Not your request to accept"})
    end
  end

  def decline_friend(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Chat.get_friendship(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Request not found"})

      %{friend_id: target_id} = f when target_id == user.id ->
        case Chat.decline_friend_request(f) do
          {:ok, _} -> conn |> json(%{ok: true, status: "none"})
          {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
        end

      _ ->
        conn |> put_status(:forbidden) |> json(%{error: "Not your request to decline"})
    end
  end

  def cancel_or_remove_friend(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Chat.get_friendship(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Friendship not found"})

      %{user_id: u1, friend_id: u2} = f when u1 == user.id or u2 == user.id ->
        Chat.remove_friendship(f)
        conn |> json(%{ok: true, status: "none"})

      _ ->
        conn |> put_status(:forbidden) |> json(%{error: "Not part of this friendship"})
    end
  end

  def friendship_status(conn, %{"user_id" => other_id}) do
    user = Guardian.Plug.current_resource(conn)
    conn |> json(Chat.friendship_status(user.id, other_id))
  end

  defp conversation_json(current_user_id, conversation) do
    other_participants =
      conversation.participants
      |> Enum.reject(fn p -> p.user_id == current_user_id end)
      |> Enum.map(fn p ->
        %{
          id: p.user.id,
          username: p.user.username,
          avatar_url: p.user.avatar_url,
          is_online: p.user.is_online
        }
      end)

    %{
      id: conversation.id,
      type: conversation.type,
      title: conversation.title,
      last_message_at: conversation.last_message_at,
      message_count: conversation.message_count,
      participants: other_participants
    }
  end

  defp message_json(message) do
    %{
      id: message.id,
      body: message.body,
      body_html: message.body_html,
      is_edited: message.is_edited,
      is_system: message.is_system,
      inserted_at: message.inserted_at,
      user: %{
        id: message.user.id,
        username: message.user.username,
        avatar_url: message.user.avatar_url
      }
    }
  end
end
