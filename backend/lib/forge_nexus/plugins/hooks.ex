defmodule ForgeNexus.Plugins.Hooks do
  @moduledoc """
  GenServer that subscribes to forum PubSub events and triggers
  matching active flows via the Executor.
  """

  use GenServer
  require Logger

  alias ForgeNexus.Plugins
  alias ForgeNexus.Plugins.Engine.Executor
  alias ForgeNexus.Plugins.JsPlugins
  alias ForgeNexus.Plugins.JsRuntime.Executor, as: JsExecutor

  @event_topics %{
    "forum:post_created" => "on_post_created",
    "forum:thread_created" => "on_thread_created",
    "forum:user_joined" => "on_user_joined",
    "forum:user_left" => "on_user_left",
    "forum:reaction_added" => "on_reaction_added",
    "chat:message_sent" => "on_chat_message",
    "forum:post_edited" => "on_post_edited",
    "forum:thread_solved" => "on_thread_solved",
    "moderation:user_banned" => "on_user_banned",
    "moderation:report_created" => "on_report_created",
    "achievement:unlocked" => "on_achievement_unlocked",
    "streak:milestone" => "on_streak_milestone",
    "economy:point_milestone" => "on_point_milestone",
    "collection:completed" => "on_collection_completed",
    "payment:received" => "on_payment_received",
    "subscription:changed" => "on_subscription_changed",
    "cooldown:expired" => "on_cooldown_expired",
    "poll:voted" => "on_poll_voted",
    "user:birthday" => "on_user_birthday",
    "slash:command" => "on_slash_command"
  }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to all forum event topics
    for {topic, _trigger_type} <- @event_topics do
      Phoenix.PubSub.subscribe(ForgeNexus.PubSub, topic)
    end

    # Subscribe to a single custom event topic (wildcard not supported by PubSub)
    Phoenix.PubSub.subscribe(ForgeNexus.PubSub, "plugin:custom_event")

    Logger.info(
      "[Plugins.Hooks] Started and subscribed to #{map_size(@event_topics)} event topics"
    )

    {:ok, %{}}
  end

  @impl true
  def handle_info({event_atom, data}, state) do
    event_string = Atom.to_string(event_atom)
    trigger_type = find_trigger_type(event_string)

    if trigger_type do
      spawn_flow_executions(trigger_type, data)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:custom_event, event_name, payload, emitter_flow_id}, state) do
    trigger_data = %{
      event_name: event_name,
      payload: payload,
      emitter_flow_id: emitter_flow_id
    }

    # Find flows that trigger on this specific custom event
    flows = Plugins.get_active_flows_for_trigger("on_custom_event")

    matching_flows =
      Enum.filter(flows, fn flow ->
        Map.get(flow.trigger_config, "event_name") == event_name
      end)

    for flow <- matching_flows do
      execute_flow_async(flow.id, trigger_data, nil)
    end

    # Tier 2: JS plugins listening for custom events
    js_plugins = JsPlugins.get_active_js_plugins_for_hook("on_custom_event")

    matching_js =
      Enum.filter(js_plugins, fn plugin ->
        manifest_event = get_in(plugin.manifest, ["trigger_config", "event_name"])
        manifest_event == event_name
      end)

    for plugin <- matching_js do
      execute_js_plugin_async(plugin.id, trigger_data, nil)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  defp find_trigger_type(event_string) do
    Enum.find_value(@event_topics, fn {_topic, trigger_type} ->
      if String.contains?(event_string, String.replace(trigger_type, "on_", "")) do
        trigger_type
      end
    end)
  end

  defp spawn_flow_executions(trigger_type, data) do
    flows = Plugins.get_active_flows_for_trigger(trigger_type)

    trigger_data = normalize_trigger_data(trigger_type, data)
    triggered_by_id = extract_user_id(data)

    for flow <- flows do
      execute_flow_async(flow.id, trigger_data, triggered_by_id)
    end

    # Tier 2: JS plugin dispatch
    js_plugins = JsPlugins.get_active_js_plugins_for_hook(trigger_type)

    for plugin <- js_plugins do
      execute_js_plugin_async(
        plugin.id,
        Map.put(trigger_data, "type", trigger_type),
        triggered_by_id
      )
    end
  end

  defp execute_flow_async(flow_id, trigger_data, triggered_by_id) do
    Task.Supervisor.start_child(ForgeNexus.PluginTaskSupervisor, fn ->
      try do
        Executor.execute_flow(flow_id, trigger_data, triggered_by_id)
      rescue
        e ->
          Logger.error("[Plugins.Hooks] Flow #{flow_id} execution failed: #{inspect(e)}")
      end
    end)
  end

  defp execute_js_plugin_async(plugin_id, trigger_data, triggered_by_id) do
    Task.Supervisor.start_child(ForgeNexus.PluginTaskSupervisor, fn ->
      try do
        JsExecutor.execute_plugin(plugin_id, trigger_data, triggered_by_id)
      rescue
        e ->
          Logger.error("[Plugins.Hooks] JS Plugin #{plugin_id} execution failed: #{inspect(e)}")
      end
    end)
  end

  defp normalize_trigger_data(_trigger_type, data) when is_map(data), do: data
  defp normalize_trigger_data(_trigger_type, data), do: %{data: data}

  defp extract_user_id(%{user_id: id}), do: id
  defp extract_user_id(%{user: %{id: id}}), do: id
  defp extract_user_id(%{"user_id" => id}), do: id
  defp extract_user_id(_), do: nil
end
