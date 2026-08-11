defmodule ForgeNexus.Plugins.Nodes.Verification.MentorshipPair do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour
  import Ecto.Query

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    new_user_id = Map.get(inputs, :new_user_id) || Map.get(inputs, "new_user_id")
    mentor_group_id = Map.get(config, "mentor_group_id", "")

    members =
      from(m in ForgeNexus.Accounts.UserGroupMembership,
        where: m.group_id == ^mentor_group_id,
        select: m.user_id
      )
      |> ForgeNexus.Repo.all()

    ctx = Sandbox.increment_db_ops(ctx)

    case Enum.random(members -- [new_user_id]) do
      nil ->
        {:error, "No active mentors found in group #{mentor_group_id}", ctx}

      mentor_id ->
        {:ok, %{mentor_user_id: mentor_id, success: true}, ctx}
    end
  rescue
    Enum.EmptyError ->
      {:error, "No active mentors found", Map.update(ctx, :db_ops, 1, &(&1 + 0))}
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "mentor_group_id") do
      nil -> {:error, ["mentor_group_id is required"]}
      "" -> {:error, ["mentor_group_id cannot be empty"]}
      _ -> :ok
    end
  end

  @impl true
  def schema do
    %{
      type: "verification/mentorship_pair",
      category: "verification",
      label: "Mentorship Pair",
      description: "Pairs a new user with a random active mentor from a designated group.",
      inputs: [%{name: "new_user_id", type: "string", required: true}],
      outputs: [
        %{name: "mentor_user_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "mentor_group_id",
          type: "string",
          default: "",
          description: "ID of the group to pick mentors from"
        }
      ]
    }
  end
end
