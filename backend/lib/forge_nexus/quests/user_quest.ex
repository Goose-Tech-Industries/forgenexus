defmodule ForgeNexus.Quests.UserQuest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_quests" do
    field :status, :string, default: "active"
    field :current_step, :integer, default: 0
    field :progress_data, :map, default: %{}
    field :completed_at, :utc_datetime

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :quest, ForgeNexus.Quests.Quest

    timestamps()
  end

  def changeset(uq, attrs) do
    uq
    |> cast(attrs, [:user_id, :quest_id, :status, :current_step, :progress_data, :completed_at])
    |> validate_required([:user_id, :quest_id, :status])
    |> validate_inclusion(:status, ~w(active completed abandoned failed))
  end
end
