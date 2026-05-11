defmodule ForgeNexus.Federation.ActivityPub.Follower do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ap_followers" do
    field :follower_uri, :string
    field :follower_inbox, :string
    field :accepted, :boolean, default: false

    belongs_to :actor, ForgeNexus.Federation.ActivityPub.Actor

    timestamps()
  end

  def changeset(follower, attrs) do
    follower
    |> cast(attrs, [:follower_uri, :follower_inbox, :accepted, :actor_id])
    |> validate_required([:follower_uri, :follower_inbox, :actor_id])
    |> unique_constraint([:actor_id, :follower_uri])
    |> foreign_key_constraint(:actor_id)
  end
end
