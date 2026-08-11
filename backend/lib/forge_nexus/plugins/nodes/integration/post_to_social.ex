defmodule ForgeNexus.Plugins.Nodes.Integration.PostToSocial do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  require Logger

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_http_limit!(ctx)

    message = Map.get(inputs, :message) || Map.get(inputs, "message")
    platform = Map.get(config, "platform", "generic_webhook")
    webhook_url = Map.get(config, "webhook_url", "")

    if webhook_url == "" do
      {:error, "webhook_url is required", ctx}
    else
      payload =
        case platform do
          "discord" ->
            Jason.encode!(%{content: message})

          "twitter" ->
            Jason.encode!(%{text: message})

          _ ->
            Jason.encode!(%{message: message})
        end

      :inets.start()
      :ssl.start()

      request = {
        String.to_charlist(webhook_url),
        [],
        ~c"application/json",
        String.to_charlist(payload)
      }

      case :httpc.request(:post, request, [{:timeout, 10_000}], []) do
        {:ok, {{_ver, status, _reason}, _headers, _body}} ->
          ctx = Sandbox.increment_http_requests(ctx)

          if status >= 200 and status < 300 do
            {:ok, %{success: true}, ctx}
          else
            {:error, "Webhook returned status #{status}", ctx}
          end

        {:error, reason} ->
          ctx = Sandbox.increment_http_requests(ctx)
          {:error, "HTTP request failed: #{inspect(reason)}", ctx}
      end
    end
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        case Map.get(config, "webhook_url") do
          nil -> ["webhook_url is required" | e]
          "" -> ["webhook_url is required" | e]
          _ -> e
        end
      end)
      |> then(fn e ->
        if Map.get(config, "platform", "generic_webhook") in ~w(discord twitter generic_webhook),
          do: e,
          else: ["platform must be discord, twitter, or generic_webhook" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "integration/post_to_social",
      category: "integration",
      label: "Post to Social",
      description:
        "Posts a message to an external platform via webhook (Discord, Twitter, or generic).",
      inputs: [
        %{name: "message", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "platform",
          type: "select",
          options: ~w(discord twitter generic_webhook),
          default: "generic_webhook",
          description: "Target platform"
        },
        %{name: "webhook_url", type: "string", default: "", description: "Webhook URL to post to"}
      ]
    }
  end
end
