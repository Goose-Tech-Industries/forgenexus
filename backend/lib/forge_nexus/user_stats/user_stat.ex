defmodule ForgeNexus.UserStats.UserStat do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_stats" do
    field :stat_key, :string
    field :value, :float, default: 0.0
    field :min_value, :float
    field :max_value, :float

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:user_id, :stat_key, :value, :min_value, :max_value])
    |> validate_required([:user_id, :stat_key])
    |> unique_constraint([:user_id, :stat_key])
  end
end
