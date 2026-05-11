defmodule ForgeNexusWeb.SlashCommandController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Plugins.SlashCommands
  alias ForgeNexus.Plugins.SlashCommand

  import Ecto.Query

  # -- Public endpoints ------------------------------------------------------

  def list(conn, _params) do
    commands = SlashCommands.list_commands()
    grouped = Enum.group_by(commands, & &1.category)

    categories =
      Enum.map(grouped, fn {category, cmds} ->
        %{
          category: category,
          commands:
            Enum.map(cmds, fn c ->
              %{name: c.name, description: c.description, category: c.category}
            end)
        }
      end)

    conn |> json(%{categories: categories})
  end

  def execute(conn, %{"command" => command_name} = params) do
    user = Guardian.Plug.current_resource(conn)
    args = Map.get(params, "args", "")

    case SlashCommands.execute_command(command_name, args, user) do
      {:ok, result} ->
        conn |> json(%{ok: true, result: result})

      {:error, :unknown_command} ->
        conn |> put_status(:not_found) |> json(%{error: "Unknown command."})

      {:error, :command_disabled} ->
        conn |> put_status(:forbidden) |> json(%{error: "This command is currently disabled."})

      {:error, :insufficient_permission} ->
        conn |> put_status(:forbidden) |> json(%{error: "You do not have permission to use this command."})

      {:error, {:cooldown, seconds}} ->
        conn |> put_status(:too_many_requests) |> json(%{error: "Command on cooldown. Try again in #{seconds}s.", cooldown: seconds})

      {:error, :no_flow_linked} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Command has no action configured."})

      {:error, {:flow_failed, reason}} ->
        conn |> put_status(:internal_server_error) |> json(%{error: "Command failed: #{inspect(reason)}"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  # -- Admin endpoints -------------------------------------------------------

  def admin_list(conn, _params) do
    commands =
      ForgeNexus.Repo.all(
        from(c in SlashCommand, order_by: [asc: c.category, asc: c.name])
      )

    conn
    |> json(%{
      commands:
        Enum.map(commands, fn c ->
          command_json(c)
        end)
    })
  end

  def admin_create(conn, %{"command" => command_params}) do
    attrs = %{
      name: Map.get(command_params, "name"),
      description: Map.get(command_params, "description"),
      category: Map.get(command_params, "category", "general"),
      flow_id: Map.get(command_params, "flow_id"),
      cooldown_seconds: Map.get(command_params, "cooldown_seconds", 0),
      permission_level: Map.get(command_params, "permission_level", "everyone"),
      response_type: Map.get(command_params, "response_type", "channel"),
      enabled: Map.get(command_params, "enabled", true),
      is_built_in: false
    }

    case SlashCommands.create_command(attrs) do
      {:ok, command} ->
        conn |> put_status(:created) |> json(%{ok: true, command: command_json(command)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def admin_update(conn, %{"id" => id} = params) do
    command = SlashCommands.get_command!(id)
    command_params = Map.get(params, "command", params)

    attrs =
      command_params
      |> Map.take(["name", "description", "category", "flow_id", "cooldown_seconds", "permission_level", "response_type", "enabled"])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
      |> Map.new()

    case SlashCommands.update_command(command, attrs) do
      {:ok, command} ->
        conn |> json(%{ok: true, command: command_json(command)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def admin_delete(conn, %{"id" => id}) do
    command = SlashCommands.get_command!(id)

    case SlashCommands.delete_command(command) do
      {:ok, _} ->
        conn |> json(%{ok: true})
      {:error, :cannot_delete_built_in} ->
        conn |> put_status(:forbidden) |> json(%{error: "Cannot delete built-in commands."})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  # -- Helpers ---------------------------------------------------------------

  defp command_json(c) do
    %{
      id: c.id, name: c.name, description: c.description,
      category: c.category, enabled: c.enabled,
      cooldown_seconds: c.cooldown_seconds,
      permission_level: c.permission_level,
      usage_count: c.usage_count, is_built_in: c.is_built_in,
      response_type: c.response_type, flow_id: c.flow_id,
      inserted_at: c.inserted_at, updated_at: c.updated_at
    }
  end

  defp changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  defp changeset_errors(error), do: inspect(error)
end
