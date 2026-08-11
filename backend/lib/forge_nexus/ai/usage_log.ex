defmodule ForgeNexus.AI.UsageLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ai_usage_logs" do
    field :feature, :string
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :cost_cents, :integer, default: 0
    field :latency_ms, :integer
    field :metadata, :map, default: %{}
    field :error, :string

    belongs_to :provider, ForgeNexus.AI.Provider
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(usage_log, attrs) do
    usage_log
    |> cast(attrs, [
      :feature,
      :input_tokens,
      :output_tokens,
      :cost_cents,
      :latency_ms,
      :metadata,
      :error,
      :provider_id,
      :user_id
    ])
    |> validate_required([:feature, :provider_id])
    |> foreign_key_constraint(:provider_id)
    |> foreign_key_constraint(:user_id)
  end
end
