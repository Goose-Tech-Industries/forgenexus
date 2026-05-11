defmodule ForgeNexus.Plugins.Flow do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(draft active disabled error)
  @tiers ~w(nocode javascript native)
  @trigger_types ~w(on_post_created on_thread_created on_user_joined on_user_left on_reaction_added on_chat_message scheduled manual webhook_received on_custom_event on_slash_command)

  schema "flows" do
    field :name, :string
    field :description, :string
    field :slug, :string
    field :status, :string, default: "draft"
    field :tier, :string, default: "nocode"
    field :version, :integer, default: 1
    field :trigger_type, :string
    field :trigger_config, :map, default: %{}
    field :settings, :map, default: %{}
    field :error_message, :string
    field :last_executed_at, :utc_datetime
    field :execution_count, :integer, default: 0

    belongs_to :created_by, ForgeNexus.Accounts.User
    has_many :nodes, ForgeNexus.Plugins.FlowNode
    has_many :edges, ForgeNexus.Plugins.FlowEdge
    has_many :executions, ForgeNexus.Plugins.FlowExecution

    timestamps()
  end

  def changeset(flow, attrs) do
    flow
    |> cast(attrs, [:name, :description, :slug, :status, :tier, :trigger_type, :trigger_config, :settings, :created_by_id])
    |> validate_required([:name, :slug, :trigger_type, :created_by_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:tier, @tiers)
    |> validate_inclusion(:trigger_type, @trigger_types)
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:created_by_id)
  end

  def status_changeset(flow, attrs) do
    flow
    |> cast(attrs, [:status, :error_message])
    |> validate_inclusion(:status, @statuses)
  end

  def execution_changeset(flow, attrs) do
    flow
    |> cast(attrs, [:last_executed_at, :execution_count])
  end
end
