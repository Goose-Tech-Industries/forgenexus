defmodule ForgeNexus.Plugins.Nodes.UserManagement.SetUsernameStyle do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @valid_effects ~w(none glow bold italic rainbow)

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    color = Map.get(config, "color", "")
    effect = Map.get(config, "effect", "none")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        style = %{"color" => color, "effect" => effect}
        metadata = Map.get(user, :metadata) || %{}
        updated_metadata = Map.put(metadata, "username_style", style)

        user
        |> Ecto.Changeset.change(%{metadata: updated_metadata})
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    errors = []

    errors =
      case Map.get(config, "effect", "none") do
        e when e in @valid_effects -> errors
        _ -> ["effect must be one of: #{Enum.join(@valid_effects, ", ")}" | errors]
      end

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "user_management/set_username_style",
      category: "user_management",
      label: "Set Username Style",
      description: "Sets a user's username color and text effect.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "color", type: "string", default: "", description: "Hex color code (e.g. #FF0000)"},
        %{name: "effect", type: "select", options: ~w(none glow bold italic rainbow), default: "none", description: "Username text effect"}
      ]
    }
  end
end
