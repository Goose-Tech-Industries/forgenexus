defmodule ForgeNexus.Governance.Proposal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "proposals" do
    field :title, :string
    field :body, :string
    field :body_html, :string
    field :type, :string
    field :status, :string, default: "discussion"
    field :discussion_ends_at, :utc_datetime
    field :voting_starts_at, :utc_datetime
    field :voting_ends_at, :utc_datetime
    field :threshold_type, :string, default: "simple_majority"
    field :min_participation, :integer
    field :is_binding, :boolean, default: false
    field :yes_count, :integer, default: 0
    field :no_count, :integer, default: 0
    field :abstain_count, :integer, default: 0
    field :result_summary, :string

    belongs_to :author, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :title, :body, :body_html, :type, :status, :discussion_ends_at,
      :voting_starts_at, :voting_ends_at, :threshold_type, :min_participation,
      :is_binding, :yes_count, :no_count, :abstain_count, :result_summary, :author_id
    ])
    |> validate_required([:title, :body, :type, :author_id])
  end
end
