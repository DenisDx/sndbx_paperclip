# Test Protocol

Static checks run without Docker. The build and runtime checks require Docker.

## Static checks

```bash
bash -n docker/entrypoint.sh docker/start-paperclip.sh docker/load-paperclip-env.sh
bash -n install.sh deploy.sh prepare_host_permissions.sh grant_current_user_data_access.sh run_after_restore.sh
python3 -m py_compile app.py
```

- Confirm `config.sndbx.json5` loads through sndbx's configuration loader with
  `PAPERCLIP_HOST_ROOT` set to the absolute checkout path.
- Confirm `.env` and `.env.example` expose the same keys.

## Image build

```bash
docker build -t paperclip:latest .
docker run --rm --entrypoint bash paperclip:latest -lc 'id node; node --version; test -f /app/server/dist/index.js'
```

Expected: the build finishes, `server/dist/index.js` exists, and `node --version`
reports v24.

## Runtime (Docker Compose)

```bash
cp .env.example .env
./install.sh
docker compose ps
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:13100/api/health
```

Expected: the service is running and `/api/health` returns HTTP 200.

## Runtime identity

```bash
docker compose exec paperclip id
ls -ln data/instances | head
```

Expected: the app runs as the configured `PAPERCLIP_UID:PAPERCLIP_GID` and files
created under `data/` are owned by that UID/GID.

## OpenClaw integration

```bash
curl -s -H "Authorization: Bearer ${PAPERCLIP_API_KEY}" \
  "http://<host>:13100/api/health"
```

Expected: HTTP 200 from a different machine, proving the API is reachable.
Paperclip-to-OpenClaw delegation is verified by adding an `openclaw_gateway`
agent and running a task; the gateway URL must be `ws://` or `wss://`.
