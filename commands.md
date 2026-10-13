# Commands

Run commands from the Paperclip checkout unless stated otherwise.

## Docker Compose

```bash
docker compose build
bash ./deploy.sh
docker compose ps
docker compose logs -f paperclip
docker compose exec paperclip bash
docker compose restart paperclip
docker compose stop paperclip
docker compose down
```

`deploy.sh` asks for `sudo` and grants the invoking user and the container UID
ACL access only inside this checkout, then rebuilds and recreates the service.

## Paperclip API

```bash
curl -s "http://127.0.0.1:13100/api/health"
curl -s -H "Authorization: Bearer ${PAPERCLIP_API_KEY}" "http://127.0.0.1:13100/api/openapi.json"
```

## OpenClaw

From the remote OpenClaw host, using the published Paperclip API:

```bash
export PAPERCLIP_API_URL="http://<this-host>:13100"
export PAPERCLIP_API_KEY="<board or agent API key>"
curl -H "Authorization: Bearer ${PAPERCLIP_API_KEY}" "${PAPERCLIP_API_URL}/api/health"
```

## sndbx

```bash
docker build -t paperclip:latest .
```

Merge `config.sndbx.json5` into the root configuration, set
`PAPERCLIP_HOST_ROOT`, then start the `paperclip` sandbox with the normal sndbx
operator command or UI.

With public keys configured in the sandbox's `ssh_keys` list:

```bash
ssh -p 12022 node@127.0.0.1
```

## Backup and restore

```bash
docker compose stop paperclip
rsync -aAX --numeric-ids data/ /backup/paperclip-data/
rsync -aAX --numeric-ids /backup/paperclip-data/ data/
sudo ./run_after_restore.sh
docker compose up -d
```

## Permissions

```bash
sudo ./grant_current_user_data_access.sh
sudo ./run_after_restore.sh
```
