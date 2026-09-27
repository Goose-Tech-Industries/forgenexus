defmodule ForgeNexus.Plugins.Nodes.Content.SplitPosts do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    post_ids = Map.get(inputs, :post_ids) || Map.get(inputs, "post_ids", [])
    new_thread_title = Map.get(inputs, :new_thread_title) || Map.get(inputs, "new_thread_title")
    forum_id = Map.get(inputs, :forum_id) || Map.get(inputs, "forum_id")

    post_ids =
      cond do
        is_list(post_ids) ->
          post_ids

        is_binary(post_ids) ->
          case Jason.decode(post_ids) do
            {:ok, parsed} when is_list(parsed) -> parsed
            _ -> []
          end

        true ->
          []
      end

    cond do
      post_ids == [] ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to split posts: post_ids cannot be empty", ctx}

      true ->
        try do
          {:ok, %{thread: thread, moved: moved}} =
            ForgeNexus.Forums.split_posts_into_new_thread(post_ids, new_thread_title, forum_id)

          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{new_thread_id: thread.id, posts_moved: moved, success: true}, ctx}
        rescue
          e in [Ecto.InvalidChangesetError, Ecto.NoResultsError, Ecto.Query.CastError, MatchError] ->
            ctx = Sandbox.increment_db_ops(ctx)
            {:error, "Failed to split posts: #{Exception.message(e)}", ctx}
        end
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "content/split_posts",
      category: "content",
      label: "Split Posts",
      description: "Moves selected posts into a new thread.",
      inputs: [
        %{name: "post_ids", type: "list", required: true},
        %{name: "new_thread_title", type: "string", required: true},
        %{name: "forum_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "new_thread_id", type: "string"},
        %{name: "posts_moved", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
