defmodule ForgeNexus.Plugins.Nodes.Profile.SetPostbitStyle do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    background_url = Map.get(config, "background_url")
    background_opacity = Map.get(config, "background_opacity", 0.3)
    postbit_url = Map.get(config, "postbit_url")
    postbit_opacity = Map.get(config, "postbit_opacity", 0.3)

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      user ->
        changes =
          %{}
          |> maybe_put(:post_background_url, background_url)
          |> maybe_put(:post_background_opacity, parse_opacity(background_opacity))
          |> maybe_put(:postbit_background_url, postbit_url)
          |> maybe_put(:postbit_background_opacity, parse_opacity(postbit_opacity))

        user
        |> Ecto.Changeset.change(changes)
        |> Repo.update!()

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    errors = []

    errors =
      case Map.get(config, "background_opacity") do
        nil -> errors
        val ->
          opacity = parse_opacity(val)
          if opacity >= 0.0 and opacity <= 1.0, do: errors, else: ["background_opacity must be between 0.0 and 1.0" | errors]
      end

    errors =
      case Map.get(config, "postbit_opacity") do
        nil -> errors
        val ->
          opacity = parse_opacity(val)
          if opacity >= 0.0 and opacity <= 1.0, do: errors, else: ["postbit_opacity must be between 0.0 and 1.0" | errors]
      end

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "profile/set_postbit_style",
      category: "profile",
      label: "Set Postbit Style",
      description: "Sets a user's post and postbit background images and opacity.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "background_url", type: "string", default: "", description: "URL for the post background image"},
        %{name: "background_opacity", type: "number", default: 0.3, description: "Post background opacity (0.0 to 1.0)"},
        %{name: "postbit_url", type: "string", default: "", description: "URL for the postbit background image"},
        %{name: "postbit_opacity", type: "number", default: 0.3, description: "Postbit background opacity (0.0 to 1.0)"}
      ]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_opacity(val) when is_float(val), do: val
  defp parse_opacity(val) when is_integer(val), do: val / 1.0
  defp parse_opacity(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.3
    end
  end
  defp parse_opacity(_), do: 0.3
end
