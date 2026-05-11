defmodule ForgeNexus.Plugins.Nodes.Pet.PetAction do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    pet_id = Map.get(inputs, :pet_id) || Map.get(inputs, "pet_id")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    action = Map.get(config, "action", "feed")

    case ForgeNexus.Pets.pet_action(pet_id, action, user_id) do
      {:ok, pet} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok,
         %{
           success: true,
           pet: %{
             id: pet.id,
             nickname: pet.nickname,
             hunger: pet.hunger,
             happiness: pet.happiness,
             health: pet.health,
             energy: pet.energy
           }
         }, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to perform pet action: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    action = Map.get(config, "action", "feed")

    if action in ~w(feed play clean rest heal) do
      :ok
    else
      {:error, ["action must be one of: feed, play, clean, rest, heal"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "pet/pet_action",
      category: "pet",
      label: "Pet Action",
      description: "Performs an action on a pet such as feeding, playing, or healing.",
      inputs: [
        %{name: "pet_id", type: "string", required: true},
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "stat_changes", type: "map"},
        %{name: "new_stats", type: "map"}
      ],
      config_fields: [
        %{name: "action", type: "select", options: ~w(feed play clean rest heal), default: "feed", description: "Action to perform on the pet"}
      ]
    }
  end
end
