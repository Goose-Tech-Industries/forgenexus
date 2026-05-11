defmodule ForgeNexusWeb.WebhookController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Channels

  # Admin endpoints

  def index(conn, %{"channel_id" => channel_id}) do
    webhooks = Channels.list_webhooks(channel_id)
    conn |> json(%{webhooks: Enum.map(webhooks, &webhook_json/1)})
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    attrs = Map.put(params, "created_by_id", user.id)

    case Channels.create_webhook(attrs) do
      {:ok, webhook} ->
        conn |> put_status(:created) |> json(%{webhook: webhook_json(webhook)})
      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        conn |> put_status(:unprocessable_entity) |> json(%{error: errors})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Channels.update_webhook(id, params) do
      {:ok, webhook} -> conn |> json(%{webhook: webhook_json(webhook)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to update"})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Channels.delete_webhook(id) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  def regenerate(conn, %{"id" => id}) do
    case Channels.regenerate_webhook_token(id) do
      {:ok, webhook} -> conn |> json(%{webhook: webhook_json(webhook)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to regenerate"})
    end
  end

  # Public execution endpoint — no auth needed, uses token
  def execute(conn, %{"token" => token} = params) do
    case Channels.get_webhook_by_token(token) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Invalid webhook token"})

      webhook ->
        body = params["content"] || params["body"] || ""

        if String.trim(body) == "" do
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Body is required"})
        else
          case Channels.execute_webhook(webhook, body, params["username"], params["avatar_url"]) do
            {:ok, message} ->
              # Broadcast to channel
              ForgeNexusWeb.Endpoint.broadcast("chat:#{webhook.channel_id}", "new_message", %{
                id: message.id, body: message.body, channel_id: message.channel_id,
                user: nil, embeds: message.embeds, inserted_at: message.inserted_at,
                is_edited: false, is_pinned: false, is_deleted: false,
                reply_to: nil, reactions: [], attachments: [], thread: nil
              })
              conn |> put_status(:created) |> json(%{ok: true, message_id: message.id})

            {:error, _} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to send"})
          end
        end
    end
  end

  defp webhook_json(webhook) do
    %{
      id: webhook.id,
      name: webhook.name,
      avatar_url: webhook.avatar_url,
      token: webhook.token,
      channel_id: webhook.channel_id,
      channel_name: webhook.channel && webhook.channel.name,
      is_active: webhook.is_active,
      url: "/api/webhooks/#{webhook.token}",
      inserted_at: webhook.inserted_at
    }
  end
end
