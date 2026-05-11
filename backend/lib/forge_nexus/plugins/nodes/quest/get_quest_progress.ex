defmodule ForgeNexus.Plugins.Nodes.Quest.GetQuestProgress do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    quests = ForgeNexus.Quests.get_user_quests(user_id)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{quests: quests, count: length(quests)}, ctx}
  end

  @impl true
  def validate_config(config) do
    sf = Map.get(config, "status_filter", "all")

    if sf in ~w(all active completed) do
      :ok
    else
      {:error, ["status_filter must be one of: all, active, completed"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "quest/get_quest_progress",
      category: "quest",
      label: "Get Quest Progress",
      description: "Retrieves a user's quests filtered by status.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "quests", type: "list"},
        %{name: "count", type: "number"}
      ],
      config_fields: [
        %{name: "status_filter", type: "select", options: ~w(all active completed), default: "all", description: "Filter quests by status"}
      ]
    }
  end
end
