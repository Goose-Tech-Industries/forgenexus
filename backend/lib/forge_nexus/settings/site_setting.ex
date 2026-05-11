defmodule ForgeNexus.Settings.SiteSetting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "site_settings" do
    field :key, :string
    field :value, :string
    field :value_type, :string, default: "string"

    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value, :value_type])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
