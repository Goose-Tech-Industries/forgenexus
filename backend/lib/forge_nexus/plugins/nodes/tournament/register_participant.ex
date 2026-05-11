defmodule ForgeNexus.Plugins.Nodes.Tournament.RegisterParticipant do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    tournament_id = Map.get(inputs, :tournament_id) || Map.get(inputs, "tournament_id")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    case ForgeNexus.Tournaments.register_participant(tournament_id, user_id) do
      {:ok, participant} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true, participant_id: participant.id}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to register participant: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "tournament/register_participant",
      category: "tournament",
      label: "Register Participant",
      description: "Registers a user as a participant in a tournament.",
      inputs: [
        %{name: "tournament_id", type: "string", required: true},
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "participant_count", type: "number"}
      ],
      config_fields: []
    }
  end
end
