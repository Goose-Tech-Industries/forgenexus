defmodule ForgeNexus.Applications.ApplicationForm do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "staff_application_forms" do
    field :title, :string
    field :description, :string
    field :fields, {:array, :map}, default: []
    field :is_open, :boolean, default: true
    field :min_posts, :integer, default: 0
    field :min_days_member, :integer, default: 0

    belongs_to :target_group, ForgeNexus.Accounts.UserGroup
    timestamps()
  end

  def changeset(form, attrs) do
    form
    |> cast(attrs, [:title, :description, :fields, :target_group_id, :is_open, :min_posts, :min_days_member])
    |> validate_required([:title])
  end
end
