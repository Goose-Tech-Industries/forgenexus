defmodule ForgeNexus.Forums.ThreadParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "thread_participants" do
    field :added_at, :utc_datetime

    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :user, ForgeNexus.Accounts.User
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:thread_id, :user_id, :added_at])
    |> validate_required([:thread_id, :user_id, :added_at])
    |> unique_constraint([:thread_id, :user_id])
    |> foreign_key_constraint(:thread_id)
    |> foreign_key_constraint(:user_id)
  end
end
