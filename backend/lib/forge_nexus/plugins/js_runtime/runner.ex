defmodule ForgeNexus.Plugins.JsRuntime.Runner do
  @moduledoc """
  Executes JS/TS plugin code in a sandboxed Deno subprocess.
  Builds a temp file from SDK + plugin code + epilogue, runs it with strict Deno flags,
  and returns the parsed JSON output.
  """

  require Logger

  @timeout_ms 30_000
  @max_output_bytes 1_048_576
  @deno_path Application.compile_env(:forge_nexus, :deno_path, "deno")

  def execute(plugin_code, trigger_data, settings, permissions, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @timeout_ms)
    allowed_domains = Keyword.get(opts, :allowed_domains, [])

    sdk_path = Path.join(:code.priv_dir(:forge_nexus), "js_runtime/sdk.ts")
    epilogue_path = Path.join(:code.priv_dir(:forge_nexus), "js_runtime/epilogue.ts")

    sdk_content = File.read!(sdk_path)
    epilogue_content = File.read!(epilogue_path)

    full_script = sdk_content <> "\n" <> plugin_code <> "\n" <> epilogue_content

    # Write to temp file
    tmp_dir = System.tmp_dir!()
    file_id = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    script_path = Path.join(tmp_dir, "fn_plugin_#{file_id}.ts")

    File.write!(script_path, full_script)

    input_json =
      Jason.encode!(%{
        trigger: trigger_data,
        settings: settings,
        permissions: permissions
      })

    # Build deno flags with strict sandbox
    deno_flags =
      [
        "run",
        "--no-prompt",
        "--deny-env",
        "--deny-write",
        "--deny-ffi",
        "--deny-run",
        "--allow-read=#{script_path}"
      ] ++ net_flags(allowed_domains) ++ [script_path, input_json]

    try do
      task =
        Task.async(fn ->
          try do
            System.cmd(@deno_path, deno_flags, stderr_to_stdout: false)
          rescue
            e -> {:error, Exception.message(e)}
          end
        end)

      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, {:error, msg}} ->
          {:error, "Failed to start Deno: #{msg}"}

        {:ok, {stdout, 0}} ->
          parse_output(stdout)

        {:ok, {stdout, exit_code}} ->
          error_msg = String.slice(stdout, 0, 500)
          Logger.warning("[JsRuntime.Runner] Deno exited with code #{exit_code}: #{error_msg}")
          {:error, "Plugin execution failed (exit code #{exit_code}): #{error_msg}"}

        nil ->
          Logger.warning("[JsRuntime.Runner] Plugin execution timed out after #{timeout}ms")
          {:error, "Plugin execution timed out after #{timeout}ms"}
      end
    after
      File.rm(script_path)
    end
  end

  defp net_flags([]), do: ["--deny-net"]
  defp net_flags(domains) when is_list(domains) do
    ["--allow-net=#{Enum.join(domains, ",")}"]
  end

  defp parse_output(stdout) when byte_size(stdout) > @max_output_bytes do
    {:error, "Plugin output exceeded maximum size (#{@max_output_bytes} bytes)"}
  end

  defp parse_output(stdout) do
    lines = String.split(stdout, "\n", trim: true)

    case List.last(lines) do
      nil ->
        {:error, "No output from plugin"}

      json_line ->
        case Jason.decode(json_line) do
          {:ok, %{"output" => output, "logs" => logs, "commands" => commands}}
          when is_map(output) and is_list(logs) and is_list(commands) ->
            {:ok, %{"output" => output, "logs" => Enum.take(logs, 100), "commands" => commands}}

          {:ok, _} ->
            {:error, "Invalid output format from plugin"}

          {:error, _} ->
            {:error, "Invalid JSON output from plugin: #{String.slice(json_line, 0, 200)}"}
        end
    end
  end
end
