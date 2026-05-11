defmodule ForgeNexus.Social.Icebreaker do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ~w(would_you_rather trivia hot_take this_or_that unpopular_opinion)

  schema "icebreaker_challenges" do
    field :type, :string
    field :question, :string
    field :options, {:array, :map}
    field :sender_answer, :string
    field :recipient_answer, :string
    field :points_reward, :integer, default: 5
    field :status, :string, default: "pending"

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :sender, ForgeNexus.Accounts.User
    belongs_to :recipient, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [:community_id, :sender_id, :recipient_id, :type, :question,
                     :options, :sender_answer, :recipient_answer, :points_reward, :status])
    |> validate_required([:sender_id, :recipient_id, :type, :question])
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:status, ~w(pending answered expired))
  end

  def types, do: @types

  def random_questions do
    %{
      "would_you_rather" => [
        "Would you rather have unlimited money or unlimited time?",
        "Would you rather be able to fly or be invisible?",
        "Would you rather live in the past or the future?",
        "Would you rather have no internet or no phone for a month?",
        "Would you rather fight 100 duck-sized horses or 1 horse-sized duck?"
      ],
      "this_or_that" => [
        "Cats or dogs?", "Morning or night?", "Beach or mountains?",
        "Coffee or tea?", "Books or movies?", "Summer or winter?",
        "Pizza or tacos?", "Marvel or DC?", "Console or PC?"
      ],
      "hot_take" => [
        "The last movie you watched was actually good",
        "Cereal is a soup",
        "The best music was made before 2010",
        "Remote work is better than office work",
        "Water is the best drink ever invented"
      ]
    }
  end
end
