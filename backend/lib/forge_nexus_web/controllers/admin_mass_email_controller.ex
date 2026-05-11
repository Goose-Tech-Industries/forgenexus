defmodule ForgeNexusWeb.AdminMassEmailController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Workers.MassEmailer
  alias ForgeNexus.Admin

  @valid_segments ~w(all active_30d verified)

  def send_email(conn, %{"subject" => subject, "body" => body, "segment" => segment})
      when segment in @valid_segments do
    user = Guardian.Plug.current_resource(conn)
    body_html = body

    recipient_count = MassEmailer.recipient_count(segment)

    %{subject: subject, body_html: body_html, segment: segment}
    |> MassEmailer.new()
    |> Oban.insert()

    Admin.log_admin_action(user.id, %{
      action: "mass_email_sent",
      category: "communication",
      target_type: "mass_email",
      description: "Sent mass email \"#{subject}\" to segment: #{segment} (~#{recipient_count} recipients)"
    })

    conn
    |> put_status(:ok)
    |> json(%{ok: true, recipient_count: recipient_count, segment: segment})
  end

  def send_email(conn, %{"segment" => segment}) when segment not in @valid_segments do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Invalid segment. Must be one of: all, active_30d, verified"})
  end

  def send_email(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Missing required fields: subject, body, segment"})
  end

  def preview(conn, %{"segment" => segment}) when segment in @valid_segments do
    recipient_count = MassEmailer.recipient_count(segment)
    conn |> json(%{recipient_count: recipient_count, segment: segment})
  end

  def preview(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Missing or invalid segment"})
  end
end
