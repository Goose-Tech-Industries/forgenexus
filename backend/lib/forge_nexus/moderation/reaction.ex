defmodule ForgeNexus.Moderation.Reaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "reactions" do
    field :type, :string, default: "like"
    field :reactable_type, :string
    field :reactable_id, :binary_id

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:type, :reactable_type, :reactable_id, :user_id])
    |> validate_required([:type, :reactable_type, :reactable_id, :user_id])
    |> validate_inclusion(:type, ["like", "thanks", "haha", "wow", "sad", "angry"])
    |> validate_inclusion(:reactable_type, ["post", "message"])
    |> unique_constraint([:user_id, :reactable_type, :reactable_id, :type])
  end
end
