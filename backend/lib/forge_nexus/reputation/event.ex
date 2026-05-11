defmodule ForgeNexus.Reputation.Event do
  @moduledoc "Reputation event — durable audit log of reputation changes."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "reputation_events" do
    field :event_type, :string
    field :points, :integer
    field :source_type, :string
    field :source_id, :binary_id

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps(updated_at: false, type: :naive_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:user_id, :event_type, :points, :source_type, :source_id])
    |> validate_required([:user_id, :event_type, :points])
  end
end
