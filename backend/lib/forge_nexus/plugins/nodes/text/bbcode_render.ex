defmodule ForgeNexus.Plugins.Nodes.Text.BbcodeRender do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, inputs, ctx) do
    text = to_string(Map.get(inputs, :text) || Map.get(inputs, "text", ""))
    html = ForgeNexus.BBCode.to_html(text)
    {:ok, %{html: html}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "text/bbcode_render",
      category: "text",
      label: "BBCode Render",
      description: "Renders BBCode text to HTML using the ForgeNexus.BBCode parser.",
      inputs: [%{name: "text", type: "string", required: true}],
      outputs: [%{name: "html", type: "string"}],
      config_fields: []
    }
  end
end
