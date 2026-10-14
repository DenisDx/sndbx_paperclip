#!/usr/bin/env bash
# Install and start the Docker Compose Paperclip service for this checkout.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir
readonly environment_file="${script_dir}/.env"
readonly service_name="paperclip"

prepare_environment() {
    local environment_created=false

    if [[ ! -f "${environment_file}" ]]; then
        environment_created=true
    fi

    source "${script_dir}/configure-public-origin.sh"
    paperclip_prepare_environment "${script_dir}"
    if [[ "${environment_created}" == true ]]; then
        paperclip_configure_public_origin "${environment_file}"
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
