defmodule ForgeNexus.Plugins.Nodes.Pet.CreatePet do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    template_id = Map.get(inputs, :template_id) || Map.get(inputs, "template_id")
    nickname = Map.get(config, "nickname", "")

    case ForgeNexus.Pets.create_pet(user_id, template_id, nickname) do
      {:ok, pet} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok,
         %{
           pet_id: pet.id,
           pet: %{
             id: pet.id,
             nickname: pet.nickname,
             template_id: pet.pet_template_id,
             level: pet.level,
             experience: pet.experience
           },
           success: true
         }, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create pet: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "pet/create_pet",
      category: "pet",
      label: "Create Pet",
      description: "Creates a new pet from a template for a user.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "template_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "pet_id", type: "string"},
        %{name: "pet", type: "map"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "nickname",
          type: "string",
          default: "",
          description: "Optional nickname for the pet"
        }
      ]
    }
  end
end
