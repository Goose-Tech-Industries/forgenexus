defmodule ForgeNexus.Federation.ActivityPub.Delivery do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ap_delivery_queue" do
    field :target_inbox, :string
    field :status, :string, default: "pending"
    field :attempts, :integer, default: 0
    field :last_attempted_at, :utc_datetime
    field :error, :string

    belongs_to :object, ForgeNexus.Federation.ActivityPub.Object

    timestamps()
  end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [:target_inbox, :status, :attempts, :last_attempted_at, :error, :object_id])
    |> validate_required([:target_inbox, :object_id])
    |> foreign_key_constraint(:object_id)
  end
end
