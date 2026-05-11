defmodule ForgeNexus.Plugins.SlashCommand do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "slash_commands" do
    field :name, :string
    field :description, :string
    field :category, :string, default: "general"
    field :enabled, :boolean, default: true
    field :cooldown_seconds, :integer, default: 0
    field :permission_level, :string, default: "everyone"
    field :usage_count, :integer, default: 0
    field :is_built_in, :boolean, default: false
    field :response_type, :string, default: "channel"

    belongs_to :flow, ForgeNexus.Plugins.Flow

    timestamps()
  end

  def changeset(command, attrs) do
    command
    |> cast(attrs, [:name, :description, :category, :flow_id, :enabled, :cooldown_seconds, :permission_level, :usage_count, :is_built_in, :response_type])
    |> validate_required([:name])
    |> validate_format(:name, ~r/^[a-z][a-z0-9_-]{0,31}$/, message: "must be lowercase alphanumeric, 1-32 chars")
    |> validate_inclusion(:permission_level, ~w(everyone member moderator admin))
    |> validate_inclusion(:response_type, ~w(channel ephemeral dm))
    |> unique_constraint(:name)
  end
end
