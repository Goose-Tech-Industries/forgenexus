defmodule ForgeNexus.Voice.Redemption do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "redemptions" do
    field :user_text, :string
    field :cost, :integer
    field :status, :string, default: "fulfilled"

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :redeemable, ForgeNexus.Voice.Redeemable
    belongs_to :room, ForgeNexus.Voice.Room
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(redemption, attrs) do
    redemption
    |> cast(attrs, [:redeemable_id, :room_id, :user_id, :user_text, :cost, :status])
    |> validate_required([:redeemable_id, :room_id, :user_id, :cost])
    |> validate_inclusion(:status, ~w(fulfilled pending refunded))
    |> validate_length(:user_text, max: 500)
  end
end
