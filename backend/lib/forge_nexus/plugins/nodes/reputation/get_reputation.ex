defmodule ForgeNexus.Plugins.Nodes.Reputation.GetReputation do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    case ForgeNexus.Reputation.get_reputation(user_id) do
      {:ok, rep} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok,
         %{
           reputation: rep.total,
           positive_count: rep.positive_count,
           negative_count: rep.negative_count
         }, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to get reputation: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "reputation/get_reputation",
      category: "reputation",
      label: "Get Reputation",
      description: "Retrieves a user's reputation score and vote counts.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "reputation", type: "number"},
        %{name: "positive_count", type: "number"},
        %{name: "negative_count", type: "number"}
      ],
      config_fields: []
    }
  end
end
