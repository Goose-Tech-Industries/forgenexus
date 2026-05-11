defmodule ForgeNexus.Workers.CountReconciler do
  @moduledoc """
  Recomputes denormalized counters (forums.thread_count, forums.post_count,
  threads.reply_count, users.post_count, users.thread_count, last_post_at,
  last_post_user_id) from source-of-truth.

  Why this exists: a few delete paths (cascading user purges, post deletions
  that bypass changeset callbacks, raw SQL operations) can leave the
  denormalized columns out of sync. This is the self-healing safety net so
  drift never becomes user-visible for more than a few minutes.
  """
  use Oban.Worker, queue: :default, max_attempts: 1

  alias ForgeNexus.Repo

  @impl Oban.Worker
  def perform(_job) do
    # Threads
    {threads_n, _} = Repo.query!("""
      UPDATE threads t SET
        reply_count = COALESCE((SELECT GREATEST(COUNT(*) - 1, 0) FROM posts p WHERE p.thread_id = t.id), 0),
        last_post_at = (SELECT MAX(p.inserted_at) FROM posts p WHERE p.thread_id = t.id),
        last_post_user_id = (
          SELECT p.user_id FROM posts p
          WHERE p.thread_id = t.id
          ORDER BY p.inserted_at DESC NULLS LAST LIMIT 1
        )
    """, []) |> then(fn r -> {r.num_rows, nil} end)

    # Forums
    {forums_n, _} = Repo.query!("""
      UPDATE forums f SET
        thread_count = COALESCE((SELECT COUNT(*) FROM threads t WHERE t.forum_id = f.id), 0),
        post_count = COALESCE((
          SELECT COUNT(*) FROM posts p
          JOIN threads t ON t.id = p.thread_id
          WHERE t.forum_id = f.id
        ), 0),
        last_post_at = (
          SELECT MAX(p.inserted_at) FROM posts p
          JOIN threads t ON t.id = p.thread_id
          WHERE t.forum_id = f.id
        ),
        last_post_user_id = (
          SELECT p.user_id FROM posts p
          JOIN threads t ON t.id = p.thread_id
          WHERE t.forum_id = f.id
          ORDER BY p.inserted_at DESC NULLS LAST LIMIT 1
        )
    """, []) |> then(fn r -> {r.num_rows, nil} end)

    # Users
    {users_n, _} = Repo.query!("""
      UPDATE users u SET
        post_count = COALESCE((SELECT COUNT(*) FROM posts p WHERE p.user_id = u.id), 0),
        thread_count = COALESCE((SELECT COUNT(*) FROM threads t WHERE t.user_id = u.id), 0),
        last_post_at = (SELECT MAX(p.inserted_at) FROM posts p WHERE p.user_id = u.id)
    """, []) |> then(fn r -> {r.num_rows, nil} end)

    {:ok, %{threads: threads_n, forums: forums_n, users: users_n}}
  end
end
