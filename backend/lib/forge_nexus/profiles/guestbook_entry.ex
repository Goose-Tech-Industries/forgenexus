defmodule ForgeNexus.Profiles.GuestbookEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "guestbook_entries" do
    field :body_bbcode, :string
    field :body_html, :string
    field :is_hidden, :boolean, default: false

    belongs_to :profile_user, ForgeNexus.Accounts.User
    belongs_to :author, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:profile_user_id, :author_id, :body_bbcode, :body_html, :is_hidden])
    |> validate_required([:profile_user_id, :author_id, :body_bbcode, :body_html])
    |> validate_length(:body_bbcode, min: 1, max: 2000)
  end
end
