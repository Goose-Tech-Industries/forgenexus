defmodule ForgeNexus.Moderation.ModerationLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "moderation_logs" do
    field :action, :string
    field :reason, :string
    field :metadata, :map, default: %{}
    field :target_type, :string
    field :target_id, :binary_id

    belongs_to :moderator, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:action, :reason, :metadata, :target_type, :target_id, :moderator_id])
    |> validate_required([:action, :target_type, :target_id, :moderator_id])
  end
end
