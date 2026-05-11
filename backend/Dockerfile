# ===========================================
# ForgeNexus Backend — Multi-stage Dockerfile
# ===========================================
# Build: docker build -t forgenexus-api .
# Run:   docker run -p 4000:4000 --env-file .env forgenexus-api

  ARG BUILDER_IMAGE="hexpm/elixir:1.18.3-erlang-26.2.5.19-debian-bookworm-20260406-slim"
  ARG RUNNER_IMAGE="debian:bookworm-slim"

# ===========================================
# Stage 1: Build
# ===========================================
FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git && apt-get clean

WORKDIR /app

ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Compile application
COPY lib lib
COPY priv priv
RUN mix compile

# Copy runtime config
COPY config/runtime.exs config/

# Build release
RUN mix release

# ===========================================
# Stage 2: Runtime
# ===========================================
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl imagemagick && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

RUN useradd --create-home --shell /bin/bash app

COPY --from=builder --chown=app:app /app/_build/prod/rel/forge_nexus ./

# Pre-create the uploads mount point with the right owner so the docker volume
# inherits app:app on first mount. Without this, the mount is root-owned and
# every File.mkdir_p! / File.cp! call from the release crashes with EACCES.
RUN mkdir -p /app/priv/static/uploads /home/app/uploads && \
    chown -R app:app /app/priv/static/uploads /home/app/uploads

USER app

ENV PHX_SERVER=true

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:4000/api/health || exit 1

CMD ["bin/forge_nexus", "start"]
