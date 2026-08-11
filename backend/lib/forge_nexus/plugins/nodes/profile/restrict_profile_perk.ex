defmodule ForgeNexus.Plugins.Nodes.Profile.RestrictProfilePerk do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @valid_perks ~w(avatar_frame name_color name_effect postbit_background profile_background custom_title)

  @perk_resets %{
    "avatar_frame" => %{metadata_key: "avatar_frame"},
    "name_color" => %{metadata_key: "name_color"},
    "name_effect" => %{metadata_key: "name_effect"},
    "postbit_background" => %{
      fields: %{postbit_background_url: nil, postbit_background_opacity: nil},
      metadata_key: "postbit_background"
    },
    "profile_background" => %{
      fields: %{post_background_url: nil, post_background_opacity: nil},
      metadata_key: "profile_background"
    },
    "custom_title" => %{fields: %{custom_title: nil}}
  }

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
        reset_info = Map.get(@perk_resets, perk_type, %{})

        # Reset direct fields if any
        field_changes = Map.get(reset_info, :fields, %{})

        # Reset metadata key if any
        metadata_changes =
          case Map.get(reset_info, :metadata_key) do
            nil ->
              %{}

            key ->
              metadata = Map.get(user, :metadata) || %{}
              updated_metadata = Map.delete(metadata, key)
              # Also remove from profile_perks list
              perks = Map.get(metadata, "profile_perks", [])
              updated_perks = List.delete(perks, perk_type)
              updated_metadata = Map.put(updated_metadata, "profile_perks", updated_perks)
              %{metadata: updated_metadata}
          end

        all_changes = Map.merge(field_changes, metadata_changes)

        user
        |> Ecto.Changeset.change(all_changes)
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
      type: "profile/restrict_profile_perk",
      category: "profile",
      label: "Restrict Profile Perk",
      description:
        "Removes/resets a cosmetic profile perk from a user (opposite of grant_profile_perk).",
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
            ~w(avatar_frame name_color name_effect postbit_background profile_background custom_title),
          default: "custom_title",
          description: "Type of profile perk to remove/reset"
        }
      ]
    }
  end
end
