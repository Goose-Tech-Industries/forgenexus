defmodule ForgeNexus.AI.FeatureSetting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ai_feature_settings" do
    field :feature, :string
    field :enabled, :boolean, default: false
    field :config, :map, default: %{}

    belongs_to :provider, ForgeNexus.AI.Provider

    timestamps()
  end

  def changeset(feature_setting, attrs) do
    feature_setting
    |> cast(attrs, [:feature, :enabled, :config, :provider_id])
    |> validate_required([:feature])
    |> unique_constraint(:feature)
    |> foreign_key_constraint(:provider_id)
  end
end
