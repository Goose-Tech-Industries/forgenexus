defmodule ForgeNexus.Plugins.Nodes.Profile.SetMood do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    emoji = Map.get(inputs, :emoji) || Map.get(inputs, "emoji")
    text = Map.get(inputs, :text) || Map.get(inputs, "text")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        mood = %{"emoji" => emoji, "text" => text}
        metadata = Map.get(user, :metadata) || %{}
        updated_metadata = Map.put(metadata, "mood", mood)

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
      type: "profile/set_mood",
      category: "profile",
      label: "Set Mood",
      description: "Sets a user's mood status with emoji and text.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "emoji", type: "string", required: true},
        %{name: "text", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
