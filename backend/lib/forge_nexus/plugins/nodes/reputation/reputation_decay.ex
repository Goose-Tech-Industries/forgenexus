defmodule ForgeNexus.Plugins.Nodes.Reputation.ReputationDecay do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    decay_percent = Map.get(config, "decay_percent", 1.0)
    inactive_days = Map.get(config, "inactive_days", 30)

    case ForgeNexus.Reputation.apply_decay(%{
           decay_percent: decay_percent,
           inactive_days: inactive_days,
           community_id: ctx.community_id
         }) do
      {:ok, %{users_affected: users_affected, total_decayed: total_decayed}} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{users_affected: users_affected, total_decayed: total_decayed}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to apply reputation decay: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        pct = Map.get(config, "decay_percent")

        if is_nil(pct) or (is_number(pct) and pct > 0 and pct <= 100),
          do: e,
          else: ["decay_percent must be between 0 and 100" | e]
      end)
      |> then(fn e ->
        days = Map.get(config, "inactive_days")

        if is_nil(days) or (is_number(days) and days > 0),
          do: e,
          else: ["inactive_days must be a positive number" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "reputation/reputation_decay",
      category: "reputation",
      label: "Reputation Decay",
      description: "Applies reputation decay to inactive users as a scheduled maintenance task.",
      inputs: [],
      outputs: [
        %{name: "users_affected", type: "number"},
        %{name: "total_decayed", type: "number"}
      ],
      config_fields: [
        %{
          name: "decay_percent",
          type: "number",
          default: 1.0,
          description: "Percentage of reputation to decay"
        },
        %{
          name: "inactive_days",
          type: "number",
          default: 30,
          description: "Days of inactivity before decay applies"
        }
      ]
    }
  end
end
