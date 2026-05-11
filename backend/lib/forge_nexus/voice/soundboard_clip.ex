defmodule ForgeNexus.Voice.SoundboardClip do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @max_duration_ms 30_000
  @max_size_bytes 2 * 1024 * 1024

  schema "soundboard_clips" do
    field :name, :string
    field :emoji, :string
    field :audio_url, :string
    field :duration_ms, :integer
    field :size_bytes, :integer
    field :play_count, :integer, default: 0
    field :is_global, :boolean, default: false

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :room, ForgeNexus.Voice.Room
    belongs_to :uploaded_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(clip, attrs) do
    clip
    |> cast(attrs, [:room_id, :uploaded_by_id, :name, :emoji, :audio_url,
                     :duration_ms, :size_bytes, :is_global])
    |> validate_required([:name, :audio_url])
    |> validate_length(:name, max: 64)
    |> validate_length(:emoji, max: 8)
    |> validate_number(:duration_ms, less_than_or_equal_to: @max_duration_ms)
    |> validate_number(:size_bytes, less_than_or_equal_to: @max_size_bytes)
  end
end
