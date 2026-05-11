defmodule ForgeNexus.Plugins.Nodes.Pet.BreedPets do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    pet1_id = Map.get(inputs, :pet1_id) || Map.get(inputs, "pet1_id")
    pet2_id = Map.get(inputs, :pet2_id) || Map.get(inputs, "pet2_id")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    case ForgeNexus.Pets.breed_pets(pet1_id, pet2_id, user_id) do
      {:ok, offspring} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok,
         %{
           offspring: %{
             id: offspring.id,
             nickname: offspring.nickname,
             template_id: offspring.template_id,
             level: offspring.level
           },
           success: true
         }, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to breed pets: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "pet/breed_pets",
      category: "pet",
      label: "Breed Pets",
      description: "Breeds two pets to create an offspring with inherited traits.",
      inputs: [
        %{name: "pet1_id", type: "string", required: true},
        %{name: "pet2_id", type: "string", required: true},
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "offspring", type: "map"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "nickname", type: "string", default: "", description: "Nickname for the offspring"}
      ]
    }
  end
end
