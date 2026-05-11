defmodule ForgeNexusWeb.ChatChannel do
  @moduledoc """
  WebSocket channel for Discord-style chat channels.

  Topic: `chat:<channel_slug>`. The frontend joins this for any channel listed
  in the channel sidebar; messages, reactions, edits, deletes, and read
  receipts all flow through here. Routes through the `Channels` context
  (NOT the `Chat` context, which handles 1:1 DMs).
  """
  use ForgeNexusWeb, :channel

  alias ForgeNexus.Channels

  @impl true
  def join("chat:" <> slug, _payload, socket) do
    user = socket.assigns.current_user

    case Channels.get_channel_by_slug(slug) do
      nil ->
        {:error, %{reason: "channel not found"}}

      channel ->
        if Channels.can_view_channel?(user, channel) do
          {:ok, socket |> assign(:channel, channel) |> assign(:channel_id, channel.id)}
        else
          {:error, %{reason: "forbidden"}}
        end
    end
  end

  @impl true
  def handle_in("new_message", %{"body" => body} = params, socket) do
    user = socket.assigns.current_user
    channel = socket.assigns.channel

    if Channels.can_post_in_channel?(user, channel) do
      attrs = %{
        body: body,
        reply_to_id: params["reply_to_id"],
        attachments: params["attachments"] || [],
        embeds: params["embeds"] || []
      }

      case Channels.create_message(channel.id, user.id, attrs) do
        {:ok, message} ->
          broadcast!(socket, "new_message", message_json(message))
          {:reply, {:ok, %{id: message.id}}, socket}

        {:error, %Ecto.Changeset{} = cs} ->
          errors = Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
          {:reply, {:error, %{errors: errors}}, socket}

        {:error, reason} ->
          {:reply, {:error, %{reason: inspect(reason)}}, socket}
      end
    else
      {:reply, {:error, %{reason: "cannot post in this channel"}}, socket}
    end
  end

  @impl true
  def handle_in("typing", _payload, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "typing", %{
      user_id: user.id,
      username: user.username,
      channel_id: socket.assigns.channel_id
    })

    {:noreply, socket}
  end

  # MSN-style nudge — broadcast to all other participants
  @impl true
  def handle_in("nudge", _payload, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "nudge", %{
      user_id: user.id,
      username: user.username
    })

    {:noreply, socket}
  end

  # Emoji reaction on a message
  @impl true
  def handle_in("reaction", %{"message_id" => message_id, "emoji" => emoji, "action" => action}, socket) do
    result =
      case action do
        "add" -> Channels.add_reaction(message_id, socket.assigns.current_user.id, emoji)
        "remove" -> Channels.remove_reaction(message_id, socket.assigns.current_user.id, emoji)
        _ -> {:error, :invalid_action}
      end

    case result do
      {:ok, _} ->
        # Re-read aggregated reactions and broadcast.
        reactions = Channels.get_reactions(message_id)
        broadcast!(socket, "reaction_update", %{
          message_id: message_id,
          reactions: reactions
        })
        {:reply, {:ok, %{}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  # Read receipt — notify others that a user has read up to a message
  @impl true
  def handle_in("read", %{"message_id" => message_id}, socket) do
    user = socket.assigns.current_user
    Channels.mark_read(socket.assigns.channel_id, user.id, message_id)

    broadcast_from!(socket, "read", %{
      user_id: user.id,
      message_id: message_id
    })

    {:reply, {:ok, %{}}, socket}
  end

  # Edit a message
  @impl true
  def handle_in("message_edit", %{"message_id" => message_id, "body" => body}, socket) do
    user = socket.assigns.current_user

    case Channels.get_message(message_id) do
      nil ->
        {:reply, {:error, %{reason: "not found"}}, socket}

      %{user_id: uid} when uid != user.id ->
        {:reply, {:error, %{reason: "not your message"}}, socket}

      message ->
        case Channels.update_message(message, %{body: body}, user.id) do
          {:ok, updated} ->
            broadcast!(socket, "message_edited", message_json(updated))
            {:reply, {:ok, %{id: updated.id}}, socket}

          {:error, _} ->
            {:reply, {:error, %{reason: "cannot edit"}}, socket}
        end
    end
  end

  # Delete a message
  @impl true
  def handle_in("message_delete", %{"message_id" => message_id}, socket) do
    user = socket.assigns.current_user

    case Channels.get_message(message_id) do
      nil ->
        {:reply, {:error, %{reason: "not found"}}, socket}

      %{user_id: uid} = message when uid == user.id ->
        Channels.delete_message(message, user.id)
        broadcast!(socket, "message_deleted", %{id: message_id})
        {:reply, {:ok, %{}}, socket}

      _ ->
        {:reply, {:error, %{reason: "not your message"}}, socket}
    end
  end

  # Catch-all: malformed payloads on any handler would otherwise crash the
  # channel and disconnect the user. Reply with an error and keep alive.
  @impl true
  def handle_in(event, payload, socket) do
    require Logger
    Logger.warning("[ChatChannel] unhandled or malformed event #{inspect(event)} payload=#{inspect(payload)}")
    {:reply, {:error, %{reason: "unknown or malformed event", event: event}}, socket}
  end

  defp message_json(message) do
    user = if Ecto.assoc_loaded?(message.user), do: message.user, else: nil

    %{
      id: message.id,
      body: message.body,
      inserted_at: message.inserted_at,
      updated_at: message.updated_at,
      is_edited: Map.get(message, :is_edited, false),
      reply_to_id: Map.get(message, :reply_to_id),
      user:
        if(user,
          do: %{id: user.id, username: user.username, avatar_url: user.avatar_url},
          else: nil
        )
    }
  end
end
