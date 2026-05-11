defmodule ForgeNexus.Gallery.MediaItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "media_items" do
    field :file_url, :string
    field :thumbnail_url, :string
    field :file_type, :string, default: "image"
    field :file_size, :integer
    field :width, :integer
    field :height, :integer
    field :caption, :string
    field :position, :integer, default: 0

    belongs_to :album, ForgeNexus.Gallery.Album
    belongs_to :user, ForgeNexus.Accounts.User
    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:file_url, :thumbnail_url, :file_type, :file_size, :width, :height, :caption, :album_id, :user_id, :position])
    |> validate_required([:file_url, :album_id, :user_id])
    |> validate_inclusion(:file_type, ~w(image video gif))
  end
end
