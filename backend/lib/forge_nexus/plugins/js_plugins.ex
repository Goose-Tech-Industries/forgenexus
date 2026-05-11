defmodule ForgeNexus.Plugins.JsPlugins do
  @moduledoc """
  Context for managing JavaScript/TypeScript plugins.
  Handles CRUD, activation, hook queries, execution recording, and rate limiting.
  """

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Plugins.{JsPlugin, JsPluginExecution, JsPluginRateLimit}

  @max_executions_per_hour 100

  # =====================
  # CRUD
  # =====================

  def create_js_plugin(attrs) do
    %JsPlugin{}
    |> JsPlugin.changeset(attrs)
    |> Repo.insert()
  end

  def update_js_plugin(id, attrs) do
    Repo.get!(JsPlugin, id)
    |> JsPlugin.changeset(attrs)
    |> Repo.update()
  end

  def update_js_plugin_settings(id, settings) do
    Repo.get!(JsPlugin, id)
    |> JsPlugin.settings_changeset(%{settings: settings})
    |> Repo.update()
  end

  def delete_js_plugin(id) do
    Repo.get!(JsPlugin, id)
    |> Repo.delete()
  end

  def get_js_plugin!(id) do
    Repo.get!(JsPlugin, id) |> Repo.preload([:created_by])
  end

  def list_js_plugins(opts \\ []) do
    status = Keyword.get(opts, :status)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from p in JsPlugin,
        order_by: [desc: :updated_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:created_by]

    query = if status, do: where(query, [p], p.status == ^status), else: query

    Repo.all(query)
  end

  # =====================
  # Activation
  # =====================

  def activate_js_plugin(id) do
    plugin = Repo.get!(JsPlugin, id)
    errors = validate_plugin(plugin)

    if errors == [] do
      plugin
      |> JsPlugin.status_changeset(%{status: "active", error_message: nil})
      |> Repo.update()
    else
      plugin
      |> JsPlugin.status_changeset(%{status: "error", error_message: Enum.join(errors, "; ")})
      |> Repo.update()

      {:error, errors}
    end
  end

  def deactivate_js_plugin(id) do
    Repo.get!(JsPlugin, id)
    |> JsPlugin.status_changeset(%{status: "disabled"})
    |> Repo.update()
  end

  defp validate_plugin(plugin) do
    errors = []
    errors = if plugin.code == "" or is_nil(plugin.code), do: ["Plugin code cannot be empty" | errors], else: errors
    hooks = Map.get(plugin.manifest, "hooks", [])
    errors = if hooks == [], do: ["Plugin must register at least one hook" | errors], else: errors
    errors
  end

  # =====================
  # Hook Queries
  # =====================

  def get_active_js_plugins_for_hook(hook_name) do
    from(p in JsPlugin,
      where: p.status == "active",
      where: fragment("? @> ?", p.manifest, ^%{"hooks" => [hook_name]})
    )
    |> Repo.all()
  end

  # =====================
  # Executions
  # =====================

  def record_js_plugin_execution(plugin_id, attrs) do
    %JsPluginExecution{}
    |> JsPluginExecution.changeset(Map.put(attrs, :js_plugin_id, plugin_id))
    |> Repo.insert!()
  end

  def complete_js_plugin_execution(execution_id, attrs) do
    Repo.get!(JsPluginExecution, execution_id)
    |> JsPluginExecution.complete_changeset(attrs)
    |> Repo.update!()
  end

  def update_plugin_execution_stats(plugin_id) do
    plugin = Repo.get!(JsPlugin, plugin_id)

    plugin
    |> JsPlugin.execution_changeset(%{
      last_executed_at: DateTime.utc_now(),
      execution_count: plugin.execution_count + 1
    })
    |> Repo.update!()
  end

  def list_js_plugin_executions(opts \\ []) do
    plugin_id = Keyword.get(opts, :plugin_id)
    status = Keyword.get(opts, :status)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from e in JsPluginExecution,
        order_by: [desc: :inserted_at],
        limit: ^limit,
        offset: ^offset

    query = if plugin_id, do: where(query, [e], e.js_plugin_id == ^plugin_id), else: query
    query = if status, do: where(query, [e], e.status == ^status), else: query

    Repo.all(query)
  end

  def get_js_plugin_execution!(id) do
    Repo.get!(JsPluginExecution, id)
  end

  # =====================
  # Rate Limiting
  # =====================

  def check_rate_limit!(plugin_id) do
    now = DateTime.utc_now()
    window_start = DateTime.truncate(now, :second)
    |> Map.put(:minute, 0)
    |> Map.put(:second, 0)

    rate_limit =
      from(r in JsPluginRateLimit,
        where: r.js_plugin_id == ^plugin_id and r.window_start == ^window_start
      )
      |> Repo.one()

    case rate_limit do
      nil ->
        %JsPluginRateLimit{}
        |> JsPluginRateLimit.changeset(%{
          js_plugin_id: plugin_id,
          window_start: window_start,
          execution_count: 1
        })
        |> Repo.insert!()
        :ok

      %{execution_count: count} when count >= @max_executions_per_hour ->
        raise "Rate limit exceeded: #{count} executions in the current hour (max #{@max_executions_per_hour})"

      rate_limit ->
        rate_limit
        |> Ecto.Changeset.change(execution_count: rate_limit.execution_count + 1)
        |> Repo.update!()
        :ok
    end
  end
end
