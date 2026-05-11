defmodule ForgeNexus.Forums.ThreadSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_levels ~w(watching tracking muted)

  schema "thread_subscriptions" do
    field :notification_level, :string, default: "watching"

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :thread, ForgeNexus.Forums.Thread

    timestamps()
  end

  def changeset(sub, attrs) do
    sub
    |> cast(attrs, [:user_id, :thread_id, :notification_level])
    |> validate_required([:user_id, :thread_id])
    |> validate_inclusion(:notification_level, @valid_levels)
    |> unique_constraint([:thread_id, :user_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:thread_id)
  end
end
