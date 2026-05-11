defmodule ForgeNexus.Economy.PointPackPurchase do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "point_pack_purchases" do
    field :points_granted, :integer
    field :amount_cents, :integer
    field :stripe_payment_intent_id, :string
    field :status, :string, default: "completed"

    belongs_to :pack, ForgeNexus.Economy.PointPack
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :community, ForgeNexus.Communities.Community

    timestamps()
  end

  def changeset(purchase, attrs) do
    purchase
    |> cast(attrs, [:pack_id, :user_id, :community_id, :points_granted, :amount_cents, :stripe_payment_intent_id, :status])
    |> validate_required([:user_id, :points_granted, :amount_cents])
    |> validate_inclusion(:status, ~w(pending completed failed refunded))
  end
end
