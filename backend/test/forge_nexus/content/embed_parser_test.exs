defmodule ForgeNexus.Content.EmbedParserTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Content.EmbedParser
  alias ForgeNexus.Forums.{Category, Forum, Poll, Thread}
  alias ForgeNexus.Voice.Clip
  alias ForgeNexus.Accounts.User

  defp insert_user! do
    n = System.unique_integer([:positive])

    %User{}
    |> User.registration_changeset(%{
      username: "embeduser#{n}",
      email: "embed#{n}@example.com",
      password: "Password123!"
    })
    |> Repo.insert!()
  end

  defp insert_forum_hierarchy! do
    user = insert_user!()
    n = System.unique_integer([:positive])

    cat =
      %Category{}
      |> Category.changeset(%{name: "Category #{n}", slug: "cat-#{n}", position: 0})
      |> Repo.insert!()

    forum =
      %Forum{}
      |> Forum.changeset(%{
        name: "Forum #{n}",
        slug: "forum-#{n}",
        position: 0,
        category_id: cat.id
      })
      |> Repo.insert!()

    thread =
      %Thread{}
      |> Thread.changeset(%{
        title: "Test Thread #{n}",
        slug: "thread-#{n}",
        forum_id: forum.id,
        user_id: user.id
      })
      |> Repo.insert!()

    {user, forum, thread}
  end

  describe "parse/1" do
    test "returns nil or empty string unchanged" do
      assert EmbedParser.parse(nil) == nil
      assert EmbedParser.parse("") == ""
    end

    test "replaces embed tags with html placeholder containers" do
      input = "Check this [clip:clip-123] and [room:room-456] plus [poll:poll-789]"

      result = EmbedParser.parse(input)

      assert result =~
               "<div class=\"platform-embed\" data-embed-type=\"clip\" data-embed-id=\"clip-123\"></div>"

      assert result =~
               "<div class=\"platform-embed\" data-embed-type=\"room\" data-embed-id=\"room-456\"></div>"

      assert result =~
               "<div class=\"platform-embed\" data-embed-type=\"poll\" data-embed-id=\"poll-789\"></div>"
    end

    test "supports thread, user, achievement, and gift embeds" do
      input = "See [thread:t-1], user [user:u-2], earned [achievement:a-3], and gift [gift:gold]"
      result = EmbedParser.parse(input)

      assert result =~ "data-embed-type=\"thread\" data-embed-id=\"t-1\""
      assert result =~ "data-embed-type=\"user\" data-embed-id=\"u-2\""
      assert result =~ "data-embed-type=\"achievement\" data-embed-id=\"a-3\""
      assert result =~ "data-embed-type=\"gift\" data-embed-id=\"gold\""
    end

    test "leaves regular text and non-matching tags alone" do
      plain = "Just normal text [unknown:123] and brackets [123]"
      assert EmbedParser.parse(plain) == plain
    end
  end

  describe "extract_embeds/1" do
    test "returns empty list for non-binary or strings without tags" do
      assert EmbedParser.extract_embeds(nil) == []
      assert EmbedParser.extract_embeds(123) == []
      assert EmbedParser.extract_embeds("no embeds here") == []
    end

    test "extracts multiple tags with type and id maps" do
      text = "Look at [clip:c-1] and [poll:p-2]"

      assert EmbedParser.extract_embeds(text) == [
               %{type: "clip", id: "c-1"},
               %{type: "poll", id: "p-2"}
             ]
    end
  end

  describe "resolve_embeds/1" do
    test "resolves clip when present and handles missing clip" do
      user = insert_user!()
      n = System.unique_integer([:positive])

      room =
        %ForgeNexus.Voice.Room{}
        |> ForgeNexus.Voice.Room.changeset(%{
          name: "Voice Room #{n}",
          slug: "voice-room-#{n}"
        })
        |> Repo.insert!()

      recording =
        %ForgeNexus.Voice.Recording{}
        |> ForgeNexus.Voice.Recording.changeset(%{
          room_id: room.id,
          host_user_id: user.id,
          audio_url: "https://example.com/audio.webm",
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.insert!()

      clip =
        %Clip{}
        |> Clip.changeset(%{
          title: "Awesome Clip",
          recording_id: recording.id,
          start_ms: 1000,
          end_ms: 5000,
          created_by_id: user.id
        })
        |> Repo.insert!()

      embeds = [
        %{type: "clip", id: clip.id},
        %{type: "clip", id: Ecto.UUID.generate()}
      ]

      [found, not_found] = EmbedParser.resolve_embeds(embeds)

      assert found.data == %{
               title: "Awesome Clip",
               start_ms: 1000,
               end_ms: 5000,
               view_count: 0
             }

      assert not_found.data == %{error: "clip not found"}
    end

    test "resolves poll when present and handles missing poll" do
      {_user, _forum, thread} = insert_forum_hierarchy!()

      poll =
        %Poll{}
        |> Poll.changeset(%{
          question: "Favorite language?",
          status: "open",
          thread_id: thread.id
        })
        |> Repo.insert!()

      embeds = [
        %{type: "poll", id: poll.id},
        %{type: "poll", id: Ecto.UUID.generate()}
      ]

      [found, not_found] = EmbedParser.resolve_embeds(embeds)

      assert found.data == %{question: "Favorite language?", status: "open"}
      assert not_found.data == %{error: "poll not found"}
    end

    test "resolves thread when present and handles missing thread" do
      {_user, _forum, thread} = insert_forum_hierarchy!()

      embeds = [
        %{type: "thread", id: thread.id},
        %{type: "thread", id: Ecto.UUID.generate()}
      ]

      [found, not_found] = EmbedParser.resolve_embeds(embeds)

      assert found.data.title == thread.title
      assert found.data.slug == thread.slug
      assert found.data.reply_count == 0
      assert not_found.data == %{error: "thread not found"}
    end

    test "returns empty map for other embed types like user or gift" do
      embeds = [
        %{type: "user", id: "u-123"},
        %{type: "gift", id: "vip"}
      ]

      [user_res, gift_res] = EmbedParser.resolve_embeds(embeds)

      assert user_res.data == %{}
      assert gift_res.data == %{}
    end
  end
end
