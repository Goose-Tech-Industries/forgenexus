defmodule ForgeNexus.Plugins.JsRuntime.Executor do
  @moduledoc """
  Orchestrates JS plugin execution: rate limiting, Deno execution, command processing, and recording.
  """

  require Logger

  alias ForgeNexus.Plugins.JsPlugins
  alias ForgeNexus.Plugins.JsRuntime.{Runner, CommandProcessor}

  def execute_plugin(plugin_id, trigger_data, triggered_by_id \\ nil) do
    plugin = JsPlugins.get_js_plugin!(plugin_id)

    # Rate limit check
    JsPlugins.check_rate_limit!(plugin_id)

    started_at = DateTime.utc_now()

    execution =
      JsPlugins.record_js_plugin_execution(plugin_id, %{
        trigger_type: trigger_type(trigger_data),
        trigger_data: normalize_trigger_data(trigger_data),
        started_at: started_at,
        triggered_by_id: triggered_by_id
      })

    permissions = Map.get(plugin.manifest, "permissions", [])
    allowed_domains = Map.get(plugin.manifest, "allowed_domains", [])

    result =
      Runner.execute(
        plugin.code,
        normalize_trigger_data(trigger_data),
        plugin.settings,
        permissions,
        allowed_domains: allowed_domains
      )

    finished_at = DateTime.utc_now()
    duration_ms = DateTime.diff(finished_at, started_at, :millisecond)

    case result do
      {:ok, %{"output" => output, "logs" => logs, "commands" => commands}} ->
        # Process side-effect commands
        command_results = CommandProcessor.process(commands, plugin, triggered_by_id)

        JsPlugins.complete_js_plugin_execution(execution.id, %{
          status: "completed",
          result: %{"output" => output, "command_results" => command_results},
          logs: logs,
          finished_at: finished_at,
          duration_ms: duration_ms
        })

        JsPlugins.update_plugin_execution_stats(plugin_id)

        Logger.info(
          "[JsRuntime.Executor] Plugin #{plugin.name} completed in #{duration_ms}ms " <>
            "(#{length(commands)} commands, #{length(logs)} logs)"
        )

        {:ok, output}

      {:error, message} ->
        JsPlugins.complete_js_plugin_execution(execution.id, %{
          status: "failed",
          result: %{"error" => message},
          logs: [],
          finished_at: finished_at,
          duration_ms: duration_ms
        })

        JsPlugins.update_plugin_execution_stats(plugin_id)

        Logger.warning("[JsRuntime.Executor] Plugin #{plugin.name} failed: #{message}")

        {:error, message}
    end
  rescue
    e ->
      Logger.error("[JsRuntime.Executor] Plugin #{plugin_id} crashed: #{inspect(e)}")
      {:error, "Plugin execution crashed: #{Exception.message(e)}"}
  end

  defp trigger_type(%{type: type}), do: type
  defp trigger_type(%{"type" => type}), do: type
  defp trigger_type(_), do: "manual"

  defp normalize_trigger_data(data) when is_map(data), do: data
  defp normalize_trigger_data(_), do: %{}
end
