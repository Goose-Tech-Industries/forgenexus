defmodule ForgeNexus.Analytics.CommunityStats do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "community_stats_daily" do
    field :date, :date
    field :new_members, :integer, default: 0
    field :active_members, :integer, default: 0
    field :posts_created, :integer, default: 0
    field :threads_created, :integer, default: 0
    field :avg_reply_time_minutes, :float
    field :response_rate, :float
    field :top_topics, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :date, :new_members, :active_members, :posts_created, :threads_created,
      :avg_reply_time_minutes, :response_rate, :top_topics
    ])
    |> validate_required([:date])
    |> unique_constraint(:date)
  end
end
