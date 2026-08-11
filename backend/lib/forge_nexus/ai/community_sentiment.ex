defmodule ForgeNexus.AI.CommunitySentiment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "community_sentiment_daily" do
    field :date, :date
    field :avg_sentiment, :float
    field :total_posts_analyzed, :integer, default: 0
    field :heated_thread_count, :integer, default: 0
    field :top_emotions, :map, default: %{}

    timestamps()
  end

  def changeset(community_sentiment, attrs) do
    community_sentiment
    |> cast(attrs, [
      :date,
      :avg_sentiment,
      :total_posts_analyzed,
      :heated_thread_count,
      :top_emotions
    ])
    |> validate_required([:date, :avg_sentiment])
    |> unique_constraint(:date)
  end
end
