defmodule ForgeNexus.Plugins.Nodes.Data.SetUserField do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @writable_fields ~w(custom_title reputation)a

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    field_str = Map.get(config, "field")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    value = Map.get(inputs, :value) || Map.get(inputs, "value")

    field =
      try do
        String.to_existing_atom(field_str)
      rescue
        ArgumentError -> nil
      end

    cond do
      field not in @writable_fields ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:error, "Field '#{field_str}' is not writable. Allowed: #{inspect(@writable_fields)}",
         ctx}

      true ->
        case Repo.get(User, user_id) do
          nil ->
            ctx = Sandbox.increment_db_ops(ctx)
            {:error, "User not found: #{user_id}", ctx}

          user ->
            user
            |> Ecto.Changeset.change(%{field => value})
            |> Repo.update!()

            ctx = Sandbox.increment_db_ops(ctx)
            {:ok, %{updated: true}, ctx}
        end
    end
  end

  @impl true
  def validate_config(config) do
    field_str = Map.get(config, "field", "")

    field =
      try do
        String.to_existing_atom(field_str)
      rescue
        ArgumentError -> nil
      end

    if field in @writable_fields do
      :ok
    else
      {:error, ["field must be one of: #{Enum.join(@writable_fields, ", ")}"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "data/set_user_field",
      category: "data",
      label: "Set User Field",
      description: "Updates a user field (strictly limited to custom_title and reputation).",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "value", type: "any", required: true}
      ],
      outputs: [%{name: "updated", type: "boolean"}],
      config_fields: [
        %{
          name: "field",
          type: "select",
          options: Enum.map(@writable_fields, &Atom.to_string/1),
          default: "custom_title",
          description: "User field to update"
        }
      ]
    }
  end
end
