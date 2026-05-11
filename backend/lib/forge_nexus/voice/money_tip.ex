defmodule ForgeNexus.Voice.MoneyTip do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending completed failed refunded)

  schema "money_tips" do
    field :amount_cents, :integer
    field :currency, :string, default: "usd"
    field :message, :string
    field :is_anonymous, :boolean, default: false

    field :platform_fee_cents, :integer
    field :creator_amount_cents, :integer
    field :creator_tier, :string

    field :stripe_fee_cents, :integer, default: 0
    field :community_kickback_cents, :integer, default: 0
    field :community_plan, :string
    field :platform_net_cents, :integer, default: 0

    field :stripe_payment_intent_id, :string
    field :stripe_transfer_id, :string
    field :status, :string, default: "pending"

    belongs_to :sender, ForgeNexus.Accounts.User
    belongs_to :recipient, ForgeNexus.Accounts.User
    belongs_to :room, ForgeNexus.Voice.Room
    belongs_to :community_owner, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(tip, attrs) do
    tip
    |> cast(attrs, [:sender_id, :recipient_id, :room_id, :amount_cents, :currency, :message,
                     :is_anonymous, :platform_fee_cents, :creator_amount_cents, :creator_tier,
                     :stripe_fee_cents, :community_kickback_cents, :community_owner_id,
                     :community_plan, :platform_net_cents,
                     :stripe_payment_intent_id, :stripe_transfer_id, :status])
    |> validate_required([:recipient_id, :amount_cents, :platform_fee_cents, :creator_amount_cents])
    |> validate_number(:amount_cents, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:message, max: 500)
  end
end
