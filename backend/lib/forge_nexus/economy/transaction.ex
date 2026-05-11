defmodule ForgeNexus.Economy.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "economy_transactions" do
    field :amount, :integer
    field :balance_after, :integer
    field :type, :string
    field :reason, :string
    field :reference_type, :string
    field :reference_id, :binary_id

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :currency, ForgeNexus.Economy.Currency

    timestamps()
  end

  def changeset(tx, attrs) do
    tx
    |> cast(attrs, [:user_id, :currency_id, :amount, :balance_after, :type, :reason, :reference_type, :reference_id])
    |> validate_required([:user_id, :currency_id, :amount, :balance_after, :type])
    |> validate_inclusion(:type, ~w(award deduct transfer interest refund))
  end
end
