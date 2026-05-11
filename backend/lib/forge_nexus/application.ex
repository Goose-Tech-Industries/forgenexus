defmodule ForgeNexus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Attach telemetry handlers before starting supervised children
    ForgeNexus.Telemetry.SlowQueryLogger.setup()

    # Sentry: forward Logger errors to Sentry. No-op when SENTRY_DSN unset.
    :logger.add_handler(:sentry_handler, Sentry.LoggerHandler, %{
      config: %{metadata: [:request_id, :user_id, :remote_ip]}
    })

    # Optionally start read replica if configured
    replica_children =
      if Application.get_env(:forge_nexus, ForgeNexus.Repo.ReadReplica) do
        [ForgeNexus.Repo.ReadReplica]
      else
        []
      end

    children = [
      ForgeNexusWeb.Telemetry,
      ForgeNexus.Repo
    ] ++ replica_children ++ [
      {DNSCluster, query: Application.get_env(:forge_nexus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ForgeNexus.PubSub},
      {Oban, Application.fetch_env!(:forge_nexus, Oban)},
      {Task.Supervisor, name: ForgeNexus.PluginTaskSupervisor},
      ForgeNexus.Cache,
      ForgeNexus.RateLimitCleaner,
      ForgeNexus.SettingsCache,
      ForgeNexus.StatsCache,
      ForgeNexus.PresenceTracker,
      ForgeNexus.Plugins.Hooks,
      ForgeNexus.Importer.Progress,
      {Registry, keys: :unique, name: ForgeNexus.Voice.RoomRegistry},
      {DynamicSupervisor, name: ForgeNexus.Voice.RoomSupervisor, strategy: :one_for_one},
      ForgeNexusWeb.Presence,
      ForgeNexusWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ForgeNexus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ForgeNexusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
