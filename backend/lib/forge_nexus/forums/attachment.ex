defmodule ForgeNexus.Forums.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @allowed_types ~w(image/jpeg image/png image/gif image/webp application/pdf text/plain application/zip)
  # 10MB
  @max_size 10_000_000

  schema "attachments" do
    field :filename, :string
    field :content_type, :string
    field :size, :integer
    field :url, :string
    field :thumbnail_url, :string
    field :width, :integer
    field :height, :integer
    # "post", "thread", "message"
    field :attachable_type, :string
    field :attachable_id, :binary_id

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [
      :filename,
      :content_type,
      :size,
      :url,
      :thumbnail_url,
      :width,
      :height,
      :attachable_type,
      :attachable_id,
      :user_id
    ])
    |> validate_required([:filename, :content_type, :size, :url, :user_id])
    |> validate_inclusion(:content_type, @allowed_types)
    |> validate_number(:size, less_than_or_equal_to: @max_size)
    |> foreign_key_constraint(:user_id)
  end

  def allowed_types, do: @allowed_types
  def max_size, do: @max_size
end
