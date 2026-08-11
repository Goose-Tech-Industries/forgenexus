defmodule ForgeNexus.Plugins.Nodes.Profile.GrantProfilePerk do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @valid_perks ~w(custom_title avatar_frame name_color name_effect postbit_bg profile_bg signature)

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    perk_type = Map.get(config, "perk_type", "custom_title")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        metadata = Map.get(user, :metadata) || %{}
        perks = Map.get(metadata, "profile_perks", [])

        updated_perks =
          if perk_type in perks, do: perks, else: [perk_type | perks]

        updated_metadata = Map.put(metadata, "profile_perks", updated_perks)

        user
        |> Ecto.Changeset.change(%{metadata: updated_metadata})
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "perk_type", "custom_title") do
      p when p in @valid_perks -> :ok
      _ -> {:error, ["perk_type must be one of: #{Enum.join(@valid_perks, ", ")}"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "profile/grant_profile_perk",
      category: "profile",
      label: "Grant Profile Perk",
      description: "Unlocks a profile customization perk for a user.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "perk_type",
          type: "select",
          options:
            ~w(custom_title avatar_frame name_color name_effect postbit_bg profile_bg signature),
          default: "custom_title",
          description: "Type of profile perk to grant"
        }
      ]
    }
  end
end
