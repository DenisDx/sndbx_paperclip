# Paperclip sndbx VM

A portable sndbx virtual machine that runs a self-hosted [Paperclip](https://github.com/paperclipai/paperclip)
instance ("the company") and can be wired to an OpenClaw instance running on
another machine ("the employee").

Paperclip is built from the pinned upstream source (`PAPERCLIP_REF`, default
`v2026.1012.0`) directly into the image. The server, the React UI, and the
embedded PostgreSQL database run in one container.

The whole instance lives in the host `data/` directory, bind-mounted at
`/paperclip`, which is the application home (`PAPERCLIP_HOME`). Copying `data/`
to another checkout moves the entire instance.

## Runtime identity

The container starts as root, remaps its internal `node` account to
`PAPERCLIP_UID:PAPERCLIP_GID` (default `1000:1000`), repairs ownership of
`/paperclip`, then drops privileges and runs Paperclip as `node`.

Set `PAPERCLIP_UID`/`PAPERCLIP_GID` in `.env` to the user that runs sndbx
(`id -u` / `id -g`) so every file created under `data/` belongs to that user.
`install.sh` writes the invoking user's IDs into `.env` on first run.

## Ports

All ports are loopback-or-LAN published from `.env`:

| Purpose | Host | Guest | Variable |
| --- | --- | --- | --- |
| Paperclip UI + API | `13100` | `3100` | `PAPERCLIP_HOST_PORT` |
| SSH (sndbx) | `12022` | `22` | `PAPERCLIP_SSH_HOST_PORT` |

`PAPERCLIP_BIND_HOST` controls both the server bind address and the host
interface the API is published on. Set `PAPERCLIP_PUBLIC_URL` to the URL remote
clients use (for example `http://192.168.1.111:13100`).

## OpenClaw integration

### OpenClaw manages Paperclip (outbound API)

Publish the Paperclip API and point the remote OpenClaw agent at it:

```bash
export PAPERCLIP_API_URL="http://192.168.1.111:13100"
export PAPERCLIP_API_KEY="<board or agent API key>"
curl -H "Authorization: Bearer ${PAPERCLIP_API_KEY}" "${PAPERCLIP_API_URL}/api/health"
```

Every endpoint is relative to `/api`. Mutating calls made during a run also send
`X-Paperclip-Run-Id`. Create API keys in the Paperclip UI (board account, then
agent keys) or through the API. The machine-readable surface is at
`GET /api/openapi.json`.

### Paperclip orchestrates OpenClaw (inbound adapter)

Paperclip drives a remote OpenClaw instance through the `openclaw_gateway`
adapter, which speaks the OpenClaw Gateway WebSocket protocol. Configure an
agent with:

- `url`: `ws://` or `wss://` address of the remote gateway. The
  `denis_obsidian_assistant` VM exposes its gateway through Caddy HTTPS, so use
  `wss://<host>:11443/` and trust Caddy's internal root certificate.
- `authToken` (or `headers["x-openclaw-token"]`): the remote gateway token.
- `autoPairOnFirstConnect` (default true) handles the one-time device pairing.

The Paperclip VM needs outbound network access to the OpenClaw host; sndbx
sandboxes have unrestricted networking by default.

## Docker Compose

```bash
cp .env.example .env
chmod 0600 .env
# edit PAPERCLIP_UID/GID, PAPERCLIP_PUBLIC_URL, and provider keys
./install.sh
```

`install.sh` creates `.env` and a private `BETTER_AUTH_SECRET` when needed, then
calls `deploy.sh`. `deploy.sh` runs `prepare_host_permissions.sh` (asks for the
invoking user's `sudo` password, grants ACL access only inside this checkout)
and then builds and recreates the service.

Open `http://localhost:13100/` (or the LAN URL), create a board account, and
configure agents.

## sndbx

Build the local image and register the sandbox:

```bash
docker build -t paperclip:latest .
```

Merge `config.sndbx.json5` into the root `sndbx` configuration and set
`PAPERCLIP_HOST_ROOT` to this checkout's absolute path. Then start the
`paperclip` sandbox.

Before the first sndbx start, run `./prepare_host_permissions.sh` from an
interactive terminal so the checkout's `data/` is writable by the container
user.

The sndbx lifecycle hook (`app.py`) repairs persistent ownership and starts
key-only SSH for `node`. Add public keys to the sandbox's `ssh_keys` list, then
restart or recreate it, and connect with `ssh -p 12022 node@127.0.0.1`.

## Safety

The service runs as an unprivileged `node` account. Secrets (`.env`, the
`BETTER_AUTH_SECRET`, agent API keys, provider keys) live under `data/` and in
`.env`, both of which are ignored by Git. Do not publish `data/` as a whole.

## Updates and backup

To update Paperclip, change `PAPERCLIP_REF` in the `Dockerfile`, rebuild the
image, and recreate the service. Do not run `apt upgrade` in a running VM.

For a consistent backup, stop the service first, then copy `data/` preserving
owners, groups, ACLs, extended attributes, and dotfiles:

```bash
docker compose stop paperclip
rsync -aAX --numeric-ids data/ /backup/paperclip-data/
docker compose up -d
```

If `data/` was copied without metadata, run `sudo ./run_after_restore.sh`
before starting the container.

## Diagnostics

```bash
docker compose ps
docker compose logs -f paperclip
docker compose exec paperclip bash
docker compose down
```

`commands.md` lists common operations. `GETTING_STARTED.md` is the shortest
first-run path. `TEST.md` records the verification protocol.
