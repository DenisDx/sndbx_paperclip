#!/usr/bin/env bash
# Default Paperclip launcher: run the user start script when present, otherwise
# start the built server with its embedded database.
set -Eeuo pipefail

source /usr/local/lib/paperclip/load-env.sh

export HOME="${PAPERCLIP_HOME:-/paperclip}"
export HOST="${PAPERCLIP_BIND_HOST:-${HOST:-0.0.0.0}}"
export PORT="${PAPERCLIP_PORT:-${PORT:-3100}}"

start_script="${HOME}/config/start.sh"
if [[ -x "${start_script}" ]]; then
    exec "${start_script}"
fi

cd /app
exec node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
