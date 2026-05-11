defmodule ForgeNexusWeb.Presence do
  use Phoenix.Presence,
    otp_app: :forge_nexus,
    pubsub_server: ForgeNexus.PubSub
end
