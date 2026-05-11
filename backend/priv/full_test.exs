alias ForgeNexus.{Repo, Accounts, Forums, Voice, Economy, Social, Communities, Platform, Notifications}
alias ForgeNexus.Voice.{LiveKit, TipCalculator, RedemptionEngine, WatchParty, RoomServer}
alias ForgeNexus.AI.{ThreadSummarizer, CommunityHealth}
alias ForgeNexus.Content.EmbedParser
alias ForgeNexus.Profiles.CssSanitizer
alias ForgeNexus.Tournaments.BracketGenerator
alias ForgeNexus.Social.{Feed, GiftTier, Icebreaker, GiftCard, Referral, UserPremium}
alias ForgeNexus.Platform.Ledger

IO.puts("\n=== ForgeNexus Full System Test ===\n")

passed = 0
failed = 0
errors = []

check = fn label, condition ->
  if condition do
    IO.puts("  ✓ #{label}")
    {passed + 1, failed, errors}
  else
    IO.puts("  ✗ FAIL: #{label}")
    {passed, failed + 1, [label | errors]}
  end
end

# ============================================================
IO.puts("\n--- 1. Communities ---")

{:ok, community} = Communities.create_community(%{
  "name" => "Test Community",
  "slug" => "test-#{:rand.uniform(99999)}",
  "subdomain" => "test#{:rand.uniform(99999)}",
  "plan" => "platform"
})
{passed, failed, errors} = check.("create community", community.id != nil)
{passed, failed, errors} = check.("community has plan", community.plan == "platform")
{passed, failed, errors} = check.("feature flags set", community.feature_flags["forums"] == true)
{passed, failed, errors} = check.("streaming enabled for platform plan", community.feature_flags["streaming"] == true)

# ============================================================
IO.puts("\n--- 2. Users ---")

user1 = Repo.all(ForgeNexus.Accounts.User) |> List.first()
{passed, failed, errors} = check.("at least one user exists", user1 != nil)

if user1 do
  {passed, failed, errors} = check.("user has username", is_binary(user1.username))
  {passed, failed, errors} = check.("user has email", is_binary(user1.email))

  {:ok, _} = Accounts.update_user_fields(user1.id, %{profile_mood: "happy", profile_mood_emoji: "😊"})
  updated = Repo.get!(ForgeNexus.Accounts.User, user1.id)
  {passed, failed, errors} = check.("update_user_fields works", updated.profile_mood == "happy")
end

# ============================================================
IO.puts("\n--- 3. Forums ---")

forums = Forums.list_forums()
{passed, failed, errors} = check.("forums exist", length(forums) > 0)

if length(forums) > 0 do
  forum = List.first(forums)
  {passed, failed, errors} = check.("forum has name", is_binary(forum.name))
end

# ============================================================
IO.puts("\n--- 4. Voice Rooms ---")

rooms = Voice.list_rooms()
{passed, failed, errors} = check.("voice rooms can be listed", is_list(rooms))

{:ok, room} = Voice.create_room(%{
  "name" => "Test Room #{:rand.uniform(9999)}",
  "type" => "lounge",
  "max_participants" => 50,
  "created_by_id" => user1 && user1.id
})
{passed, failed, errors} = check.("create voice room", room.id != nil)
{passed, failed, errors} = check.("room max_participants is 50", room.max_participants == 50)

# ============================================================
IO.puts("\n--- 5. Watch Party URL Parser ---")

urls = [
  {"https://www.youtube.com/watch?v=dQw4w9WgXcQ", :youtube},
  {"https://youtu.be/dQw4w9WgXcQ", :youtube},
  {"https://www.twitch.tv/videos/1234567890", :twitch_video},
  {"https://clips.twitch.tv/ClipName", :twitch_clip},
  {"https://www.twitch.tv/shroud", :twitch_channel},
  {"https://vimeo.com/123456789", :vimeo}
]

for {url, expected_type} <- urls do
  case WatchParty.parse_url(url) do
    {:ok, %{type: ^expected_type}} ->
      {passed, failed, errors} = check.("parse #{expected_type}: #{url}", true)
    other ->
      {passed, failed, errors} = check.("parse #{expected_type}: #{url} (got #{inspect(other)})", false)
  end
end

{passed, failed, errors} = check.("rejects invalid URL", match?({:error, _}, WatchParty.parse_url("not-a-url")))

# ============================================================
IO.puts("\n--- 6. LiveKit Token Minting ---")

{passed, failed, errors} = check.("LiveKit not configured by default", LiveKit.configured?() == false)
{passed, failed, errors} = check.("access_token returns :not_configured", match?({:error, :not_configured}, LiveKit.access_token("room", "user", :speaker)))
{passed, failed, errors} = check.("room_name prefixes with vr_", LiveKit.room_name("test") == "vr_test")

# ============================================================
IO.puts("\n--- 7. Economy ---")

if user1 do
  balance = Economy.get_points(user1.id)
  {passed, failed, errors} = check.("get_points returns integer", is_integer(balance))
end

# ============================================================
IO.puts("\n--- 8. TipCalculator ---")

calc = TipCalculator.calculate(1000, "basic", "starter")
{passed, failed, errors} = check.("basic tier takes 25%", calc.creator_amount_cents == 750)
{passed, failed, errors} = check.("platform gross is 250", calc.platform_gross_cents == 250)
{passed, failed, errors} = check.("stripe fee calculated", calc.stripe_fee_cents > 0)
{passed, failed, errors} = check.("community kickback 15%", calc.community_kickback_cents == round(250 * 0.15))
{passed, failed, errors} = check.("platform net positive", calc.platform_net_cents > 0)

calc_top = TipCalculator.calculate(10000, "top", "enterprise")
{passed, failed, errors} = check.("top tier takes 13%", calc_top.creator_amount_cents == 8700)
{passed, failed, errors} = check.("enterprise kickback 25%", calc_top.community_kickback_cents == round(1300 * 0.25))

preview = TipCalculator.preview(500)
{passed, failed, errors} = check.("preview returns formatted strings", is_binary(preview.you_pay))

# ============================================================
IO.puts("\n--- 9. Redeemable Types ---")

types = ForgeNexus.Voice.Redeemable.types()
{passed, failed, errors} = check.("32 redemption types registered", length(types) == 32)
{passed, failed, errors} = check.("includes tts_message", "tts_message" in types)
{passed, failed, errors} = check.("includes lucky_wheel", "lucky_wheel" in types)
{passed, failed, errors} = check.("includes raid", "raid" in types)
{passed, failed, errors} = check.("includes combo_multiplier", "combo_multiplier" in types)

# ============================================================
IO.puts("\n--- 10. CSS Sanitizer ---")

{:ok, clean} = CssSanitizer.sanitize("h1 { color: red; }")
{passed, failed, errors} = check.("basic CSS passes", String.contains?(clean, "color: red"))
{passed, failed, errors} = check.("CSS scoped to .profile-custom", String.contains?(clean, ".profile-custom"))

{:error, _} = CssSanitizer.sanitize("div { background: expression(alert(1)); }")
{passed, failed, errors} = check.("blocks javascript expressions", true)

{:ok, stripped} = CssSanitizer.sanitize("div { position: fixed; color: blue; }")
{passed, failed, errors} = check.("strips position: fixed", not String.contains?(stripped, "position"))

# ============================================================
IO.puts("\n--- 11. Embed Parser ---")

parsed = EmbedParser.parse("Check this out [clip:abc-123] and [poll:def-456]!")
{passed, failed, errors} = check.("parses clip embed", String.contains?(parsed, "data-embed-type=\"clip\""))
{passed, failed, errors} = check.("parses poll embed", String.contains?(parsed, "data-embed-type=\"poll\""))

embeds = EmbedParser.extract_embeds("Look at [thread:xyz] and [user:abc]")
{passed, failed, errors} = check.("extracts 2 embeds", length(embeds) == 2)

# ============================================================
IO.puts("\n--- 12. Tournament Brackets ---")

{:ok, bracket} = BracketGenerator.generate(["p1", "p2", "p3", "p4"], "single_elimination")
{passed, failed, errors} = check.("single elim generates bracket", bracket.format == "single_elimination")
{passed, failed, errors} = check.("4 players = 2 rounds", bracket.rounds == 2)
{passed, failed, errors} = check.("bracket has matches", length(bracket.matches) > 0)

{:ok, rr} = BracketGenerator.generate(["a", "b", "c", "d"], "round_robin")
{passed, failed, errors} = check.("round robin generates", rr.format == "round_robin")
{passed, failed, errors} = check.("round robin has matches", length(rr.matches) > 0)

{:ok, swiss} = BracketGenerator.generate(["x", "y", "z", "w"], "swiss")
{passed, failed, errors} = check.("swiss generates", swiss.format == "swiss")

# ============================================================
IO.puts("\n--- 13. Social Features ---")

poke_types = ForgeNexus.Social.Poke.types()
{passed, failed, errors} = check.("7 poke types", length(poke_types) == 7)
{passed, failed, errors} = check.("includes wink", "wink" in poke_types)

gift_tiers = GiftTier.tiers()
{passed, failed, errors} = check.("5 gift tiers", length(gift_tiers) == 5)
{passed, failed, errors} = check.("includes legendary", "legendary" in gift_tiers)

defaults = GiftTier.default_gifts()
{passed, failed, errors} = check.("8 default gifts", length(defaults) == 8)

icebreaker_types = Icebreaker.types()
{passed, failed, errors} = check.("5 icebreaker types", length(icebreaker_types) == 5)

questions = Icebreaker.random_questions()
{passed, failed, errors} = check.("has would_you_rather questions", length(questions["would_you_rather"]) > 0)

premium_plans = UserPremium.plans()
{passed, failed, errors} = check.("3 premium plans", length(premium_plans) == 3)

premium_features = UserPremium.features_for_plan("pro")
{passed, failed, errors} = check.("pro plan has priority_support", premium_features["priority_support"] == true)

{passed, failed, errors} = check.("gift card code generation", String.starts_with?(GiftCard.generate_code(), "FNX-"))

# ============================================================
IO.puts("\n--- 14. Community Health Score ---")

health = CommunityHealth.calculate(community.id)
{passed, failed, errors} = check.("health score calculated", is_float(health.score))
{passed, failed, errors} = check.("health score 0-100", health.score >= 0 and health.score <= 100)
{passed, failed, errors} = check.("health has trend", health.trend in ["new", "up", "down", "stable"])
{passed, failed, errors} = check.("health has components", is_map(health.components))

# ============================================================
IO.puts("\n--- 15. Platform Ledger ---")

{:ok, entry} = Ledger.record_revenue(%{
  community_id: community.id,
  type: "community_fee",
  source: "test",
  amount_cents: 2900,
  description: "Test community fee"
})
{passed, failed, errors} = check.("ledger entry created", entry.id != nil)
{passed, failed, errors} = check.("infra allocation > 0", entry.infra_allocation_cents > 0)
{passed, failed, errors} = check.("profit allocation > 0", entry.profit_allocation_cents > 0)
{passed, failed, errors} = check.("infra + profit = total", entry.infra_allocation_cents + entry.profit_allocation_cents == 2900)

dashboard = Ledger.dashboard()
{passed, failed, errors} = check.("dashboard has infra balance", is_integer(dashboard.infra_fund_balance_cents))
{passed, failed, errors} = check.("dashboard has runway", is_float(dashboard.runway_months))

# ============================================================
IO.puts("\n--- 16. Social Feed ---")

if user1 do
  {:ok, post} = Social.create_status_post(%{
    community_id: community.id,
    user_id: user1.id,
    body: "Testing the social feed! #ForgeNexus",
    media_type: "text"
  })
  {passed, failed, errors} = check.("create status post", post.id != nil)

  feed = Feed.get_feed(community.id, limit: 10)
  {passed, failed, errors} = check.("feed returns items", is_list(feed))
end

# ============================================================
IO.puts("\n--- 17. Watch Along ---")

{:ok, wa} = Repo.insert(%ForgeNexus.Social.WatchAlong{
  community_id: community.id,
  created_by_id: user1 && user1.id,
  title: "WrestleMania Watch Party",
  show_type: "wrestling",
  starts_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
  segments: ForgeNexus.Social.WatchAlong.example_wrestling_segments()
})
{passed, failed, errors} = check.("create watch along", wa.id != nil)
{passed, failed, errors} = check.("watch along has segments", length(wa.segments) == 4)
{passed, failed, errors} = check.("show_type is wrestling", wa.show_type == "wrestling")

# ============================================================
IO.puts("\n--- 18. API Keys ---")

if user1 do
  {:ok, key, raw_key} = Platform.create_api_key(user1.id, community.id, "Test Key", "free")
  {passed, failed, errors} = check.("API key created", key.id != nil)
  {passed, failed, errors} = check.("raw key starts with fnx_", String.starts_with?(raw_key, "fnx_"))
  {passed, failed, errors} = check.("key has prefix", is_binary(key.key_prefix))
  {passed, failed, errors} = check.("key scopes set", key.scopes == ["read"])
  {passed, failed, errors} = check.("rate limit set", key.rate_limit_per_minute == 100)

  keys = Platform.list_api_keys(user1.id)
  {passed, failed, errors} = check.("list API keys", length(keys) > 0)
end

# ============================================================
IO.puts("\n--- 19. Community Plans ---")

plans = ForgeNexus.Communities.Community.plans()
{passed, failed, errors} = check.("6 community plans", length(plans) == 6)
{passed, failed, errors} = check.("includes enterprise", "enterprise" in plans)

plan_features = ForgeNexus.Communities.Community.plan_features()
{passed, failed, errors} = check.("free plan has forums only", plan_features["free"]["forums"] == true)
{passed, failed, errors} = check.("free plan no streaming", plan_features["free"]["streaming"] != true)
{passed, failed, errors} = check.("creator plan has streaming", plan_features["creator"]["streaming"] == true)
{passed, failed, errors} = check.("enterprise has white_label", plan_features["enterprise"]["white_label"] == true)

# ============================================================
IO.puts("\n--- 20. Profile Widgets ---")

widget_types = ForgeNexus.Profiles.ProfileWidget.widget_types()
{passed, failed, errors} = check.("15 widget types", length(widget_types) == 15)
{passed, failed, errors} = check.("includes trophy_case", "trophy_case" in widget_types)
{passed, failed, errors} = check.("includes mood_board", "mood_board" in widget_types)

defaults = ForgeNexus.Profiles.ProfileWidget.default_widgets()
{passed, failed, errors} = check.("6 default widgets", length(defaults) == 6)

# ============================================================
# Cleanup
Repo.delete(community)

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("Results: #{passed} passed, #{failed} failed")

if failed > 0 do
  IO.puts("\nFailed tests:")
  Enum.each(Enum.reverse(errors), fn e -> IO.puts("  ✗ #{e}") end)
  IO.puts("")
  System.halt(1)
else
  IO.puts("\n=== ALL TESTS PASSED ===\n")
end
