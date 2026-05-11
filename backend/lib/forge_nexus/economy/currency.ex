defmodule ForgeNexus.Economy.Currency do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "currencies" do
    field :name, :string
    field :slug, :string
    field :icon, :string
    field :is_default, :boolean, default: false
    field :is_tradeable, :boolean, default: true
    field :is_active, :boolean, default: true

    timestamps()
  end

  def changeset(currency, attrs) do
    currency
    |> cast(attrs, [:name, :slug, :icon, :is_default, :is_tradeable, :is_active])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
  end
end
