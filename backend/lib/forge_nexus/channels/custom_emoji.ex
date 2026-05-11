defmodule ForgeNexus.Channels.CustomEmoji do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "custom_emojis" do
    field :name, :string
    field :shortcode, :string
    field :image_url, :string
    field :category, :string, default: "custom"
    field :is_animated, :boolean, default: false
    field :is_active, :boolean, default: true

    belongs_to :created_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(emoji, attrs) do
    emoji
    |> cast(attrs, [:name, :shortcode, :image_url, :category, :is_animated, :is_active, :created_by_id])
    |> validate_required([:name, :shortcode, :image_url])
    |> validate_format(:shortcode, ~r/^[a-z0-9_]+$/, message: "must be lowercase alphanumeric with underscores")
    |> validate_length(:shortcode, min: 2, max: 32)
    |> unique_constraint(:shortcode)
  end
end
