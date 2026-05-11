defmodule ForgeNexusWeb.StripeWebhookController do
  @moduledoc """
  Stripe webhook receiver. Always responds 200 unless the signature is bad —
  Stripe's retry policy is unfriendly to long error tails.

  Signature verification requires the RAW request body, not the parsed JSON.
  This is wired via the `StripeRawBody` plug mounted on `/api/webhooks/stripe`
  in router.ex.
  """
  use ForgeNexusWeb, :controller
  require Logger

  alias ForgeNexus.Billing

  def receive(conn, _params) do
    [signature | _] = get_req_header(conn, "stripe-signature")
    raw_body = conn.assigns[:raw_body] || ""

    case Billing.handle_webhook(raw_body, signature) do
      :ok ->
        send_resp(conn, 200, "ok")

      {:error, {:invalid_signature, reason}} ->
        Logger.warning("[StripeWebhook] invalid signature: #{inspect(reason)}")
        send_resp(conn, 400, "invalid signature")

      {:error, :no_secret} ->
        send_resp(conn, 503, "not configured")

      {:error, reason} ->
        Logger.error("[StripeWebhook] unexpected error: #{inspect(reason)}")
        send_resp(conn, 500, "error")
    end
  end
end
