defmodule ForgeNexus.Social.Poke do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ~w(poke wink wave high_five fist_bump hug nudge)

  schema "pokes" do
    field :type, :string, default: "poke"
    field :message, :string
    field :is_read, :boolean, default: false

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :sender, ForgeNexus.Accounts.User
    belongs_to :recipient, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(poke, attrs) do
    poke
    |> cast(attrs, [:community_id, :sender_id, :recipient_id, :type, :message])
    |> validate_required([:sender_id, :recipient_id])
    |> validate_inclusion(:type, @types)
    |> validate_length(:message, max: 200)
  end

  def types, do: @types
end
