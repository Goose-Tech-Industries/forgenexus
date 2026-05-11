defmodule ForgeNexus.Admin.Announcement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @display_locations ~w(banner forum all)

  schema "announcements" do
    field :title, :string
    field :body, :string
    field :body_html, :string
    field :priority, :integer, default: 0
    field :display_location, :string, default: "banner"
    field :target_group_ids, {:array, :binary_id}, default: []
    field :is_dismissible, :boolean, default: true
    field :is_active, :boolean, default: true
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime

    belongs_to :forum, ForgeNexus.Forums.Forum
    belongs_to :created_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(announcement, attrs) do
    announcement
    |> cast(attrs, [:title, :body, :body_html, :priority, :display_location, :forum_id,
                    :target_group_ids, :is_dismissible, :is_active, :starts_at, :ends_at, :created_by_id])
    |> validate_required([:title, :body])
    |> validate_inclusion(:display_location, @display_locations)
  end
end
