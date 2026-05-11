defmodule ForgeNexus.Plugins.Nodes.Profile.SetNameplate do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    color = Map.get(config, "color", "")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        user
        |> Ecto.Changeset.change(%{nameplate_color: color})
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    color = Map.get(config, "color", "")
    if String.match?(color, ~r/^#[0-9a-fA-F]{3,8}$/) or color == "" do
      :ok
    else
      {:error, ["color must be a valid hex color (e.g. #ff0000)"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "profile/set_nameplate",
      category: "profile",
      label: "Set Nameplate Color",
      description: "Sets a user's nameplate background color.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "color", type: "string", default: "", description: "Hex color for the nameplate (e.g. #ff0000)"}
      ]
    }
  end
end
