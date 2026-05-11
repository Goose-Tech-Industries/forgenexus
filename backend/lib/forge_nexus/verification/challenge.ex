defmodule ForgeNexus.Verification.Challenge do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "verification_challenges" do
    field :challenge_type, :string
    field :challenge_data, :map, default: %{}
    field :expected_answer, :string
    field :status, :string, default: "pending"
    field :attempts, :integer, default: 0
    field :max_attempts, :integer, default: 3
    field :expires_at, :utc_datetime

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [:challenge_type, :challenge_data, :expected_answer, :status, :attempts, :max_attempts, :expires_at, :user_id])
    |> validate_required([:challenge_type, :expected_answer, :user_id])
    |> validate_inclusion(:challenge_type, ~w(math_captcha text_captcha email_verify question))
    |> validate_inclusion(:status, ~w(pending completed failed expired))
  end
end
