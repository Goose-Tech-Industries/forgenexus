defmodule ForgeNexus.Economy.PointTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "point_transactions" do
    field :amount, :integer
    field :balance_after, :integer
    field :reason, :string
    field :reference_type, :string
    field :reference_id, :binary_id
    field :description, :string

    belongs_to :user, ForgeNexus.Accounts.User
    timestamps()
  end

  def changeset(tx, attrs) do
    tx
    |> cast(attrs, [
      :user_id,
      :amount,
      :balance_after,
      :reason,
      :reference_type,
      :reference_id,
      :description
    ])
    |> validate_required([:user_id, :amount, :balance_after, :reason])
  end
end
