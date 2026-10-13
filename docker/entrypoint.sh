#!/usr/bin/env bash
# Container entrypoint: align the app user with the requested UID/GID, repair
# ownership of the persistent home, then drop privileges and start Paperclip.
set -Eeuo pipefail

source /usr/local/lib/paperclip/load-env.sh

export HOME="${PAPERCLIP_HOME:-/paperclip}"

target_uid="${PAPERCLIP_UID:-${USER_UID:-1000}}"
target_gid="${PAPERCLIP_GID:-${USER_GID:-1000}}"
home_dir="${PAPERCLIP_HOME:-/paperclip}"
ownership_marker="${home_dir}/.paperclip-ownership-verified"

if [[ "$(id -u)" -ne 0 ]]; then
    if [[ "$(id -u)" -ne "${target_uid}" || "$(id -g)" -ne "${target_gid}" ]]; then
        printf 'running unprivileged as %s:%s; cannot remap to %s:%s\n' \
            "$(id -u)" "$(id -g)" "${target_uid}" "${target_gid}" >&2
    fi
    exec "$@"
fi

# Remap the packaged node account only when the requested identity differs.
if [[ "$(id -u node)" -ne "${target_uid}" ]]; then
    printf 'updating node UID to %s\n' "${target_uid}" >&2
    usermod -o -u "${target_uid}" node
fi
if [[ "$(id -g node)" -ne "${target_gid}" ]]; then
    printf 'updating node GID to %s\n' "${target_gid}" >&2
    groupmod -o -g "${target_gid}" node
    usermod -g "${target_gid}" node
fi

# The mounted read-only environment file keeps its host ownership and is never
# touched. Confirm the mounted env file exists so the prune path matches the
# file that is actually mounted over the persistent home.
external_env="${home_dir}/.env"

# find_foreign prints the first home entry not owned by node below an optional
# depth, skipping the read-only environment file.
find_foreign() {
    local max_depth="$1"
    local -a cmd=(find "${home_dir}")
    if [[ -n "${max_depth}" ]]; then
        cmd+=(-maxdepth "${max_depth}")
    fi
    cmd+=(-path "${external_env}" -prune -o \( ! -user node -o ! -group node \) -print -quit)
    "${cmd[@]}" 2>/dev/null || true
}

# repair_ownership restores node ownership of the persistent home, skipping the
# read-only environment file.
repair_ownership() {
    find "${home_dir}" -path "${external_env}" -prune -o -exec chown node:node {} +
}

if [[ -d "${home_dir}" ]]; then
    expected_marker="v1 $(id -u node):$(id -g node)"
    current_marker="$(cat "${ownership_marker}" 2>/dev/null || true)"
    if [[ -n "$(find_foreign 3)" ]]; then
        printf 'repairing ownership of %s\n' "${home_dir}" >&2
        repair_ownership
    elif [[ "${current_marker}" != "${expected_marker}" ]]; then
        if [[ -z "$(find_foreign '')" ]]; then
            gosu node sh -c 'printf "%s\n" "$1" > "$2"' sh "${expected_marker}" "${ownership_marker}" 2>/dev/null || true
        else
            printf 'repairing ownership of %s\n' "${home_dir}" >&2
            repair_ownership
        fi
    fi
fi

printf 'starting paperclip as node (%s:%s)\n' "$(id -u node)" "$(id -g node)" >&2
exec gosu node "$@"
