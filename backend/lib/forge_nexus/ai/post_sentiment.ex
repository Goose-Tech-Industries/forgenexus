defmodule ForgeNexus.AI.PostSentiment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "post_sentiments" do
    field :sentiment, :float
    field :emotion_tags, :map, default: %{}

    belongs_to :post, ForgeNexus.Forums.Post
    belongs_to :thread, ForgeNexus.Forums.Thread

    timestamps()
  end

  def changeset(post_sentiment, attrs) do
    post_sentiment
    |> cast(attrs, [:sentiment, :emotion_tags, :post_id, :thread_id])
    |> validate_required([:sentiment, :post_id, :thread_id])
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:thread_id)
  end
end
