#!/usr/bin/env bash
# Restore project-local data permissions, then build and recreate the service.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir

main() {
    "${script_dir}/prepare_host_permissions.sh"
    docker compose --project-directory "${script_dir}" up --detach --build --force-recreate "$@"
}

main "$@"
