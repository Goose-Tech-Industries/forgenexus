defmodule ForgeNexus.Repo.Migrations.CreateCommunitiesAndAddTenantId do
  use Ecto.Migration

  @content_tables ~w(
    forums threads posts categories
    chat_channels chat_messages chat_threads chat_thread_messages
    voice_rooms voice_recordings voice_clips voice_call_logs
    soundboard_clips room_redeemables redemptions money_tips
    flows flow_nodes flow_edges flow_executions
    polls poll_options poll_votes predictions prediction_bets prediction_options
    events event_rsvps
    announcements
    wiki_pages wiki_categories wiki_revisions wiki_edits
    suggestions suggestion_votes
    proposals proposal_comments proposal_votes
    achievements badges user_achievements user_badges
    quests quest_steps user_quests
    currencies user_balances point_transactions transactions
    item_templates user_inventory
    marketplace_listings
    custom_emojis custom_bbcodes
    themes
    reports moderation_logs warnings bans appeals quarantine_records
    slash_commands
    albums media_items
    shoutbox_messages
    tickets ticket_messages
    chat_webhooks forum_webhooks
    notifications
    site_settings
    ranks user_groups forum_permissions promotion_rules
    reactions post_ratings post_bookmarks
    thread_prefixes thread_types
    seasons tournaments tournament_matches tournament_participants
    community_maps map_rooms
    automod_rules content_policies
    community_stats_daily community_sentiment_daily
    guestbook_entries profile_visits profile_top_friends
  )a

  @user_scoped_tables ~w(
    users user_follows user_blocks friendships
    conversations conversation_participants messages
    dm_calls
    login_attempts login_sessions auth_tokens
    user_preferences user_streaks user_cooldowns user_custom_stats
    onboarding_checklists
    post_drafts post_edits post_sentiments post_translations
    thread_reads thread_subscriptions thread_participants thread_summaries thread_answers answer_votes
    thread_ratings
    user_group_memberships
    user_map_positions user_pets user_collection_progress
    suspicious_accounts verification_challenges
    user_subscriptions
    oauth_accounts federated_identities
    staff_applications staff_application_forms
    mod_notes impersonation_logs
    chat_channel_members chat_mentions chat_message_bookmarks chat_message_edits chat_message_reactions
    reputation_events
    debate_positions
    election_candidates elections
    ama_sessions
    collection_items collection_sets
    crafting_recipes crafting_ingredients
    pet_templates
    avatar_frames
    content_ignores
    webhook_deliveries
  )a

  def up do
    # 1. Create the communities table
    create table(:communities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :subdomain, :string
      add :custom_domain, :string
      add :description, :text
      add :logo_url, :string
      add :banner_url, :string
      add :plan, :string, default: "free", null: false
      add :feature_flags, :jsonb, default: "{}", null: false
      add :settings, :jsonb, default: "{}", null: false
      add :is_active, :boolean, default: true, null: false
      add :member_count, :integer, default: 0
      add :monthly_fee_cents, :integer, default: 0
      add :owner_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:communities, [:slug])
    create unique_index(:communities, [:subdomain], where: "subdomain IS NOT NULL")
    create unique_index(:communities, [:custom_domain], where: "custom_domain IS NOT NULL")

    # 2. Create a default community for existing data
    flush()

    execute """
    INSERT INTO communities (id, name, slug, subdomain, plan, feature_flags, is_active, inserted_at, updated_at)
    VALUES (
      '00000000-0000-0000-0000-000000000001',
      'Default Community',
      'default',
      'default',
      'platform',
      '{"forums":true,"profiles":true,"chat":true,"voice":true,"streaming":true,"economy":true,"social_feed":true,"automation":true,"marketplace":true,"white_label":true}',
      true,
      NOW(),
      NOW()
    )
    """

    # 3. Add community_id to all content tables
    for tbl <- @content_tables do
      tbl_str = Atom.to_string(tbl)

      if table_exists?(tbl_str) do
        alter table(tbl) do
          add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all),
            default: "00000000-0000-0000-0000-000000000001"
        end

        create index(tbl, [:community_id])
      end
    end

    # 4. Add community_id to user-scoped tables
    for tbl <- @user_scoped_tables do
      tbl_str = Atom.to_string(tbl)

      if table_exists?(tbl_str) do
        alter table(tbl) do
          add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all),
            default: "00000000-0000-0000-0000-000000000001"
        end

        create index(tbl, [:community_id])
      end
    end

    # 5. Create community_members join table
    create table(:community_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, default: "member"
      add :joined_at, :utc_datetime, default: fragment("NOW()")

      timestamps()
    end

    create unique_index(:community_members, [:community_id, :user_id])
    create index(:community_members, [:user_id])
  end

  def down do
    drop table(:community_members)

    for tbl <- @content_tables ++ @user_scoped_tables do
      tbl_str = Atom.to_string(tbl)

      if table_exists?(tbl_str) and column_exists?(tbl_str, "community_id") do
        drop_if_exists index(tbl, [:community_id])

        alter table(tbl) do
          remove :community_id
        end
      end
    end

    execute "DELETE FROM communities WHERE id = '00000000-0000-0000-0000-000000000001'"
    drop table(:communities)
  end

  defp table_exists?(table) do
    query = "SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = '#{table}')"
    %{rows: [[exists]]} = repo().query!(query)
    exists
  end

  defp column_exists?(table, column) do
    query = "SELECT EXISTS (SELECT FROM information_schema.columns WHERE table_name = '#{table}' AND column_name = '#{column}')"
    %{rows: [[exists]]} = repo().query!(query)
    exists
  end
end
