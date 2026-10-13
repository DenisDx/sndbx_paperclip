#!/usr/bin/env bash
# Restore Paperclip data ownership, modes, and the optional startup script
# after a backup was copied without preserving metadata.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir
readonly environment_file="${script_dir}/.env"
readonly data_dir="${script_dir}/data"

# container_ids reads PAPERCLIP_UID/PAPERCLIP_GID from .env, defaulting to 1000.
container_ids() {
    local uid gid
    uid="$(sed -n 's/^PAPERCLIP_UID=//p' "${environment_file}" 2>/dev/null | head -n1)"
    gid="$(sed -n 's/^PAPERCLIP_GID=//p' "${environment_file}" 2>/dev/null | head -n1)"
    printf '%s %s\n' "${uid:-1000}" "${gid:-1000}"
}

require_root() {
    if (( EUID != 0 )); then
        printf 'Run this script with sudo: sudo %q\n' "$0" >&2
        exit 1
    fi
}

require_data_directory() {
    if [[ -L "${data_dir}" || ! -d "${data_dir}" ]]; then
        printf 'Expected a real data directory at %s\n' "${data_dir}" >&2
        exit 1
    fi
}

restore_owner_and_modes() {
    local container_uid="$1"
    local container_gid="$2"
    chown --recursive "${container_uid}:${container_gid}" "${data_dir}"
    find "${data_dir}" -xdev -type d -exec chmod 0750 {} +
    find "${data_dir}" -xdev -type f -perm /0111 -exec chmod 0750 {} +
    find "${data_dir}" -xdev -type f ! -perm /0111 -exec chmod 0640 {} +
}

restore_runtime_files() {
    local startup_script="${data_dir}/config/start.sh"
    if [[ -f "${startup_script}" ]]; then
        chmod 0750 "${startup_script}"
    fi
}

main() {
    require_root
    require_data_directory
    local container_uid container_gid
    read -r container_uid container_gid < <(container_ids)
    restore_owner_and_modes "${container_uid}" "${container_gid}"
    restore_runtime_files
    printf 'Restored Paperclip data permissions at %s\n' "${data_dir}"
}

main "$@"
