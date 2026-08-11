defmodule ForgeNexus.Tournaments.Tournament do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tournaments" do
    field :name, :string
    field :description, :string
    field :format, :string, default: "single_elimination"
    field :status, :string, default: "registration"
    field :max_participants, :integer
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :prize_pool, :map, default: %{}
    field :rules, :string

    belongs_to :created_by, ForgeNexus.Accounts.User
    has_many :participants, ForgeNexus.Tournaments.Participant
    has_many :matches, ForgeNexus.Tournaments.Match

    timestamps()
  end

  def changeset(tournament, attrs) do
    tournament
    |> cast(attrs, [
      :name,
      :description,
      :format,
      :status,
      :max_participants,
      :starts_at,
      :ends_at,
      :prize_pool,
      :rules,
      :created_by_id
    ])
    |> validate_required([:name, :format])
    |> validate_inclusion(:format, ~w(single_elimination double_elimination round_robin swiss))
    |> validate_inclusion(:status, ~w(registration active in_progress completed cancelled))
  end
end
