defmodule ForgeNexus.Profiles.ForgeCode do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "forge_codes" do
    field :code, :string
    field :name, :string
    field :description, :string
    field :vibe_tag, :string
    field :config, :map, default: %{}
    field :is_official, :boolean, default: false
    field :is_public, :boolean, default: true
    field :is_remixable, :boolean, default: true
    field :applies_count, :integer, default: 0
    field :endorsement_count, :integer, default: 0
    field :preview_image_url, :string
    field :schema_version, :integer, default: 1

    belongs_to :owner, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(forge_code, attrs) do
    forge_code
    |> cast(attrs, [
      :code, :name, :description, :vibe_tag, :config,
      :is_official, :is_public, :is_remixable,
      :preview_image_url, :schema_version, :owner_id
    ])
    |> validate_required([:code, :name, :config])
    |> validate_length(:code, min: 4, max: 24)
    |> validate_length(:name, min: 1, max: 80)
    |> validate_length(:description, max: 500)
    |> validate_format(:code, ~r/^[a-z0-9-]+$/,
         message: "only lowercase letters, numbers, and hyphens"
       )
    |> unique_constraint(:code)
  end
end
