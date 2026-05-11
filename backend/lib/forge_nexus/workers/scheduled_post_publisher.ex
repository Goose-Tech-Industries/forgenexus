defmodule ForgeNexus.Workers.ScheduledPostPublisher do
  @moduledoc "Oban worker that publishes scheduled threads when their scheduled_at time arrives."
  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Forums.Thread

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()

    threads =
      from(t in Thread,
        where: t.status == "scheduled" and not is_nil(t.scheduled_at) and t.scheduled_at <= ^now,
        preload: [:user, :forum]
      )
      |> Repo.all()

    for thread <- threads do
      thread
      |> Ecto.Changeset.change(status: "published", is_hidden: false)
      |> Repo.update!()

      # Broadcast via PubSub for real-time updates
      Phoenix.PubSub.broadcast(
        ForgeNexus.PubSub,
        "forum:#{thread.forum_id}",
        {:new_thread, %{
          id: thread.id,
          title: thread.title,
          slug: thread.slug,
          forum_id: thread.forum_id,
          user: %{
            id: thread.user.id,
            username: thread.user.username,
            slug: thread.user.slug,
            avatar_url: thread.user.avatar_url
          }
        }}
      )
    end

    :ok
  end
end
