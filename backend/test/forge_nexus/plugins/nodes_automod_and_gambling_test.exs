defmodule ForgeNexus.Plugins.NodesAutomodAndGamblingTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Plugins.Engine.Context
  alias ForgeNexus.Accounts
  alias ForgeNexus.Forums
  alias ForgeNexus.Plugins.Flow

  # Automod nodes
  alias ForgeNexus.Plugins.Nodes.Automod.{
    AccountAgeCheck,
    AiContentClassify,
    ContentLengthCheck,
    DuplicateCheck,
    InviteLinkFilter,
    KarmaCheck,
    KeywordFilter,
    LinkFilter,
    MediaFilter,
    MentionSpamCheck,
    RateLimitCheck,
    SpamScore
  }

  # Gambling nodes
  alias ForgeNexus.Plugins.Nodes.Gambling.{
    CardDraw,
    Chance,
    CoinFlip,
    DiceRoll,
    GachaPull,
    PickFromTable,
    RouletteSpin,
    Shuffle,
    SlotMachine,
    WeightedPick
  }

  defp make_ctx do
    %Context{
      execution_id: Ecto.UUID.generate(),
      flow_id: Ecto.UUID.generate(),
      started_at: DateTime.utc_now()
    }
  end

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "ag_u_#{unique}",
        email: "ag_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_forum_and_thread(user) do
    unique = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "AG Category #{unique}",
        slug: "ag-cat-#{unique}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "AG Forum #{unique}",
        slug: "ag-forum-#{unique}",
        category_id: cat.id
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "AG Thread #{unique}",
        body: "First post in thread",
        forum_id: forum.id,
        user_id: user.id
      })

    {forum, thread}
  end

  defp create_test_flow(user) do
    unique = System.unique_integer([:positive])

    %Flow{}
    |> Flow.changeset(%{
      name: "Test Flow #{unique}",
      slug: "test-flow-#{unique}",
      trigger_type: "manual",
      status: "active",
      created_by_id: user.id
    })
    |> ForgeNexus.Repo.insert!()
  end

  # ============================================================================
  # AUTOMOD NODES (12)
  # ============================================================================

  describe "Nodes.Automod.AccountAgeCheck" do
    test "checks account age in days and validates config" do
      ctx = make_ctx()

      # User not found -> age 0 -> new
      assert {:branch, "new", %{account_age_days: +0.0}, _} =
               AccountAgeCheck.execute(
                 %{"min_days" => 7},
                 %{"user_id" => Ecto.UUID.generate()},
                 ctx
               )

      # Mature user
      user = create_user()
      # update inserted_at to 10 days ago
      ten_days_ago = NaiveDateTime.utc_now() |> NaiveDateTime.add(-10 * 86_400, :second)

      ForgeNexus.Repo.update_all(
        from(u in ForgeNexus.Accounts.User, where: u.id == ^user.id),
        set: [inserted_at: ten_days_ago]
      )

      assert {:branch, "mature", %{account_age_days: days}, _} =
               AccountAgeCheck.execute(%{"min_days" => 5}, %{"user_id" => user.id}, ctx)

      assert days >= 9.9

      # String min_days and fallback
      assert {:branch, "mature", _, _} =
               AccountAgeCheck.execute(%{"min_days" => "5.0"}, %{"user_id" => user.id}, ctx)

      assert {:branch, "mature", _, _} =
               AccountAgeCheck.execute(%{"min_days" => "invalid"}, %{"user_id" => user.id}, ctx)

      assert {:branch, "mature", _, _} =
               AccountAgeCheck.execute(%{"min_days" => nil}, %{"user_id" => user.id}, ctx)

      # validate_config
      assert :ok = AccountAgeCheck.validate_config(%{"min_days" => 10})
      assert :ok = AccountAgeCheck.validate_config(%{"min_days" => "10"})
      assert {:error, _} = AccountAgeCheck.validate_config(%{})
      assert {:error, _} = AccountAgeCheck.validate_config(%{"min_days" => -5})
      assert {:error, _} = AccountAgeCheck.validate_config(%{"min_days" => "invalid"})
      assert {:error, _} = AccountAgeCheck.validate_config(%{"min_days" => []})
      assert is_map(AccountAgeCheck.schema())
    end
  end

  describe "Nodes.Automod.AiContentClassify" do
    test "classifies content and validates config" do
      ctx = make_ctx()

      # safe content (no policy configured)
      assert {:ok, %{classification: "safe", confidence: 1.0, scores: scores}, _} =
               AiContentClassify.execute(
                 %{"categories" => "spam,toxic,nsfw"},
                 %{"content" => "Hello world"},
                 ctx
               )

      assert is_map(scores)
      assert scores["spam"] == +0.0

      # flagged content via forum content policy
      user = create_user()
      {forum, _thread} = create_forum_and_thread(user)

      ForgeNexus.Moderation.create_content_policy(%{
        name: "AI Test Policy #{System.unique_integer()}",
        forum_id: forum.id,
        is_active: true,
        ai_moderation_enabled: true,
        rules: %{"blocked_words" => ["prohibited_term"]}
      })

      assert {:ok, %{classification: classification, confidence: 1.0, scores: flagged_scores}, _} =
               AiContentClassify.execute(
                 %{"categories" => "spam,toxic,nsfw"},
                 %{"content" => "this has prohibited_term in it", "forum_id" => forum.id},
                 ctx
               )

      assert String.contains?(classification, "prohibited_term")
      assert is_map(flagged_scores)

      # validate_config
      assert :ok = AiContentClassify.validate_config(%{"categories" => "spam,toxic"})
      assert {:error, _} = AiContentClassify.validate_config(%{})
      assert {:error, _} = AiContentClassify.validate_config(%{"categories" => ""})
      assert is_map(AiContentClassify.schema())
    end
  end

  describe "Nodes.Automod.ContentLengthCheck" do
    test "validates content length against bounds" do
      ctx = make_ctx()

      # valid
      assert {:branch, "valid", %{length: 5}, _} =
               ContentLengthCheck.execute(
                 %{"min_length" => 2, "max_length" => 10},
                 %{"content" => "hello"},
                 ctx
               )

      # too short
      assert {:branch, "invalid", %{reason: "Content too short (min: 10.0)"}, _} =
               ContentLengthCheck.execute(
                 %{"min_length" => "10", "max_length" => 20},
                 %{"content" => "hi"},
                 ctx
               )

      # too long
      assert {:branch, "invalid", %{reason: "Content too long (max: 3.0)"}, _} =
               ContentLengthCheck.execute(
                 %{"min_length" => 0, "max_length" => "3.0"},
                 %{"content" => "hello world"},
                 ctx
               )

      # fallback to_number
      assert {:branch, "invalid", %{reason: "Content too long (max: 0)"}, _} =
               ContentLengthCheck.execute(
                 %{"min_length" => "bad", "max_length" => []},
                 %{"content" => "ok"},
                 ctx
               )

      assert :ok = ContentLengthCheck.validate_config(%{})
      assert is_map(ContentLengthCheck.schema())
    end
  end

  describe "Nodes.Automod.DuplicateCheck" do
    test "detects duplicate content against user's recent posts" do
      ctx = make_ctx()
      user = create_user()
      {_forum, thread} = create_forum_and_thread(user)

      {:ok, _post} =
        Forums.create_post(%{
          thread_id: thread.id,
          user_id: user.id,
          body: "This is my unique forum post content"
        })

      # Similar content -> duplicate
      assert {:branch, "duplicate", %{similarity: sim}, _} =
               DuplicateCheck.execute(
                 %{"lookback_minutes" => 60, "similarity_threshold" => 0.5},
                 %{"content" => "This is my unique forum post content", "user_id" => user.id},
                 ctx
               )

      assert sim >= 0.5

      # Different content -> unique
      assert {:branch, "unique", _, _} =
               DuplicateCheck.execute(
                 %{"lookback_minutes" => "60", "similarity_threshold" => "0.8"},
                 %{
                   "content" => "Something completely unrelated and different",
                   "user_id" => user.id
                 },
                 ctx
               )

      # Empty content against user with recent post (tests jaccard("", b))
      assert {:branch, "unique", _, _} =
               DuplicateCheck.execute(
                 %{"lookback_minutes" => 60, "similarity_threshold" => 0.5},
                 %{"content" => "", "user_id" => user.id},
                 ctx
               )

      # Create post with empty body to test jaccard(a, "")
      ForgeNexus.Repo.insert!(%ForgeNexus.Forums.Post{
        thread_id: thread.id,
        user_id: user.id,
        body: "   ",
        body_html: "",
        position: 99
      })

      assert {:branch, "duplicate", _, _} =
               DuplicateCheck.execute(
                 %{"lookback_minutes" => 60, "similarity_threshold" => 0.5},
                 %{"content" => "This is my unique forum post content", "user_id" => user.id},
                 ctx
               )

      # Empty content or empty recent posts
      assert {:branch, "unique", _, _} =
               DuplicateCheck.execute(
                 %{},
                 %{"content" => "", "user_id" => Ecto.UUID.generate()},
                 ctx
               )

      # to_number fallbacks
      assert {:branch, "duplicate", _, _} =
               DuplicateCheck.execute(
                 %{"lookback_minutes" => "invalid", "similarity_threshold" => []},
                 %{"content" => "hello", "user_id" => user.id},
                 ctx
               )

      assert :ok = DuplicateCheck.validate_config(%{})
      assert is_map(DuplicateCheck.schema())
    end
  end

  describe "Nodes.Automod.InviteLinkFilter" do
    test "detects and filters invite links" do
      ctx = make_ctx()

      # clean content
      assert {:branch, "clean", %{content: "Check out our site https://example.com"}, _} =
               InviteLinkFilter.execute(
                 %{},
                 %{"content" => "Check out our site https://example.com"},
                 ctx
               )

      # has discord invite
      assert {:branch, "has_invites", %{invite_links: links}, _} =
               InviteLinkFilter.execute(
                 %{},
                 %{"content" => "Join us on https://discord.gg/abc1234 now!"},
                 ctx
               )

      assert length(links) == 1

      # whitelisted domain
      assert {:branch, "clean", _, _} =
               InviteLinkFilter.execute(
                 %{"allowed_domains" => "discord.gg, t.me"},
                 %{"content" => "Join our official https://discord.gg/official"},
                 ctx
               )

      assert :ok = InviteLinkFilter.validate_config(%{})
      assert is_map(InviteLinkFilter.schema())
    end
  end

  describe "Nodes.Automod.KarmaCheck" do
    test "branches based on user reputation and validates config" do
      ctx = make_ctx()

      # non-existent user karma = 0 -> above when min_karma is 0
      assert {:branch, "above", %{karma: 0}, _} =
               KarmaCheck.execute(%{"min_karma" => 0}, %{"user_id" => Ecto.UUID.generate()}, ctx)

      # below min_karma = 10
      assert {:branch, "below", %{karma: 0}, _} =
               KarmaCheck.execute(
                 %{"min_karma" => "10"},
                 %{"user_id" => Ecto.UUID.generate()},
                 ctx
               )

      # User with actual reputation in DB
      user = create_user()

      ForgeNexus.Repo.update_all(
        from(u in ForgeNexus.Accounts.User, where: u.id == ^user.id),
        set: [reputation: 25]
      )

      assert {:branch, "above", %{karma: 25}, _} =
               KarmaCheck.execute(%{"min_karma" => 10}, %{"user_id" => user.id}, ctx)

      assert {:branch, "below", %{karma: 25}, _} =
               KarmaCheck.execute(%{"min_karma" => 50}, %{"user_id" => user.id}, ctx)

      # to_number fallbacks
      assert {:branch, "above", _, _} =
               KarmaCheck.execute(
                 %{"min_karma" => "invalid"},
                 %{"user_id" => Ecto.UUID.generate()},
                 ctx
               )

      assert {:branch, "above", _, _} =
               KarmaCheck.execute(%{"min_karma" => []}, %{"user_id" => Ecto.UUID.generate()}, ctx)

      # validate_config
      assert :ok = KarmaCheck.validate_config(%{"min_karma" => 10})
      assert :ok = KarmaCheck.validate_config(%{"min_karma" => "10.5"})
      assert {:error, _} = KarmaCheck.validate_config(%{})
      assert {:error, _} = KarmaCheck.validate_config(%{"min_karma" => "abc"})
      assert {:error, _} = KarmaCheck.validate_config(%{"min_karma" => []})
      assert is_map(KarmaCheck.schema())
    end
  end

  describe "Nodes.Automod.KeywordFilter" do
    test "filters keywords by contains, exact, and regex modes" do
      ctx = make_ctx()

      # contains
      assert {:branch, "match", %{matched_word: "spam"}, _} =
               KeywordFilter.execute(
                 %{"words" => "spam, scam", "match_type" => "contains"},
                 %{"content" => "this is a spammy post"},
                 ctx
               )

      assert {:branch, "no_match", _, _} =
               KeywordFilter.execute(
                 %{"words" => "spam, scam", "match_type" => "contains"},
                 %{"content" => "this is clean text"},
                 ctx
               )

      # exact
      assert {:branch, "match", %{matched_word: "buy"}, _} =
               KeywordFilter.execute(
                 %{"words" => "buy, sell", "match_type" => "exact"},
                 %{"content" => "Go buy now"},
                 ctx
               )

      assert {:branch, "no_match", _, _} =
               KeywordFilter.execute(
                 %{"words" => "buy, sell", "match_type" => "exact"},
                 %{"content" => "buying something"},
                 ctx
               )

      # regex
      assert {:branch, "match", %{matched_word: "b[aou]y"}, _} =
               KeywordFilter.execute(
                 %{"words" => "b[aou]y, [0-9]{5}", "match_type" => "regex"},
                 %{"content" => "boy oh boy"},
                 ctx
               )

      assert {:branch, "no_match", _, _} =
               KeywordFilter.execute(
                 %{"words" => "[invalid(, good", "match_type" => "regex"},
                 %{"content" => "hello world"},
                 ctx
               )

      # unknown match_type
      assert {:branch, "no_match", _, _} =
               KeywordFilter.execute(
                 %{"words" => "test", "match_type" => "unknown"},
                 %{"content" => "test"},
                 ctx
               )

      # validate_config
      assert :ok = KeywordFilter.validate_config(%{"words" => "spam", "match_type" => "exact"})
      assert {:error, _} = KeywordFilter.validate_config(%{})
      assert {:error, _} = KeywordFilter.validate_config(%{"words" => ""})

      assert {:error, _} =
               KeywordFilter.validate_config(%{"words" => "spam", "match_type" => "bad"})

      assert is_map(KeywordFilter.schema())
    end
  end

  describe "Nodes.Automod.LinkFilter" do
    test "filters links via blacklist and whitelist modes" do
      ctx = make_ctx()

      # clean content (no links)
      assert {:branch, "clean", _, _} =
               LinkFilter.execute(%{}, %{"content" => "no links here"}, ctx)

      # blacklist mode
      assert {:branch, "has_links", %{links: flagged}, _} =
               LinkFilter.execute(
                 %{"mode" => "blacklist", "domains" => "evil.com, spam.net"},
                 %{"content" => "visit http://evil.com/page now"},
                 ctx
               )

      assert length(flagged) == 1

      assert {:branch, "clean", _, _} =
               LinkFilter.execute(
                 %{"mode" => "blacklist", "domains" => "evil.com"},
                 %{"content" => "visit http://safe.org/page"},
                 ctx
               )

      # whitelist mode
      assert {:branch, "clean", _, _} =
               LinkFilter.execute(
                 %{"mode" => "whitelist", "domains" => "good.com"},
                 %{"content" => "visit https://good.com/docs"},
                 ctx
               )

      assert {:branch, "has_links", _, _} =
               LinkFilter.execute(
                 %{"mode" => "whitelist", "domains" => "good.com"},
                 %{"content" => "visit https://bad.com/docs"},
                 ctx
               )

      # unknown mode
      assert {:branch, "clean", _, _} =
               LinkFilter.execute(
                 %{"mode" => "other", "domains" => "good.com"},
                 %{"content" => "visit https://bad.com/docs"},
                 ctx
               )

      # validate_config
      assert :ok = LinkFilter.validate_config(%{"mode" => "whitelist"})
      assert {:error, _} = LinkFilter.validate_config(%{"mode" => "invalid"})
      assert is_map(LinkFilter.schema())
    end
  end

  describe "Nodes.Automod.MediaFilter" do
    test "checks attachments count, type, and size" do
      ctx = make_ctx()

      attachments = [
        %{"content_type" => "image/png", "size" => 1024 * 1024},
        %{"content_type" => "image/jpeg", "size" => 2 * 1024 * 1024}
      ]

      # valid
      assert {:branch, "valid", %{attachments: ^attachments}, _} =
               MediaFilter.execute(
                 %{
                   "max_count" => 5,
                   "allowed_types" => "image/png, image/jpeg",
                   "max_size_mb" => 5
                 },
                 %{"attachments" => attachments},
                 ctx
               )

      # too many
      assert {:branch, "invalid", %{violations: violations}, _} =
               MediaFilter.execute(
                 %{"max_count" => 1},
                 %{"attachments" => attachments},
                 ctx
               )

      assert Enum.any?(violations, &String.contains?(&1, "Too many"))

      # disallowed types
      assert {:branch, "invalid", %{violations: violations}, _} =
               MediaFilter.execute(
                 %{"allowed_types" => "application/pdf"},
                 %{"attachments" => attachments},
                 ctx
               )

      assert Enum.any?(violations, &String.contains?(&1, "Disallowed file types"))

      # file exceeds size
      assert {:branch, "invalid", %{violations: violations}, _} =
               MediaFilter.execute(
                 %{"max_size_mb" => 0.5},
                 %{"attachments" => attachments},
                 ctx
               )

      assert Enum.any?(violations, &String.contains?(&1, "File exceeds max size"))

      # non-list attachments & to_number string/float/error/nil fallbacks
      assert {:branch, "valid", _, _} =
               MediaFilter.execute(%{}, %{"attachments" => nil}, ctx)

      assert {:branch, "valid", _, _} =
               MediaFilter.execute(
                 %{"max_count" => "5.0", "max_size_mb" => "10.5"},
                 %{"attachments" => attachments},
                 ctx
               )

      assert {:branch, "invalid", _, _} =
               MediaFilter.execute(
                 %{"max_count" => nil, "max_size_mb" => "invalid"},
                 %{"attachments" => attachments},
                 ctx
               )

      assert :ok = MediaFilter.validate_config(%{})
      assert is_map(MediaFilter.schema())
    end
  end

  describe "Nodes.Automod.MentionSpamCheck" do
    test "checks mention count against max mentions" do
      ctx = make_ctx()

      # ok
      assert {:branch, "ok", %{mention_count: 2}, _} =
               MentionSpamCheck.execute(
                 %{"max_mentions" => 3},
                 %{"content" => "Hello @alice and @bob"},
                 ctx
               )

      # spam
      assert {:branch, "spam", %{mention_count: 3}, _} =
               MentionSpamCheck.execute(
                 %{"max_mentions" => "2"},
                 %{"content" => "@one @two @three are mentioned"},
                 ctx
               )

      # to_number fallbacks
      assert {:branch, "ok", _, _} =
               MentionSpamCheck.execute(
                 %{"max_mentions" => "bad"},
                 %{"content" => "no mentions"},
                 ctx
               )

      assert {:branch, "ok", _, _} =
               MentionSpamCheck.execute(
                 %{"max_mentions" => []},
                 %{"content" => "no mentions"},
                 ctx
               )

      assert :ok = MentionSpamCheck.validate_config(%{})
      assert is_map(MentionSpamCheck.schema())
    end
  end

  describe "Nodes.Automod.RateLimitCheck" do
    test "checks action rate limiting and validates config" do
      ctx = make_ctx()
      user = create_user()
      user_id = user.id
      action_key = "action_#{System.unique_integer([:positive])}"

      # Allowed on first check
      assert {:branch, "allowed", %{count: 1}, _} =
               RateLimitCheck.execute(
                 %{"action_key" => action_key, "window_seconds" => 60},
                 %{"user_id" => user_id},
                 ctx
               )

      # Limited on immediate second check
      assert {:branch, "limited", %{retry_after: retry_after}, _} =
               RateLimitCheck.execute(
                 %{"action_key" => action_key, "max_count" => "5", "window_seconds" => "60"},
                 %{"user_id" => user_id},
                 ctx
               )

      assert retry_after >= 1

      # to_number fallbacks
      assert {:branch, "limited", _, _} =
               RateLimitCheck.execute(
                 %{"action_key" => action_key, "max_count" => "bad", "window_seconds" => []},
                 %{"user_id" => user_id},
                 ctx
               )

      # validate_config
      assert :ok = RateLimitCheck.validate_config(%{"action_key" => "post_create"})
      assert {:error, _} = RateLimitCheck.validate_config(%{})
      assert {:error, _} = RateLimitCheck.validate_config(%{"action_key" => ""})
      assert is_map(RateLimitCheck.schema())
    end
  end

  describe "Nodes.Automod.SpamScore" do
    test "calculates weighted heuristic spam score" do
      ctx = make_ctx()

      # clean text
      assert {:ok, %{score: score, caps_ratio: +0.0, link_count: 0}, _} =
               SpamScore.execute(%{}, %{"content" => "this is a normal forum message"}, ctx)

      assert score < 30

      # heavy spam (caps + links + repetition)
      spammy =
        "BUY NOW FREE COINS BUY NOW FREE COINS https://spam1.com https://spam2.com https://spam3.com https://spam4.com"

      assert {:ok, %{score: spam_score, link_count: lc}, _} =
               SpamScore.execute(%{}, %{"content" => spammy}, ctx)

      assert spam_score > 30
      assert lc == 4

      # edge cases: empty content and single-word content
      assert {:ok, %{score: 0}, _} = SpamScore.execute(%{}, %{"content" => ""}, ctx)
      assert {:ok, %{score: 0}, _} = SpamScore.execute(%{}, %{"content" => "123"}, ctx)

      assert :ok = SpamScore.validate_config(%{})
      assert is_map(SpamScore.schema())
    end
  end

  # ============================================================================
  # GAMBLING NODES (10)
  # ============================================================================

  describe "Nodes.Gambling.CardDraw" do
    test "draws standard cards from deck" do
      ctx = make_ctx()

      assert {:ok, %{cards: cards, remaining: remaining}, _} =
               CardDraw.execute(%{"deck_type" => "standard", "count" => 3}, %{}, ctx)

      assert length(cards) == 3
      assert remaining == 49

      # string count, float count, bad count
      assert {:ok, %{cards: [_]}, _} =
               CardDraw.execute(%{"count" => "1"}, %{}, ctx)

      assert {:ok, %{cards: [_]}, _} =
               CardDraw.execute(%{"count" => 1.5}, %{}, ctx)

      assert {:ok, %{cards: [_]}, _} =
               CardDraw.execute(%{"count" => "bad"}, %{}, ctx)

      assert {:ok, %{cards: [_]}, _} =
               CardDraw.execute(%{"count" => nil}, %{}, ctx)

      # custom deck_type fallback to standard
      assert {:ok, %{cards: [_]}, _} =
               CardDraw.execute(%{"deck_type" => "custom", "count" => 1}, %{}, ctx)

      assert :ok = CardDraw.validate_config(%{})
      assert is_map(CardDraw.schema())
    end
  end

  describe "Nodes.Gambling.Chance" do
    test "branches on probability roll and validates config" do
      ctx = make_ctx()

      # 100% success
      assert {:branch, "success", %{roll: _}, _} =
               Chance.execute(%{"probability" => 100}, %{}, ctx)

      # 0% failure
      assert {:branch, "failure", %{roll: _}, _} =
               Chance.execute(%{"probability" => 0}, %{}, ctx)

      # string probability & fallback
      assert {:branch, _, _, _} =
               Chance.execute(%{"probability" => "75.5"}, %{}, ctx)

      assert {:branch, _, _, _} =
               Chance.execute(%{"probability" => "bad"}, %{}, ctx)

      assert {:branch, _, _, _} =
               Chance.execute(%{"probability" => []}, %{}, ctx)

      # validate_config
      assert :ok = Chance.validate_config(%{"probability" => 50})
      assert :ok = Chance.validate_config(%{})
      assert {:error, _} = Chance.validate_config(%{"probability" => 150})
      assert {:error, _} = Chance.validate_config(%{"probability" => -10})
      assert {:error, _} = Chance.validate_config(%{"probability" => "fifty"})
      assert is_map(Chance.schema())
    end
  end

  describe "Nodes.Gambling.CoinFlip" do
    test "flips coin returning heads or tails" do
      ctx = make_ctx()

      assert {:ok, %{result: result, is_heads: is_heads}, _} =
               CoinFlip.execute(%{}, %{}, ctx)

      assert result in ["heads", "tails"]
      assert is_boolean(is_heads)

      assert :ok = CoinFlip.validate_config(%{})
      assert is_map(CoinFlip.schema())
    end
  end

  describe "Nodes.Gambling.DiceRoll" do
    test "rolls dice in NdS format and handles bad notation" do
      ctx = make_ctx()

      assert {:ok, %{total: total, rolls: rolls, notation: "2d6"}, _} =
               DiceRoll.execute(%{"notation" => "2d6"}, %{}, ctx)

      assert length(rolls) == 2
      assert total >= 2 and total <= 12

      # invalid notation error
      assert {:error, "Invalid dice notation: bad. Use NdS format (e.g. 2d6)", _} =
               DiceRoll.execute(%{"notation" => "bad"}, %{}, ctx)

      assert {:error, _, _} = DiceRoll.execute(%{"notation" => 123}, %{}, ctx)
      assert {:error, _, _} = DiceRoll.execute(%{"notation" => "0d6"}, %{}, ctx)
      assert {:error, _, _} = DiceRoll.execute(%{"notation" => "1d0"}, %{}, ctx)

      # validate_config
      assert :ok = DiceRoll.validate_config(%{"notation" => "3d10"})
      assert {:error, _} = DiceRoll.validate_config(%{"notation" => "invalid"})
      assert {:error, _} = DiceRoll.validate_config(%{"notation" => 123})
      assert is_map(DiceRoll.schema())
    end
  end

  describe "Nodes.Gambling.GachaPull" do
    test "performs pulls, tracks pity in FlowGlobalStore, and hits pity threshold" do
      user = create_user()
      flow = create_test_flow(user)
      ctx = %{make_ctx() | flow_id: flow.id}
      user_id = user.id
      rates = %{"common" => 80, "rare" => 19, "legendary" => 1}

      # First pull: initializes pity counter to 1
      assert {:ok, %{rarity: rarity, pull_count: 1, is_pity: false}, _} =
               GachaPull.execute(
                 %{"rates" => rates, "pity_threshold" => 3},
                 %{"user_id" => user_id},
                 ctx
               )

      assert is_binary(rarity)

      # Second pull: increments pity counter to 2
      assert {:ok, %{pull_count: 2, is_pity: false}, _} =
               GachaPull.execute(
                 %{"rates" => rates, "pity_threshold" => 3},
                 %{"user_id" => user_id},
                 ctx
               )

      # Third pull: hits pity threshold -> is_pity: true, gives rarest ("legendary")
      assert {:ok, %{rarity: "legendary", pull_count: 3, is_pity: true}, _} =
               GachaPull.execute(
                 %{"rates" => rates, "pity_threshold" => 3},
                 %{"user_id" => user_id},
                 ctx
               )

      # Fourth pull: pity reset, count is 1 again
      assert {:ok, %{pull_count: 1, is_pity: false}, _} =
               GachaPull.execute(
                 %{"rates" => rates, "pity_threshold" => 3},
                 %{"user_id" => user_id},
                 ctx
               )

      # JSON string rates & string pity_threshold
      rates_json = Jason.encode!(rates)

      assert {:ok, %{pull_count: 2}, _} =
               GachaPull.execute(
                 %{"rates" => rates_json, "pity_threshold" => "10"},
                 %{"user_id" => user_id},
                 ctx
               )

      # Fallback rates (invalid json)
      assert {:ok, %{rarity: "common"}, _} =
               GachaPull.execute(
                 %{"rates" => "invalid_json", "pity_threshold" => 10},
                 %{"user_id" => Ecto.UUID.generate()},
                 ctx
               )

      # String store value in pity record branch
      pity_key = "gacha_pity:#{user_id}"

      ForgeNexus.Repo.update_all(
        from(s in ForgeNexus.Plugins.FlowGlobalStore,
          where: s.flow_id == ^ctx.flow_id and s.key == ^pity_key
        ),
        set: [value: %{"count" => "4"}]
      )

      assert {:ok, %{pull_count: 5}, _} =
               GachaPull.execute(
                 %{"rates" => rates, "pity_threshold" => 10},
                 %{"user_id" => user_id},
                 ctx
               )

      # String store value with bad integer parse
      ForgeNexus.Repo.update_all(
        from(s in ForgeNexus.Plugins.FlowGlobalStore,
          where: s.flow_id == ^ctx.flow_id and s.key == ^pity_key
        ),
        set: [value: %{"count" => "bad_int"}]
      )

      assert {:ok, %{pull_count: 1}, _} =
               GachaPull.execute(
                 %{"rates" => rates, "pity_threshold" => 10},
                 %{"user_id" => user_id},
                 ctx
               )

      # Other store value (missing count key)
      ForgeNexus.Repo.update_all(
        from(s in ForgeNexus.Plugins.FlowGlobalStore,
          where: s.flow_id == ^ctx.flow_id and s.key == ^pity_key
        ),
        set: [value: %{"other" => 123}]
      )

      assert {:ok, %{pull_count: 1}, _} =
               GachaPull.execute(
                 %{"rates" => rates, "pity_threshold" => 10},
                 %{"user_id" => user_id},
                 ctx
               )

      # Non-binary key in rates (triggers _ -> "common" in then())
      int_rates = %{123 => 10}

      assert {:ok, %{rarity: "common"}, _} =
               GachaPull.execute(
                 %{"rates" => int_rates, "pity_threshold" => 10},
                 %{"user_id" => user_id},
                 ctx
               )

      # String float weight and bad float weight in rates, and nil weight
      str_float_rates = %{"rare" => "10.5", "bad" => "invalid_float", "epic" => nil}

      assert {:ok, %{rarity: _}, _} =
               GachaPull.execute(
                 %{"rates" => str_float_rates, "pity_threshold" => 10},
                 %{"user_id" => user_id},
                 ctx
               )

      # pity_threshold float, string bad, and nil
      assert {:ok, %{pull_count: _}, _} =
               GachaPull.execute(
                 %{"rates" => rates, "pity_threshold" => 10.5},
                 %{"user_id" => user_id},
                 ctx
               )

      assert {:ok, %{pull_count: _}, _} =
               GachaPull.execute(
                 %{"rates" => rates, "pity_threshold" => "bad"},
                 %{"user_id" => user_id},
                 ctx
               )

      assert {:ok, %{pull_count: _}, _} =
               GachaPull.execute(
                 %{"rates" => rates, "pity_threshold" => nil},
                 %{"user_id" => user_id},
                 ctx
               )

      # parse_json with non-map, non-binary
      assert {:ok, %{rarity: "common"}, _} =
               GachaPull.execute(
                 %{"rates" => 123, "pity_threshold" => 10},
                 %{"user_id" => user_id},
                 ctx
               )

      # validate_config
      assert :ok = GachaPull.validate_config(%{"rates" => rates, "pity_threshold" => 50})
      assert :ok = GachaPull.validate_config(%{"rates" => rates_json})
      assert {:error, _} = GachaPull.validate_config(%{"rates" => "invalid_json"})
      assert {:error, _} = GachaPull.validate_config(%{"rates" => %{}, "pity_threshold" => -1})
      assert is_map(GachaPull.schema())
    end
  end

  describe "Nodes.Gambling.PickFromTable" do
    test "picks items randomly from list or JSON string" do
      ctx = make_ctx()

      items = ["sword", "shield", "potion", "ring"]

      assert {:ok, %{picked: picked}, _} =
               PickFromTable.execute(%{"count" => 2}, %{"items" => items}, ctx)

      assert length(picked) == 2
      assert Enum.all?(picked, &(&1 in items))

      # from JSON string
      json_items = Jason.encode!(items)

      assert {:ok, %{picked: [_]}, _} =
               PickFromTable.execute(%{"count" => "1"}, %{"items" => json_items}, ctx)

      # float count & fallbacks
      assert {:ok, %{picked: [_]}, _} =
               PickFromTable.execute(%{"count" => 1.5}, %{"items" => items}, ctx)

      assert {:ok, %{picked: [_]}, _} =
               PickFromTable.execute(%{"count" => "bad"}, %{"items" => items}, ctx)

      assert {:ok, %{picked: [_]}, _} =
               PickFromTable.execute(%{"count" => nil}, %{"items" => items}, ctx)

      # empty items error
      assert {:error, "items list is empty", _} =
               PickFromTable.execute(%{}, %{"items" => []}, ctx)

      assert {:error, "items list is empty", _} =
               PickFromTable.execute(%{}, %{"items" => "invalid_json"}, ctx)

      assert {:error, "items list is empty", _} =
               PickFromTable.execute(%{}, %{"items" => 123}, ctx)

      assert :ok = PickFromTable.validate_config(%{})
      assert is_map(PickFromTable.schema())
    end
  end

  describe "Nodes.Gambling.RouletteSpin" do
    test "spins roulette returning number, color, is_even, range" do
      ctx = make_ctx()

      seen =
        Enum.reduce_while(
          1..1000,
          %{green: false, red: false, black: false, r0: false, r1_18: false, r19_36: false},
          fn _, acc ->
            {:ok, res, _} = RouletteSpin.execute(%{}, %{}, ctx)

            acc =
              acc
              |> Map.update!(:green, &(&1 or res.color == "green"))
              |> Map.update!(:red, &(&1 or res.color == "red"))
              |> Map.update!(:black, &(&1 or res.color == "black"))
              |> Map.update!(:r0, &(&1 or res.range == "0"))
              |> Map.update!(:r1_18, &(&1 or res.range == "1-18"))
              |> Map.update!(:r19_36, &(&1 or res.range == "19-36"))

            if Enum.all?(Map.values(acc), & &1), do: {:halt, acc}, else: {:cont, acc}
          end
        )

      assert seen.green
      assert seen.red
      assert seen.black
      assert seen.r0
      assert seen.r1_18
      assert seen.r19_36

      assert :ok = RouletteSpin.validate_config(%{})
      assert is_map(RouletteSpin.schema())
    end
  end

  describe "Nodes.Gambling.Shuffle" do
    test "shuffles items list or JSON string" do
      ctx = make_ctx()

      items = [1, 2, 3, 4, 5]

      assert {:ok, %{shuffled: shuffled}, _} =
               Shuffle.execute(%{}, %{"items" => items}, ctx)

      assert length(shuffled) == 5
      assert Enum.sort(shuffled) == [1, 2, 3, 4, 5]

      # JSON string
      assert {:ok, %{shuffled: s2}, _} =
               Shuffle.execute(%{}, %{"items" => Jason.encode!(items)}, ctx)

      assert length(s2) == 5

      # invalid JSON or other
      assert {:ok, %{shuffled: []}, _} =
               Shuffle.execute(%{}, %{"items" => "bad_json"}, ctx)

      assert {:ok, %{shuffled: []}, _} =
               Shuffle.execute(%{}, %{"items" => 123}, ctx)

      assert :ok = Shuffle.validate_config(%{})
      assert is_map(Shuffle.schema())
    end
  end

  describe "Nodes.Gambling.SlotMachine" do
    test "spins reels, checks paylines and returns outcome" do
      ctx = make_ctx()

      symbols = [
        %{"symbol" => "cherry", "weight" => 10},
        %{"symbol" => "lemon", "weight" => 10},
        %{"symbol" => "seven", "weight" => 1}
      ]

      paylines = [
        %{"pattern" => ["seven", "seven", "seven"], "multiplier" => 50},
        %{"pattern" => "cherry,cherry,cherry", "multiplier" => 5}
      ]

      assert {:ok, %{reels: reels, is_winner: is_winner, multiplier: mult}, _} =
               SlotMachine.execute(
                 %{"symbols" => symbols, "paylines" => paylines},
                 %{},
                 ctx
               )

      assert length(reels) == 3
      assert is_boolean(is_winner)
      assert is_number(mult)

      # Deterministic winning payline (matching_payline != nil)
      cherry_sym = [%{"symbol" => "cherry", "weight" => 10}]
      cherry_line = [%{"pattern" => ["cherry", "cherry", "cherry"], "multiplier" => 5}]

      assert {:ok, %{reels: ["cherry", "cherry", "cherry"], is_winner: true, multiplier: 5}, _} =
               SlotMachine.execute(
                 %{"symbols" => cherry_sym, "paylines" => cherry_line},
                 %{},
                 ctx
               )

      # Pattern fallback to [] when pattern is neither list nor binary
      bad_pattern_line = [%{"pattern" => 123, "multiplier" => 2}]

      assert {:ok, %{reels: ["cherry", "cherry", "cherry"], is_winner: true, multiplier: 3}, _} =
               SlotMachine.execute(
                 %{"symbols" => cherry_sym, "paylines" => bad_pattern_line},
                 %{},
                 ctx
               )

      # Non-binary symbol label fallback to "?"
      int_sym = [%{"symbol" => 123, "weight" => 10}]

      assert {:ok, %{reels: ["?", "?", "?"]}, _} =
               SlotMachine.execute(%{"symbols" => int_sym}, %{}, ctx)

      # JSON string format & parse_json fallbacks
      assert {:ok, %{reels: [_ | _]}, _} =
               SlotMachine.execute(
                 %{"symbols" => Jason.encode!(symbols), "paylines" => Jason.encode!(paylines)},
                 %{},
                 ctx
               )

      assert {:error, "symbols list is empty", _} =
               SlotMachine.execute(%{"symbols" => "123", "paylines" => 123}, %{}, ctx)

      # Empty symbols error
      assert {:error, "symbols list is empty", _} =
               SlotMachine.execute(%{"symbols" => []}, %{}, ctx)

      # validate_config
      assert :ok = SlotMachine.validate_config(%{"symbols" => symbols})
      assert {:error, _} = SlotMachine.validate_config(%{})
      assert {:error, _} = SlotMachine.validate_config(%{"symbols" => []})
      assert is_map(SlotMachine.schema())
    end
  end

  describe "Nodes.Gambling.WeightedPick" do
    test "picks item based on weights and validates config" do
      ctx = make_ctx()

      items = [
        %{"label" => "common_gem", "weight" => 100},
        %{"label" => "rare_gem", "weight" => 1}
      ]

      assert {:ok, %{result: res, index: idx}, _} =
               WeightedPick.execute(%{"items" => items}, %{}, ctx)

      assert res in ["common_gem", "rare_gem"]
      assert idx in [0, 1]

      # Item without label defaults to "item_0"
      assert {:ok, %{result: "item_0", index: 0}, _} =
               WeightedPick.execute(%{"items" => [%{"weight" => 10}]}, %{}, ctx)

      # Advance index when first item not selected
      weighted_items = [
        %{"label" => "zero_weight", "weight" => 0},
        %{"label" => "selected", "weight" => 100}
      ]

      assert {:ok, %{result: "selected", index: 1}, _} =
               WeightedPick.execute(%{"items" => weighted_items}, %{}, ctx)

      # Fallback to unknown when roll exceeds cumulative (negative weight)
      assert {:ok, %{result: "unknown"}, _} =
               WeightedPick.execute(%{"items" => [%{"weight" => -1}]}, %{}, ctx)

      # JSON string format
      assert {:ok, %{result: _}, _} =
               WeightedPick.execute(%{"items" => Jason.encode!(items)}, %{}, ctx)

      # Empty items error
      assert {:error, "items list is empty", _} =
               WeightedPick.execute(%{"items" => []}, %{}, ctx)

      assert {:error, "items list is empty", _} =
               WeightedPick.execute(%{"items" => "bad_json"}, %{}, ctx)

      assert {:error, "items list is empty", _} =
               WeightedPick.execute(%{"items" => 123}, %{}, ctx)

      # validate_config
      assert :ok = WeightedPick.validate_config(%{"items" => items})
      assert :ok = WeightedPick.validate_config(%{"items" => ~s([{"label":"gem"}])})
      assert {:error, _} = WeightedPick.validate_config(%{})
      assert {:error, _} = WeightedPick.validate_config(%{"items" => []})
      assert {:error, _} = WeightedPick.validate_config(%{"items" => "bad_json"})
      assert {:error, _} = WeightedPick.validate_config(%{"items" => 123})
      assert is_map(WeightedPick.schema())
    end
  end
end
