defmodule ForgeNexus.Plugins.Nodes.Registry do
  @moduledoc """
  Maps node type strings to their handler modules.
  343 node types across 43 categories.
  """

  alias ForgeNexus.Plugins.Nodes

  @handlers %{
    # === Triggers (24) ===
    "trigger/on_post_created" => Nodes.Trigger.OnPostCreated,
    "trigger/on_thread_created" => Nodes.Trigger.OnThreadCreated,
    "trigger/on_user_joined" => Nodes.Trigger.OnUserJoined,
    "trigger/on_user_left" => Nodes.Trigger.OnUserLeft,
    "trigger/on_reaction_added" => Nodes.Trigger.OnReactionAdded,
    "trigger/on_chat_message" => Nodes.Trigger.OnChatMessage,
    "trigger/scheduled" => Nodes.Trigger.Scheduled,
    "trigger/manual" => Nodes.Trigger.Manual,
    "trigger/webhook_received" => Nodes.Trigger.WebhookReceived,
    "trigger/on_custom_event" => Nodes.Trigger.OnCustomEvent,
    "trigger/on_slash_command" => Nodes.Trigger.OnSlashCommand,
    "trigger/on_user_banned" => Nodes.Trigger.OnUserBanned,
    "trigger/on_report_created" => Nodes.Trigger.OnReportCreated,
    "trigger/on_post_edited" => Nodes.Trigger.OnPostEdited,
    "trigger/on_thread_solved" => Nodes.Trigger.OnThreadSolved,
    "trigger/on_achievement_unlocked" => Nodes.Trigger.OnAchievementUnlocked,
    "trigger/on_streak_milestone" => Nodes.Trigger.OnStreakMilestone,
    "trigger/on_point_milestone" => Nodes.Trigger.OnPointMilestone,
    "trigger/on_collection_completed" => Nodes.Trigger.OnCollectionCompleted,
    "trigger/on_payment_received" => Nodes.Trigger.OnPaymentReceived,
    "trigger/on_subscription_changed" => Nodes.Trigger.OnSubscriptionChanged,
    "trigger/on_cooldown_expired" => Nodes.Trigger.OnCooldownExpired,
    "trigger/on_poll_voted" => Nodes.Trigger.OnPollVoted,
    "trigger/on_user_birthday" => Nodes.Trigger.OnUserBirthday,

    # === Logic (6) ===
    "logic/if_else" => Nodes.Logic.IfElse,
    "logic/switch_case" => Nodes.Logic.SwitchCase,
    "logic/loop" => Nodes.Logic.Loop,
    "logic/delay" => Nodes.Logic.Delay,
    "logic/random" => Nodes.Logic.Random,
    "logic/compare" => Nodes.Logic.Compare,

    # === Math (2) ===
    "math/arithmetic" => Nodes.Math.Arithmetic,
    "math/functions" => Nodes.Math.Functions,

    # === Data (10) ===
    "data/get_user_data" => Nodes.Data.GetUserData,
    "data/set_user_data" => Nodes.Data.SetUserData,
    "data/get_global_data" => Nodes.Data.GetGlobalData,
    "data/set_global_data" => Nodes.Data.SetGlobalData,
    "data/query_table" => Nodes.Data.QueryTable,
    "data/insert_row" => Nodes.Data.InsertRow,
    "data/update_row" => Nodes.Data.UpdateRow,
    "data/delete_row" => Nodes.Data.DeleteRow,
    "data/get_user_field" => Nodes.Data.GetUserField,
    "data/set_user_field" => Nodes.Data.SetUserField,

    # === Actions (10) ===
    "action/create_post" => Nodes.Action.CreatePost,
    "action/create_thread" => Nodes.Action.CreateThread,
    "action/send_dm" => Nodes.Action.SendDm,
    "action/send_notification" => Nodes.Action.SendNotification,
    "action/add_to_group" => Nodes.Action.AddToGroup,
    "action/remove_from_group" => Nodes.Action.RemoveFromGroup,
    "action/set_custom_title" => Nodes.Action.SetCustomTitle,
    "action/award_points" => Nodes.Action.AwardPoints,
    "action/http_request" => Nodes.Action.HttpRequest,
    "action/emit_custom_event" => Nodes.Action.EmitCustomEvent,

    # === Text (6) ===
    "text/format_string" => Nodes.Text.FormatString,
    "text/regex_match" => Nodes.Text.RegexMatch,
    "text/contains" => Nodes.Text.Contains,
    "text/split" => Nodes.Text.Split,
    "text/join" => Nodes.Text.Join,
    "text/bbcode_render" => Nodes.Text.BbcodeRender,

    # === UI (3) ===
    "ui/render_profile_widget" => Nodes.UI.RenderProfileWidget,
    "ui/render_post_widget" => Nodes.UI.RenderPostWidget,
    "ui/render_page" => Nodes.UI.RenderPage,

    # === Moderation (10) ===
    "moderation/timeout_user" => Nodes.Moderation.TimeoutUser,
    "moderation/unban_user" => Nodes.Moderation.UnbanUser,
    "moderation/add_infraction" => Nodes.Moderation.AddInfraction,
    "moderation/check_infraction_points" => Nodes.Moderation.CheckInfractionPoints,
    "moderation/ip_ban" => Nodes.Moderation.IpBan,
    "moderation/quarantine_user" => Nodes.Moderation.QuarantineUser,
    "moderation/slow_mode" => Nodes.Moderation.SlowMode,
    "moderation/bulk_delete" => Nodes.Moderation.BulkDelete,
    "moderation/set_post_approval" => Nodes.Moderation.SetPostApproval,
    "moderation/send_mod_alert" => Nodes.Moderation.SendModAlert,

    # === AutoMod / Content Filter (12) ===
    "automod/keyword_filter" => Nodes.Automod.KeywordFilter,
    "automod/link_filter" => Nodes.Automod.LinkFilter,
    "automod/spam_score" => Nodes.Automod.SpamScore,
    "automod/rate_limit_check" => Nodes.Automod.RateLimitCheck,
    "automod/account_age_check" => Nodes.Automod.AccountAgeCheck,
    "automod/karma_check" => Nodes.Automod.KarmaCheck,
    "automod/content_length_check" => Nodes.Automod.ContentLengthCheck,
    "automod/duplicate_check" => Nodes.Automod.DuplicateCheck,
    "automod/media_filter" => Nodes.Automod.MediaFilter,
    "automod/mention_spam_check" => Nodes.Automod.MentionSpamCheck,
    "automod/invite_link_filter" => Nodes.Automod.InviteLinkFilter,
    "automod/ai_content_classify" => Nodes.Automod.AiContentClassify,

    # === User Management (10) ===
    "user_management/set_user_group" => Nodes.UserManagement.SetUserGroup,
    "user_management/promote_user" => Nodes.UserManagement.PromoteUser,
    "user_management/demote_user" => Nodes.UserManagement.DemoteUser,
    "user_management/set_user_title" => Nodes.UserManagement.SetUserTitle,
    "user_management/set_username_style" => Nodes.UserManagement.SetUsernameStyle,
    "user_management/set_user_flair" => Nodes.UserManagement.SetUserFlair,
    "user_management/check_user_group" => Nodes.UserManagement.CheckUserGroup,
    "user_management/get_user_profile" => Nodes.UserManagement.GetUserProfile,
    "user_management/check_online_status" => Nodes.UserManagement.CheckOnlineStatus,
    "user_management/merge_accounts" => Nodes.UserManagement.MergeAccounts,

    # === Notification (5) ===
    "notification/send_dm" => Nodes.Notification.SendDm,
    "notification/send_announcement" => Nodes.Notification.SendAnnouncement,
    "notification/digest_summary" => Nodes.Notification.DigestSummary,
    "notification/channel_notification" => Nodes.Notification.ChannelNotification,
    "notification/broadcast_message" => Nodes.Notification.BroadcastMessage,

    # === Economy (12) ===
    "economy/get_balance" => Nodes.Economy.GetBalance,
    "economy/award_points" => Nodes.Economy.AwardPoints,
    "economy/deduct_points" => Nodes.Economy.DeductPoints,
    "economy/transfer_points" => Nodes.Economy.TransferPoints,
    "economy/get_leaderboard" => Nodes.Economy.GetLeaderboard,
    "economy/create_transaction" => Nodes.Economy.CreateTransaction,
    "economy/check_balance" => Nodes.Economy.CheckBalance,
    "economy/set_price" => Nodes.Economy.SetPrice,
    "economy/add_interest" => Nodes.Economy.AddInterest,
    "economy/tax_transaction" => Nodes.Economy.TaxTransaction,
    "economy/create_lottery_pool" => Nodes.Economy.CreateLotteryPool,
    "economy/currency_exchange" => Nodes.Economy.CurrencyExchange,

    # === Gambling / Chance (10) ===
    "gambling/weighted_pick" => Nodes.Gambling.WeightedPick,
    "gambling/dice_roll" => Nodes.Gambling.DiceRoll,
    "gambling/chance" => Nodes.Gambling.Chance,
    "gambling/shuffle" => Nodes.Gambling.Shuffle,
    "gambling/pick_from_table" => Nodes.Gambling.PickFromTable,
    "gambling/coin_flip" => Nodes.Gambling.CoinFlip,
    "gambling/slot_machine" => Nodes.Gambling.SlotMachine,
    "gambling/card_draw" => Nodes.Gambling.CardDraw,
    "gambling/roulette_spin" => Nodes.Gambling.RouletteSpin,
    "gambling/gacha_pull" => Nodes.Gambling.GachaPull,

    # === Inventory (12) ===
    "inventory/define_item" => Nodes.Inventory.DefineItem,
    "inventory/give_item" => Nodes.Inventory.GiveItem,
    "inventory/remove_item" => Nodes.Inventory.RemoveItem,
    "inventory/has_item" => Nodes.Inventory.HasItem,
    "inventory/get_inventory" => Nodes.Inventory.GetInventory,
    "inventory/transfer_item" => Nodes.Inventory.TransferItem,
    "inventory/equip_item" => Nodes.Inventory.EquipItem,
    "inventory/consume_item" => Nodes.Inventory.ConsumeItem,
    "inventory/craft_item" => Nodes.Inventory.CraftItem,
    "inventory/item_durability" => Nodes.Inventory.ItemDurability,
    "inventory/list_for_sale" => Nodes.Inventory.ListForSale,
    "inventory/open_pack" => Nodes.Inventory.OpenPack,

    # === Collection (6) ===
    "collection/define_set" => Nodes.Collection.DefineSet,
    "collection/add_to_set" => Nodes.Collection.AddToSet,
    "collection/check_completion" => Nodes.Collection.CheckCompletion,
    "collection/get_progress" => Nodes.Collection.GetProgress,
    "collection/get_missing" => Nodes.Collection.GetMissing,
    "collection/trade_collection_item" => Nodes.Collection.TradeCollectionItem,

    # === Competition / Tournament (8) ===
    "tournament/create_tournament" => Nodes.Tournament.CreateTournament,
    "tournament/register_participant" => Nodes.Tournament.RegisterParticipant,
    "tournament/get_matchup" => Nodes.Tournament.GetMatchup,
    "tournament/submit_result" => Nodes.Tournament.SubmitResult,
    "tournament/advance_bracket" => Nodes.Tournament.AdvanceBracket,
    "tournament/get_standings" => Nodes.Tournament.GetStandings,
    "tournament/award_placement" => Nodes.Tournament.AwardPlacement,
    "tournament/create_season" => Nodes.Tournament.CreateSeason,

    # === Reputation / Karma (6) ===
    "reputation/give_reputation" => Nodes.Reputation.GiveReputation,
    "reputation/get_reputation" => Nodes.Reputation.GetReputation,
    "reputation/check_reputation" => Nodes.Reputation.CheckReputation,
    "reputation/scale_rep_power" => Nodes.Reputation.ScaleRepPower,
    "reputation/get_trade_rep" => Nodes.Reputation.GetTradeRep,
    "reputation/reputation_decay" => Nodes.Reputation.ReputationDecay,

    # === Achievement / Badge (8) ===
    "achievement/define_achievement" => Nodes.Achievement.DefineAchievement,
    "achievement/check_achievement" => Nodes.Achievement.CheckAchievement,
    "achievement/award_badge" => Nodes.Achievement.AwardBadge,
    "achievement/revoke_badge" => Nodes.Achievement.RevokeBadge,
    "achievement/get_badges" => Nodes.Achievement.GetBadges,
    "achievement/has_badge" => Nodes.Achievement.HasBadge,
    "achievement/display_badge" => Nodes.Achievement.DisplayBadge,
    "achievement/create_milestone" => Nodes.Achievement.CreateMilestone,

    # === Pet / Creature (8) ===
    "pet/create_pet" => Nodes.Pet.CreatePet,
    "pet/get_pet_stats" => Nodes.Pet.GetPetStats,
    "pet/pet_action" => Nodes.Pet.PetAction,
    "pet/pet_evolve" => Nodes.Pet.PetEvolve,
    "pet/breed_pets" => Nodes.Pet.BreedPets,
    "pet/pet_battle" => Nodes.Pet.PetBattle,
    "pet/pet_decay" => Nodes.Pet.PetDecay,
    "pet/pet_compete" => Nodes.Pet.PetCompete,

    # === Quest / Mission (8) ===
    "quest/define_quest" => Nodes.Quest.DefineQuest,
    "quest/start_quest" => Nodes.Quest.StartQuest,
    "quest/check_quest_step" => Nodes.Quest.CheckQuestStep,
    "quest/advance_quest" => Nodes.Quest.AdvanceQuest,
    "quest/complete_quest" => Nodes.Quest.CompleteQuest,
    "quest/get_quest_progress" => Nodes.Quest.GetQuestProgress,
    "quest/create_daily_quest" => Nodes.Quest.CreateDailyQuest,
    "quest/create_quest_chain" => Nodes.Quest.CreateQuestChain,

    # === User Stats (6) ===
    "stats/get_stat" => Nodes.Stats.GetStat,
    "stats/set_stat" => Nodes.Stats.SetStat,
    "stats/modify_stat" => Nodes.Stats.ModifyStat,
    "stats/check_stat" => Nodes.Stats.CheckStat,
    "stats/get_level" => Nodes.Stats.GetLevel,
    "stats/get_all_stats" => Nodes.Stats.GetAllStats,

    # === Ticket / Support (8) ===
    "ticket/create_ticket" => Nodes.Ticket.CreateTicket,
    "ticket/assign_ticket" => Nodes.Ticket.AssignTicket,
    "ticket/claim_ticket" => Nodes.Ticket.ClaimTicket,
    "ticket/update_ticket_status" => Nodes.Ticket.UpdateTicketStatus,
    "ticket/escalate_ticket" => Nodes.Ticket.EscalateTicket,
    "ticket/add_internal_note" => Nodes.Ticket.AddInternalNote,
    "ticket/ticket_sla_check" => Nodes.Ticket.TicketSlaCheck,
    "ticket/close_with_rating" => Nodes.Ticket.CloseWithRating,

    # === Poll / Voting (8) ===
    "poll/create_poll" => Nodes.Poll.CreatePoll,
    "poll/add_vote" => Nodes.Poll.AddVote,
    "poll/get_poll_results" => Nodes.Poll.GetPollResults,
    "poll/close_poll" => Nodes.Poll.ClosePoll,
    "poll/create_prediction" => Nodes.Poll.CreatePrediction,
    "poll/resolve_prediction" => Nodes.Poll.ResolvePrediction,
    "poll/create_suggestion" => Nodes.Poll.CreateSuggestion,
    "poll/update_suggestion_status" => Nodes.Poll.UpdateSuggestionStatus,

    # === Verification / Onboarding (8) ===
    "verification/send_captcha" => Nodes.Verification.SendCaptcha,
    "verification/verify_captcha" => Nodes.Verification.VerifyCaptcha,
    "verification/send_verification_dm" => Nodes.Verification.SendVerificationDm,
    "verification/check_account_criteria" => Nodes.Verification.CheckAccountCriteria,
    "verification/assign_onboarding_checklist" => Nodes.Verification.AssignOnboardingChecklist,
    "verification/check_onboarding_complete" => Nodes.Verification.CheckOnboardingComplete,
    "verification/create_introduction_prompt" => Nodes.Verification.CreateIntroductionPrompt,
    "verification/mentorship_pair" => Nodes.Verification.MentorshipPair,

    # === Content Management (10) ===
    "content/create_thread" => Nodes.Content.CreateThreadNode,
    "content/edit_thread" => Nodes.Content.EditThread,
    "content/pin_content" => Nodes.Content.PinContent,
    "content/unpin_content" => Nodes.Content.UnpinContent,
    "content/set_thread_prefix" => Nodes.Content.SetThreadPrefix,
    "content/enforce_template" => Nodes.Content.EnforceTemplate,
    "content/merge_threads" => Nodes.Content.MergeThreads,
    "content/split_posts" => Nodes.Content.SplitPosts,
    "content/archive_content" => Nodes.Content.ArchiveContent,
    "content/feature_content" => Nodes.Content.FeatureContent,

    # === Scheduling / Calendar (6) ===
    "scheduling/create_event" => Nodes.Scheduling.CreateEvent,
    "scheduling/send_reminder" => Nodes.Scheduling.SendReminder,
    "scheduling/create_recurring_post" => Nodes.Scheduling.CreateRecurringPost,
    "scheduling/rotate_featured" => Nodes.Scheduling.RotateFeatured,
    "scheduling/double_xp_event" => Nodes.Scheduling.DoubleXpEvent,
    "scheduling/holiday_theme" => Nodes.Scheduling.HolidayTheme,

    # === Feed / Integration (4) ===
    "integration/post_to_social" => Nodes.Integration.PostToSocial,
    "integration/youtube_check" => Nodes.Integration.YoutubeCheck,
    "integration/email_inbound" => Nodes.Integration.EmailInbound,
    "integration/parse_webhook" => Nodes.Integration.ParseWebhook,

    # === Analytics / Insight (8) ===
    "analytics/get_user_activity" => Nodes.Analytics.GetUserActivity,
    "analytics/get_content_metrics" => Nodes.Analytics.GetContentMetrics,
    "analytics/get_growth_metrics" => Nodes.Analytics.GetGrowthMetrics,
    "analytics/get_engagement_score" => Nodes.Analytics.GetEngagementScore,
    "analytics/detect_trending" => Nodes.Analytics.DetectTrending,
    "analytics/detect_churn_risk" => Nodes.Analytics.DetectChurnRisk,
    "analytics/compare_periods" => Nodes.Analytics.ComparePeriods,
    "analytics/export_analytics" => Nodes.Analytics.ExportAnalytics,

    # === Approval / Workflow (3) ===
    "approval/multi_level_approval" => Nodes.Approval.MultiLevelApproval,
    "approval/delegate_approval" => Nodes.Approval.DelegateApproval,
    "approval/auto_approve_on_timeout" => Nodes.Approval.AutoApproveOnTimeout,

    # === Profile / Display (14) ===
    "profile/set_avatar_frame" => Nodes.Profile.SetAvatarFrame,
    "profile/set_name_color" => Nodes.Profile.SetNameColor,
    "profile/set_name_effect" => Nodes.Profile.SetNameEffect,
    "profile/set_postbit_background" => Nodes.Profile.SetPostbitBackground,
    "profile/set_profile_background" => Nodes.Profile.SetProfileBackground,
    "profile/set_mood" => Nodes.Profile.SetMood,
    "profile/grant_profile_perk" => Nodes.Profile.GrantProfilePerk,
    "profile/set_custom_field" => Nodes.Profile.SetCustomField,
    "profile/set_signature" => Nodes.Profile.SetSignature,
    "profile/show_profile_widget" => Nodes.Profile.ShowProfileWidget,
    "profile/set_custom_title" => Nodes.Profile.SetCustomTitle,
    "profile/set_nameplate" => Nodes.Profile.SetNameplate,
    "profile/set_postbit_style" => Nodes.Profile.SetPostbitStyle,
    "profile/restrict_profile_perk" => Nodes.Profile.RestrictProfilePerk,

    # === Shoutbox (8) ===
    "shoutbox/send_shout" => Nodes.Shoutbox.SendShout,
    "shoutbox/send_announcement" => Nodes.Shoutbox.SendAnnouncement,
    "shoutbox/clear_shoutbox" => Nodes.Shoutbox.ClearShoutbox,
    "shoutbox/pin_shout" => Nodes.Shoutbox.PinShout,
    "shoutbox/delete_shout" => Nodes.Shoutbox.DeleteShout,
    "shoutbox/get_shoutbox_stats" => Nodes.Shoutbox.GetShoutboxStats,
    "shoutbox/shoutbox_cooldown" => Nodes.Shoutbox.ShoutboxCooldown,
    "shoutbox/mute_user_shoutbox" => Nodes.Shoutbox.MuteUserShoutbox
  }

  @doc "Returns the handler module for a given node type string."
  def get_handler(type) do
    case Map.fetch(@handlers, type) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :unknown_node_type}
    end
  end

  @doc "Returns all registered node types with their schemas."
  def all_types do
    Enum.map(@handlers, fn {type, module} ->
      {type, module.schema()}
    end)
  end

  @doc "Returns node types grouped by category."
  def categories do
    @handlers
    |> Enum.map(fn {type, module} -> {type, module} end)
    |> Enum.group_by(fn {type, _module} ->
      type |> String.split("/") |> List.first()
    end)
    |> Enum.map(fn {category, entries} ->
      {category, Enum.map(entries, fn {type, module} -> {type, module.schema()} end)}
    end)
    |> Map.new()
  end

  @doc "Returns the total count of registered node types."
  def count, do: map_size(@handlers)
end
