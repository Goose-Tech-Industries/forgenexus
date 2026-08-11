defmodule ForgeNexus.Plugins.Nodes.Pet.PetBattle do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Repo
  alias ForgeNexus.Pets.Pet

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    pet1_id = Map.get(inputs, :pet1_id) || Map.get(inputs, "pet1_id")
    pet2_id = Map.get(inputs, :pet2_id) || Map.get(inputs, "pet2_id")

    with %Pet{} = pet1 <- Repo.get(Pet, pet1_id),
         %Pet{} = pet2 <- Repo.get(Pet, pet2_id) do
      ctx = Sandbox.increment_db_ops(ctx)

      score1 = pet1.experience + pet1.level * 10
      score2 = pet2.experience + pet2.level * 10

      {winner, loser} = if score1 >= score2, do: {pet1, pet2}, else: {pet2, pet1}

      {:ok,
       %{
         winner_id: winner.id,
         battle_log: [
           "#{winner.nickname} (score: #{max(score1, score2)}) vs #{loser.nickname} (score: #{min(score1, score2)})",
           "#{winner.nickname} wins!"
         ],
         stats_comparison: %{
           pet1: %{
             id: pet1.id,
             nickname: pet1.nickname,
             level: pet1.level,
             experience: pet1.experience
           },
           pet2: %{
             id: pet2.id,
             nickname: pet2.nickname,
             level: pet2.level,
             experience: pet2.experience
           }
         }
       }, ctx}
    else
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "One or both pets not found", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "pet/pet_battle",
      category: "pet",
      label: "Pet Battle",
      description: "Runs a battle between two pets and determines a winner.",
      inputs: [
        %{name: "pet1_id", type: "string", required: true},
        %{name: "pet2_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "winner_id", type: "string"},
        %{name: "battle_log", type: "list"},
        %{name: "stats_comparison", type: "map"}
      ],
      config_fields: []
    }
  end
end
