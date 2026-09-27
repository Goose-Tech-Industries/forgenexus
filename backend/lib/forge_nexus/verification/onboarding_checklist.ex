defmodule ForgeNexus.Verification.OnboardingChecklist do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "onboarding_checklists" do
    field :checklist_data, :map, default: %{}
    field :completed_count, :integer, default: 0
    field :total_count, :integer, default: 0
    field :completed_at, :utc_datetime

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(checklist, attrs) do
    checklist
    |> cast(attrs, [:checklist_data, :completed_count, :total_count, :completed_at, :user_id])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end
end
