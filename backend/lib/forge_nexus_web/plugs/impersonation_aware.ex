defmodule ForgeNexusWeb.Plugs.ImpersonationAware do
  import Plug.Conn

  alias ForgeNexus.Moderation

  def init(opts), do: opts

  def call(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn

      user ->
        case Moderation.get_active_impersonation(user.id) do
          nil ->
            conn

          impersonation ->
            conn
            |> assign(:impersonating, true)
            |> assign(:impersonation_target, impersonation.target_user)
            |> assign(:impersonation_log_id, impersonation.id)
        end
    end
  end
end
