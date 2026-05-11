defmodule ForgeNexus.Workers.AISentimentDailyWorker do
  use Oban.Worker, queue: :ai, max_attempts: 1

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.AI.{PostSentiment, CommunitySentiment}

  @impl Oban.Worker
  def perform(_job) do
    yesterday = Date.utc_today() |> Date.add(-1)
    start_dt = DateTime.new!(yesterday, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(yesterday, ~T[23:59:59], "Etc/UTC")

    stats = from(ps in PostSentiment,
      where: ps.inserted_at >= ^start_dt and ps.inserted_at <= ^end_dt,
      select: %{
        avg_sentiment: avg(ps.sentiment),
        total: count(ps.id),
        heated: count(fragment("CASE WHEN ? < -0.5 THEN 1 END", ps.sentiment))
      }
    ) |> Repo.one()

    # Get top emotions
    emotions = from(ps in PostSentiment,
      where: ps.inserted_at >= ^start_dt and ps.inserted_at <= ^end_dt,
      select: ps.emotion_tags
    ) |> Repo.all()
    |> List.flatten()
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
    |> Map.new()

    %CommunitySentiment{}
    |> CommunitySentiment.changeset(%{
      date: yesterday,
      avg_sentiment: stats.avg_sentiment || 0.0,
      total_posts_analyzed: stats.total || 0,
      heated_thread_count: stats.heated || 0,
      top_emotions: emotions
    })
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :date)

    :ok
  end
end
