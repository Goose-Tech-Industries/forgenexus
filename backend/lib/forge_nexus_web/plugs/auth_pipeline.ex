defmodule ForgeNexusWeb.Plugs.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :forge_nexus,
    module: ForgeNexus.Guardian,
    error_handler: ForgeNexusWeb.Plugs.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug ForgeNexusWeb.Plugs.VerifyTokenCookie
  plug Guardian.Plug.LoadResource, allow_blank: true
end
