defmodule ForgeNexus.Verification.OnboardingChecklist do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "onboarding_checklists" do
    field :tasks, {:array, :map}, default: []
    field :is_complete, :boolean, default: false

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(checklist, attrs) do
    checklist
    |> cast(attrs, [:tasks, :is_complete, :user_id])
    |> validate_required([:user_id, :tasks])
    |> unique_constraint(:user_id)
  end
end
