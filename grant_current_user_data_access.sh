#!/usr/bin/env bash
# Restore the container user's ownership of data/ and grant the invoking user
# ACL read/write access to it only.
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

if (( EUID != 0 )); then
    exec sudo "$0" "$@"
fi

if [[ -z "${SUDO_USER:-}" || "${SUDO_USER}" == "root" ]]; then
    printf 'Run this script as the user who needs data access, not directly as root.\n' >&2
    exit 1
fi

if [[ -L "${script_dir}" || -L "${data_dir}" || ! -d "${data_dir}" ]]; then
    printf 'Expected a real data directory at %s\n' "${data_dir}" >&2
    exit 1
fi

read -r container_uid container_gid < <(container_ids)
target_user_id="$(id --user "${SUDO_USER}")"

chown --recursive "${container_uid}:${container_gid}" "${data_dir}"
setfacl --recursive --modify \
    "u:${target_user_id}:rwX,u:${container_uid}:rwX,m::rwX" "${data_dir}"
find "${data_dir}" -xdev -type d -exec setfacl --default --modify \
    "u::rwx,u:${target_user_id}:rwx,u:${container_uid}:rwx,g::r-x,m::rwx,o::---" {} +

printf 'Restored data ownership to UID:GID %s:%s and granted user %s (UID %s) ACL access to %s\n' \
    "${container_uid}" "${container_gid}" "${SUDO_USER}" "${target_user_id}" "${data_dir}"
