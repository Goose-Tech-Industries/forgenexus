defmodule ForgeNexus.Plugins.Nodes.Action.SetCustomTitle do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    title = Map.get(inputs, :title) || Map.get(inputs, "title")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        user
        |> Ecto.Changeset.change(%{custom_title: title})
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{updated: true}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "action/set_custom_title",
      category: "action",
      label: "Set Custom Title",
      description: "Sets a user's custom title.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "title", type: "string", required: true}
      ],
      outputs: [%{name: "updated", type: "boolean"}],
      config_fields: []
    }
  end
end
