defmodule ForgeNexus.Plugins.JsPlugin do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(draft active disabled error)

  schema "js_plugins" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :version, :string, default: "1.0.0"
    field :status, :string, default: "draft"
    field :code, :string, default: ""
    field :manifest, :map, default: %{}
    field :settings, :map, default: %{}
    field :error_message, :string
    field :last_executed_at, :utc_datetime
    field :execution_count, :integer, default: 0

    belongs_to :created_by, ForgeNexus.Accounts.User
    has_many :executions, ForgeNexus.Plugins.JsPluginExecution

    timestamps()
  end

  def changeset(plugin, attrs) do
    plugin
    |> cast(attrs, [:name, :slug, :description, :version, :code, :manifest, :settings, :created_by_id])
    |> validate_required([:name, :slug, :created_by_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_manifest()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:created_by_id)
  end

  def status_changeset(plugin, attrs) do
    plugin
    |> cast(attrs, [:status, :error_message])
    |> validate_inclusion(:status, @statuses)
  end

  def execution_changeset(plugin, attrs) do
    plugin
    |> cast(attrs, [:last_executed_at, :execution_count])
  end

  def settings_changeset(plugin, attrs) do
    plugin
    |> cast(attrs, [:settings])
  end

  defp validate_manifest(changeset) do
    case get_field(changeset, :manifest) do
      nil -> changeset
      manifest ->
        hooks = Map.get(manifest, "hooks", [])
        if is_list(hooks) do
          changeset
        else
          add_error(changeset, :manifest, "hooks must be a list")
        end
    end
  end
end
