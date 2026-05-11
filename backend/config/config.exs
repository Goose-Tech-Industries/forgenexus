# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :forge_nexus,
  ecto_repos: [ForgeNexus.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :forge_nexus, ForgeNexusWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: ForgeNexusWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ForgeNexus.PubSub,
  live_view: [signing_salt: "+i06VNVe"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :forge_nexus, ForgeNexus.Mailer, adapter: Swoosh.Adapters.Local

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Guardian JWT config
config :forge_nexus, ForgeNexus.Guardian,
  issuer: "forge_nexus",
  secret_key: "dev_secret_key_change_in_production_please_use_mix_guardian_gen_secret",
  ttl: {7, :days}

# Oban job queue
config :forge_nexus, Oban,
  repo: ForgeNexus.Repo,
  queues: [default: 10, mailers: 5, notifications: 10, webhooks: 10, transcription: 2],
  plugins: [
    # Prune completed jobs after 7 days
    {Oban.Plugins.Pruner, max_age: 7 * 24 * 60 * 60},
    # Scheduled cron jobs
    {Oban.Plugins.Cron,
     crontab: [
       # Precompute community stats every 5 minutes
       {"*/5 * * * *", ForgeNexus.Workers.StatsComputer},
       # Mark stale users offline (last_seen_at > 5 min ago)
       {"* * * * *", ForgeNexus.Workers.PresenceReaper},
       # Reconcile denormalized counters from source-of-truth (heals drift)
       {"*/15 * * * *", ForgeNexus.Workers.CountReconciler}
     ]}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
