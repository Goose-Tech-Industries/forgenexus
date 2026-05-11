defmodule ForgeNexus.Plugins.Nodes.UI.RenderPage do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Plugins.PluginPage
  alias ForgeNexus.Repo

  import Ecto.Query

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    slug = Map.get(config, "slug", "")
    title = Map.get(config, "title", "")
    template = Map.get(config, "template", %{})

    existing =
      from(p in PluginPage,
        where: p.flow_id == ^ctx.flow_id and p.slug == ^slug
      )
      |> Repo.one()

    page =
      case existing do
        nil ->
          %PluginPage{}
          |> PluginPage.changeset(%{
            flow_id: ctx.flow_id,
            slug: slug,
            title: title,
            template: template,
            is_published: true
          })
          |> Repo.insert!()

        p ->
          p
          |> PluginPage.changeset(%{title: title, template: template, is_published: true})
          |> Repo.update!()
      end

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{page_id: page.id, slug: page.slug}, ctx}
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e -> if Map.get(config, "slug", "") != "", do: e, else: ["slug is required" | e] end)
      |> then(fn e -> if Map.get(config, "title", "") != "", do: e, else: ["title is required" | e] end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "ui/render_page",
      category: "ui",
      label: "Render Page",
      description: "Creates or updates a custom plugin page.",
      inputs: [],
      outputs: [
        %{name: "page_id", type: "string"},
        %{name: "slug", type: "string"}
      ],
      config_fields: [
        %{name: "slug", type: "string", default: "", description: "Page URL slug"},
        %{name: "title", type: "string", default: "", description: "Page title"},
        %{name: "template", type: "json", default: %{}, description: "Page template data"}
      ]
    }
  end
end
