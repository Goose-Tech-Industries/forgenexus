defmodule ForgeNexus.Profiles.ForgeCodeApplication do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "forge_code_applications" do
    belongs_to :forge_code, ForgeNexus.Profiles.ForgeCode
    belongs_to :user, ForgeNexus.Accounts.User

    field :inserted_at, :utc_datetime
  end

  def changeset(application, attrs) do
    application
    |> cast(attrs, [:forge_code_id, :user_id, :inserted_at])
    |> validate_required([:forge_code_id, :user_id])
    |> foreign_key_constraint(:forge_code_id)
    |> foreign_key_constraint(:user_id)
  end
end
