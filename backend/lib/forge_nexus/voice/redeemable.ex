defmodule ForgeNexus.Voice.Redeemable do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ~w(
    sound_effect visual_effect highlighted_message game_command custom_flow webhook
    tts_message temp_custom_title temp_username_color queue_priority
    choose_next_video timeout_user raid screen_takeover
    gift_achievement emote_unlock slow_mode_toggle
    dare_challenge hydration_check change_room_title dj_request
    spotlight shoutout emoji_rain lucky_wheel banner_message
    collab_request pet_spawn quest_trigger force_poll
    gift_points combo_multiplier
  )

  schema "room_redeemables" do
    field :name, :string
    field :description, :string
    field :emoji, :string
    field :cost, :integer
    field :type, :string
    field :config, :map, default: %{}
    field :cooldown_seconds, :integer, default: 0
    field :max_per_stream, :integer
    field :max_per_user_per_stream, :integer
    field :is_enabled, :boolean, default: true
    field :requires_text, :boolean, default: false
    field :position, :integer, default: 0

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :room, ForgeNexus.Voice.Room
    belongs_to :created_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(redeemable, attrs) do
    redeemable
    |> cast(attrs, [
      :room_id,
      :created_by_id,
      :name,
      :description,
      :emoji,
      :cost,
      :type,
      :config,
      :cooldown_seconds,
      :max_per_stream,
      :max_per_user_per_stream,
      :is_enabled,
      :requires_text,
      :position
    ])
    |> validate_required([:name, :cost, :type])
    |> validate_inclusion(:type, @types)
    |> validate_number(:cost, greater_than: 0)
    |> validate_number(:cooldown_seconds, greater_than_or_equal_to: 0)
    |> validate_length(:name, max: 100)
    |> validate_length(:emoji, max: 8)
  end

  def types, do: @types
end
