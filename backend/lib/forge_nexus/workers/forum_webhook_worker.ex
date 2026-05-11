defmodule ForgeNexus.Workers.ForumWebhookWorker do
  @moduledoc """
  Oban worker that delivers forum webhook payloads with HMAC-SHA256 signatures.

  Retries up to 8 times with Oban's default exponential backoff. Every attempt
  (success or failure) is persisted to `webhook_deliveries` for observability.
  Webhooks are auto-disabled after 10 consecutive failures on the parent row.
  """
  use Oban.Worker, queue: :webhooks, max_attempts: 8

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Forums.{ForumWebhook, WebhookDelivery}

  @request_timeout_ms 10_000

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"webhook_id" => webhook_id, "event" => event, "payload" => payload},
        attempt: attempt
      }) do
    case Repo.get(ForumWebhook, webhook_id) do
      nil ->
        :ok

      %ForumWebhook{is_active: false} ->
        :ok

      webhook ->
        deliver(webhook, event, payload, attempt)
    end
  end

  defp deliver(webhook, event, payload, attempt) do
    body =
      Jason.encode!(%{
        event: event,
        data: payload,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    signature = compute_signature(body, webhook.secret)

    headers = [
      {"content-type", "application/json"},
      {"user-agent", "ForgeNexus-Webhooks/1.0"},
      {"x-forgenexus-event", event},
      {"x-forgenexus-delivery", Ecto.UUID.generate()},
      {"x-forgenexus-signature", "sha256=" <> signature}
    ]

    started = System.monotonic_time(:millisecond)

    result =
      try do
        Req.post(webhook.url,
          headers: headers,
          body: body,
          receive_timeout: @request_timeout_ms,
          retry: false,
          decode_body: false
        )
      rescue
        e -> {:error, Exception.message(e)}
      catch
        :exit, reason -> {:error, "exit: #{inspect(reason)}"}
      end

    latency_ms = System.monotonic_time(:millisecond) - started

    case result do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
        log_delivery(webhook, event, payload, attempt,
          response_status: status,
          response_body: truncate(resp_body),
          latency_ms: latency_ms
        )

        from(w in ForumWebhook, where: w.id == ^webhook.id)
        |> Repo.update_all(
          set: [
            last_triggered_at: DateTime.utc_now() |> DateTime.truncate(:second),
            failure_count: 0
          ]
        )

        :ok

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        log_delivery(webhook, event, payload, attempt,
          response_status: status,
          response_body: truncate(resp_body),
          latency_ms: latency_ms,
          error: "HTTP #{status}"
        )

        increment_failure(webhook.id)
        {:error, "HTTP #{status}"}

      {:error, %{__exception__: true} = exception} ->
        reason = Exception.message(exception)
        log_failure(webhook, event, payload, attempt, latency_ms, reason)
        increment_failure(webhook.id)
        {:error, reason}

      {:error, reason} ->
        log_failure(webhook, event, payload, attempt, latency_ms, inspect(reason))
        increment_failure(webhook.id)
        {:error, inspect(reason)}
    end
  end

  defp log_delivery(webhook, event, payload, attempt, fields) do
    attrs =
      Enum.into(fields, %{
        webhook_id: webhook.id,
        event_type: event,
        payload: payload,
        attempt: attempt,
        delivered_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    %WebhookDelivery{}
    |> WebhookDelivery.changeset(attrs)
    |> Repo.insert()
  end

  defp log_failure(webhook, event, payload, attempt, latency_ms, reason) do
    log_delivery(webhook, event, payload, attempt,
      latency_ms: latency_ms,
      error: truncate(reason)
    )
  end

  defp truncate(nil), do: nil
  defp truncate(body) when is_binary(body), do: String.slice(body, 0, 4000)
  defp truncate(body), do: body |> inspect() |> String.slice(0, 4000)

  defp compute_signature(body, secret) when is_binary(secret) do
    :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)
  end

  defp increment_failure(webhook_id) do
    from(w in ForumWebhook, where: w.id == ^webhook_id)
    |> Repo.update_all(inc: [failure_count: 1])

    webhook = Repo.get(ForumWebhook, webhook_id)

    if webhook && webhook.failure_count >= 10 do
      from(w in ForumWebhook, where: w.id == ^webhook_id)
      |> Repo.update_all(set: [is_active: false])
    end
  end
end
