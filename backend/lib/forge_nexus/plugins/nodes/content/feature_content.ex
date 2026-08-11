defmodule ForgeNexus.Plugins.Nodes.Content.FeatureContent do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    thread_id = Map.get(inputs, :thread_id) || Map.get(inputs, "thread_id")
    featured_until = Map.get(config, "featured_until", "")
    position = Map.get(config, "position", "homepage")

    case ForgeNexus.Forums.feature_thread(thread_id, position, featured_until) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to feature: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    if Map.get(config, "position", "homepage") in ~w(homepage sidebar banner),
      do: :ok,
      else: {:error, ["position must be homepage, sidebar, or banner"]}
  end

  @impl true
  def schema do
    %{
      type: "content/feature_content",
      category: "content",
      label: "Feature Content",
      description: "Features a thread in a prominent position until a specified date.",
      inputs: [%{name: "thread_id", type: "string", required: true}],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: [
        %{
          name: "featured_until",
          type: "string",
          default: "",
          description: "ISO date until which content is featured"
        },
        %{
          name: "position",
          type: "select",
          options: ~w(homepage sidebar banner),
          default: "homepage",
          description: "Where to display featured content"
        }
      ]
    }
  end
end
