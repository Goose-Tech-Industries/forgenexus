defmodule ForgeNexus.Plugins.Nodes.Action.CreatePost do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    thread_id = Map.get(inputs, :thread_id) || Map.get(inputs, "thread_id")
    body = Map.get(inputs, :body) || Map.get(inputs, "body")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    try do
      {:ok, post} =
        ForgeNexus.Forums.create_post(%{
          thread_id: thread_id,
          body: body,
          user_id: user_id
        })

      ctx = Sandbox.increment_db_ops(ctx)
      {:ok, %{post_id: post.id, created: true}, ctx}
    rescue
      e in [Ecto.InvalidChangesetError, Ecto.NoResultsError, Ecto.Query.CastError, MatchError] ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create post: #{Exception.message(e)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "action/create_post",
      category: "action",
      label: "Create Post",
      description: "Creates a new post in a thread.",
      inputs: [
        %{name: "thread_id", type: "string", required: true},
        %{name: "body", type: "string", required: true},
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "post_id", type: "string"},
        %{name: "created", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
