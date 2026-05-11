defmodule ForgeNexus.Plugins.Nodes.Automod.LinkFilter do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @link_regex ~r{https?://([^/\s]+)}i

  @impl true
  def execute(config, inputs, ctx) do
    content = Map.get(inputs, :content) || Map.get(inputs, "content", "")
    mode = Map.get(config, "mode", "blacklist")
    domains_raw = Map.get(config, "domains", "")

    domains =
      domains_raw
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))

    links =
      Regex.scan(@link_regex, content)
      |> Enum.map(fn [full_url, domain] -> %{url: full_url, domain: String.downcase(domain)} end)

    if links == [] do
      {:branch, "clean", %{content: content}, ctx}
    else
      flagged =
        case mode do
          "whitelist" ->
            Enum.reject(links, fn %{domain: d} -> d in domains end)

          "blacklist" ->
            Enum.filter(links, fn %{domain: d} -> d in domains end)

          _ ->
            []
        end

      if flagged == [] do
        {:branch, "clean", %{content: content}, ctx}
      else
        {:branch, "has_links", %{links: flagged, content: content}, ctx}
      end
    end
  end

  @impl true
  def validate_config(config) do
    if Map.get(config, "mode", "blacklist") in ~w(whitelist blacklist),
      do: :ok,
      else: {:error, ["mode must be whitelist or blacklist"]}
  end

  @impl true
  def schema do
    %{
      type: "automod/link_filter",
      category: "automod",
      label: "Link Filter",
      description: "Checks content for links and filters by whitelist or blacklist.",
      inputs: [
        %{name: "content", type: "string", required: true}
      ],
      outputs: [
        %{name: "has_links", type: "branch", fields: [
          %{name: "links", type: "list"},
          %{name: "content", type: "string"}
        ]},
        %{name: "clean", type: "branch", fields: [
          %{name: "content", type: "string"}
        ]}
      ],
      config_fields: [
        %{name: "mode", type: "select", options: ~w(whitelist blacklist), default: "blacklist", description: "Filter mode"},
        %{name: "domains", type: "string", default: "", description: "Comma-separated list of domains"}
      ]
    }
  end
end
