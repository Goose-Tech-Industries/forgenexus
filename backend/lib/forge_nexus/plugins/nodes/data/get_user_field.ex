defmodule ForgeNexus.Plugins.Nodes.Data.GetUserField do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @allowed_fields ~w(username post_count thread_count reputation trust_level custom_title inserted_at last_seen_at)a

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    field_str = Map.get(config, "field")
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    field =
      try do
        String.to_existing_atom(field_str)
      rescue
        ArgumentError -> nil
      end

    cond do
      field not in @allowed_fields ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Field '#{field_str}' is not in the allowed list", ctx}

      true ->
        case Repo.get(User, user_id) do
          nil ->
            ctx = Sandbox.increment_db_ops(ctx)
            {:error, "User not found: #{user_id}", ctx}

          user ->
            ctx = Sandbox.increment_db_ops(ctx)
            {:ok, %{value: Map.get(user, field)}, ctx}
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

    if field in @allowed_fields do
      :ok
    else
      {:error, ["field must be one of: #{Enum.join(@allowed_fields, ", ")}"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "data/get_user_field",
      category: "data",
      label: "Get User Field",
      description: "Reads a field from a user's profile (limited allowlist).",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [%{name: "value", type: "any"}],
      config_fields: [
        %{
          name: "field",
          type: "select",
          options: Enum.map(@allowed_fields, &Atom.to_string/1),
          default: "username",
          description: "User field to read"
        }
      ]
    }
  end
end
