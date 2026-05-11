defmodule ForgeNexus.Accounts.Rank do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ranks" do
    field :title, :string
    field :min_posts, :integer
    field :image_url, :string
    field :position, :integer, default: 0

    timestamps()
  end

  def changeset(rank, attrs) do
    rank
    |> cast(attrs, [:title, :min_posts, :image_url, :position])
    |> validate_required([:title])
  end
end
