import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts.

if System.get_env("PHX_SERVER") do
  config :forge_nexus, ForgeNexusWeb.Endpoint, server: true
end

config :forge_nexus, ForgeNexusWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  # -------------------------------------------------------
  # Database
  # -------------------------------------------------------
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :forge_nexus, ForgeNexus.Repo,
    ssl: System.get_env("DATABASE_SSL", "false") in ~w(true 1),
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "40")),
    queue_target: 5_000,
    queue_interval: 1_000,
    timeout: 60_000,
    socket_options: maybe_ipv6

  # -------------------------------------------------------
  # Read Replica (optional — for heavy analytics/search reads)
  # -------------------------------------------------------
  if replica_url = System.get_env("READ_REPLICA_URL") do
    config :forge_nexus, ForgeNexus.Repo.ReadReplica,
      ssl: System.get_env("DATABASE_SSL", "false") in ~w(true 1),
      url: replica_url,
      pool_size: String.to_integer(System.get_env("REPLICA_POOL_SIZE", "10")),
      timeout: 60_000,
      socket_options: maybe_ipv6
  end

  # -------------------------------------------------------
  # Endpoint / Secrets
  # -------------------------------------------------------
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || raise "PHX_HOST environment variable is required"

  config :forge_nexus, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  check_origins =
    case System.get_env("ALLOWED_ORIGINS") do
      nil ->
        ["//#{host}"]

      origins ->
        origins
        |> String.split(",", trim: true)
        |> Enum.map(&String.trim/1)
    end

  config :forge_nexus, ForgeNexusWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT", "4000"))
    ],
    check_origin: check_origins,
    secret_key_base: secret_key_base

  # -------------------------------------------------------
  # Guardian JWT
  # -------------------------------------------------------
  guardian_secret =
    System.get_env("GUARDIAN_SECRET_KEY") ||
      System.get_env("SECRET_KEY_BASE") ||
      raise "GUARDIAN_SECRET_KEY or SECRET_KEY_BASE required"

  config :forge_nexus, ForgeNexus.Guardian, secret_key: guardian_secret

  # -------------------------------------------------------
  # CORS
  # -------------------------------------------------------
  cors_origins =
    case System.get_env("ALLOWED_ORIGINS") do
      nil -> ["https://#{host}"]
      origins -> String.split(origins, ",", trim: true) |> Enum.map(&String.trim/1)
    end

  config :forge_nexus, :cors_origins, cors_origins

  # -------------------------------------------------------
  # Email (Resend)
  # -------------------------------------------------------
  if resend_key = System.get_env("RESEND_API_KEY") do
    config :forge_nexus, ForgeNexus.Mailer,
      adapter: Swoosh.Adapters.Resend,
      api_key: resend_key
  end

  # URL used to build links inside transactional emails (verify, reset, etc.)
  config :forge_nexus,
    frontend_url: System.get_env("FRONTEND_URL", "https://forum.tcgaming.quest")

  # -------------------------------------------------------
  # Meilisearch
  # -------------------------------------------------------
  config :forge_nexus,
    meilisearch_url: System.get_env("MEILISEARCH_URL", "http://localhost:7700"),
    meilisearch_key: System.get_env("MEILISEARCH_KEY", "")

  # -------------------------------------------------------
  # Security headers (CSP origins)
  # -------------------------------------------------------
  config :forge_nexus, :frontend_origin, "https://#{host}"

  # -------------------------------------------------------
  # Bandit / Graceful shutdown
  # -------------------------------------------------------
  config :forge_nexus, ForgeNexusWeb.Endpoint,
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT", "4000")),
      thousand_island_options: [
        shutdown_timeout: 30_000
      ]
    ]

  # -------------------------------------------------------
  # Structured JSON logging for production
  # -------------------------------------------------------
  config :logger, :default_formatter,
    format: {ForgeNexus.JSONLogger, :format},
    metadata: [:request_id, :user_id, :remote_ip]

  # -------------------------------------------------------
  # Sentry — error tracking (no-op until SENTRY_DSN is set)
  # -------------------------------------------------------
  if sentry_dsn = System.get_env("SENTRY_DSN") do
    config :sentry,
      dsn: sentry_dsn,
      environment_name: System.get_env("SENTRY_ENV", "production"),
      release: System.get_env("BUILD_ID"),
      enable_source_code_context: true,
      root_source_code_paths: [File.cwd!()],
      tags: %{app: "forge_nexus"}
  end

  # -------------------------------------------------------
  # Stripe (subscriptions + connect)
  # -------------------------------------------------------
  if stripe_secret = System.get_env("STRIPE_SECRET_KEY") do
    config :stripity_stripe, api_key: stripe_secret

    config :forge_nexus, :stripe,
      secret_key: stripe_secret,
      publishable_key: System.get_env("STRIPE_PUBLISHABLE_KEY"),
      webhook_secret: System.get_env("STRIPE_WEBHOOK_SECRET"),
      success_url: "https://#{host}/billing/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "https://#{host}/billing/cancel"
  end
end
