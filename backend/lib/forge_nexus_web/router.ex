defmodule ForgeNexusWeb.Router do
  use ForgeNexusWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug ForgeNexusWeb.Plugs.RateLimit, max: 120, window: 60_000, by: :ip, scope: "api"
    plug ForgeNexusWeb.Plugs.ClampPagination
    plug ForgeNexusWeb.Plugs.AuthPipeline
  end

  pipeline :auth_limited do
    plug ForgeNexusWeb.Plugs.RateLimit, max: 10, window: 60_000, by: :ip, scope: "auth"
  end

  pipeline :authenticated do
    plug ForgeNexusWeb.Plugs.EnsureAuthenticated
    plug ForgeNexusWeb.Plugs.CheckBan
    plug ForgeNexusWeb.Plugs.MaintenanceMode
  end

  pipeline :staff do
    plug ForgeNexusWeb.Plugs.EnsureStaff
  end

  pipeline :admin do
    plug ForgeNexusWeb.Plugs.EnsureAdmin
  end

  pipeline :verified_email do
    plug ForgeNexusWeb.Plugs.RequireVerifiedEmail
  end

  # Public API routes
  scope "/api", ForgeNexusWeb do
    pipe_through :api

    # Health check (no auth, no setup check)
    get "/health", HealthController, :index

    # Stripe webhook receiver — public, signature-verified, no auth.
    # Must accept any IP since Stripe rotates source IPs.
    post "/webhooks/stripe", StripeWebhookController, :receive

    # Public billing catalog
    get "/billing/plans", BillingController, :plans

    # Setup (first-run installer)
    get "/setup/status", SetupController, :status
    get "/setup/preflight", SetupController, :preflight
    post "/setup/upload-logo", SetupController, :upload_logo
    post "/setup/install", SetupController, :install

    # Auth (rate-limited: 10 req/min per IP)
    scope "/auth" do
      pipe_through :auth_limited

      post "/register", AuthController, :register
      post "/login", AuthController, :login
      post "/forgot-password", AuthController, :forgot_password
      post "/reset-password", AuthController, :reset_password
      post "/2fa/verify", AuthController, :verify_2fa_login
    end

    # Marketing-funnel signup (rate-limited).
    # /signup/tier provisions user + community tenant + (when Stripe is wired
    # for the plan) a Checkout session in one round-trip.
    scope "/signup" do
      pipe_through :auth_limited

      post "/tier", SignupController, :tier
      post "/houses", HousesController, :signup
    end

    # Auth (normal rate limit)
    get "/auth/me", AuthController, :me
    post "/auth/verify-email", AuthController, :verify_email
    post "/auth/resend-verification", AuthController, :resend_verification
    post "/auth/request-email-change", AuthController, :request_email_change
    post "/auth/confirm-email-change", AuthController, :confirm_email_change
    post "/auth/refresh", AuthController, :refresh
    post "/auth/logout", AuthController, :logout

    # OAuth
    get "/auth/oauth/:provider", OAuthController, :redirect_to_provider
    get "/auth/oauth/:provider/callback", OAuthController, :callback

    # Public settings
    get "/settings/public", SettingsController, :public

    # Shoutbox (public read)
    get "/shoutbox", ChatController, :shoutbox

    # Chat channels (public browsing — live messaging uses Phoenix channels)
    get "/channels", ChannelController, :index
    get "/channels/:slug", ChannelController, :show
    get "/channels/:slug/messages", ChannelController, :messages
    get "/channels/:slug/pins", ChannelController, :pins

    # Forums (public read)
    get "/forums", ForumController, :index
    get "/forums/:slug", ForumController, :show
    get "/forums/:slug/threads", ForumController, :threads
    get "/threads/trending", ThreadController, :trending
    get "/threads/similar", FeaturesController, :similar_threads
    get "/threads/:slug", ThreadController, :show

    # Profiles (public read)
    get "/profiles/:slug", ProfileController, :show
    get "/profiles/:slug/guestbook", ProfileController, :guestbook

    # Forge Codes — shareable profile themes (public browsing)
    get "/forge-codes/vocabulary", ForgeCodeController, :vocabulary
    get "/forge-codes/gallery", ForgeCodeController, :gallery
    get "/forge-codes/:code", ForgeCodeController, :show

    # Reputation breakdown
    get "/profiles/:slug/reputation", ProfileController, :reputation
    get "/profiles/:slug/activity-heatmap", ActivityHeatmapController, :show

    # Themes (public read)
    get "/themes", ThemeController, :index
    get "/themes/:id", ThemeController, :show

    # Avatar frames (public read)
    get "/avatar-frames", ProfileController, :avatar_frames

    # Badges (public list)
    get "/badges", BadgeController, :index
    get "/badges/user/:user_id", BadgeController, :user_badges

    # Achievements (public)
    get "/achievements", AchievementController, :all_achievements
    get "/users/:user_id/achievements", AchievementController, :user_achievements

    # Custom emojis (public list)
    get "/emojis", EmojiController, :index

    # Events (public)
    get "/events", EventController, :index
    get "/events/upcoming", EventController, :upcoming
    get "/events/:id", EventController, :show

    # Gallery (public)
    get "/gallery/user/:user_id", GalleryController, :user_albums
    get "/gallery/albums/:id", GalleryController, :show
    get "/gallery/recent", GalleryController, :recent

    # Staff Applications (public)
    get "/applications/forms", ApplicationController, :open_forms
    get "/applications/forms/:id", ApplicationController, :show_form

    # Points leaderboard (public)
    get "/points/leaderboard", EconomyController, :leaderboard

    # Plugin pages (public)
    get "/pages/:slug", PluginPageController, :show
    get "/widgets/:placement", PluginPageController, :widgets

    # Featured threads (public)
    get "/featured-threads", StatsController, :featured_threads

    # Slash commands (public listing for autocomplete)
    get "/commands", SlashCommandController, :list

    # Search
    get "/search", SearchController, :search

    # Webhooks (public execution)
    post "/webhooks/:token", WebhookController, :execute

    # Discovery / explore
    get "/discover", FeedController, :discover
    get "/discover/suggested-members", FeedController, :suggested_members

    # Social feed (public, community-scoped)
    get "/feed", FeedController, :index
    get "/feed/:id/comments", FeedController, :comments

    # Voice rooms (public listing for any user)
    get "/voice/ice-config", VoiceRoomController, :ice_config
    get "/voice/rooms", VoiceRoomController, :index
    get "/voice/rooms/upcoming", VoiceRoomController, :upcoming
    get "/voice/rooms/:slug", VoiceRoomController, :show
    get "/voice/rooms/:slug/recordings", VoiceRoomController, :list_recordings
    get "/voice/recordings/:recording_id", VoiceRoomController, :show_recording
    get "/voice/recordings/:recording_id/clips", VoiceRoomController, :list_clips
    get "/voice/clips/recent", VoiceRoomController, :recent_clips
    get "/voice/clips/:clip_id", VoiceRoomController, :show_clip
    get "/voice/rooms/:id/soundboard", VoiceRoomController, :list_soundboard

    # Marketplace (public)
    get "/marketplace/templates", MarketplaceController, :list_templates
    get "/marketplace/templates/:id", MarketplaceController, :show_template
    get "/marketplace/plugins", MarketplaceController, :list_plugins
    get "/marketplace/plugins/:id", MarketplaceController, :show_plugin

    # Subscriptions (public tier listing)
    get "/subscriptions/tiers", SubscriptionController, :tiers

    # Economy (auth)
    get "/economy/balance", EconomyController, :balance
    get "/economy/history", EconomyController, :history

    # Notifications
    get "/notifications", NotificationController, :index
    get "/notifications/count", NotificationController, :count

    # Preferences (stub)
    get "/preferences", PreferencesController, :index
    put "/preferences", PreferencesController, :update

    # Chat friends (stub)
    get "/chat/friends", ChatController, :friends_public

    # Members (public)
    get "/members", MemberController, :index
    get "/members/search", MemberController, :search_users

    # Recent posts (public)
    get "/recent-posts", MemberController, :recent_posts

    # Sitemap
    get "/sitemap.xml", SitemapController, :index

    # RSS Feeds
    get "/rss/threads", RssController, :threads
    get "/rss/posts", RssController, :posts

    # Contact form (public)
    post "/contact", ContactController, :create

    # Online users (public)
    get "/users/online", StatsController, :online

    # Welcome center stats (public)
    get "/stats/welcome", StatsController, :welcome

    # Forum statistics (public)
    get "/stats", StatsController, :index
    get "/stats/cached", StatsController, :cached

    # Active announcements (public)
    get "/announcements/active", AdminAnnouncementController, :active

    # Thread Types (public read)
    get "/thread-types", ThreadTypeController, :index
    get "/thread-types/:slug", ThreadTypeController, :show
    get "/threads/:thread_id/answers", ThreadTypeController, :list_answers
    get "/threads/:thread_id/debate-positions", ThreadTypeController, :debate_positions
    get "/threads/:thread_id/ama", ThreadTypeController, :ama_session
    get "/threads/:thread_id/marketplace", ThreadTypeController, :marketplace_listing
    get "/threads/:thread_id/wiki-edits", ThreadTypeController, :wiki_edits

    # AI (public read)
    get "/threads/:thread_id/summary", AIController, :thread_summary
    get "/threads/:thread_id/tag-suggestions", AIController, :tag_suggestions
    get "/posts/:id/translate", AIController, :translate

    # Wiki (public read)
    get "/wiki/categories", WikiController, :categories
    get "/wiki/pages", WikiController, :index
    get "/wiki/pages/:slug", WikiController, :show
    get "/wiki/pages/:slug/revisions", WikiController, :revisions
    get "/wiki/search", WikiController, :search

    # Governance (public read)
    get "/governance/proposals", GovernanceController, :index
    get "/governance/proposals/:id", GovernanceController, :show
    get "/governance/proposals/:id/comments", GovernanceController, :comments
    get "/governance/elections/:id", GovernanceController, :show_election

    # Community Analytics (public)
    get "/stats/community", CommunityStatsController, :index
    get "/stats/community/contributors", CommunityStatsController, :contributors
    get "/stats/community/topics", CommunityStatsController, :popular_topics

    # Spaces (public read)
    get "/spaces", SpaceController, :index
    get "/spaces/:slug", SpaceController, :show
    get "/spaces/rooms/:id/users", SpaceController, :room_users

    # ActivityPub / Federation (public)
    get "/ap/actors/:id", FederationController, :actor
    post "/ap/actors/:id/inbox", FederationController, :inbox
    get "/ap/actors/:id/outbox", FederationController, :outbox
  end

  # WebFinger (must be outside /api scope)
  scope "/", ForgeNexusWeb do
    pipe_through :api
    get "/.well-known/webfinger", FederationController, :webfinger
  end

  # Content creation routes (require verified email)
  scope "/api", ForgeNexusWeb do
    pipe_through [:api, :authenticated, :verified_email]

    post "/threads", ThreadController, :create
    post "/threads/:slug/reply", ThreadController, :reply

    # Post edit + history (action lived in ThreadController unrouted)
    put "/posts/:id", ThreadController, :edit_post
    get "/posts/:id/history", ThreadController, :post_history
    post "/reputation", ProfileController, :give_reputation
    post "/reports", ReportController, :create

    # Community SaaS billing (owner-gated in controller)
    post "/billing/communities/:community_id/checkout", BillingController, :create_checkout
    get "/billing/communities/:community_id/subscription", BillingController, :show

    # Notifications — write ops
    put "/notifications/read-all", NotificationController, :mark_all_read
    put "/notifications/:id/read", NotificationController, :mark_read
    delete "/notifications/:id", NotificationController, :delete

    # Slash commands (execution requires auth)
    post "/commands/execute", SlashCommandController, :execute

    # Voice recordings — host/speaker uploads the captured audio
    post "/voice/rooms/:id/recordings", VoiceRoomController, :upload_recording

    # Social features (auth)
    post "/poke", FeedController, :send_poke
    get "/pokes", FeedController, :list_pokes
    post "/pokes/read", FeedController, :mark_pokes_read
    put "/presence", FeedController, :update_presence
    get "/premium", FeedController, :premium_status

    # Social feed (auth)
    post "/feed/status", FeedController, :create_status
    post "/feed/:id/like", FeedController, :like
    post "/feed/:id/comment", FeedController, :comment

    # API keys
    get "/api-keys", ApiKeyController, :index
    post "/api-keys", ApiKeyController, :create
    delete "/api-keys/:id", ApiKeyController, :revoke
    get "/api-keys/:id/usage", ApiKeyController, :usage

    # Creator dashboard
    get "/creator/dashboard", CreatorDashboardController, :show

    # AI features
    get "/thread-summary/:id", ThreadController, :ai_summary
    get "/community/health", FeedController, :community_health

    # Profile self-update (user editing their own profile)
    put "/profile", ProfileController, :update
    put "/profile/top-friends", ProfileController, :top_friends

    # Message bookmarks
    get "/bookmarks", BookmarkController, :index
    get "/bookmarks/ids", BookmarkController, :bookmark_ids
    post "/bookmarks", BookmarkController, :toggle

    # Post bookmarks (forum thread posts)
    get "/post-bookmarks", FeaturesController, :list_post_bookmarks
    get "/post-bookmarks/ids", FeaturesController, :post_bookmark_ids
    post "/posts/:post_id/bookmark", FeaturesController, :toggle_post_bookmark

    # BBCode preview (composer)
    post "/bbcode/render", FeaturesController, :render_bbcode

    # Post ratings (likes)
    post "/posts/:post_id/rate", FeaturesController, :rate_post
    get "/posts/:post_id/ratings", FeaturesController, :post_ratings

    # Post reactions (emoji)
    post "/posts/:post_id/react", FeaturesController, :react_to_post
    get "/posts/:post_id/reactions", FeaturesController, :get_post_reactions

    # Thread Q&A (best-answer marking)
    post "/threads/:thread_id/mark-solved", FeaturesController, :mark_solved
    delete "/threads/:thread_id/mark-solved", FeaturesController, :unmark_solved

    # Thread prefixes
    get "/forums/:forum_id/prefixes", FeaturesController, :list_prefixes
    post "/threads/:thread_id/prefix", FeaturesController, :set_thread_prefix

    # User blocks
    post "/users/:user_id/block", FeaturesController, :block_user
    delete "/users/:user_id/block", FeaturesController, :unblock_user
    get "/blocked-users", FeaturesController, :list_blocked

    # Draft autosave (post + thread compose)
    post "/drafts", FeaturesController, :save_draft
    get "/drafts/:context_type/:context_id", FeaturesController, :get_draft
    delete "/drafts/:context_type/:context_id", FeaturesController, :delete_draft

    # /threads/similar is mounted earlier in the public scope so it isn't
    # eaten by the /threads/:slug pattern.

    # Content ignores (forum + thread)
    get "/ignores", ContentIgnoreController, :index
    post "/ignores/forum/:forum_id", ContentIgnoreController, :ignore_forum
    delete "/ignores/forum/:forum_id", ContentIgnoreController, :unignore_forum
    post "/ignores/thread/:thread_id", ContentIgnoreController, :ignore_thread
    delete "/ignores/thread/:thread_id", ContentIgnoreController, :unignore_thread

    # Thread subscription / watching
    get "/threads/:slug/subscription", ThreadSubscriptionController, :show
    put "/threads/:slug/subscription", ThreadSubscriptionController, :update
    delete "/threads/:slug/subscription", ThreadSubscriptionController, :delete

    # Thread read tracking
    post "/threads/:slug/read", ThreadReadController, :mark_read
    post "/forums/:slug/read", ThreadReadController, :mark_forum_read
    get "/unread-counts", ThreadReadController, :unread_counts

    # Thread ratings (1-5 stars)
    post "/threads/:thread_id/rate", ThreadRatingController, :rate
    get "/threads/:thread_id/rating", ThreadRatingController, :show

    # Thread participants
    get "/threads/:slug/participants", ThreadParticipantController, :index
    post "/threads/:slug/participants", ThreadParticipantController, :add
    delete "/threads/:slug/participants/:user_id", ThreadParticipantController, :remove

    # Thread activity
    get "/threads/:slug/activity", ActivityController, :show

    # Polls
    get "/threads/:thread_id/poll", PollController, :show
    post "/threads/:thread_id/poll", PollController, :create
    post "/polls/:poll_id/vote", PollController, :vote
    post "/polls/:poll_id/close", PollController, :close

    # Link preview (Open Graph)
    get "/link-preview", LinkPreviewController, :show

    # User preferences
    get "/user/preferences", UserPreferenceController, :show
    put "/user/preferences", UserPreferenceController, :update

    # Status updates (presence message)
    put "/user/status", StatusController, :update

    # 1:1 / group calls
    post "/calls", CallController, :initiate
    post "/calls/:id/answer", CallController, :answer
    post "/calls/:id/decline", CallController, :decline
    post "/calls/:id/hang-up", CallController, :hang_up
    get "/conversations/:conversation_id/calls/active", CallController, :active
    get "/conversations/:conversation_id/calls/history", CallController, :history

    # Channel-message threading (Discord-style threads-on-message)
    post "/channels/:channel_slug/messages/:message_id/threads", ThreadChatController, :create
    get "/channels/:channel_slug/threads", ThreadChatController, :index
    get "/chat-threads/:id", ThreadChatController, :show
    get "/chat-threads/:id/messages", ThreadChatController, :messages
    post "/chat-threads/:id/messages", ThreadChatController, :create_message

    # Profile widgets
    get "/profile/widgets", ProfileController, :list_widgets
    post "/profile/widgets", ProfileController, :create_widget
    put "/profile/widgets/:id", ProfileController, :update_widget
    delete "/profile/widgets/:id", ProfileController, :delete_widget
    put "/profile/blurbs", ProfileController, :update_blurbs
    put "/profile/mood", ProfileController, :update_mood
    put "/profile/layout", ProfileController, :update_layout
    put "/profile/css", ProfileController, :update_css

    # Chat channels — authenticated write ops
    post "/channels/:slug/messages", ChannelController, :create_message
    put "/channels/:slug/messages/:message_id", ChannelController, :update_message
    delete "/channels/:slug/messages/:message_id", ChannelController, :delete_message
    post "/channels/:slug/read", ChannelController, :mark_read
    post "/channels/messages/:message_id/reactions", ChannelController, :add_reaction
    delete "/channels/messages/:message_id/reactions/:emoji", ChannelController, :remove_reaction

    # Shoutbox write (fallback; primary path is Phoenix channel)
    post "/shoutbox", ChatController, :send_shoutbox

    # Chat / Direct Messages
    get "/chat/conversations", ChatController, :conversations
    post "/chat/conversations/direct", ChatController, :create_direct
    post "/chat/conversations/group", ChatController, :create_group
    get "/chat/conversations/:id/messages", ChatController, :messages
    post "/chat/conversations/:id/messages", ChatController, :create_message
    put "/chat/conversations/:conversation_id/messages/:id", ChatController, :update_message
    delete "/chat/conversations/:conversation_id/messages/:id", ChatController, :delete_message

    # Follow
    post "/users/:id/follow", FollowController, :toggle
    get "/users/:id/followers", FollowController, :followers
    get "/users/:id/following", FollowController, :following
    get "/following/feed", FollowController, :feed

    # Appeals (users submit their own; staff list/review is under /api/mod)
    post "/appeals", AppealController, :create
    get "/appeals/mine", AppealController, :my_appeals
    get "/my/infractions", AppealController, :my_infractions

    # Friends
    get "/friends/status/:user_id", ChatController, :friendship_status
    get "/friends/requests", ChatController, :friend_requests
    post "/friends/request", ChatController, :send_friend_request
    put "/friends/:id/accept", ChatController, :accept_friend
    put "/friends/:id/decline", ChatController, :decline_friend
    delete "/friends/:id", ChatController, :cancel_or_remove_friend

    # Forge Codes — authenticated ops
    get "/forge-codes-mine", ForgeCodeController, :mine
    post "/forge-codes", ForgeCodeController, :create
    post "/forge-codes/:code/apply", ForgeCodeController, :apply
    put "/forge-codes/:code", ForgeCodeController, :update
    delete "/forge-codes/:code", ForgeCodeController, :delete

    # Profile endorsements (emoji reactions)
    post "/profiles/:slug/endorse", ProfileEndorsementController, :create
    delete "/profiles/:slug/endorse", ProfileEndorsementController, :delete

    # Profile extras
    post "/profiles/:slug/ai-summary", ProfileController, :ai_summary
    put "/profile/pin-thread", ProfileController, :pin_thread
    delete "/profile/pin-thread", ProfileController, :unpin_thread
    get "/profile/analytics", ProfileController, :analytics

    # Uploads (profile backgrounds, music, etc.)
    post "/uploads", UploadController, :create
    delete "/uploads/:id", UploadController, :delete

    # Tip / send points to another user
    post "/economy/tip", EconomyController, :tip

    # Cross-community syndication
    post "/syndicate", FeedController, :syndicate_thread

    # Voice clips
    post "/voice/clips", VoiceRoomController, :create_clip

    # Voice translation
    post "/voice/translate", VoiceRoomController, :translate

    # Soundboard
    post "/voice/rooms/:id/soundboard", VoiceRoomController, :upload_soundboard_clip

    # LiveKit access token (mints a short-lived JWT for the current user to join the SFU room)
    post "/voice/rooms/:id/token", VoiceRoomController, :livekit_token
  end

  # Staff-only moderation routes
  scope "/api/mod", ForgeNexusWeb do
    pipe_through [:api, :authenticated, :staff]

    get "/reports", ModerationController, :list_reports
    get "/reports/:id", ModerationController, :show_report
    get "/reports/:id/context", ModerationController, :show_report_with_context
    put "/reports/:id/assign", ModerationController, :assign_report
    put "/reports/:id/resolve", ModerationController, :resolve_report
    put "/reports/:id/dismiss", ModerationController, :dismiss_report

    get "/bans", ModerationController, :list_bans
    post "/bans", ModerationController, :create_ban
    put "/bans/:id/revoke", ModerationController, :revoke_ban

    get "/warnings", ModerationController, :list_warnings
    post "/warnings", ModerationController, :create_warning
    put "/warnings/:id/revoke", ModerationController, :revoke_warning
    get "/users/:user_id/infractions", ModerationController, :user_infractions

    get "/users/:user_id/notes", ModerationController, :list_notes
    post "/users/:user_id/notes", ModerationController, :create_note
    delete "/notes/:id", ModerationController, :delete_note

    get "/logs", ModerationController, :list_logs

    get "/appeals", ModerationController, :list_appeals
    get "/appeals/:id", ModerationController, :show_appeal
    put "/appeals/:id/review", ModerationController, :review_appeal

    # Soft-block moderation
    post "/soft-block", ModerationController, :soft_block
    put "/soft-block/:id/edit", ModerationController, :soft_block_edit
    get "/soft-blocks", ModerationController, :list_soft_blocks

    get "/dashboard/workload", ModerationController, :workload
    get "/dashboard/queue", ModerationController, :queue_stats
    get "/dashboard/suggest-assignment", ModerationController, :suggest_assignment

    post "/threads/bulk", ModerationController, :bulk_thread_action

    put "/threads/:id/lock", ModerationController, :lock_thread
    put "/threads/:id/unlock", ModerationController, :unlock_thread
    put "/threads/:id/pin", ModerationController, :pin_thread
    put "/threads/:id/unpin", ModerationController, :unpin_thread
    put "/threads/:id/hide", ModerationController, :hide_thread
    put "/threads/:id/unhide", ModerationController, :unhide_thread
    put "/threads/:id/move", ModerationController, :move_thread
    put "/threads/:id/merge", ModerationController, :merge_threads

    put "/posts/:id/hide", ModerationController, :hide_post
    put "/posts/:id/unhide", ModerationController, :unhide_post

    get "/suspicious-accounts", ModerationController, :list_suspicious_accounts
    post "/suspicious-accounts/scan/:user_id", ModerationController, :scan_suspicious
    put "/suspicious-accounts/:id/review", ModerationController, :review_suspicious

    post "/posts/check-merge", ModerationController, :check_double_post

    get "/policies", ModerationController, :list_policies
    get "/policies/:id", ModerationController, :show_policy
    post "/policies", ModerationController, :create_policy
    put "/policies/:id", ModerationController, :update_policy
    delete "/policies/:id", ModerationController, :delete_policy
  end

  # Admin-only routes
  scope "/api/admin", ForgeNexusWeb do
    pipe_through [:api, :authenticated, :admin]

    get "/settings", AdminSettingsController, :index
    put "/settings", AdminSettingsController, :update

    # Slash commands (admin management)
    get "/commands", SlashCommandController, :admin_list
    post "/commands", SlashCommandController, :admin_create
    put "/commands/:id", SlashCommandController, :admin_update
    delete "/commands/:id", SlashCommandController, :admin_delete

    # No-code flows (Tier 1)
    get "/plugins/flows", PluginController, :list_flows
    post "/plugins/flows", PluginController, :create_flow
    get "/plugins/flows/:id", PluginController, :show_flow
    put "/plugins/flows/:id", PluginController, :update_flow
    delete "/plugins/flows/:id", PluginController, :delete_flow
    put "/plugins/flows/:id/activate", PluginController, :activate_flow
    put "/plugins/flows/:id/deactivate", PluginController, :deactivate_flow
    post "/plugins/flows/:id/execute", PluginController, :execute_flow
    get "/plugins/executions", PluginController, :list_executions
    get "/plugins/executions/:id", PluginController, :show_execution
    get "/plugins/node-types", PluginController, :node_types
    post "/plugins/flows/generate", PluginController, :generate_flow

    # JS/Deno plugins (Tier 2)
    get "/plugins/js", JsPluginController, :list_plugins
    post "/plugins/js", JsPluginController, :create_plugin
    get "/plugins/js/:id", JsPluginController, :show_plugin
    put "/plugins/js/:id", JsPluginController, :update_plugin
    delete "/plugins/js/:id", JsPluginController, :delete_plugin
    put "/plugins/js/:id/activate", JsPluginController, :activate_plugin
    put "/plugins/js/:id/deactivate", JsPluginController, :deactivate_plugin
    post "/plugins/js/:id/execute", JsPluginController, :execute_plugin
    get "/plugins/js/:id/executions", JsPluginController, :list_executions

    # Custom BBCode Tags (admin CRUD)
    get "/bbcodes", AdminBBCodeController, :index
    post "/bbcodes", AdminBBCodeController, :create
    put "/bbcodes/:id", AdminBBCodeController, :update
    delete "/bbcodes/:id", AdminBBCodeController, :delete

    # Channel webhooks (Discord-style chat webhooks)
    get "/webhooks", WebhookController, :index
    post "/webhooks", WebhookController, :create
    put "/webhooks/:id", WebhookController, :update
    delete "/webhooks/:id", WebhookController, :delete
    post "/webhooks/:id/regenerate", WebhookController, :regenerate

    # Forum event webhooks (outbound notifications on forum events)
    get "/forum-webhooks", ForumWebhookController, :index
    post "/forum-webhooks", ForumWebhookController, :create
    put "/forum-webhooks/:id", ForumWebhookController, :update
    delete "/forum-webhooks/:id", ForumWebhookController, :delete
    post "/forum-webhooks/:id/test", ForumWebhookController, :test
    get "/forum-webhooks/event-types", ForumWebhookController, :event_types
    get "/forum-webhooks/:id/deliveries", ForumWebhookController, :deliveries

    # Login events (security timeline)
    get "/login-events", AdminLoginEventController, :index

    # Impersonation (admin audit + live session control). /impersonate/active is already registered elsewhere in this file.
    get "/impersonate/logs", ModerationController, :impersonation_logs
    post "/impersonate/start", ModerationController, :start_impersonation
    post "/impersonate/end", ModerationController, :end_impersonation

    # Voice rooms (admin CRUD)
    post "/voice/rooms", VoiceRoomController, :create
    put "/voice/rooms/:id", VoiceRoomController, :update
    delete "/voice/rooms/:id", VoiceRoomController, :delete
    delete "/voice/recordings/:recording_id", VoiceRoomController, :delete_recording
    delete "/voice/soundboard/:clip_id", VoiceRoomController, :delete_soundboard_clip

    # Community management
    get "/communities", CommunityController, :index
    post "/communities", CommunityController, :create
    get "/communities/:id", CommunityController, :show
    put "/communities/:id", CommunityController, :update
    delete "/communities/:id", CommunityController, :delete

    # Overlay token generation
    post "/voice/rooms/:id/overlay-token", OverlayController, :generate_token

    # Redeemables (channel point rewards) — admin CRUD
    get "/voice/rooms/:id/redeemables", VoiceRoomController, :list_redeemables
    post "/voice/rooms/:id/redeemables", VoiceRoomController, :create_redeemable
    put "/voice/redeemables/:redeemable_id", VoiceRoomController, :update_redeemable
    delete "/voice/redeemables/:redeemable_id", VoiceRoomController, :delete_redeemable
    get "/voice/rooms/:id/redemptions", VoiceRoomController, :list_redemptions

    # Promotion rules (auto-promote users between groups by criteria)
    get "/promotion-rules", AdminPromotionController, :index
    post "/promotion-rules", AdminPromotionController, :create
    put "/promotion-rules/:id", AdminPromotionController, :update
    delete "/promotion-rules/:id", AdminPromotionController, :delete
    post "/promotion-rules/evaluate", AdminPromotionController, :evaluate_all

    # Data import (phpBB/vBulletin/Discourse migration)
    get "/import/sources", ImportController, :available_sources
    post "/import/start", ImportController, :start_import
    post "/import/preview", ImportController, :preview
    get "/import/status/:id", ImportController, :import_status
    post "/import/cancel/:id", ImportController, :cancel_import

    # Quarantine (user quarantine view/manage)
    get "/quarantine", AdminQuarantineController, :index
    post "/quarantine", AdminQuarantineController, :create
    delete "/quarantine/:user_id", AdminQuarantineController, :release

    # Achievements (admin CRUD + manual grant/revoke)
    get "/achievements", AdminAchievementController, :index
    get "/achievements/:id", AdminAchievementController, :show
    post "/achievements", AdminAchievementController, :create
    put "/achievements/:id", AdminAchievementController, :update
    delete "/achievements/:id", AdminAchievementController, :delete
    post "/achievements/:id/grant/:user_id", AdminAchievementController, :grant
    delete "/achievements/:id/grant/:user_id", AdminAchievementController, :revoke
    post "/achievements/:id/bulk", AdminAchievementController, :bulk

    get "/emojis", EmojiController, :admin_index
    post "/emojis", EmojiController, :create
    put "/emojis/:id", EmojiController, :update
    delete "/emojis/:id", EmojiController, :delete

    post "/mass-email", AdminMassEmailController, :send_email
    get "/mass-email/preview", AdminMassEmailController, :preview

    # Dashboard
    get "/dashboard/war-room", AdminDashboardController, :war_room
    get "/dashboard/health-score", AdminDashboardController, :health_score
    get "/dashboard/content-decay", AdminDashboardController, :content_decay
    get "/dashboard/registration-funnel", AdminDashboardController, :registration_funnel
    get "/dashboard/plugin-impact", AdminDashboardController, :plugin_impact
    get "/dashboard/activity-heatmap", AdminDashboardController, :activity_heatmap
    get "/dashboard/comparison", AdminDashboardController, :comparison
    get "/dashboard/mod-queue", AdminDashboardController, :mod_queue
    get "/dashboard/new-members", AdminDashboardController, :new_members
    get "/dashboard/what-if", AdminDashboardController, :what_if
    get "/dashboard/sentiment-trends", AdminDashboardController, :sentiment_trends
    get "/dashboard/merge-suggestions", AdminDashboardController, :merge_suggestions
    get "/dashboard/live-feed", AdminDashboardController, :live_feed
    get "/dashboard/staff-performance", AdminDashboardController, :staff_performance
    get "/dashboard/engagement-scores", AdminDashboardController, :engagement_scores
    put "/dashboard/engagement-scores/config", AdminDashboardController, :update_engagement_config
    get "/dashboard/toxic-warning", AdminDashboardController, :toxic_warning
    get "/dashboard/content-quality", AdminDashboardController, :content_quality
    get "/dashboard/growth-forecast", AdminDashboardController, :growth_forecast
    get "/dashboard/lapsed-users", AdminDashboardController, :lapsed_users
    get "/dashboard/seo-health", AdminDashboardController, :seo_health
    get "/dashboard/cleanup-preview", AdminDashboardController, :cleanup_preview
    post "/dashboard/run-cleanup", AdminDashboardController, :run_cleanup

    # Audit logs
    get "/audit-logs", AdminDashboardController, :list_audit_logs
    post "/audit-logs/:id/rollback", AdminDashboardController, :rollback_audit_log

    # Reordering
    post "/reorder-categories", AdminDashboardController, :reorder_categories
    post "/reorder-forums", AdminDashboardController, :reorder_forums

    # Users
    get "/users", AdminUserController, :index
    get "/users/:id", AdminUserController, :show
    put "/users/:id", AdminUserController, :update
    delete "/users/:id", AdminUserController, :delete
    post "/users/:id/reset-password", AdminUserController, :reset_password
    post "/users/bulk-action", AdminUserController, :bulk_action
    get "/users/:id/journey", AdminUserController, :journey
    get "/users/search-by-ip", AdminUserController, :search_by_ip

    # Groups & Ranks
    # Chat channel management
    get "/chat/categories", AdminChannelController, :list_categories
    post "/chat/categories", AdminChannelController, :create_category
    put "/chat/categories/reorder", AdminChannelController, :reorder_categories
    put "/chat/categories/:id", AdminChannelController, :update_category
    delete "/chat/categories/:id", AdminChannelController, :delete_category

    get "/chat/channels", AdminChannelController, :list_channels
    post "/chat/channels", AdminChannelController, :create_channel
    put "/chat/channels/:id", AdminChannelController, :update_channel
    delete "/chat/channels/:id", AdminChannelController, :delete_channel
    put "/chat/channels/:id/archive", AdminChannelController, :archive_channel
    put "/chat/channels/:id/unarchive", AdminChannelController, :unarchive_channel
    put "/chat/channels/reorder/:category_id", AdminChannelController, :reorder_channels
    delete "/chat/channels/messages/:id", AdminChannelController, :delete_message

    get "/groups", AdminGroupController, :list_groups
    post "/groups", AdminGroupController, :create_group
    put "/groups/:id", AdminGroupController, :update_group
    delete "/groups/:id", AdminGroupController, :delete_group
    get "/groups/default-permissions", AdminGroupController, :default_permissions
    get "/groups/:id/members", AdminGroupController, :list_members
    post "/groups/:id/members", AdminGroupController, :add_member
    delete "/groups/:id/members/:user_id", AdminGroupController, :remove_member
    get "/ranks", AdminGroupController, :list_ranks
    post "/ranks", AdminGroupController, :create_rank

    # Forums management
    get "/forums", AdminForumController, :list_all
    post "/categories", AdminForumController, :create_category
    put "/categories/:id", AdminForumController, :update_category
    delete "/categories/:id", AdminForumController, :delete_category
    post "/forums", AdminForumController, :create_forum
    put "/forums/:id", AdminForumController, :update_forum
    delete "/forums/:id", AdminForumController, :delete_forum

    # Admin pages management
    get "/pages", PageController, :list
    post "/pages", PageController, :create
    put "/pages/:id", PageController, :update
    delete "/pages/:id", PageController, :delete

    # Impersonation
    get "/impersonate/active", ModerationController, :active_impersonation
  end

  if Application.compile_env(:forge_nexus, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: ForgeNexusWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Stream overlays (OBS browser sources — token-gated, no auth cookies)
  scope "/overlay", ForgeNexusWeb do
    get "/:token/:type", OverlayController, :show
  end

  # Catch-all for unmatched API routes (ensures CORS headers on 404)
  scope "/api", ForgeNexusWeb do
    pipe_through :api
    match :*, "/*path", FallbackController, :not_found
  end
end
