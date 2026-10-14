# Getting Started

Choose one deployment mode for this checkout. Do not run Docker Compose while
the sndbx `paperclip` sandbox uses the same `data/` directory: the services
would conflict on ports and could access the embedded PostgreSQL data at the
same time.

## Docker Compose

> **WARNING:** `./install.sh` is only for the standalone Docker Compose mode.
> Do not run it when this checkout is managed by sndbx.

```bash
./install.sh # prompts for the public host/IP or URL on the first run
```

Open the printed public URL, create the first board account, and configure
agents and API keys.

## sndbx

```bash
./configure_sndbx.sh "$SNDBX_ROOT" # prompts for the public host/IP or URL
docker build -t paperclip:latest .
```

Merge `config.sndbx.json5` into the root `sndbx` configuration and start the
`paperclip` sandbox. The helper sets `PAPERCLIP_HOST_ROOT` and all public URL
and Better Auth origin variables in the root sndbx `.env`. The sandbox path
aligns the container UID with the sndbx service user, so it does not require
`prepare_host_permissions.sh`; that script is for standalone Docker Compose
deployments only.

## Connect an OpenClaw instance

1. Expose this VM's API (already published on `PAPERCLIP_HOST_PORT`, default
   `13100`) and create an API key in the Paperclip UI.
2. From the remote OpenClaw host:

   ```bash
   export PAPERCLIP_API_URL="http://<this-host>:13100"
   export PAPERCLIP_API_KEY="<api key>"
   curl -H "Authorization: Bearer ${PAPERCLIP_API_KEY}" "${PAPERCLIP_API_URL}/api/health"
   ```

3. To let Paperclip drive a remote OpenClaw gateway, add an agent using the
   `openclaw_gateway` adapter with the gateway `wss://` URL and token (see
   `README.md`).
