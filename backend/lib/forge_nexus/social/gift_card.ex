defmodule ForgeNexus.Social.GiftCard do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "gift_cards" do
    field :code, :string
    field :amount_cents, :integer
    field :points_amount, :integer
    field :type, :string, default: "points"
    field :status, :string, default: "active"
    field :redeemed_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :purchaser, ForgeNexus.Accounts.User
    belongs_to :redeemed_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(card, attrs) do
    card
    |> cast(attrs, [
      :community_id,
      :purchaser_id,
      :redeemed_by_id,
      :code,
      :amount_cents,
      :points_amount,
      :type,
      :status,
      :redeemed_at,
      :expires_at
    ])
    |> validate_required([:code])
    |> validate_inclusion(:type, ~w(points money premium_time))
    |> validate_inclusion(:status, ~w(active redeemed expired))
    |> unique_constraint(:code)
  end

  def generate_code do
    "FNX-" <> String.upcase(Base.encode32(:crypto.strong_rand_bytes(5), padding: false))
  end
end
