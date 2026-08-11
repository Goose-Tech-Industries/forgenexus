defmodule ForgeNexus.Plugins.Nodes.Profile.SetNameEffect do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @valid_effects ~w(none glow bold italic rainbow sparkle)

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    effect = Map.get(config, "effect", "none")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        metadata = Map.get(user, :metadata) || %{}
        updated_metadata = Map.put(metadata, "name_effect", effect)

        user
        |> Ecto.Changeset.change(%{metadata: updated_metadata})
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "effect", "none") do
      e when e in @valid_effects -> :ok
      _ -> {:error, ["effect must be one of: #{Enum.join(@valid_effects, ", ")}"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "profile/set_name_effect",
      category: "profile",
      label: "Set Name Effect",
      description: "Sets a visual effect on a user's display name.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "effect",
          type: "select",
          options: ~w(none glow bold italic rainbow sparkle),
          default: "none",
          description: "Name text effect"
        }
      ]
    }
  end
end
