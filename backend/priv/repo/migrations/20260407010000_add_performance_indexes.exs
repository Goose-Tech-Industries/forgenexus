defmodule ForgeNexus.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  @moduledoc """
  Adds missing indexes for hot query paths identified during performance audit.
  All indexes are created concurrently to avoid locking tables in production.
  """

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    # ===========================================
    # Threads — listing, trending, user profiles
    # ===========================================

    # Thread listing sorted by creation date
    create_if_not_exists index(:threads, [:inserted_at], concurrently: true)

    # User's threads in a specific forum (profile pages, mod tools)
    create_if_not_exists index(:threads, [:forum_id, :user_id], concurrently: true)

    # Trending threads query (filters by recent + sorts by engagement)
    create_if_not_exists index(:threads, [:inserted_at, :forum_id], concurrently: true)

    # ===========================================
    # Posts — timeline, thread display, first post
    # ===========================================

    # Posts sorted by date (latest posts feed, activity stream)
    create_if_not_exists index(:posts, [:inserted_at], concurrently: true)

    # Posts within a thread sorted by date (thread display, pagination)
    create_if_not_exists index(:posts, [:thread_id, :inserted_at], concurrently: true)

    # Quick lookup of first post in a thread (thread previews)
    create_if_not_exists index(:posts, [:thread_id, :is_first_post], concurrently: true)

    # User's recent posts (profile page, mod tools, search by author)
    create_if_not_exists index(:posts, [:user_id, :inserted_at], concurrently: true)

    # ===========================================
    # Notifications — inbox queries
    # ===========================================

    # Optimized for "show unread notifications for user, newest first"
    create_if_not_exists index(:notifications, [:user_id, :is_read, :inserted_at], concurrently: true)

    # ===========================================
    # Messages — conversation display
    # ===========================================

    # Messages in a conversation by user, sorted (DM history)
    create_if_not_exists index(:messages, [:conversation_id, :user_id, :inserted_at], concurrently: true)

    # ===========================================
    # User follows — follower/following counts
    # ===========================================

    # Count followers for a user (profile display)
    create_if_not_exists index(:user_follows, [:followed_id], concurrently: true)

    # Count who a user follows (profile display)
    create_if_not_exists index(:user_follows, [:follower_id], concurrently: true)

    # ===========================================
    # Reputation events — user history
    # ===========================================

    # User's reputation timeline (profile, sorted by date)
    create_if_not_exists index(:reputation_events, [:user_id, :inserted_at], concurrently: true)

    # ===========================================
    # Chat — message search, recent activity
    # ===========================================

    # User's chat messages sorted by date (search, moderation)
    create_if_not_exists index(:chat_messages, [:user_id, :inserted_at], concurrently: true)

    # ===========================================
    # Shoutbox — recent messages
    # ===========================================

    # Shoutbox messages sorted by date (main display query)
    create_if_not_exists index(:shoutbox_messages, [:inserted_at], concurrently: true)
  end
end
