defmodule ForgeNexusWeb.ForumWebhookController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Forums, Admin}
  alias ForgeNexus.Forums.ForumWebhook

  def index(conn, _params) do
    webhooks = Forums.list_forum_webhooks()
    conn |> json(%{webhooks: Enum.map(webhooks, &webhook_json/1)})
  end

  def create(conn, params) do
    admin = Guardian.Plug.current_resource(conn)
    attrs = Map.put(params, "created_by_id", admin.id)

    case Forums.create_forum_webhook(attrs) do
      {:ok, webhook} ->
        Admin.log_admin_action(admin.id, %{
          action: "forum_webhook_created",
          category: "integrations",
          target_type: "forum_webhook",
          target_id: webhook.id,
          description: "Created forum webhook #{webhook.name}"
        })

        conn |> put_status(:created) |> json(%{webhook: webhook_json(webhook)})

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        conn |> put_status(:unprocessable_entity) |> json(%{error: errors})
    end
  end

  def update(conn, %{"id" => id} = params) do
    admin = Guardian.Plug.current_resource(conn)

    case Forums.update_forum_webhook(id, params) do
      {:ok, webhook} ->
        Admin.log_admin_action(admin.id, %{
          action: "forum_webhook_updated",
          category: "integrations",
          target_type: "forum_webhook",
          target_id: id,
          description: "Updated forum webhook #{webhook.name}"
        })

        conn |> json(%{webhook: webhook_json(webhook)})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to update"})
    end
  end

  def delete(conn, %{"id" => id}) do
    admin = Guardian.Plug.current_resource(conn)

    case Forums.delete_forum_webhook(id) do
      {:ok, _} ->
        Admin.log_admin_action(admin.id, %{
          action: "forum_webhook_deleted",
          category: "integrations",
          target_type: "forum_webhook",
          target_id: id,
          description: "Deleted forum webhook"
        })

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  def test(conn, %{"id" => id}) do
    webhook = Forums.get_forum_webhook!(id)

    payload = %{
      event: "test",
      data: %{message: "This is a test webhook from ForgeNexus"},
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    %{webhook_id: webhook.id, event: "test", payload: payload}
    |> ForgeNexus.Workers.ForumWebhookWorker.new()
    |> Oban.insert()

    conn |> json(%{ok: true, message: "Test webhook enqueued"})
  end

  def event_types(conn, _params) do
    conn |> json(%{events: ForumWebhook.valid_events()})
  end

  def deliveries(conn, %{"id" => id} = params) do
    limit =
      case Integer.parse(Map.get(params, "limit", "50")) do
        {n, _} when n > 0 and n <= 500 -> n
        _ -> 50
      end

    case Forums.get_forum_webhook(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Webhook not found"})

      webhook ->
        deliveries = Forums.list_webhook_deliveries(id, limit: limit)

        conn
        |> json(%{
          webhook: %{id: webhook.id, name: webhook.name, url: webhook.url},
          deliveries: Enum.map(deliveries, &delivery_json/1)
        })
    end
  end

  defp delivery_json(d) do
    %{
      id: d.id,
      event_type: d.event_type,
      response_status: d.response_status,
      latency_ms: d.latency_ms,
      attempt: d.attempt,
      error: d.error,
      delivered_at: d.delivered_at,
      ok: is_integer(d.response_status) and d.response_status >= 200 and d.response_status < 300,
      payload: d.payload,
      response_body_preview: preview(d.response_body)
    }
  end

  defp preview(nil), do: nil
  defp preview(body) when is_binary(body), do: String.slice(body, 0, 500)
  defp preview(_), do: nil

  defp webhook_json(webhook) do
    %{
      id: webhook.id,
      name: webhook.name,
      url: webhook.url,
      secret: webhook.secret,
      events: webhook.events,
      is_active: webhook.is_active,
      last_triggered_at: webhook.last_triggered_at,
      failure_count: webhook.failure_count,
      inserted_at: webhook.inserted_at
    }
  end
end
