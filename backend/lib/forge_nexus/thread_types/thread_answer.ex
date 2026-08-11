defmodule ForgeNexus.ThreadTypes.ThreadAnswer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "thread_answers" do
    field :is_accepted, :boolean, default: false
    field :vote_count, :integer, default: 0
    field :accepted_at, :utc_datetime

    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :post, ForgeNexus.Forums.Post
    belongs_to :accepted_by, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :is_accepted,
      :vote_count,
      :accepted_at,
      :thread_id,
      :post_id,
      :accepted_by_id
    ])
    |> validate_required([:thread_id, :post_id])
  end
end
