defmodule ForgeNexus.Achievements.UserAchievement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_achievements" do
    field :unlocked_at, :utc_datetime

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :achievement, ForgeNexus.Achievements.Achievement

    timestamps()
  end

  def changeset(ua, attrs) do
    ua
    |> cast(attrs, [:user_id, :achievement_id, :unlocked_at])
    |> validate_required([:user_id, :achievement_id, :unlocked_at])
    |> unique_constraint([:user_id, :achievement_id])
  end
end
