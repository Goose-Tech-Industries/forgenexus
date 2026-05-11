defmodule ForgeNexus.Plugins.Nodes.Profile.SetProfileBackground do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    image_url = Map.get(inputs, :image_url) || Map.get(inputs, "image_url")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        metadata = Map.get(user, :metadata) || %{}
        updated_metadata = Map.put(metadata, "profile_background", image_url)

        user
        |> Ecto.Changeset.change(%{metadata: updated_metadata})
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "profile/set_profile_background",
      category: "profile",
      label: "Set Profile Background",
      description: "Sets a custom background image for a user's profile page.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "image_url", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
