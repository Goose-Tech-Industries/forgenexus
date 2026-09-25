defmodule ForgeNexus.Chat.ChatSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Chat.{
    Friendship,
    Notification,
    Message,
    ShoutboxMessage,
    Conversation,
    ConversationParticipant
  }

  describe "Friendship schema" do
    test "valid friendship attributes" do
      user_id = Ecto.UUID.generate()
      friend_id = Ecto.UUID.generate()

      changeset =
        Friendship.changeset(%Friendship{}, %{
          user_id: user_id,
          friend_id: friend_id,
          status: "pending"
        })

      assert changeset.valid?
      assert get_field(changeset, :status) == "pending"
    end

    test "requires user_id and friend_id" do
      changeset = Friendship.changeset(%Friendship{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).friend_id
    end

    test "validates status inclusion" do
      user_id = Ecto.UUID.generate()
      friend_id = Ecto.UUID.generate()

      invalid =
        Friendship.changeset(%Friendship{}, %{
          user_id: user_id,
          friend_id: friend_id,
          status: "blocked_invalid"
        })

      refute invalid.valid?
      assert "is invalid" in errors_on(invalid).status

      for s <- ["pending", "accepted", "declined"] do
        assert Friendship.changeset(%Friendship{}, %{
                 user_id: user_id,
                 friend_id: friend_id,
                 status: s
               }).valid?
      end
    end

    test "prevents self-friending" do
      same_id = Ecto.UUID.generate()
      changeset = Friendship.changeset(%Friendship{}, %{user_id: same_id, friend_id: same_id})

      refute changeset.valid?
      assert "cannot be yourself" in errors_on(changeset).friend_id
    end
  end

  describe "Notification schema" do
    test "valid notification changeset" do
      user_id = Ecto.UUID.generate()

      attrs = %{
        type: "mention",
        title: "You were mentioned",
        body: "In thread #1",
        user_id: user_id
      }

      changeset = Notification.changeset(%Notification{}, attrs)
      assert changeset.valid?
    end

    test "requires type, title, and user_id" do
      changeset = Notification.changeset(%Notification{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).type
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "read_changeset marks notification as read with timestamp" do
      notif = %Notification{is_read: false, read_at: nil}
      changeset = Notification.read_changeset(notif)

      assert changeset.valid?
      assert get_change(changeset, :is_read) == true
      assert get_change(changeset, :read_at) != nil
    end
  end

  describe "Message schema" do
    test "valid message attributes" do
      attrs = %{
        body: "Hey there!",
        conversation_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate()
      }

      changeset = Message.changeset(%Message{}, attrs)
      assert changeset.valid?
    end

    test "requires body, conversation_id, and user_id" do
      changeset = Message.changeset(%Message{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).body
      assert "can't be blank" in errors_on(changeset).conversation_id
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "validates body length (1 to 10,000)" do
      too_long =
        Message.changeset(%Message{}, %{
          body: String.duplicate("a", 10_001),
          conversation_id: Ecto.UUID.generate(),
          user_id: Ecto.UUID.generate()
        })

      refute too_long.valid?
      assert "should be at most 10000 character(s)" in errors_on(too_long).body
    end
  end

  describe "ShoutboxMessage schema" do
    test "valid shoutbox message attributes" do
      attrs = %{user_id: Ecto.UUID.generate(), body: "Shouting in the lobby!"}
      changeset = ShoutboxMessage.changeset(%ShoutboxMessage{}, attrs)
      assert changeset.valid?
    end

    test "requires user_id and body" do
      changeset = ShoutboxMessage.changeset(%ShoutboxMessage{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).body
    end

    test "validates body length (1 to 500)" do
      too_long =
        ShoutboxMessage.changeset(%ShoutboxMessage{}, %{
          user_id: Ecto.UUID.generate(),
          body: String.duplicate("a", 501)
        })

      refute too_long.valid?
      assert "should be at most 500 character(s)" in errors_on(too_long).body
    end
  end

  describe "Conversation schema" do
    test "valid conversation attributes" do
      attrs = %{type: "group", title: "Mod Team Chat"}
      changeset = Conversation.changeset(%Conversation{}, attrs)
      assert changeset.valid?
    end

    test "validates type inclusion and requirement" do
      missing = Conversation.changeset(%Conversation{}, %{type: nil})
      refute missing.valid?
      assert "can't be blank" in errors_on(missing).type

      invalid = Conversation.changeset(%Conversation{}, %{type: "invalid_type"})
      refute invalid.valid?
      assert "is invalid" in errors_on(invalid).type

      assert Conversation.changeset(%Conversation{}, %{type: "direct"}).valid?
      assert Conversation.changeset(%Conversation{}, %{type: "group"}).valid?
    end
  end

  describe "ConversationParticipant schema" do
    test "valid participant auto-populates joined_at" do
      attrs = %{
        conversation_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        role: "admin"
      }

      changeset = ConversationParticipant.changeset(%ConversationParticipant{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :joined_at) != nil
    end

    test "preserves existing joined_at if already present" do
      existing_time = ~U[2026-01-01 12:00:00Z]
      participant = %ConversationParticipant{joined_at: existing_time}

      changeset =
        ConversationParticipant.changeset(participant, %{
          conversation_id: Ecto.UUID.generate(),
          user_id: Ecto.UUID.generate()
        })

      assert changeset.valid?
      assert get_change(changeset, :joined_at) == nil
      assert get_field(changeset, :joined_at) == existing_time
    end

    test "requires conversation_id and user_id" do
      changeset = ConversationParticipant.changeset(%ConversationParticipant{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).conversation_id
      assert "can't be blank" in errors_on(changeset).user_id
    end
  end
end
