defmodule ForgeNexus.Profiles.ProfileVisit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profile_visits" do
    field :visited_at, :utc_datetime

    belongs_to :profile_user, ForgeNexus.Accounts.User
    belongs_to :visitor, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(visit, attrs) do
    visit
    |> cast(attrs, [:profile_user_id, :visitor_id, :visited_at])
    |> validate_required([:profile_user_id, :visitor_id, :visited_at])
    |> unique_constraint([:profile_user_id, :visitor_id])
  end
end
