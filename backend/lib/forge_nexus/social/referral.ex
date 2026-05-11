defmodule ForgeNexus.Social.Referral do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "referrals" do
    field :code, :string
    field :commission_rate, :float, default: 0.15
    field :commission_duration_months, :integer, default: 12
    field :total_earned_cents, :integer, default: 0
    field :status, :string, default: "active"

    belongs_to :referrer, ForgeNexus.Accounts.User
    belongs_to :referred_community, ForgeNexus.Communities.Community
    belongs_to :referred_user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(ref, attrs) do
    ref
    |> cast(attrs, [:referrer_id, :referred_community_id, :referred_user_id, :code,
                     :commission_rate, :commission_duration_months, :status])
    |> validate_required([:referrer_id, :code])
    |> unique_constraint(:code)
  end

  def generate_code(user_id) do
    short = user_id |> String.slice(0, 6) |> String.upcase()
    "REF-#{short}-#{:rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")}"
  end
end
