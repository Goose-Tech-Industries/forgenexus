defmodule ForgeNexus.Forums.ForumsRemainingSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Forums.{
    Attachment,
    Badge,
    ContentIgnore,
    CustomBBCode,
    ForumPermission,
    ForumWebhook,
    Poll,
    PollOption,
    PollVote,
    PostBookmark,
    PostDraft,
    PostEdit,
    PostRating,
    ThreadParticipant,
    ThreadPrefix,
    ThreadRead,
    UserBadge,
    WebhookDelivery
  }

  describe "Attachment" do
    @uid Ecto.UUID.generate()

    test "valid changeset, allowed_types/0, and max_size/0" do
      types = Attachment.allowed_types()
      assert "image/png" in types
      assert Attachment.max_size() == 10_000_000

      cs =
        Attachment.changeset(%Attachment{}, %{
          filename: "screenshot.png",
          content_type: "image/png",
          size: 500_000,
          url: "https://cdn.example.com/screenshot.png",
          user_id: @uid
        })

      assert cs.valid?

      req_cs = Attachment.changeset(%Attachment{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).filename
      assert "can't be blank" in errors_on(req_cs).content_type
      assert "can't be blank" in errors_on(req_cs).size
      assert "can't be blank" in errors_on(req_cs).url
      assert "can't be blank" in errors_on(req_cs).user_id

      # Invalid content type and size over max
      bad_cs =
        Attachment.changeset(%Attachment{}, %{
          filename: "malware.exe",
          content_type: "application/x-dosexec",
          size: 15_000_000,
          url: "https://example.com/bad",
          user_id: @uid
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).content_type
      assert "must be less than or equal to 10000000" in errors_on(bad_cs).size
    end
  end

  describe "Badge" do
    test "valid changeset and category inclusions" do
      for cat <- ["achievement", "milestone", "admin_granted", "event"] do
        cs =
          Badge.changeset(%Badge{}, %{
            name: "Bug Hunter",
            category: cat
          })

        assert cs.valid?
        assert get_field(cs, :category) == cat
      end

      req_cs = Badge.changeset(%Badge{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name

      bad_cat_cs =
        Badge.changeset(%Badge{}, %{
          name: "Badge",
          category: "secret"
        })

      refute bad_cat_cs.valid?
      assert "is invalid" in errors_on(bad_cat_cs).category
    end
  end

  describe "ContentIgnore" do
    @uid Ecto.UUID.generate()
    @fid Ecto.UUID.generate()
    @tid Ecto.UUID.generate()

    test "valid changeset with forum or thread target" do
      forum_cs =
        ContentIgnore.changeset(%ContentIgnore{}, %{
          user_id: @uid,
          forum_id: @fid
        })

      assert forum_cs.valid?

      thread_cs =
        ContentIgnore.changeset(%ContentIgnore{}, %{
          user_id: @uid,
          thread_id: @tid
        })

      assert thread_cs.valid?

      # Missing user_id
      req_cs = ContentIgnore.changeset(%ContentIgnore{}, %{forum_id: @fid})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id

      # Missing both forum_id and thread_id
      no_target_cs = ContentIgnore.changeset(%ContentIgnore{}, %{user_id: @uid})
      refute no_target_cs.valid?
      assert "must ignore either a forum or a thread" in errors_on(no_target_cs).forum_id
    end
  end

  describe "CustomBBCode" do
    test "valid changeset and script tag prevention" do
      cs =
        CustomBBCode.changeset(%CustomBBCode{}, %{
          tag_name: "spoiler",
          replacement_html: "<span class=\"spoiler\">{param}</span>"
        })

      assert cs.valid?

      req_cs = CustomBBCode.changeset(%CustomBBCode{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).tag_name
      assert "can't be blank" in errors_on(req_cs).replacement_html

      # Invalid tag format
      bad_tag_cs =
        CustomBBCode.changeset(%CustomBBCode{}, %{
          tag_name: "123_invalid",
          replacement_html: "<div></div>"
        })

      refute bad_tag_cs.valid?

      assert "must start with a letter and contain only letters, numbers, hyphens, underscores" in errors_on(
               bad_tag_cs
             ).tag_name

      # Disallows script tags
      script_cs =
        CustomBBCode.changeset(%CustomBBCode{}, %{
          tag_name: "exploit",
          replacement_html: "<script>alert(1)</script>"
        })

      refute script_cs.valid?
      assert "must not contain script tags" in errors_on(script_cs).replacement_html
    end
  end

  describe "ForumPermission" do
    @fid Ecto.UUID.generate()
    @gid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        ForumPermission.changeset(%ForumPermission{}, %{
          forum_id: @fid,
          group_id: @gid,
          can_view: true,
          can_post: true,
          can_create_threads: false
        })

      assert cs.valid?

      req_cs = ForumPermission.changeset(%ForumPermission{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).forum_id
      assert "can't be blank" in errors_on(req_cs).group_id
    end
  end

  describe "ForumWebhook" do
    test "valid changeset, valid_events/0, and url/events validation" do
      events = ForumWebhook.valid_events()
      assert "forum.thread.created" in events

      cs =
        ForumWebhook.changeset(%ForumWebhook{}, %{
          name: "Discord Bot",
          url: "https://discord.com/api/webhooks/123",
          events: ["forum.thread.created", "forum.post.created"]
        })

      assert cs.valid?
      secret = get_field(cs, :secret)
      assert is_binary(secret)
      assert byte_size(secret) > 20

      req_cs = ForumWebhook.changeset(%ForumWebhook{}, %{events: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).url
      assert "can't be blank" in errors_on(req_cs).events

      # Bad URL scheme
      bad_url_cs =
        ForumWebhook.changeset(%ForumWebhook{}, %{
          name: "Test",
          url: "ftp://example.com/webhook",
          events: ["forum.thread.created"]
        })

      refute bad_url_cs.valid?
      assert "must start with http:// or https://" in errors_on(bad_url_cs).url

      # Invalid events
      bad_ev_cs =
        ForumWebhook.changeset(%ForumWebhook{}, %{
          name: "Test",
          url: "https://example.com",
          events: ["invalid.event"]
        })

      refute bad_ev_cs.valid?
      assert any_error?(errors_on(bad_ev_cs).events, "contains invalid events")
    end
  end

  describe "Poll, PollOption, and PollVote" do
    @tid Ecto.UUID.generate()
    @pid Ecto.UUID.generate()
    @poid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changesets" do
      poll_cs =
        Poll.changeset(%Poll{}, %{
          question: "Best Elixir web framework?",
          thread_id: @tid
        })

      assert poll_cs.valid?

      req_poll_cs = Poll.changeset(%Poll{}, %{})
      refute req_poll_cs.valid?
      assert "can't be blank" in errors_on(req_poll_cs).question
      assert "can't be blank" in errors_on(req_poll_cs).thread_id

      opt_cs =
        PollOption.changeset(%PollOption{}, %{
          text: "Phoenix",
          poll_id: @pid
        })

      assert opt_cs.valid?

      req_opt_cs = PollOption.changeset(%PollOption{}, %{})
      refute req_opt_cs.valid?
      assert "can't be blank" in errors_on(req_opt_cs).text
      assert "can't be blank" in errors_on(req_opt_cs).poll_id

      vote_cs =
        PollVote.changeset(%PollVote{}, %{
          poll_id: @pid,
          option_id: @poid,
          user_id: @uid
        })

      assert vote_cs.valid?

      req_vote_cs = PollVote.changeset(%PollVote{}, %{})
      refute req_vote_cs.valid?
      assert "can't be blank" in errors_on(req_vote_cs).poll_id
      assert "can't be blank" in errors_on(req_vote_cs).option_id
      assert "can't be blank" in errors_on(req_vote_cs).user_id
    end
  end

  describe "PostBookmark, PostDraft, PostEdit, and PostRating" do
    @pid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "PostBookmark" do
      cs =
        PostBookmark.changeset(%PostBookmark{}, %{
          post_id: @pid,
          user_id: @uid,
          note: "Favorite post"
        })

      assert cs.valid?

      req_cs = PostBookmark.changeset(%PostBookmark{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).post_id
      assert "can't be blank" in errors_on(req_cs).user_id
    end

    test "PostDraft" do
      for ctype <- ["thread_create", "thread_reply", "dm"] do
        cs =
          PostDraft.changeset(%PostDraft{}, %{
            user_id: @uid,
            context_type: ctype,
            body: "Draft content..."
          })

        assert cs.valid?
      end

      req_cs = PostDraft.changeset(%PostDraft{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).context_type
      assert "can't be blank" in errors_on(req_cs).body

      bad_cs =
        PostDraft.changeset(%PostDraft{}, %{
          user_id: @uid,
          context_type: "blog",
          body: "Draft"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).context_type
    end

    test "PostEdit struct" do
      edit = %PostEdit{body_before: "before", body_after: "after", reason: "typo"}
      assert edit.body_before == "before"
      assert edit.body_after == "after"
      assert edit.reason == "typo"
    end

    test "PostRating" do
      types = PostRating.rating_types()
      assert "like" in types
      assert "informative" in types

      for rtype <- types do
        cs =
          PostRating.changeset(%PostRating{}, %{
            post_id: @pid,
            user_id: @uid,
            rating_type: rtype
          })

        assert cs.valid?
      end

      req_cs = PostRating.changeset(%PostRating{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).post_id
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).rating_type

      bad_cs =
        PostRating.changeset(%PostRating{}, %{
          post_id: @pid,
          user_id: @uid,
          rating_type: "angry"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).rating_type
    end
  end

  describe "ThreadParticipant, ThreadPrefix, and ThreadRead" do
    @tid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "ThreadParticipant" do
      now = ~U[2026-03-01 12:00:00Z]

      cs =
        ThreadParticipant.changeset(%ThreadParticipant{}, %{
          thread_id: @tid,
          user_id: @uid,
          added_at: now
        })

      assert cs.valid?

      req_cs = ThreadParticipant.changeset(%ThreadParticipant{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).thread_id
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).added_at
    end

    test "ThreadPrefix" do
      cs = ThreadPrefix.changeset(%ThreadPrefix{}, %{name: "Announcement", color: "#ff0000"})
      assert cs.valid?

      req_cs = ThreadPrefix.changeset(%ThreadPrefix{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name

      long_cs = ThreadPrefix.changeset(%ThreadPrefix{}, %{name: String.duplicate("a", 31)})
      refute long_cs.valid?
      assert "should be at most 30 character(s)" in errors_on(long_cs).name
    end

    test "ThreadRead" do
      now = ~U[2026-03-01 12:00:00Z]

      cs =
        ThreadRead.changeset(%ThreadRead{}, %{
          thread_id: @tid,
          user_id: @uid,
          last_read_at: now
        })

      assert cs.valid?

      req_cs = ThreadRead.changeset(%ThreadRead{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).thread_id
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).last_read_at
    end
  end

  describe "UserBadge and WebhookDelivery" do
    @uid Ecto.UUID.generate()
    @bid Ecto.UUID.generate()
    @wid Ecto.UUID.generate()

    test "UserBadge" do
      cs =
        UserBadge.changeset(%UserBadge{}, %{
          user_id: @uid,
          badge_id: @bid,
          reason: "Contributed to open source"
        })

      assert cs.valid?

      req_cs = UserBadge.changeset(%UserBadge{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).badge_id
    end

    test "WebhookDelivery" do
      now = ~U[2026-03-01 12:00:00Z]

      cs =
        WebhookDelivery.changeset(%WebhookDelivery{}, %{
          webhook_id: @wid,
          event_type: "forum.post.created",
          delivered_at: now,
          attempt: 1,
          response_status: 200
        })

      assert cs.valid?

      req_cs = WebhookDelivery.changeset(%WebhookDelivery{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).webhook_id
      assert "can't be blank" in errors_on(req_cs).event_type
      assert "can't be blank" in errors_on(req_cs).delivered_at
    end
  end

  defp any_error?(error_list, pattern) when is_list(error_list) do
    Enum.any?(error_list, &String.contains?(&1, pattern))
  end

  defp any_error?(_, _), do: false
end
