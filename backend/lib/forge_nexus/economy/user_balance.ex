defmodule ForgeNexus.Economy.UserBalance do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_balances" do
    field :balance, :integer, default: 0
    field :lifetime_earned, :integer, default: 0

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :currency, ForgeNexus.Economy.Currency

    timestamps()
  end

  def changeset(user_balance, attrs) do
    user_balance
    |> cast(attrs, [:user_id, :currency_id, :balance, :lifetime_earned])
    |> validate_required([:user_id, :currency_id])
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> unique_constraint([:user_id, :currency_id])
  end
end
