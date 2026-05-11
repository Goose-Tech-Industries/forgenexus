defmodule ForgeNexus.Plugins.Nodes.Quest.CreateQuestChain do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    quest_ids = Map.get(inputs, :quest_ids) || Map.get(inputs, "quest_ids") || []

    quest_ids =
      cond do
        is_list(quest_ids) ->
          quest_ids

        is_binary(quest_ids) ->
          quest_ids |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

        true ->
          []
      end

    flow_data = Map.get(ctx, :flow_data, %{})
    chains = Map.get(flow_data, "quest_chains", [])
    chain_id = Ecto.UUID.generate()
    chain = %{"id" => chain_id, "quest_ids" => quest_ids}
    flow_data = Map.put(flow_data, "quest_chains", [chain | chains])
    ctx = Map.put(ctx, :flow_data, flow_data)
    ctx = Sandbox.increment_db_ops(ctx)

    {:ok, %{chain_length: length(quest_ids), success: true}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "quest/create_quest_chain",
      category: "quest",
      label: "Create Quest Chain",
      description: "Links quests into a sequential chain by setting prerequisite relationships.",
      inputs: [%{name: "quest_ids", type: "list", required: true}],
      outputs: [
        %{name: "chain_length", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
