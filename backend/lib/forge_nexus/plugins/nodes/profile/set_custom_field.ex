defmodule ForgeNexus.Plugins.Nodes.Profile.SetCustomField do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    field_name = Map.get(inputs, :field_name) || Map.get(inputs, "field_name")
    field_value = Map.get(inputs, :field_value) || Map.get(inputs, "field_value")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        metadata = Map.get(user, :metadata) || %{}
        custom_fields = Map.get(metadata, "custom_fields", %{})
        updated_fields = Map.put(custom_fields, field_name, field_value)
        updated_metadata = Map.put(metadata, "custom_fields", updated_fields)

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
      type: "profile/set_custom_field",
      category: "profile",
      label: "Set Custom Field",
      description: "Sets a custom profile field value for a user.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "field_name", type: "string", required: true},
        %{name: "field_value", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
