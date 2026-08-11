defmodule ForgeNexus.AI.ModerationAnalysis do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ai_moderation_analyses" do
    field :suggested_action, :string
    field :confidence, :float
    field :reasoning, :string
    field :context_summary, :string
    field :mod_decision, :string
    field :was_accepted, :boolean

    belongs_to :report, ForgeNexus.Moderation.Report
    belongs_to :post, ForgeNexus.Forums.Post
    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :mod, ForgeNexus.Accounts.User
    belongs_to :provider, ForgeNexus.AI.Provider

    timestamps()
  end

  def changeset(moderation_analysis, attrs) do
    moderation_analysis
    |> cast(attrs, [
      :suggested_action,
      :confidence,
      :reasoning,
      :context_summary,
      :mod_decision,
      :was_accepted,
      :report_id,
      :post_id,
      :thread_id,
      :mod_id,
      :provider_id
    ])
    |> validate_required([:suggested_action, :confidence, :reasoning])
    |> foreign_key_constraint(:report_id)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:thread_id)
    |> foreign_key_constraint(:mod_id)
    |> foreign_key_constraint(:provider_id)
  end
end
