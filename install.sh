#!/usr/bin/env bash
# Install and start the Docker Compose Paperclip service for this checkout.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir
readonly environment_file="${script_dir}/.env"
readonly service_name="paperclip"

prepare_environment() {
    if [[ ! -f "${environment_file}" ]]; then
        cp "${script_dir}/.env.example" "${environment_file}"
        chmod 0600 "${environment_file}"
    fi

    if grep --quiet '^BETTER_AUTH_SECRET=replace-with-a-long-random-secret$' "${environment_file}"; then
        local secret
        secret="$(openssl rand -hex 32)"
        sed -i "s/^BETTER_AUTH_SECRET=.*/BETTER_AUTH_SECRET=${secret}/" "${environment_file}"
        unset secret
    fi
}

main() {
    prepare_environment
    "${script_dir}/deploy.sh"
    printf '\nPaperclip is starting at %s\n' "$(sed -n 's/^PAPERCLIP_PUBLIC_URL=//p' "${environment_file}" | head -n1)"
    printf 'Create a board account on first open, then generate agent API keys for OpenClaw.\n'
    docker compose --project-directory "${script_dir}" logs --tail 20 "${service_name}" || true
}

main "$@"
