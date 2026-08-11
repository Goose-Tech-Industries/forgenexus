defmodule ForgeNexus.Plugins.Nodes.Automod.InviteLinkFilter do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  # Matches common invite link patterns: discord.gg, t.me, etc.
  @invite_regex ~r{https?://(?:discord\.gg|discord\.com/invite|t\.me|invite\.[^/\s]+)/[\w-]+}i

  @impl true
  def execute(config, inputs, ctx) do
    content = Map.get(inputs, :content) || Map.get(inputs, "content", "")
    allowed_domains_raw = Map.get(config, "allowed_domains", "")

    allowed_domains =
      allowed_domains_raw
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))

    invite_links = Regex.scan(@invite_regex, content) |> Enum.map(&List.first/1)

    # Filter out links from allowed domains
    flagged_links =
      Enum.reject(invite_links, fn link ->
        Enum.any?(allowed_domains, fn domain ->
          String.contains?(String.downcase(link), domain)
        end)
      end)

    if flagged_links == [] do
      {:branch, "clean", %{content: content}, ctx}
    else
      {:branch, "has_invites", %{invite_links: flagged_links}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "automod/invite_link_filter",
      category: "automod",
      label: "Invite Link Filter",
      description: "Detects invite links (Discord, Telegram, etc.) in content.",
      inputs: [
        %{name: "content", type: "string", required: true}
      ],
      outputs: [
        %{name: "clean", type: "branch", fields: [%{name: "content", type: "string"}]},
        %{name: "has_invites", type: "branch", fields: [%{name: "invite_links", type: "list"}]}
      ],
      config_fields: [
        %{
          name: "allowed_domains",
          type: "string",
          default: "",
          description: "Comma-separated domains to whitelist (e.g. your own forum invite domain)"
        }
      ]
    }
  end
end
