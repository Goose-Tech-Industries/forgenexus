defmodule ForgeNexus.Channels.ChannelSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Channels.{
    Channel,
    ChannelCategory,
    ChannelMember,
    ChannelMessage,
    ChatMention,
    ChatThread,
    CustomEmoji,
    MessageBookmark,
    MessageEdit,
    MessageReaction,
    ThreadMember,
    ThreadMessage,
    Webhook
  }

  describe "Channel" do
    test "valid changeset auto-generates slug from name" do
      cs = Channel.changeset(%Channel{}, %{name: "General Discussion"})
      assert cs.valid?
      assert get_change(cs, :name) == "General Discussion"
      assert get_change(cs, :slug) == "general-discussion"
    end

    test "valid changeset preserves explicitly passed slug" do
      cs = Channel.changeset(%Channel{}, %{name: "General Discussion", slug: "custom-general"})
      assert cs.valid?
      assert get_change(cs, :slug) == "custom-general"
    end

    test "validates required fields" do
      cs = Channel.changeset(%Channel{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
    end

    test "validates channel type inclusion" do
      for type <- ["text", "voice", "announcements"] do
        cs = Channel.changeset(%Channel{}, %{name: "Chan", type: type})
        assert cs.valid?
      end

      cs = Channel.changeset(%Channel{}, %{name: "Chan", type: "streaming"})
      refute cs.valid?
      assert "is invalid" in errors_on(cs).type
    end

    test "validates slowmode_seconds is non-negative" do
      cs = Channel.changeset(%Channel{}, %{name: "Chan", slowmode_seconds: -1})
      refute cs.valid?
      assert "must be greater than or equal to 0" in errors_on(cs).slowmode_seconds

      valid_cs = Channel.changeset(%Channel{}, %{name: "Chan", slowmode_seconds: 15})
      assert valid_cs.valid?
    end

    test "no name change leaves slug unchanged" do
      chan = %Channel{name: "Existing", slug: "existing"}
      cs = Channel.changeset(chan, %{topic: "New topic"})
      assert cs.valid?
      assert get_field(cs, :slug) == "existing"
    end
  end

  describe "ChannelCategory" do
    test "valid changeset auto-generates slug and preserves custom slug" do
      cs = ChannelCategory.changeset(%ChannelCategory{}, %{name: "Gaming Categories"})
      assert cs.valid?
      assert get_change(cs, :slug) == "gaming-categories"

      cs2 =
        ChannelCategory.changeset(%ChannelCategory{}, %{name: "Gaming", slug: "custom-gaming"})

      assert cs2.valid?
      assert get_change(cs2, :slug) == "custom-gaming"

      # No name change branch
      cat = %ChannelCategory{name: "Dev", slug: "dev"}
      cs3 = ChannelCategory.changeset(cat, %{position: 3})
      assert cs3.valid?
      assert get_field(cs3, :slug) == "dev"
    end

    test "validates required name" do
      cs = ChannelCategory.changeset(%ChannelCategory{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
    end
  end

  describe "ChannelMember" do
    @cid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset with valid notification level" do
      cs =
        ChannelMember.changeset(%ChannelMember{}, %{
          channel_id: @cid,
          user_id: @uid,
          notification_level: "mentions",
          is_muted: true
        })

      assert cs.valid?
      assert get_field(cs, :notification_level) == "mentions"
      assert get_field(cs, :is_muted) == true
    end

    test "validates required channel_id and user_id" do
      cs = ChannelMember.changeset(%ChannelMember{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).channel_id
      assert "can't be blank" in errors_on(cs).user_id
    end

    test "validates notification_level inclusion" do
      for level <- ["all", "mentions", "none"] do
        cs =
          ChannelMember.changeset(%ChannelMember{}, %{
            channel_id: @cid,
            user_id: @uid,
            notification_level: level
          })

        assert cs.valid?
      end

      cs =
        ChannelMember.changeset(%ChannelMember{}, %{
          channel_id: @cid,
          user_id: @uid,
          notification_level: "invalid_level"
        })

      refute cs.valid?
      assert "is invalid" in errors_on(cs).notification_level
    end
  end

  describe "ChannelMessage" do
    @cid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset with all fields" do
      cs =
        ChannelMessage.changeset(%ChannelMessage{}, %{
          body: "Hello world!",
          channel_id: @cid,
          user_id: @uid,
          attachments: [%{"url" => "https://img.example.com/1.png"}],
          embeds: [%{"title" => "Example"}]
        })

      assert cs.valid?
      assert get_field(cs, :body) == "Hello world!"
      assert length(get_field(cs, :attachments)) == 1
    end

    test "validates required fields" do
      cs = ChannelMessage.changeset(%ChannelMessage{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).body
      assert "can't be blank" in errors_on(cs).channel_id
      assert "can't be blank" in errors_on(cs).user_id
    end

    test "validates body length" do
      empty_cs =
        ChannelMessage.changeset(%ChannelMessage{}, %{
          body: "",
          channel_id: @cid,
          user_id: @uid
        })

      refute empty_cs.valid?
      assert "can't be blank" in errors_on(empty_cs).body

      long_body = String.duplicate("a", 10_001)

      long_cs =
        ChannelMessage.changeset(%ChannelMessage{}, %{
          body: long_body,
          channel_id: @cid,
          user_id: @uid
        })

      refute long_cs.valid?
      assert "should be at most 10000 character(s)" in errors_on(long_cs).body
    end

    test "edit_changeset updates body and sets is_edited and edited_at" do
      msg = %ChannelMessage{body: "Original text"}
      cs = ChannelMessage.edit_changeset(msg, %{body: "Updated text"})
      assert cs.valid?
      assert get_change(cs, :body) == "Updated text"
      assert get_change(cs, :is_edited) == true
      assert %DateTime{} = get_change(cs, :edited_at)
    end

    test "pin_changeset and unpin_changeset" do
      msg = %ChannelMessage{}
      pin_cs = ChannelMessage.pin_changeset(msg, @uid)
      assert get_change(pin_cs, :is_pinned) == true
      assert get_change(pin_cs, :pinned_by_id) == @uid
      assert %DateTime{} = get_change(pin_cs, :pinned_at)

      pinned_msg = %ChannelMessage{
        is_pinned: true,
        pinned_by_id: @uid,
        pinned_at: DateTime.utc_now()
      }

      unpin_cs = ChannelMessage.unpin_changeset(pinned_msg)
      assert get_change(unpin_cs, :is_pinned) == false
      assert get_change(unpin_cs, :pinned_by_id) == nil
      assert get_change(unpin_cs, :pinned_at) == nil
    end

    test "delete_changeset marks is_deleted and records deleted_by_id" do
      msg = %ChannelMessage{}
      del_cs = ChannelMessage.delete_changeset(msg, @uid)
      assert get_change(del_cs, :is_deleted) == true
      assert get_change(del_cs, :deleted_by_id) == @uid
    end
  end

  describe "ChatMention" do
    @mid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset with valid mention types" do
      for type <- ["user", "group", "everyone", "here"] do
        cs =
          ChatMention.changeset(%ChatMention{}, %{
            message_id: @mid,
            mentioned_user_id: @uid,
            mention_type: type,
            read: true
          })

        assert cs.valid?
        assert get_field(cs, :mention_type) == type
        assert get_field(cs, :read) == true
      end
    end

    test "validates required fields and invalid mention type" do
      cs = ChatMention.changeset(%ChatMention{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).message_id
      assert "can't be blank" in errors_on(cs).mentioned_user_id

      invalid_type_cs =
        ChatMention.changeset(%ChatMention{}, %{
          message_id: @mid,
          mentioned_user_id: @uid,
          mention_type: "broadcast"
        })

      refute invalid_type_cs.valid?
      assert "is invalid" in errors_on(invalid_type_cs).mention_type
    end
  end

  describe "ChatThread" do
    @cid Ecto.UUID.generate()
    @mid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        ChatThread.changeset(%ChatThread{}, %{
          name: "Thread Discussion",
          channel_id: @cid,
          parent_message_id: @mid,
          created_by_id: @uid,
          auto_archive_minutes: 60,
          is_archived: false,
          is_locked: false
        })

      assert cs.valid?
      assert get_field(cs, :name) == "Thread Discussion"
      assert get_field(cs, :auto_archive_minutes) == 60
    end

    test "validates required fields" do
      cs = ChatThread.changeset(%ChatThread{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
      assert "can't be blank" in errors_on(cs).channel_id
      assert "can't be blank" in errors_on(cs).parent_message_id
      assert "can't be blank" in errors_on(cs).created_by_id
    end

    test "validates name length up to 100 characters" do
      long_name = String.duplicate("n", 101)

      cs =
        ChatThread.changeset(%ChatThread{}, %{
          name: long_name,
          channel_id: @cid,
          parent_message_id: @mid,
          created_by_id: @uid
        })

      refute cs.valid?
      assert "should be at most 100 character(s)" in errors_on(cs).name
    end
  end

  describe "CustomEmoji" do
    @uid Ecto.UUID.generate()

    test "valid changeset with clean shortcode" do
      cs =
        CustomEmoji.changeset(%CustomEmoji{}, %{
          name: "Party Blob",
          shortcode: "party_blob_123",
          image_url: "https://example.com/blob.png",
          category: "reactions",
          is_animated: true,
          created_by_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :shortcode) == "party_blob_123"
    end

    test "validates required fields" do
      cs = CustomEmoji.changeset(%CustomEmoji{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
      assert "can't be blank" in errors_on(cs).shortcode
      assert "can't be blank" in errors_on(cs).image_url
    end

    test "validates shortcode format and length" do
      # Format uppercase or symbols
      bad_format_cs =
        CustomEmoji.changeset(%CustomEmoji{}, %{
          name: "Test",
          shortcode: "Party-Blob!",
          image_url: "https://example.com/test.png"
        })

      refute bad_format_cs.valid?

      assert "must be lowercase alphanumeric with underscores" in errors_on(bad_format_cs).shortcode

      # Too short (< 2)
      short_cs =
        CustomEmoji.changeset(%CustomEmoji{}, %{
          name: "Test",
          shortcode: "a",
          image_url: "https://example.com/test.png"
        })

      refute short_cs.valid?
      assert "should be at least 2 character(s)" in errors_on(short_cs).shortcode

      # Too long (> 32)
      long_code = String.duplicate("a", 33)

      long_cs =
        CustomEmoji.changeset(%CustomEmoji{}, %{
          name: "Test",
          shortcode: long_code,
          image_url: "https://example.com/test.png"
        })

      refute long_cs.valid?
      assert "should be at most 32 character(s)" in errors_on(long_cs).shortcode
    end
  end

  describe "MessageBookmark" do
    @mid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        MessageBookmark.changeset(%MessageBookmark{}, %{
          message_id: @mid,
          user_id: @uid,
          note: "Read later"
        })

      assert cs.valid?
      assert get_field(cs, :note) == "Read later"
    end

    test "validates required fields" do
      cs = MessageBookmark.changeset(%MessageBookmark{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).message_id
      assert "can't be blank" in errors_on(cs).user_id
    end
  end

  describe "MessageEdit" do
    @mid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        MessageEdit.changeset(%MessageEdit{}, %{
          message_id: @mid,
          previous_body: "Old body",
          edited_by_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :previous_body) == "Old body"
    end

    test "validates required fields" do
      cs = MessageEdit.changeset(%MessageEdit{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).message_id
      assert "can't be blank" in errors_on(cs).previous_body
      assert "can't be blank" in errors_on(cs).edited_by_id
    end
  end

  describe "MessageReaction" do
    @mid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        MessageReaction.changeset(%MessageReaction{}, %{
          emoji: "🚀",
          message_id: @mid,
          user_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :emoji) == "🚀"
    end

    test "validates required fields and length" do
      cs = MessageReaction.changeset(%MessageReaction{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).emoji
      assert "can't be blank" in errors_on(cs).message_id
      assert "can't be blank" in errors_on(cs).user_id

      long_emoji = String.duplicate("e", 65)

      long_cs =
        MessageReaction.changeset(%MessageReaction{}, %{
          emoji: long_emoji,
          message_id: @mid,
          user_id: @uid
        })

      refute long_cs.valid?
      assert "should be at most 64 character(s)" in errors_on(long_cs).emoji
    end
  end

  describe "ThreadMember" do
    @tid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      cs =
        ThreadMember.changeset(%ThreadMember{}, %{
          thread_id: @tid,
          user_id: @uid,
          last_read_at: now
        })

      assert cs.valid?
      assert get_field(cs, :thread_id) == @tid
      assert get_field(cs, :last_read_at) == now
    end

    test "validates required fields" do
      cs = ThreadMember.changeset(%ThreadMember{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).thread_id
      assert "can't be blank" in errors_on(cs).user_id
    end
  end

  describe "ThreadMessage" do
    @tid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset and edit_changeset" do
      cs =
        ThreadMessage.changeset(%ThreadMessage{}, %{
          body: "Thread response",
          thread_id: @tid,
          user_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :body) == "Thread response"

      edit_cs =
        ThreadMessage.edit_changeset(%ThreadMessage{body: "Old"}, %{body: "New thread response"})

      assert edit_cs.valid?
      assert get_change(edit_cs, :body) == "New thread response"
      assert get_change(edit_cs, :is_edited) == true
      assert %DateTime{} = get_change(edit_cs, :edited_at)
    end

    test "validates required fields" do
      cs = ThreadMessage.changeset(%ThreadMessage{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).body
      assert "can't be blank" in errors_on(cs).thread_id
      assert "can't be blank" in errors_on(cs).user_id
    end
  end

  describe "Webhook" do
    @cid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset auto-generates token when not provided" do
      cs =
        Webhook.changeset(%Webhook{}, %{
          name: "GitHub Deploy Webhook",
          channel_id: @cid,
          created_by_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :name) == "GitHub Deploy Webhook"
      token = get_change(cs, :token)
      assert is_binary(token)
      assert byte_size(token) > 20
    end

    test "valid changeset preserves existing token" do
      existing = %Webhook{token: "existing_token_12345"}
      cs = Webhook.changeset(existing, %{name: "Updated Name", channel_id: @cid})
      assert cs.valid?
      assert get_field(cs, :token) == "existing_token_12345"
      refute Map.has_key?(cs.changes, :token)
    end

    test "validates required fields" do
      cs = Webhook.changeset(%Webhook{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
      assert "can't be blank" in errors_on(cs).channel_id
    end

    test "validates name length" do
      long_name = String.duplicate("a", 81)

      cs =
        Webhook.changeset(%Webhook{}, %{
          name: long_name,
          channel_id: @cid
        })

      refute cs.valid?
      assert "should be at most 80 character(s)" in errors_on(cs).name
    end
  end
end
