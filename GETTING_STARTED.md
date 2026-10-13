# Getting Started

## Docker Compose

```bash
cp .env.example .env
chmod 0600 .env
# set PAPERCLIP_UID/GID to your user, PAPERCLIP_PUBLIC_URL, and provider keys
./install.sh
```

Open `http://localhost:13100/`, create the first board account, and configure
agents and API keys.

## sndbx

```bash
docker build -t paperclip:latest .
```

Merge `config.sndbx.json5` into the root `sndbx` configuration, set
`PAPERCLIP_HOST_ROOT` to this checkout, and start the `paperclip` sandbox.
The sandbox path aligns the container UID with the sndbx service user, so it
does not require `prepare_host_permissions.sh`; that script is for standalone
Docker Compose deployments only.

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
