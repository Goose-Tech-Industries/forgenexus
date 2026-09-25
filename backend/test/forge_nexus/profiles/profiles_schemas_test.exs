defmodule ForgeNexus.Profiles.ProfilesSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Profiles.{
    ForgeCode,
    ForgeCodeApplication,
    GuestbookEntry,
    ProfileEndorsement,
    ProfileVisit,
    ProfileWidget,
    TopFriend
  }

  describe "ForgeCode" do
    @valid_attrs %{
      code: "retro-synth-80s",
      name: "Retro Synthwave Theme",
      description: "Neon colors with dark background",
      config: %{"primary_color" => "#ff00ff"}
    }

    test "valid changeset and formatting" do
      cs = ForgeCode.changeset(%ForgeCode{}, @valid_attrs)
      assert cs.valid?
      assert get_field(cs, :code) == "retro-synth-80s"

      req_cs = ForgeCode.changeset(%ForgeCode{}, %{config: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).code
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).config

      # Invalid code format (capital letters or symbols)
      bad_code_cs = ForgeCode.changeset(%ForgeCode{}, Map.put(@valid_attrs, :code, "Retro_Wave!"))
      refute bad_code_cs.valid?
      assert errors_on(bad_code_cs).code != []

      # Code too short (< 4) or too long (> 24)
      short_cs = ForgeCode.changeset(%ForgeCode{}, Map.put(@valid_attrs, :code, "abc"))
      refute short_cs.valid?
      assert "should be at least 4 character(s)" in errors_on(short_cs).code

      long_cs =
        ForgeCode.changeset(%ForgeCode{}, Map.put(@valid_attrs, :code, String.duplicate("a", 25)))

      refute long_cs.valid?
      assert "should be at most 24 character(s)" in errors_on(long_cs).code
    end
  end

  describe "ForgeCodeApplication" do
    @fcid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        ForgeCodeApplication.changeset(%ForgeCodeApplication{}, %{
          forge_code_id: @fcid,
          user_id: @uid
        })

      assert cs.valid?

      req_cs = ForgeCodeApplication.changeset(%ForgeCodeApplication{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).forge_code_id
      assert "can't be blank" in errors_on(req_cs).user_id
    end
  end

  describe "GuestbookEntry" do
    @puid Ecto.UUID.generate()
    @auid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        GuestbookEntry.changeset(%GuestbookEntry{}, %{
          profile_user_id: @puid,
          author_id: @auid,
          body_bbcode: "[b]Thanks for the add![/b]",
          body_html: "<strong>Thanks for the add!</strong>"
        })

      assert cs.valid?

      req_cs = GuestbookEntry.changeset(%GuestbookEntry{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).profile_user_id
      assert "can't be blank" in errors_on(req_cs).author_id
      assert "can't be blank" in errors_on(req_cs).body_bbcode
      assert "can't be blank" in errors_on(req_cs).body_html
    end
  end

  describe "ProfileEndorsement" do
    @puid Ecto.UUID.generate()
    @suid Ecto.UUID.generate()

    test "valid changeset, allowed_emoji/0 and inclusions" do
      emojis = ProfileEndorsement.allowed_emoji()
      assert "🔥" in emojis
      assert "👑" in emojis

      for emoji <- emojis do
        cs =
          ProfileEndorsement.changeset(%ProfileEndorsement{}, %{
            profile_user_id: @puid,
            sender_id: @suid,
            emoji: emoji
          })

        assert cs.valid?
        assert get_field(cs, :emoji) == emoji
      end

      req_cs = ProfileEndorsement.changeset(%ProfileEndorsement{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).profile_user_id
      assert "can't be blank" in errors_on(req_cs).sender_id
      assert "can't be blank" in errors_on(req_cs).emoji

      bad_emoji_cs =
        ProfileEndorsement.changeset(%ProfileEndorsement{}, %{
          profile_user_id: @puid,
          sender_id: @suid,
          emoji: "💩"
        })

      refute bad_emoji_cs.valid?
      assert "is invalid" in errors_on(bad_emoji_cs).emoji
    end
  end

  describe "ProfileVisit" do
    @puid Ecto.UUID.generate()
    @vuid Ecto.UUID.generate()

    test "valid changeset" do
      now = ~U[2026-03-01 12:00:00Z]

      cs =
        ProfileVisit.changeset(%ProfileVisit{}, %{
          profile_user_id: @puid,
          visitor_id: @vuid,
          visited_at: now
        })

      assert cs.valid?
      assert get_field(cs, :visited_at) == now

      req_cs = ProfileVisit.changeset(%ProfileVisit{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).profile_user_id
      assert "can't be blank" in errors_on(req_cs).visitor_id
      assert "can't be blank" in errors_on(req_cs).visited_at
    end
  end

  describe "ProfileWidget" do
    @uid Ecto.UUID.generate()

    test "valid changeset, widget_types/0, default_widgets/0 and inclusions" do
      types = ProfileWidget.widget_types()
      assert "about" in types
      assert "top_friends" in types

      defaults = ProfileWidget.default_widgets()
      assert is_list(defaults)
      assert length(defaults) > 0

      for wtype <- types do
        cs =
          ProfileWidget.changeset(%ProfileWidget{}, %{
            user_id: @uid,
            type: wtype,
            title: "My #{wtype}"
          })

        assert cs.valid?
        assert get_field(cs, :type) == wtype
      end

      req_cs = ProfileWidget.changeset(%ProfileWidget{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).type

      bad_type_cs =
        ProfileWidget.changeset(%ProfileWidget{}, %{
          user_id: @uid,
          type: "bitcoin_ticker"
        })

      refute bad_type_cs.valid?
      assert "is invalid" in errors_on(bad_type_cs).type
    end
  end

  describe "TopFriend" do
    @uid Ecto.UUID.generate()
    @fuid Ecto.UUID.generate()

    test "valid changeset and position bounds (0..9)" do
      for pos <- 0..9 do
        cs =
          TopFriend.changeset(%TopFriend{}, %{
            user_id: @uid,
            friend_id: @fuid,
            position: pos
          })

        assert cs.valid?
        assert get_field(cs, :position) == pos
      end

      req_cs = TopFriend.changeset(%TopFriend{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).friend_id
      assert "can't be blank" in errors_on(req_cs).position

      bad_pos_cs =
        TopFriend.changeset(%TopFriend{}, %{
          user_id: @uid,
          friend_id: @fuid,
          position: 10
        })

      refute bad_pos_cs.valid?
      assert "must be less than 10" in errors_on(bad_pos_cs).position

      neg_pos_cs =
        TopFriend.changeset(%TopFriend{}, %{
          user_id: @uid,
          friend_id: @fuid,
          position: -1
        })

      refute neg_pos_cs.valid?
      assert "must be greater than or equal to 0" in errors_on(neg_pos_cs).position
    end
  end
end
