defmodule ForgeNexus.Forums.ThreadRead do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "thread_reads" do
    field :last_read_at, :utc_datetime

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :last_read_post, ForgeNexus.Forums.Post

    timestamps()
  end

  def changeset(read, attrs) do
    read
    |> cast(attrs, [:user_id, :thread_id, :last_read_at, :last_read_post_id])
    |> validate_required([:user_id, :thread_id, :last_read_at])
    |> unique_constraint([:thread_id, :user_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:thread_id)
  end
end
