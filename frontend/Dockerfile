# ===========================================
# ForgeNexus Frontend — SvelteKit with Node adapter
# ===========================================
# Build: docker build -t forgenexus-ui .
# Run:   docker run -p 3000:3000 forgenexus-ui

FROM node:22-slim AS builder

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

COPY . .

ARG VITE_API_BASE=/api
ENV VITE_API_BASE=${VITE_API_BASE}

# Inject a build identifier so SvelteKit's `version.json` changes per build.
# Used by version-poll to detect deploys and reload before chunk-404s.
ARG BUILD_ID
ENV BUILD_ID=${BUILD_ID}

RUN BUILD_ID="${BUILD_ID:-$(date +%s)}" npm run build

# ===========================================
# Runtime
# ===========================================
FROM node:22-slim

WORKDIR /app

RUN useradd --create-home --shell /bin/bash app

COPY --from=builder --chown=app:app /app/build ./build
COPY --from=builder --chown=app:app /app/package.json .
COPY --from=builder --chown=app:app /app/node_modules ./node_modules

USER app

ENV PORT=3000
ENV HOST=0.0.0.0

EXPOSE 3000

CMD ["node", "build"]
