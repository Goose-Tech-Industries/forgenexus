defmodule ForgeNexus.Forums.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "posts" do
    field :body, :string
    field :body_html, :string
    field :is_first_post, :boolean, default: false
    field :is_hidden, :boolean, default: false
    field :is_approved, :boolean, default: true
    field :is_edited, :boolean, default: false
    field :edited_at, :utc_datetime
    field :edit_count, :integer, default: 0
    field :ip_address, :string
    field :like_count, :integer, default: 0
    field :position, :integer, default: 0

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :edited_by, ForgeNexus.Accounts.User
    belongs_to :reply_to, __MODULE__

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:body, :body_html, :ip_address, :thread_id, :user_id, :reply_to_id, :position, :is_first_post])
    |> validate_required([:body, :thread_id, :user_id])
    |> validate_length(:body, min: 1, max: 50_000)
    |> foreign_key_constraint(:thread_id)
    |> foreign_key_constraint(:user_id)
  end

  def mod_changeset(post, attrs) do
    post
    |> cast(attrs, [:body, :body_html, :is_hidden, :is_approved])
  end

  def edit_changeset(post, attrs) do
    post
    |> cast(attrs, [:body, :body_html, :edited_by_id])
    |> validate_required([:body])
    |> put_change(:is_edited, true)
    |> put_change(:edited_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> increment_edit_count()
  end

  defp increment_edit_count(changeset) do
    case changeset.data.edit_count do
      nil -> put_change(changeset, :edit_count, 1)
      count -> put_change(changeset, :edit_count, count + 1)
    end
  end
end
