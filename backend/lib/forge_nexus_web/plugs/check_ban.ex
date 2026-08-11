defmodule ForgeNexusWeb.Plugs.CheckBan do
  import Plug.Conn
  import Phoenix.Controller

  alias ForgeNexus.Moderation

  def init(opts), do: opts

  def call(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        assign(conn, :user_restriction, :none)

      user ->
        restriction = Moderation.get_user_restriction(user.id)

        case restriction do
          :banned ->
            ban = Moderation.get_active_ban(user.id)

            ban_info =
              if ban do
                %{
                  reason: ban.reason,
                  type: ban.type,
                  expires_at: ban.expires_at,
                  banned_by: if(ban.banned_by, do: ban.banned_by.username, else: "System")
                }
              else
                %{
                  reason: "You are banned",
                  type: "permanent",
                  expires_at: nil,
                  banned_by: "System"
                }
              end

            conn
            |> put_status(:forbidden)
            |> json(%{error: "You are banned", ban: ban_info})
            |> halt()

          other ->
            assign(conn, :user_restriction, other)
        end
    end
  end
end
