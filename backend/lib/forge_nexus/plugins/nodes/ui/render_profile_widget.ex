defmodule ForgeNexus.Plugins.Nodes.UI.RenderProfileWidget do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Plugins.PluginWidget
  alias ForgeNexus.Repo

  import Ecto.Query

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    template = Map.get(config, "template", %{})
    placement = Map.get(config, "placement", "profile_sidebar")

    # Upsert: find existing widget for this flow+placement or create new
    existing =
      from(w in PluginWidget,
        where: w.flow_id == ^ctx.flow_id and w.placement == ^placement
      )
      |> Repo.one()

    widget =
      case existing do
        nil ->
          %PluginWidget{}
          |> PluginWidget.changeset(%{
            flow_id: ctx.flow_id,
            placement: placement,
            template: template,
            is_active: true
          })
          |> Repo.insert!()

        w ->
          w
          |> PluginWidget.changeset(%{template: template, is_active: true})
          |> Repo.update!()
      end

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{widget_id: widget.id}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "ui/render_profile_widget",
      category: "ui",
      label: "Render Profile Widget",
      description: "Creates or updates a widget displayed on user profiles.",
      inputs: [],
      outputs: [%{name: "widget_id", type: "string"}],
      config_fields: [
        %{name: "template", type: "json", default: %{}, description: "Widget template data"},
        %{
          name: "placement",
          type: "select",
          options: ~w(profile_sidebar profile_header),
          default: "profile_sidebar",
          description: "Where to display the widget"
        }
      ]
    }
  end
end
