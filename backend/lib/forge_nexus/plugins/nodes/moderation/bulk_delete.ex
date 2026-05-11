defmodule ForgeNexus.Plugins.Nodes.Moderation.BulkDelete do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    target_type = Map.get(inputs, :target_type) || Map.get(inputs, "target_type", "post")
    target_ids = Map.get(inputs, :target_ids) || Map.get(inputs, "target_ids", [])
    target_ids = if is_list(target_ids), do: target_ids, else: []

    deleted =
      case target_type do
        "post" -> ForgeNexus.Moderation.bulk_delete_posts(target_ids)
        _ -> 0
      end

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{deleted_count: deleted}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "moderation/bulk_delete",
      category: "moderation",
      label: "Bulk Delete",
      description: "Deletes multiple posts or messages by their IDs.",
      inputs: [
        %{name: "target_type", type: "string", required: true},
        %{name: "target_ids", type: "list", required: true}
      ],
      outputs: [%{name: "deleted_count", type: "number"}],
      config_fields: []
    }
  end
end
