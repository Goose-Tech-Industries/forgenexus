defmodule ForgeNexus.Plugins.Nodes.Content.ArchiveContent do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    thread_id = Map.get(inputs, :thread_id) || Map.get(inputs, "thread_id")
    archive_forum_slug = Map.get(config, "archive_forum_slug", "archive")

    case ForgeNexus.Forums.archive_thread(thread_id, archive_forum_slug) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to archive: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "content/archive_content",
      category: "content",
      label: "Archive Content",
      description: "Moves a thread to an archive forum.",
      inputs: [%{name: "thread_id", type: "string", required: true}],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: [
        %{
          name: "archive_forum_slug",
          type: "string",
          default: "archive",
          description: "Slug of the archive forum to move the thread to"
        }
      ]
    }
  end
end
