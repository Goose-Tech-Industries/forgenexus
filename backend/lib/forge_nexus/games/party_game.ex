defmodule ForgeNexus.Games.PartyGame do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @game_types ~w(
    cards_against_humanity
    trivia
    would_you_rather
    drawing_guess
    word_chain
    story_builder
    hot_takes
    mafia
  )

  @statuses ~w(lobby playing round_end game_over cancelled)

  schema "party_games" do
    field :game_type, :string
    field :status, :string, default: "lobby"
    field :settings, :map, default: %{}
    field :state, :map, default: %{}
    field :max_players, :integer, default: 10
    field :round_number, :integer, default: 0
    field :total_rounds, :integer, default: 5
    field :wager_enabled, :boolean, default: false
    field :wager_per_round, :integer, default: 0

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :room, ForgeNexus.Voice.Room
    belongs_to :host, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [
      :community_id,
      :room_id,
      :host_id,
      :game_type,
      :status,
      :settings,
      :state,
      :max_players,
      :round_number,
      :total_rounds,
      :wager_enabled,
      :wager_per_round
    ])
    |> validate_required([:game_type])
    |> validate_inclusion(:game_type, @game_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:max_players, greater_than: 1, less_than_or_equal_to: 50)
  end

  def game_types, do: @game_types
end
