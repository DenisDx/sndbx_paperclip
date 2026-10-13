#!/usr/bin/env bash
# Grant the invoking user and the container user ACL access only to the
# persistent data directory mounted by Docker Compose.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir
readonly environment_file="${script_dir}/.env"
readonly portable_home_dir="${script_dir}/data"

# container_ids reads PAPERCLIP_UID/PAPERCLIP_GID from .env, defaulting to 1000.
container_ids() {
    local uid gid
    uid="$(sed -n 's/^PAPERCLIP_UID=//p' "${environment_file}" 2>/dev/null | head -n1)"
    gid="$(sed -n 's/^PAPERCLIP_GID=//p' "${environment_file}" 2>/dev/null | head -n1)"
    printf '%s %s\n' "${uid:-1000}" "${gid:-1000}"
}

require_sudo() {
    if (( EUID != 0 )); then
        exec sudo "$0" "$@"
    fi
}

invoking_user() {
    if [[ -z "${SUDO_USER:-}" || "${SUDO_USER}" == "root" ]]; then
        printf 'Run this script as the user who needs project access, not directly as root.\n' >&2
        exit 1
    fi
    id --user "${SUDO_USER}"
}

require_project_directory() {
    if [[ -L "${script_dir}" || ! -d "${script_dir}" ]]; then
        printf 'Expected a real project directory at %s\n' "${script_dir}" >&2
        exit 1
    fi
}

prepare_portable_mount_point() {
    local container_uid="$1"
    local container_gid="$2"
    mkdir --parents "${portable_home_dir}"
    chown --recursive "${container_uid}:${container_gid}" "${portable_home_dir}" 2>/dev/null || true
}

grant_data_access() {
    local invoking_user_id="$1"
    local container_uid="$2"

    setfacl --recursive --modify \
        "u:${invoking_user_id}:rwX,u:${container_uid}:rwX,m::rwX" "${portable_home_dir}"
    find "${portable_home_dir}" -type d -exec setfacl --default --modify \
        "u::rwx,u:${invoking_user_id}:rwx,u:${container_uid}:rwx,g::r-x,m::rwx,o::---" {} +
}

main() {
    require_sudo "$@"
    require_project_directory
    local user_id container_uid container_gid
    read -r container_uid container_gid < <(container_ids)
    user_id="$(invoking_user)"
    prepare_portable_mount_point "${container_uid}" "${container_gid}"
    grant_data_access "${user_id}" "${container_uid}"
    printf 'Granted ACL access to user UID %s and container UID %s in %s.\n' \
        "${user_id}" "${container_uid}" "${portable_home_dir}"
}

main "$@"
