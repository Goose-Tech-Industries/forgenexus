defmodule ForgeNexus.Plugins.Nodes.Integration.EmailInbound do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  require Logger

  @impl true
  def execute(_config, _inputs, ctx) do
    # Extract trigger_data fields — paired with a webhook that receives inbound emails
    trigger_data = Map.get(ctx, :trigger_data, %{})

    from = Map.get(trigger_data, "from") || Map.get(trigger_data, :from, "")
    subject = Map.get(trigger_data, "subject") || Map.get(trigger_data, :subject, "")
    body = Map.get(trigger_data, "body") || Map.get(trigger_data, :body, "")
    attachments = Map.get(trigger_data, "attachments") || Map.get(trigger_data, :attachments, [])

    Logger.info("[PluginFlow] integration/email_inbound: from=#{from}, subject=#{subject}")

    {:ok,
     %{
       from: from,
       subject: subject,
       body: body,
       attachments: attachments
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "integration/email_inbound",
      category: "integration",
      label: "Email Inbound",
      description:
        "Extracts fields from an inbound email webhook trigger (from, subject, body, attachments).",
      inputs: [],
      outputs: [
        %{name: "from", type: "string"},
        %{name: "subject", type: "string"},
        %{name: "body", type: "string"},
        %{name: "attachments", type: "list"}
      ],
      config_fields: []
    }
  end
end
