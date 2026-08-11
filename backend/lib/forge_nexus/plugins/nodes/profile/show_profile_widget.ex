defmodule ForgeNexus.Plugins.Nodes.Profile.ShowProfileWidget do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @valid_widget_types ~w(stats inventory badges pets achievements)
  @valid_positions ~w(sidebar below_avatar below_posts)

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    widget_data = Map.get(inputs, :widget_data) || Map.get(inputs, "widget_data") || %{}
    widget_type = Map.get(config, "widget_type", "stats")
    position = Map.get(config, "position", "sidebar")

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        metadata = Map.get(user, :metadata) || %{}
        widgets = Map.get(metadata, "profile_widgets", [])

        widget = %{
          "type" => widget_type,
          "position" => position,
          "data" => widget_data
        }

        # Replace existing widget of same type+position, or append
        updated_widgets =
          case Enum.find_index(widgets, fn w ->
                 w["type"] == widget_type and w["position"] == position
               end) do
            nil -> [widget | widgets]
            idx -> List.replace_at(widgets, idx, widget)
          end

        updated_metadata = Map.put(metadata, "profile_widgets", updated_widgets)

        user
        |> Ecto.Changeset.change(%{metadata: updated_metadata})
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    errors = []

    errors =
      case Map.get(config, "widget_type", "stats") do
        t when t in @valid_widget_types -> errors
        _ -> ["widget_type must be one of: #{Enum.join(@valid_widget_types, ", ")}" | errors]
      end

    errors =
      case Map.get(config, "position", "sidebar") do
        p when p in @valid_positions -> errors
        _ -> ["position must be one of: #{Enum.join(@valid_positions, ", ")}" | errors]
      end

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "profile/show_profile_widget",
      category: "profile",
      label: "Show Profile Widget",
      description: "Displays a widget on a user's profile (stats, inventory, badges, etc.).",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "widget_data", type: "map", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "widget_type",
          type: "select",
          options: ~w(stats inventory badges pets achievements),
          default: "stats",
          description: "Type of widget to display"
        },
        %{
          name: "position",
          type: "select",
          options: ~w(sidebar below_avatar below_posts),
          default: "sidebar",
          description: "Where to place the widget on the profile"
        }
      ]
    }
  end
end
