#!/usr/bin/env bash
# Shared Paperclip public-origin configuration helpers.

paperclip_environment_value() {
    # Return a value from a shell-compatible environment file.
    local environment_file="$1"
    local variable_name="$2"
    sed -n "s/^${variable_name}=//p" "${environment_file}" | head -n1
}

paperclip_set_environment_value() {
    # Replace one environment-file value without exposing other settings.
    local environment_file="$1"
    local variable_name="$2"
    local value="$3"
    local temporary_file

    temporary_file="$(mktemp "${environment_file}.XXXXXX")"
    awk -v name="${variable_name}" -v value="${value}" '
        BEGIN { replaced = 0 }
        $0 ~ "^" name "=" {
            print name "=" value
            replaced = 1
            next
        }
        { print }
        END {
            if (!replaced) {
                print name "=" value
            }
        }
    ' "${environment_file}" > "${temporary_file}"
    chmod --reference="${environment_file}" "${temporary_file}"
    mv "${temporary_file}" "${environment_file}"
}

paperclip_prepare_environment() {
    # Create the private environment file and generate its session secret.
    local install_dir="$1"
    local environment_file="${install_dir}/.env"

    if [[ ! -f "${environment_file}" ]]; then
        cp "${install_dir}/.env.example" "${environment_file}"
        chmod 0600 "${environment_file}"
    fi

    if grep --quiet '^BETTER_AUTH_SECRET=replace-with-a-long-random-secret$' "${environment_file}"; then
        local secret
        secret="$(openssl rand -hex 32)"
        paperclip_set_environment_value "${environment_file}" "BETTER_AUTH_SECRET" "${secret}"
        unset secret
    fi
}

paperclip_configure_public_origin() {
    # Prompt for a public origin and synchronize its Paperclip settings.
    local environment_file="$1"
    local configured_port origin host public_url

    configured_port="$(paperclip_environment_value "${environment_file}" "PAPERCLIP_HOST_PORT")"
    configured_port="${configured_port:-13100}"
    origin="${PAPERCLIP_PUBLIC_ORIGIN:-}"
    if [[ -z "${origin}" ]]; then
        read -r -p "Paperclip public host/IP or URL [http://localhost:${configured_port}]: " origin
        origin="${origin:-http://localhost:${configured_port}}"
    fi

    origin="${origin%/}"
    if [[ "${origin}" =~ ^https?://([^/:]+)(:[0-9]+)?$ ]]; then
        public_url="${origin}"
        host="${BASH_REMATCH[1]}"
    elif [[ "${origin}" =~ ^[A-Za-z0-9.-]+$ ]]; then
        host="${origin}"
        public_url="http://${host}:${configured_port}"
    else
        printf 'Invalid Paperclip public origin: %s\n' "${origin}" >&2
        return 1
    fi

    paperclip_set_environment_value "${environment_file}" "PAPERCLIP_PUBLIC_URL" "${public_url}"
    paperclip_set_environment_value "${environment_file}" "PAPERCLIP_ALLOWED_HOSTNAMES" "${host}"
    paperclip_set_environment_value "${environment_file}" "BETTER_AUTH_URL" "${public_url}"
    paperclip_set_environment_value "${environment_file}" "BETTER_AUTH_TRUSTED_ORIGINS" "${public_url}"
}
