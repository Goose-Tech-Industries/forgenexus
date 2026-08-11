defmodule ForgeNexus.Social.StatusPost do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "status_posts" do
    field :body, :string
    field :media_urls, {:array, :string}, default: []
    field :media_type, :string, default: "text"
    field :reference_type, :string
    field :reference_id, :binary_id
    field :like_count, :integer, default: 0
    field :comment_count, :integer, default: 0
    field :share_count, :integer, default: 0
    field :is_pinned, :boolean, default: false
    field :visibility, :string, default: "public"

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :community_id,
      :user_id,
      :body,
      :media_urls,
      :media_type,
      :reference_type,
      :reference_id,
      :is_pinned,
      :visibility
    ])
    |> validate_required([:user_id, :body])
    |> validate_length(:body, min: 1, max: 500)
    |> validate_inclusion(:visibility, ~w(public friends_only private))
    |> validate_inclusion(:media_type, ~w(text image video poll clip_share thread_share))
  end
end
