defmodule ForgeNexus.Plugins.Nodes.Profile.SetPostbitBackground do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    image_url = Map.get(inputs, :image_url) || Map.get(inputs, "image_url")
    opacity = Map.get(config, "opacity", 0.3)

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        postbit_bg = %{"image_url" => image_url, "opacity" => opacity}
        metadata = Map.get(user, :metadata) || %{}
        updated_metadata = Map.put(metadata, "postbit_background", postbit_bg)

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
      type: "profile/set_postbit_background",
      category: "profile",
      label: "Set Postbit Background",
      description: "Sets a custom background image for a user's post display area.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "image_url", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "opacity", type: "number", default: 0.3, description: "Background image opacity (0.0 to 1.0)"}
      ]
    }
  end
end
