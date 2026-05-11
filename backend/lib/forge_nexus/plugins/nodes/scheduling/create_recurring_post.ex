defmodule ForgeNexus.Plugins.Nodes.Scheduling.CreateRecurringPost do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  require Logger

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    forum_slug = Map.get(config, "forum_slug", "")
    title_template = Map.get(config, "title_template", "")
    body_template = Map.get(config, "body_template", "")
    day_of_week = Map.get(config, "day_of_week", "monday")
    time = Map.get(config, "time", "09:00")

    # Create a cron trigger configuration stored in flow_global_store
    # The scheduled trigger node will pick this up and create posts on schedule
    Logger.info("[PluginFlow] scheduling/create_recurring_post: forum=#{forum_slug}, day=#{day_of_week}, time=#{time}")

    cron_config = %{
      forum_slug: forum_slug,
      title_template: title_template,
      body_template: body_template,
      day_of_week: day_of_week,
      time: time
    }

    flow_global = Map.get(ctx, :flow_global_store, %{})
    recurring_posts = Map.get(flow_global, "recurring_posts", [])
    recurring_posts = [cron_config | recurring_posts]
    flow_global = Map.put(flow_global, "recurring_posts", recurring_posts)
    ctx = Map.put(ctx, :flow_global_store, flow_global)

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{success: true}, ctx}
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        case Map.get(config, "forum_slug") do
          nil -> ["forum_slug is required" | e]
          "" -> ["forum_slug is required" | e]
          _ -> e
        end
      end)
      |> then(fn e ->
        case Map.get(config, "title_template") do
          nil -> ["title_template is required" | e]
          "" -> ["title_template is required" | e]
          _ -> e
        end
      end)
      |> then(fn e ->
        if Map.get(config, "day_of_week", "monday") in ~w(monday tuesday wednesday thursday friday saturday sunday),
          do: e,
          else: ["day_of_week must be a valid day name" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "scheduling/create_recurring_post",
      category: "scheduling",
      label: "Create Recurring Post",
      description: "Configures a recurring thread to be posted on a schedule (e.g. weekly discussion).",
      inputs: [],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "forum_slug", type: "string", default: "", description: "Forum slug to post in"},
        %{name: "title_template", type: "string", default: "", description: "Thread title template (supports {{date}})"},
        %{name: "body_template", type: "text", default: "", description: "Thread body template"},
        %{name: "day_of_week", type: "select", options: ~w(monday tuesday wednesday thursday friday saturday sunday), default: "monday", description: "Day of week to post"},
        %{name: "time", type: "string", default: "09:00", description: "Time to post (HH:MM, 24h format)"}
      ]
    }
  end
end
