defmodule ForgeNexus.Applications.StaffApplication do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "staff_applications" do
    field :answers, {:array, :map}, default: []
    field :status, :string, default: "pending"
    field :review_note, :string
    field :reviewed_at, :utc_datetime

    belongs_to :form, ForgeNexus.Applications.ApplicationForm
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :reviewer, ForgeNexus.Accounts.User
    timestamps()
  end

  def changeset(app, attrs) do
    app
    |> cast(attrs, [
      :form_id,
      :user_id,
      :answers,
      :status,
      :reviewer_id,
      :review_note,
      :reviewed_at
    ])
    |> validate_required([:form_id, :user_id, :answers])
    |> validate_inclusion(:status, ~w(pending under_review accepted denied))
  end
end
