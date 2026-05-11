defmodule ForgeNexus.Voice.Clip do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "voice_clips" do
    field :title, :string
    field :start_ms, :integer
    field :end_ms, :integer
    field :view_count, :integer, default: 0
    field :is_public, :boolean, default: true

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :recording, ForgeNexus.Voice.Recording
    belongs_to :created_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(clip, attrs) do
    clip
    |> cast(attrs, [:recording_id, :created_by_id, :title, :start_ms, :end_ms, :is_public])
    |> validate_required([:recording_id, :start_ms, :end_ms])
    |> validate_number(:start_ms, greater_than_or_equal_to: 0)
    |> validate_number(:end_ms, greater_than: 0)
    |> validate_clip_range()
  end

  defp validate_clip_range(changeset) do
    start_ms = get_field(changeset, :start_ms)
    end_ms = get_field(changeset, :end_ms)

    cond do
      is_nil(start_ms) or is_nil(end_ms) -> changeset
      end_ms <= start_ms -> add_error(changeset, :end_ms, "must be after start")
      end_ms - start_ms > 120_000 -> add_error(changeset, :end_ms, "clip cannot exceed 2 minutes")
      end_ms - start_ms < 1_000 -> add_error(changeset, :end_ms, "clip must be at least 1 second")
      true -> changeset
    end
  end
end
