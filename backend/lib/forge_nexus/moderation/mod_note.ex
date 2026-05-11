defmodule ForgeNexus.Moderation.ModNote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mod_notes" do
    field :body, :string

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :author, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:body, :user_id, :author_id])
    |> validate_required([:body, :user_id, :author_id])
  end
end
