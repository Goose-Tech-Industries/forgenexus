defmodule ForgeNexus.Plugins.Nodes.Action.CreateThread do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    forum_id = Map.get(inputs, :forum_id) || Map.get(inputs, "forum_id")
    title = Map.get(inputs, :title) || Map.get(inputs, "title")
    body = Map.get(inputs, :body) || Map.get(inputs, "body")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    case ForgeNexus.Forums.create_thread(%{
           forum_id: forum_id,
           title: title,
           body: body,
           user_id: user_id
         }) do
      {:ok, thread} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{thread_id: thread.id, created: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create thread: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "action/create_thread",
      category: "action",
      label: "Create Thread",
      description: "Creates a new thread in a forum.",
      inputs: [
        %{name: "forum_id", type: "string", required: true},
        %{name: "title", type: "string", required: true},
        %{name: "body", type: "string", required: true},
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "thread_id", type: "string"},
        %{name: "created", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
