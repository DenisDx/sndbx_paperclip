#!/usr/bin/env bash
# Configure Paperclip public-origin settings for an sndbx installation.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir

resolve_sndbx_root() {
    # Return the configured sndbx root directory.
    local candidate="${1:-${SNDBX_ROOT:-}}"
    if [[ -z "${candidate}" ]]; then
        candidate="$(cd -- "${script_dir}/../.." && pwd -P)"
    fi
    if [[ ! -f "${candidate}/.env" ]]; then
        printf 'sndbx .env was not found at: %s\n' "${candidate}" >&2
        return 1
    fi
    printf '%s\n' "${candidate}"
}

synchronize_sndbx_environment() {
    # Copy Paperclip public-origin settings into the root sndbx environment.
    local paperclip_environment_file="$1"
    local sndbx_environment_file="$2"
    local variable_name

    for variable_name in \
        PAPERCLIP_PUBLIC_URL \
        PAPERCLIP_ALLOWED_HOSTNAMES \
        BETTER_AUTH_URL \
        BETTER_AUTH_TRUSTED_ORIGINS; do
        paperclip_set_environment_value \
            "${sndbx_environment_file}" \
            "${variable_name}" \
            "$(paperclip_environment_value "${paperclip_environment_file}" "${variable_name}")"
    done
    paperclip_set_environment_value "${sndbx_environment_file}" "PAPERCLIP_HOST_ROOT" "${script_dir}"
}

main() {
    # Prepare both environment files from one public-origin prompt.
    local sndbx_root
    source "${script_dir}/configure-public-origin.sh"
    sndbx_root="$(resolve_sndbx_root "${1:-}")"
    paperclip_prepare_environment "${script_dir}"
    paperclip_configure_public_origin "${script_dir}/.env"
    synchronize_sndbx_environment "${script_dir}/.env" "${sndbx_root}/.env"
    printf 'Paperclip public origin configured. Merge config.sndbx.json5 into %s/config.json5 if needed.\n' "${sndbx_root}"
}

main "$@"
