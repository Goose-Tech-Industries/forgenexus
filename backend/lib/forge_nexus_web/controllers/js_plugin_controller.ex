defmodule ForgeNexusWeb.JsPluginController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Plugins.JsPlugins
  alias ForgeNexus.Plugins.JsRuntime.Executor

  def list_plugins(conn, params) do
    opts = [
      status: Map.get(params, "status"),
      limit: parse_int(params, "limit", 25),
      offset: parse_int(params, "offset", 0)
    ]

    plugins = JsPlugins.list_js_plugins(opts)
    conn |> json(%{plugins: Enum.map(plugins, &plugin_json/1)})
  end

  def show_plugin(conn, %{"id" => id}) do
    plugin = JsPlugins.get_js_plugin!(id)
    conn |> json(%{plugin: plugin_detail_json(plugin)})
  end

  def create_plugin(conn, %{"plugin" => plugin_params}) do
    user = Guardian.Plug.current_resource(conn)

    slug =
      (Map.get(plugin_params, "name") || "")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s-]/, "")
      |> String.replace(~r/\s+/, "-")
      |> String.trim("-")

    attrs = %{
      name: Map.get(plugin_params, "name"),
      slug: slug,
      description: Map.get(plugin_params, "description"),
      version: Map.get(plugin_params, "version", "1.0.0"),
      code: Map.get(plugin_params, "code", ""),
      manifest: Map.get(plugin_params, "manifest", %{}),
      settings: Map.get(plugin_params, "settings", %{}),
      created_by_id: user.id
    }

    case JsPlugins.create_js_plugin(attrs) do
      {:ok, plugin} ->
        plugin = JsPlugins.get_js_plugin!(plugin.id)
        conn |> put_status(:created) |> json(%{plugin: plugin_detail_json(plugin)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def update_plugin(conn, %{"id" => id, "plugin" => plugin_params}) do
    attrs =
      plugin_params
      |> Map.take(["name", "description", "version", "code", "manifest", "settings"])
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
      |> Map.new()

    attrs =
      if Map.has_key?(attrs, :name) do
        slug =
          attrs[:name]
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9\s-]/, "")
          |> String.replace(~r/\s+/, "-")
          |> String.trim("-")

        Map.put(attrs, :slug, slug)
      else
        attrs
      end

    case JsPlugins.update_js_plugin(id, attrs) do
      {:ok, plugin} ->
        plugin = JsPlugins.get_js_plugin!(plugin.id)
        conn |> json(%{plugin: plugin_detail_json(plugin)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def delete_plugin(conn, %{"id" => id}) do
    case JsPlugins.delete_js_plugin(id) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete plugin"})
    end
  end

  def activate_plugin(conn, %{"id" => id}) do
    case JsPlugins.activate_js_plugin(id) do
      {:ok, plugin} ->
        plugin = ForgeNexus.Repo.preload(plugin, [:created_by])
        conn |> json(%{plugin: plugin_json(plugin)})

      {:error, errors} when is_list(errors) ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: Enum.join(errors, "; ")})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def deactivate_plugin(conn, %{"id" => id}) do
    case JsPlugins.deactivate_js_plugin(id) do
      {:ok, plugin} ->
        plugin = ForgeNexus.Repo.preload(plugin, [:created_by])
        conn |> json(%{plugin: plugin_json(plugin)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def execute_plugin(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Executor.execute_plugin(id, %{"type" => "manual"}, user.id) do
      {:ok, output} ->
        conn |> json(%{status: "completed", output: output})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: reason})
    end
  end

  def list_executions(conn, %{"id" => id} = params) do
    opts = [
      plugin_id: id,
      status: Map.get(params, "status"),
      limit: parse_int(params, "limit", 25),
      offset: parse_int(params, "offset", 0)
    ]

    executions = JsPlugins.list_js_plugin_executions(opts)
    conn |> json(%{executions: Enum.map(executions, &execution_json/1)})
  end

  # =====================
  # JSON serializers
  # =====================

  defp plugin_json(plugin) do
    %{
      id: plugin.id,
      name: plugin.name,
      slug: plugin.slug,
      description: plugin.description,
      version: plugin.version,
      status: plugin.status,
      manifest: plugin.manifest,
      error_message: plugin.error_message,
      last_executed_at: plugin.last_executed_at,
      execution_count: plugin.execution_count,
      inserted_at: plugin.inserted_at,
      updated_at: plugin.updated_at,
      created_by: if(Ecto.assoc_loaded?(plugin.created_by), do: user_mini_json(plugin.created_by))
    }
  end

  defp plugin_detail_json(plugin) do
    Map.merge(plugin_json(plugin), %{
      code: plugin.code,
      settings: plugin.settings
    })
  end

  defp execution_json(exec) do
    %{
      id: exec.id,
      js_plugin_id: exec.js_plugin_id,
      status: exec.status,
      trigger_type: exec.trigger_type,
      trigger_data: exec.trigger_data,
      result: exec.result,
      logs: exec.logs,
      started_at: exec.started_at,
      finished_at: exec.finished_at,
      duration_ms: exec.duration_ms,
      inserted_at: exec.inserted_at
    }
  end

  defp user_mini_json(nil), do: nil

  defp user_mini_json(user),
    do: %{id: user.id, username: user.username, slug: user.slug, avatar_url: user.avatar_url}

  defp parse_int(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      val when is_binary(val) -> safe_to_integer(val, default)
      val when is_integer(val) -> val
    end
  end

  defp changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  defp changeset_errors(error), do: inspect(error)

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end

  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default
end
