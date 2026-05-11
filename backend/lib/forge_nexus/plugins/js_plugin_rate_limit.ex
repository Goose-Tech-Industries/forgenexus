defmodule ForgeNexus.Plugins.JsPluginRateLimit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "js_plugin_rate_limits" do
    field :window_start, :utc_datetime
    field :window_seconds, :integer, default: 3600
    field :execution_count, :integer, default: 0

    belongs_to :js_plugin, ForgeNexus.Plugins.JsPlugin

    timestamps()
  end

  def changeset(rate_limit, attrs) do
    rate_limit
    |> cast(attrs, [:js_plugin_id, :window_start, :window_seconds, :execution_count])
    |> validate_required([:js_plugin_id, :window_start])
    |> unique_constraint([:js_plugin_id, :window_start])
  end
end
