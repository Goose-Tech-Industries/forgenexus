defmodule ForgeNexus.Plugins.JsRuntime.CommandProcessor do
  @moduledoc """
  Processes commands emitted by JS plugins during execution.
  Each command maps to an Elixir context function call, with permission checks.
  """

  require Logger

  alias ForgeNexus.{Forums, Chat}

  @max_commands 50

  @permission_map %{
    "create_post" => "create_post",
    "create_thread" => "create_post",
    "send_dm" => "send_dm",
    "send_notification" => "send_notification",
    "set_user_data" => "write_data",
    "get_user_data" => "read_data",
    "set_global_data" => "write_data",
    "get_global_data" => "read_data",
    "query_table" => "read_data_tables",
    "insert_row" => "write_data_tables",
    "update_row" => "write_data_tables",
    "delete_row" => "write_data_tables",
    "emit_event" => "emit_events",
    "award_points" => "manage_users",
    "set_custom_title" => "manage_users",
    "http_request" => "http_request"
  }

  def process(commands, plugin, triggered_by_id) when is_list(commands) do
    permissions = Map.get(plugin.manifest, "permissions", [])
    commands_to_run = Enum.take(commands, @max_commands)

    Enum.map(commands_to_run, fn command ->
      type = Map.get(command, "type")
      args = Map.get(command, "args", %{})

      required_perm = Map.get(@permission_map, type)

      cond do
        is_nil(type) ->
          %{type: "unknown", status: "error", error: "Missing command type"}

        required_perm && required_perm not in permissions ->
          %{type: type, status: "denied", error: "Permission '#{required_perm}' not granted"}

        true ->
          execute_command(type, args, triggered_by_id)
      end
    end)
  end

  def process(_, _, _), do: []

  defp execute_command("create_post", args, triggered_by_id) do
    try do
      case Forums.create_post(%{
             body: Map.get(args, "body", ""),
             thread_id: Map.get(args, "thread_id"),
             user_id: triggered_by_id
           }) do
        {:ok, post} -> %{type: "create_post", status: "ok", id: post.id}
        _error -> %{type: "create_post", status: "error", error: "Failed to create post"}
      end
    rescue
      e -> %{type: "create_post", status: "error", error: Exception.message(e)}
    end
  end

  defp execute_command("create_thread", args, triggered_by_id) do
    try do
      title = Map.get(args, "title", "")
      body = Map.get(args, "body", title)

      case Forums.create_thread(%{
             title: title,
             body: body,
             forum_id: Map.get(args, "forum_id"),
             user_id: triggered_by_id
           }) do
        {:ok, thread} -> %{type: "create_thread", status: "ok", id: thread.id}
        _error -> %{type: "create_thread", status: "error", error: "Failed to create thread"}
      end
    rescue
      e -> %{type: "create_thread", status: "error", error: Exception.message(e)}
    end
  end

  defp execute_command("send_dm", args, triggered_by_id) do
    try do
      recipient_id = Map.get(args, "user_id") || Map.get(args, "recipient_id")
      body = Map.get(args, "body", "")
      conversation_id = Map.get(args, "conversation_id")

      result =
        cond do
          conversation_id ->
            Chat.send_message(%{
              conversation_id: conversation_id,
              user_id: triggered_by_id,
              body: body
            })

          recipient_id && triggered_by_id ->
            {:ok, conversation} =
              Chat.get_or_create_direct_conversation(triggered_by_id, recipient_id)

            Chat.send_message(%{
              conversation_id: conversation.id,
              user_id: triggered_by_id,
              body: body
            })

          true ->
            {:error, :missing_recipient}
        end

      case result do
        {:ok, _msg} -> %{type: "send_dm", status: "ok"}
        {:error, _} -> %{type: "send_dm", status: "error", error: "Failed to send DM"}
      end
    rescue
      e -> %{type: "send_dm", status: "error", error: Exception.message(e)}
    end
  end

  defp execute_command("set_user_data", _args, _triggered_by_id) do
    # TODO: Implement JS plugin-scoped key-value storage
    %{type: "set_user_data", status: "skipped", error: "JS plugin data store not yet implemented"}
  end

  defp execute_command("set_global_data", _args, _triggered_by_id) do
    # TODO: Implement JS plugin-scoped key-value storage
    %{
      type: "set_global_data",
      status: "skipped",
      error: "JS plugin data store not yet implemented"
    }
  end

  defp execute_command("emit_event", args, _triggered_by_id) do
    try do
      event_name = Map.get(args, "event_name")
      payload = Map.get(args, "payload", %{})

      Phoenix.PubSub.broadcast(
        ForgeNexus.PubSub,
        "plugin:custom_event",
        {:custom_event, event_name, payload, nil}
      )

      %{type: "emit_event", status: "ok"}
    rescue
      e -> %{type: "emit_event", status: "error", error: Exception.message(e)}
    end
  end

  defp execute_command(type, _args, _triggered_by_id) do
    Logger.debug("[CommandProcessor] Unhandled command type: #{type}")
    %{type: type, status: "skipped", error: "Command type not yet implemented"}
  end
end
