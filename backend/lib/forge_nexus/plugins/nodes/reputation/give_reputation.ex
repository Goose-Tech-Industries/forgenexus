defmodule ForgeNexus.Plugins.Nodes.Reputation.GiveReputation do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    from_user_id = Map.get(inputs, :from_user_id) || Map.get(inputs, "from_user_id")
    to_user_id = Map.get(inputs, :to_user_id) || Map.get(inputs, "to_user_id")
    amount = Map.get(config, "amount", 1)
    type = Map.get(config, "type", "positive")

    case ForgeNexus.Reputation.give_reputation(%{
           from_user_id: from_user_id,
           to_user_id: to_user_id,
           amount: amount,
           type: type
         }) do
      {:ok, new_reputation} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{new_reputation: new_reputation, success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to give reputation: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        if Map.get(config, "type", "positive") in ~w(positive negative),
          do: e,
          else: ["type must be positive or negative" | e]
      end)
      |> then(fn e ->
        amount = Map.get(config, "amount")

        if is_nil(amount) or (is_number(amount) and amount > 0),
          do: e,
          else: ["amount must be a positive number" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "reputation/give_reputation",
      category: "reputation",
      label: "Give Reputation",
      description: "Gives positive or negative reputation from one user to another.",
      inputs: [
        %{name: "from_user_id", type: "string", required: true},
        %{name: "to_user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "new_reputation", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "amount",
          type: "number",
          default: 1,
          description: "Amount of reputation to give"
        },
        %{
          name: "type",
          type: "select",
          options: ~w(positive negative),
          default: "positive",
          description: "Positive or negative reputation"
        }
      ]
    }
  end
end
