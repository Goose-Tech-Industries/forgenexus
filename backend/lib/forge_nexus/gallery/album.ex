defmodule ForgeNexus.Gallery.Album do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "albums" do
    field :title, :string
    field :description, :string
    field :is_public, :boolean, default: true
    field :cover_image_url, :string
    field :media_count, :integer, default: 0
    field :position, :integer, default: 0

    belongs_to :user, ForgeNexus.Accounts.User
    has_many :items, ForgeNexus.Gallery.MediaItem
    timestamps()
  end

  def changeset(album, attrs) do
    album
    |> cast(attrs, [:title, :description, :user_id, :is_public, :cover_image_url, :position])
    |> validate_required([:title, :user_id])
  end
end
