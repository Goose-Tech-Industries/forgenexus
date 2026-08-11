defmodule ForgeNexus.Profiles.ProfileEndorsement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Strictly typed emoji set — stops "emoji as any Unicode" spam.
  @allowed_emoji ~w(🔥 ⚡ 🎨 ⚒️ 🛡️ 🧙 👑 💎 🌙 ☀️ 🌈 🎮 🎵 📚 ✨ 💯 🎭 🗡️ 🐉 🦊)

  schema "profile_endorsements" do
    field :emoji, :string

    belongs_to :profile_user, ForgeNexus.Accounts.User
    belongs_to :sender, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(endorsement, attrs) do
    endorsement
    |> cast(attrs, [:profile_user_id, :sender_id, :emoji])
    |> validate_required([:profile_user_id, :sender_id, :emoji])
    |> validate_inclusion(:emoji, @allowed_emoji)
    |> unique_constraint([:profile_user_id, :sender_id, :emoji],
      name: :profile_endorsements_profile_user_id_sender_id_emoji_index
    )
  end

  def allowed_emoji, do: @allowed_emoji
end
