defmodule ForgeNexus.Plugins.Nodes.UserManagement.GetUserProfile do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    case Repo.get(User, user_id) |> Repo.preload(:groups) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        ctx = Sandbox.increment_db_ops(ctx)

        profile = %{
          id: user.id,
          username: user.username,
          email: user.email,
          avatar_url: Map.get(user, :avatar_url),
          post_count: Map.get(user, :post_count, 0),
          thread_count: Map.get(user, :thread_count, 0),
          joined_at: user.inserted_at |> to_string(),
          custom_title: Map.get(user, :custom_title),
          groups: Enum.map(user.groups, & &1.id) |> Enum.map(&to_string/1),
          trust_level: Map.get(user, :trust_level, 0)
        }

        {:ok, %{user: profile}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "user_management/get_user_profile",
      category: "user_management",
      label: "Get User Profile",
      description: "Retrieves a user's full profile data including groups and stats.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "user", type: "map"}
      ],
      config_fields: []
    }
  end
end
