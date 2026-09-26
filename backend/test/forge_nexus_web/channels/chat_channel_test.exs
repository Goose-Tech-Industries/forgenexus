defmodule ForgeNexusWeb.ChatChannelTest do
  use ForgeNexusWeb.ChannelCase

  alias ForgeNexus.Accounts
  alias ForgeNexus.Channels
  alias ForgeNexusWeb.{ChatChannel, UserSocket}

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "chat_user_#{unique_suffix}",
      email: "chat_user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      defaults
      |> Accounts.register_user()

    user
    |> Ecto.Changeset.change(attrs)
    |> Repo.update!()
  end

  defp create_channel(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])
    {:ok, category} = Channels.create_category(%{name: "Cat #{unique_suffix}"})

    defaults = %{
      name: "channel-#{unique_suffix}",
      slug: "channel-#{unique_suffix}",
      category_id: category.id,
      is_private: false
    }

    {:ok, channel} =
      defaults
      |> Map.merge(Enum.into(attrs, %{}))
      |> Channels.create_channel()

    channel
  end

  setup do
    user = create_user()
    channel = create_channel()
    socket = socket(UserSocket, "user_socket:#{user.id}", %{current_user: user})

    {:ok, _, channel_socket} =
      subscribe_and_join(socket, ChatChannel, "chat:#{channel.slug}")

    %{
      user: user,
      channel: channel,
      socket: channel_socket,
      raw_socket: socket
    }
  end

  describe "join/3" do
    test "fails when channel slug does not exist", %{raw_socket: socket} do
      assert {:error, %{reason: "channel not found"}} =
               subscribe_and_join(socket, ChatChannel, "chat:does-not-exist-slug")
    end

    test "fails when channel is private and user has no access", %{raw_socket: socket} do
      private_channel =
        create_channel(%{is_private: true, allowed_group_ids: [Ecto.UUID.generate()]})

      assert {:error, %{reason: "forbidden"}} =
               subscribe_and_join(socket, ChatChannel, "chat:#{private_channel.slug}")
    end
  end

  describe "messages lifecycle" do
    test "posts a new message and broadcasts to subscribers", %{socket: socket, user: user} do
      ref = push(socket, "new_message", %{"body" => "Hello chat channel!"})
      assert_reply ref, :ok, %{id: message_id}

      assert_broadcast "new_message", %{
        id: ^message_id,
        body: "Hello chat channel!",
        user: %{id: uid, username: uname}
      }

      assert uid == user.id
      assert uname == user.username
    end

    test "handles message creation validation error", %{socket: socket} do
      ref = push(socket, "new_message", %{"body" => ""})
      assert_reply ref, :error, %{errors: errors}
      assert errors[:body] || errors["body"]
    end

    test "edits own message successfully", %{socket: socket, user: user, channel: channel} do
      {:ok, msg} = Channels.create_message(channel.id, user.id, %{body: "Original text"})

      ref = push(socket, "message_edit", %{"message_id" => msg.id, "body" => "Updated text"})
      assert_reply ref, :ok, %{id: updated_id}
      assert updated_id == msg.id

      assert_broadcast "message_edited", %{
        id: ^updated_id,
        body: "Updated text",
        is_edited: true
      }
    end

    test "cannot edit someone else's message", %{socket: socket, channel: channel} do
      other_user = create_user()
      {:ok, msg} = Channels.create_message(channel.id, other_user.id, %{body: "Their text"})

      ref = push(socket, "message_edit", %{"message_id" => msg.id, "body" => "Hacked text"})
      assert_reply ref, :error, %{reason: "not your message"}
    end

    test "returns not found for editing non-existent message", %{socket: socket} do
      ref =
        push(socket, "message_edit", %{"message_id" => Ecto.UUID.generate(), "body" => "test"})

      assert_reply ref, :error, %{reason: "not found"}
    end

    test "deletes own message successfully", %{socket: socket, user: user, channel: channel} do
      {:ok, msg} = Channels.create_message(channel.id, user.id, %{body: "Delete me"})

      ref = push(socket, "message_delete", %{"message_id" => msg.id})
      assert_reply ref, :ok, %{}

      assert_broadcast "message_deleted", %{id: deleted_id}
      assert deleted_id == msg.id
    end

    test "cannot delete someone else's message", %{socket: socket, channel: channel} do
      other_user = create_user()
      {:ok, msg} = Channels.create_message(channel.id, other_user.id, %{body: "Not mine"})

      ref = push(socket, "message_delete", %{"message_id" => msg.id})
      assert_reply ref, :error, %{reason: "not your message"}
    end

    test "returns not found for deleting non-existent message", %{socket: socket} do
      ref = push(socket, "message_delete", %{"message_id" => Ecto.UUID.generate()})
      assert_reply ref, :error, %{reason: "not found"}
    end
  end

  describe "reactions, presence, and read receipts" do
    test "adds and removes reactions and broadcasts reaction_update", %{
      socket: socket,
      user: user,
      channel: channel
    } do
      {:ok, msg} = Channels.create_message(channel.id, user.id, %{body: "React to this"})

      # Add reaction
      ref = push(socket, "reaction", %{"message_id" => msg.id, "emoji" => "🔥", "action" => "add"})
      assert_reply ref, :ok, %{}
      assert_broadcast "reaction_update", %{message_id: mid, reactions: _}
      assert mid == msg.id

      # Remove reaction
      ref2 =
        push(socket, "reaction", %{"message_id" => msg.id, "emoji" => "🔥", "action" => "remove"})

      assert_reply ref2, :ok, %{}
      assert_broadcast "reaction_update", %{message_id: mid2}
      assert mid2 == msg.id

      # Invalid reaction action
      ref3 =
        push(socket, "reaction", %{"message_id" => msg.id, "emoji" => "🔥", "action" => "invalid"})

      assert_reply ref3, :error, %{reason: ":invalid_action"}
    end

    test "typing and nudge broadcast to other users without crashing", %{
      socket: socket,
      user: user,
      channel: channel
    } do
      push(socket, "typing", %{})
      assert_broadcast "typing", %{user_id: uid, username: uname, channel_id: cid}
      assert uid == user.id
      assert uname == user.username
      assert cid == channel.id

      push(socket, "nudge", %{})
      assert_broadcast "nudge", %{user_id: uid2, username: uname2}
      assert uid2 == user.id
      assert uname2 == user.username
    end

    test "marks message as read and broadcasts read receipt", %{
      socket: socket,
      user: user,
      channel: channel
    } do
      {:ok, msg} = Channels.create_message(channel.id, user.id, %{body: "Read receipt test"})

      ref = push(socket, "read", %{"message_id" => msg.id})
      assert_reply ref, :ok, %{}
      assert_broadcast "read", %{user_id: uid, message_id: mid}
      assert uid == user.id
      assert mid == msg.id
    end

    test "handles unknown or malformed client event", %{socket: socket} do
      ref = push(socket, "completely_unknown_event", %{"foo" => "bar"})

      assert_reply ref, :error, %{
        reason: "unknown or malformed event",
        event: "completely_unknown_event"
      }
    end
  end
end
