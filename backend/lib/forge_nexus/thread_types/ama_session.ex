defmodule ForgeNexus.ThreadTypes.AmaSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ama_sessions" do
    field :title, :string
    field :description, :string
    field :scheduled_start, :utc_datetime
    field :scheduled_end, :utc_datetime
    field :status, :string, default: "upcoming"

    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :host, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:title, :description, :scheduled_start, :scheduled_end, :status, :thread_id, :host_id])
    |> validate_required([:title, :thread_id, :host_id])
    |> validate_inclusion(:status, ["upcoming", "live", "ended"])
  end
end
