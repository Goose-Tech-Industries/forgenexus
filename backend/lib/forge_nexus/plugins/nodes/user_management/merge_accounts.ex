defmodule ForgeNexus.Plugins.Nodes.UserManagement.MergeAccounts do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour
  import Ecto.Query

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    primary_user_id = Map.get(inputs, :primary_user_id) || Map.get(inputs, "primary_user_id")
    secondary_user_id = Map.get(inputs, :secondary_user_id) || Map.get(inputs, "secondary_user_id")

    if primary_user_id == secondary_user_id do
      {:error, "primary and secondary user_ids must differ", ctx}
    else
      {moved, _} =
        from(p in ForgeNexus.Forums.Post, where: p.user_id == ^secondary_user_id)
        |> ForgeNexus.Repo.update_all(set: [user_id: primary_user_id])

      from(t in ForgeNexus.Forums.Thread, where: t.user_id == ^secondary_user_id)
      |> ForgeNexus.Repo.update_all(set: [user_id: primary_user_id])

      case ForgeNexus.Repo.get(ForgeNexus.Accounts.User, secondary_user_id) do
        nil ->
          :ok

        user ->
          user
          |> Ecto.Changeset.change(status: "merged")
          |> ForgeNexus.Repo.update()
      end

      ctx = Sandbox.increment_db_ops(ctx)
      {:ok, %{success: true, merged_post_count: moved}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "user_management/merge_accounts",
      category: "user_management",
      label: "Merge Accounts",
      description: "Reassigns posts/threads from a secondary account to a primary account and marks the secondary as merged.",
      inputs: [
        %{name: "primary_user_id", type: "string", required: true},
        %{name: "secondary_user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "merged_post_count", type: "number"}
      ],
      config_fields: []
    }
  end
end
