defmodule ForgeNexus.AutoMod.AutoModRule do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "automod_rules" do
    field :name, :string
    field :description, :string
    field :rule_type, :string
    field :config, :map, default: %{}
    field :action, :string, default: "flag"
    field :severity, :integer, default: 1
    field :is_enabled, :boolean, default: true
    field :sort_order, :integer, default: 0

    timestamps()
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :name,
      :description,
      :rule_type,
      :config,
      :action,
      :severity,
      :is_enabled,
      :sort_order
    ])
    |> validate_required([:name, :rule_type])
    |> validate_inclusion(:rule_type, ~w(keyword spam regex rate_limit custom))
    |> validate_inclusion(:action, ~w(flag warn delete mute ban))
  end
end
