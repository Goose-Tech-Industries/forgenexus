defmodule ForgeNexus.AI.ThreadSummary do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "thread_summaries" do
    field :summary, :string
    field :key_points, :map, default: %{}
    field :participant_count, :integer
    field :post_count_at_generation, :integer
    field :last_generated_at, :utc_datetime

    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :provider, ForgeNexus.AI.Provider

    timestamps()
  end

  def changeset(thread_summary, attrs) do
    thread_summary
    |> cast(attrs, [
      :summary,
      :key_points,
      :participant_count,
      :post_count_at_generation,
      :last_generated_at,
      :thread_id,
      :provider_id
    ])
    |> validate_required([:summary, :thread_id])
    |> foreign_key_constraint(:thread_id)
    |> foreign_key_constraint(:provider_id)
  end
end
