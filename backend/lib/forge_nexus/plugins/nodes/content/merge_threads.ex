defmodule ForgeNexus.Plugins.Nodes.Content.MergeThreads do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    source_thread_id = Map.get(inputs, :source_thread_id) || Map.get(inputs, "source_thread_id")
    target_thread_id = Map.get(inputs, :target_thread_id) || Map.get(inputs, "target_thread_id")

    case ForgeNexus.Forums.merge_threads(source_thread_id, target_thread_id) do
      {:ok, %{moved_count: n}} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{merged_post_count: n, success: true}, ctx}

      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{merged_post_count: 0, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to merge threads: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "content/merge_threads",
      category: "content",
      label: "Merge Threads",
      description: "Merges all posts from a source thread into a target thread.",
      inputs: [
        %{name: "source_thread_id", type: "string", required: true},
        %{name: "target_thread_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "merged_post_count", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
