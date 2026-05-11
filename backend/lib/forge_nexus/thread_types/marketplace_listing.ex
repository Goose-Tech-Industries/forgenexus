defmodule ForgeNexus.ThreadTypes.MarketplaceListing do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "marketplace_listings" do
    field :price, :decimal
    field :currency, :string, default: "USD"
    field :condition, :string
    field :status, :string, default: "available"
    field :location, :string
    field :shipping_info, :string

    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:price, :currency, :condition, :status, :location, :shipping_info, :thread_id, :user_id])
    |> validate_required([:price, :condition, :thread_id, :user_id])
    |> validate_inclusion(:condition, ["new", "like_new", "good", "fair", "poor"])
    |> validate_inclusion(:status, ["available", "pending", "sold", "withdrawn"])
  end
end
