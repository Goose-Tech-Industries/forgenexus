defmodule ForgeNexus.Collections.UserCollection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_collections" do
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :collection_item, ForgeNexus.Collections.CollectionItem

    timestamps()
  end

  def changeset(uc, attrs) do
    uc
    |> cast(attrs, [:user_id, :collection_item_id])
    |> validate_required([:user_id, :collection_item_id])
    |> unique_constraint([:user_id, :collection_item_id])
  end
end
