defmodule ForgeNexus.ThreadTypes.WikiEdit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wiki_edits" do
    field :body, :string
    field :body_html, :string
    field :edit_summary, :string
    field :revision_number, :integer

    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:body, :body_html, :edit_summary, :revision_number, :thread_id, :user_id])
    |> validate_required([:body, :revision_number, :thread_id, :user_id])
  end
end
