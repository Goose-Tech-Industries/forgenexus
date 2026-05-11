defmodule ForgeNexus.Moderation.SoftBlock do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending edited expired deleted)

  schema "soft_blocks" do
    field :reason, :string
    field :rule_violated, :string
    field :expires_at, :utc_datetime
    field :status, :string, default: "pending"
    field :edited_at, :utc_datetime
    field :original_body, :string

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :post, ForgeNexus.Forums.Post
    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :moderator, ForgeNexus.Accounts.User
    belongs_to :author, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(sb, attrs) do
    sb
    |> cast(attrs, [:community_id, :post_id, :thread_id, :moderator_id, :author_id,
                     :reason, :rule_violated, :expires_at, :status, :edited_at, :original_body])
    |> validate_required([:post_id, :moderator_id, :author_id, :reason, :expires_at])
    |> validate_inclusion(:status, @statuses)
  end
end
