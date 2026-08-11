defmodule ForgeNexus.Plugins.Nodes.UserManagement.SetUserFlair do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    flair_text = Map.get(config, "flair_text", "")
    flair_color = Map.get(config, "flair_color", "")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        flair = %{"text" => flair_text, "color" => flair_color}
        metadata = Map.get(user, :metadata) || %{}
        updated_metadata = Map.put(metadata, "flair", flair)

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
      type: "user_management/set_user_flair",
      category: "user_management",
      label: "Set User Flair",
      description: "Sets a user's display flair text and color.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "flair_text", type: "string", default: "", description: "Flair label text"},
        %{
          name: "flair_color",
          type: "string",
          default: "",
          description: "Flair background color (hex)"
        }
      ]
    }
  end
end
