defmodule ForgeNexus.Plugins.Nodes.Profile.SetNameColor do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    color = Map.get(inputs, :color) || Map.get(inputs, "color")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        metadata = Map.get(user, :metadata) || %{}
        updated_metadata = Map.put(metadata, "name_color", color)

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
      type: "profile/set_name_color",
      category: "profile",
      label: "Set Name Color",
      description: "Sets a user's display name color.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "color", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
