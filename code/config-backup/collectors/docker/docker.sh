#!/usr/bin/env bash

[[ -n "${POLARIS_DOCKER_SH_LOADED:-}" ]] && return 0
readonly POLARIS_DOCKER_SH_LOADED=1

###############################################################################
# Project Polaris
# Docker01 Configuration Collector
###############################################################################

###############################################################################
# Framework Initialization
###############################################################################

POLARIS_DOCKER_COLLECTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly POLARIS_DOCKER_COLLECTOR_DIR

POLARIS_DOCKER_FRAMEWORK_ROOT="$(cd -- "${POLARIS_DOCKER_COLLECTOR_DIR}/../.." && pwd -P)"
readonly POLARIS_DOCKER_FRAMEWORK_ROOT

readonly POLARIS_DOCKER_LIB_DIR="${POLARIS_DOCKER_FRAMEWORK_ROOT}/lib"

# shellcheck source=/dev/null
source "${POLARIS_DOCKER_LIB_DIR}/polaris-common.sh"

readonly POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_DOCKER_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_DOCKER_COLLECTOR_RESULT_NO_CHANGE=2

readonly POLARIS_DOCKER_MODULE_NAME="docker"
readonly POLARIS_DOCKER_MODULE_DISPLAY_NAME="Docker01 Collector"
readonly POLARIS_DOCKER_MODULE_VERSION="1.8.0"
readonly POLARIS_DOCKER_MODULE_AUTHOR="Project Polaris"

readonly DOCKER_COLLECTION_STATUS_COMPOSE_DISCOVERY="engine-daemon-and-compose-discovery"

readonly POLARIS_DOCKER_HOST="192.168.10.20"
readonly POLARIS_DOCKER_USER="lab-admin"
readonly POLARIS_DOCKER_SSH_KEY="/root/.ssh/polaris-docker-backup"
readonly POLARIS_DOCKER_SSH_CONNECT_TIMEOUT="10"

POLARIS_DOCKER_STAGING_ROOT=""
POLARIS_DOCKER_CONFIGURATION_DIR=""
POLARIS_DOCKER_DOCKER_DIR=""
POLARIS_DOCKER_ENGINE_DIR=""
POLARIS_DOCKER_DAEMON_DIR=""
POLARIS_DOCKER_COMPOSE_DIR=""
POLARIS_DOCKER_CONTAINER_DIR=""
POLARIS_DOCKER_NETWORK_DIR=""
POLARIS_DOCKER_VOLUME_DIR=""
POLARIS_DOCKER_HOST_DIR=""
POLARIS_DOCKER_METADATA_DIR=""
POLARIS_DOCKER_COLLECTION_STATUS=""


# Purpose: Provide the Docker collector with its configured shared SSH transport.
# This comment documents intent; implementation behavior is unchanged.
_docker_ssh() {
    local stdin_mode="${1:-allow}"
    local remote_command="${2:-}"

    polaris_ssh_execute \
        "${POLARIS_DOCKER_HOST}" \
        "${POLARIS_DOCKER_USER}" \
        "${POLARIS_DOCKER_SSH_KEY}" \
        "${POLARIS_DOCKER_SSH_CONNECT_TIMEOUT}" \
        "${stdin_mode}" \
        "no" \
        "${remote_command}"
}

# Purpose: Validate environment before continuing with the collection lifecycle.
# This comment documents intent; implementation behavior is unchanged.
_validate_environment() {
    local required_commands=(awk date find install python3 sha256sum ssh stat)
    local required_command=""

    log_info "Validating Docker01 collector environment."

    if ! is_root_user; then
        operator_error "Collector must be run as root."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    for required_command in "${required_commands[@]}"; do
        if ! command_exists "${required_command}"; then
            operator_error "Required command is not available: ${required_command}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi
    done

    if [[ ! -r "${POLARIS_DOCKER_SSH_KEY}" ]]; then
        operator_error "Docker01 SSH private key is not readable: ${POLARIS_DOCKER_SSH_KEY}"
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_ssh "allow" \
        "command -v docker >/dev/null 2>&1 &&
         docker info >/dev/null 2>&1 &&
         systemctl is-active --quiet docker"
    then
        operator_error "Unable to validate unattended Docker access on Docker01."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Docker01 collector environment validation successful."
    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Initialize staging required by the collection lifecycle.
# This comment documents intent; implementation behavior is unchanged.
_initialize_staging() {
    local staging_root="${1:-}"

    if [[ -z "${staging_root}" ]]; then
        operator_error "Docker01 staging root was not provided."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_DOCKER_STAGING_ROOT="${staging_root}"
    POLARIS_DOCKER_CONFIGURATION_DIR="${POLARIS_DOCKER_STAGING_ROOT}/configuration"
    POLARIS_DOCKER_DOCKER_DIR="${POLARIS_DOCKER_CONFIGURATION_DIR}/docker"
    POLARIS_DOCKER_ENGINE_DIR="${POLARIS_DOCKER_DOCKER_DIR}/engine"
    POLARIS_DOCKER_DAEMON_DIR="${POLARIS_DOCKER_DOCKER_DIR}/daemon"
    POLARIS_DOCKER_COMPOSE_DIR="${POLARIS_DOCKER_DOCKER_DIR}/compose"
    POLARIS_DOCKER_CONTAINER_DIR="${POLARIS_DOCKER_DOCKER_DIR}/containers"
    POLARIS_DOCKER_NETWORK_DIR="${POLARIS_DOCKER_DOCKER_DIR}/networks"
    POLARIS_DOCKER_VOLUME_DIR="${POLARIS_DOCKER_DOCKER_DIR}/volumes"
    POLARIS_DOCKER_HOST_DIR="${POLARIS_DOCKER_DOCKER_DIR}/host"
    POLARIS_DOCKER_METADATA_DIR="${POLARIS_DOCKER_STAGING_ROOT}/metadata"

    if ! polaris_prepare_staging_directories \
        "${POLARIS_DOCKER_STAGING_ROOT}" \
        "Docker01" \
        "${POLARIS_DOCKER_ENGINE_DIR}" \
        "${POLARIS_DOCKER_DAEMON_DIR}" \
        "${POLARIS_DOCKER_COMPOSE_DIR}" \
        "${POLARIS_DOCKER_CONTAINER_DIR}" \
        "${POLARIS_DOCKER_NETWORK_DIR}" \
        "${POLARIS_DOCKER_VOLUME_DIR}" \
        "${POLARIS_DOCKER_HOST_DIR}" \
        "${POLARIS_DOCKER_METADATA_DIR}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_DOCKER_COLLECTION_STATUS="${DOCKER_COLLECTION_STATUS_COMPOSE_DISCOVERY}"

    log_success "Docker01 staging directories initialized."
    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Execute one Docker host command while preserving the collector’s output and error-handling contract.
# This comment documents intent; implementation behavior is unchanged.
_docker_remote_execute() {
    local remote_command="${1:-}"
    local output_file="${2:-}"

    if [[ -z "${remote_command}" ]]; then
        operator_error "Docker01 remote command was not provided."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ -z "${output_file}" ]]; then
        operator_error "Docker01 remote command output path was not provided."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! polaris_ssh_execute_to_file \
        "${POLARIS_DOCKER_HOST}" \
        "${POLARIS_DOCKER_USER}" \
        "${POLARIS_DOCKER_SSH_KEY}" \
        "${POLARIS_DOCKER_SSH_CONNECT_TIMEOUT}" \
        "allow" \
        "no" \
        "${remote_command}" \
        "${output_file}" \
        "reject" \
        "Docker01"
    then
        operator_error "Docker01 remote command failed: ${remote_command}"
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Record why an optional Docker artifact was unavailable instead of silently omitting it.
# This comment documents intent; implementation behavior is unchanged.
_write_placeholder_artifact() {
    local output_file="${1:-}"
    local artifact_title="${2:-Unnamed artifact}"
    local reason="${3:-Reason unavailable}"
    local timestamp=""

    if [[ -z "${output_file}" ]]; then
        operator_error "Docker01 placeholder output path was not provided."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" || {
        operator_error "Unable to generate Docker01 placeholder timestamp."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    }

    if ! cat > "${output_file}" <<EOF
Project Polaris Docker01 Collector Placeholder
==============================================

Artifact: ${artifact_title}
Timestamp (UTC): ${timestamp}
Status: Not collected
Reason: ${reason}
Collector Version: ${POLARIS_DOCKER_MODULE_VERSION}
EOF
    then
        operator_error "Unable to write Docker01 placeholder artifact: ${output_file}"
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    chmod 600 "${output_file}" || {
        operator_error "Unable to secure Docker01 placeholder artifact: ${output_file}"
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    }

    [[ -s "${output_file}" ]] || {
        operator_error "Docker01 placeholder artifact is empty: ${output_file}"
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    }

    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Collect an optional remote file or write a traceable absence artifact.
# This comment documents intent; implementation behavior is unchanged.
_collect_optional_remote_file() {
    local remote_path="${1:-}"
    local collected_file="${2:-}"
    local placeholder_file="${3:-}"
    local artifact_title="${4:-Remote file}"
    local ssh_result=0

    if [[ -z "${remote_path}" ]] ||
       [[ -z "${collected_file}" ]] ||
       [[ -z "${placeholder_file}" ]]
    then
        operator_error "Docker01 optional remote-file parameters were not provided."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    _docker_ssh "allow" \
                "if [ ! -e '${remote_path}' ]; then
             exit 3
         elif [ ! -f '${remote_path}' ]; then
             exit 4
         elif [ ! -r '${remote_path}' ]; then
             exit 5
         else
             cat -- '${remote_path}'
         fi" \
        > "${collected_file}" 2>&1

    ssh_result=$?

    case "${ssh_result}" in
        0)
            rm -f -- "${placeholder_file}"

            if ! chmod 600 "${collected_file}"; then
                operator_error \
                    "Unable to secure collected Docker01 file: ${collected_file}"
                return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
            fi

            if [[ ! -s "${collected_file}" ]]; then
                operator_error \
                    "Collected Docker01 file is empty: ${remote_path}"
                return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
            fi

            return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
            ;;

        3)
            rm -f -- "${collected_file}"

            _write_placeholder_artifact \
                "${placeholder_file}" \
                "${artifact_title}" \
                "Remote file is not present: ${remote_path}"
            return $?
            ;;

        4)
            rm -f -- "${collected_file}"
            operator_error \
                "Docker01 remote path exists but is not a regular file: ${remote_path}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
            ;;

        5)
            rm -f -- "${collected_file}"
            operator_error \
                "Docker01 remote file is not readable by ${POLARIS_DOCKER_USER}: ${remote_path}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
            ;;

        *)
            rm -f -- "${collected_file}"
            operator_error \
                "Unable to inspect or collect Docker01 remote file: ${remote_path}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
            ;;
    esac
}

# Purpose: Collect daemon configuration data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_collect_daemon_configuration() {
    local remote_daemon_file="/etc/docker/daemon.json"
    local collected_file="${POLARIS_DOCKER_DAEMON_DIR}/daemon.json"
    local placeholder_file="${POLARIS_DOCKER_DAEMON_DIR}/daemon-placeholder.txt"
    local summary_file="${POLARIS_DOCKER_DAEMON_DIR}/daemon-summary.txt"
    local configuration_status=""
    local configuration_source=""

    log_info "Collecting Docker01 daemon configuration."

    if [[ -z "${POLARIS_DOCKER_DAEMON_DIR}" ]] ||
       [[ ! -d "${POLARIS_DOCKER_DAEMON_DIR}" ]]
    then
        operator_error \
            "Docker01 daemon staging directory has not been initialized."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_optional_remote_file \
        "${remote_daemon_file}" \
        "${collected_file}" \
        "${placeholder_file}" \
        "Docker daemon configuration"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ -f "${collected_file}" ]]; then
        configuration_status="Present"
        configuration_source="Custom daemon.json"
    elif [[ -f "${placeholder_file}" ]]; then
        configuration_status="Not Present"
        configuration_source="Docker defaults"
    else
        operator_error \
            "Docker01 daemon collection produced neither a configuration nor a placeholder."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! cat > "${summary_file}" <<EOF
Project Polaris Docker01 Daemon Summary
=======================================

Target Host: ${POLARIS_DOCKER_HOST}
Configuration File: ${remote_daemon_file}
Configuration Status: ${configuration_status}
Configuration Source: ${configuration_source}
Collection Status: Success
EOF
    then
        operator_error "Unable to write Docker01 daemon summary."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Docker01 daemon summary."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Docker01 daemon summary is empty."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Docker01 daemon configuration collected successfully."
    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}


# Purpose: Collect engine information data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_collect_engine_information() {
    local docker_version_file="${POLARIS_DOCKER_ENGINE_DIR}/docker-version.txt"
    local compose_version_file="${POLARIS_DOCKER_ENGINE_DIR}/compose-version.txt"
    local docker_info_file="${POLARIS_DOCKER_ENGINE_DIR}/docker-info.txt"
    local service_status_file="${POLARIS_DOCKER_ENGINE_DIR}/docker-service-status.txt"
    local engine_summary_file="${POLARIS_DOCKER_ENGINE_DIR}/engine-summary.txt"

    local docker_version=""
    local compose_version=""
    local service_status=""

    log_info "Collecting Docker01 engine information."

    if [[ -z "${POLARIS_DOCKER_ENGINE_DIR}" ]] ||
       [[ ! -d "${POLARIS_DOCKER_ENGINE_DIR}" ]]
    then
        operator_error "Docker01 engine staging directory has not been initialized."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    _docker_remote_execute "docker --version" "${docker_version_file}" || return 1
    _docker_remote_execute "docker compose version" "${compose_version_file}" || return 1
    _docker_remote_execute "docker info" "${docker_info_file}" || return 1
    _docker_remote_execute "systemctl is-active docker" "${service_status_file}" || return 1

    docker_version="$(head -n 1 "${docker_version_file}")"
    compose_version="$(head -n 1 "${compose_version_file}")"
    service_status="$(head -n 1 "${service_status_file}")"

    if ! cat > "${engine_summary_file}" <<EOF
Project Polaris Docker01 Engine Summary
=======================================

Target Host: ${POLARIS_DOCKER_HOST}
Remote User: ${POLARIS_DOCKER_USER}
Docker Engine: ${docker_version}
Docker Compose: ${compose_version}
Docker Service Status: ${service_status}
Detailed Docker Information: docker-info.txt
EOF
    then
        operator_error "Unable to write Docker01 engine summary."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    chmod 600 "${engine_summary_file}" || {
        operator_error "Unable to secure Docker01 engine summary."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    }

    [[ -s "${engine_summary_file}" ]] || {
        operator_error "Docker01 engine summary is empty."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    }

    log_success "Docker01 engine information collected successfully."
    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Collect compose discovery data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_collect_compose_discovery() {
    local raw_projects_file="${POLARIS_DOCKER_COMPOSE_DIR}/.compose-projects.json"
    local parsed_projects_file="${POLARIS_DOCKER_COMPOSE_DIR}/.compose-inventory.tsv"
    local parser_counts_file="${POLARIS_DOCKER_COMPOSE_DIR}/.compose-parser-counts.txt"
    local discovered_files_file="${POLARIS_DOCKER_COMPOSE_DIR}/.discovered-compose-files.txt"
    local output_file="${POLARIS_DOCKER_COMPOSE_DIR}/project-list.txt"

    local project_name=""
    local project_status=""
    local compose_file=""
    local working_directory=""
    local validation_status=""
    local quoted_compose_file=""
    local discovered_path=""

    local docker_reported_project_count=0
    local parser_project_count=0
    local parser_compose_file_count=0
    local validated_project_count=0
    local validated_compose_file_count=0
    local additional_file_count=0

    declare -A active_compose_files=()
    declare -A validated_projects=()

    log_info "Discovering Docker01 Compose projects."

    if [[ -z "${POLARIS_DOCKER_COMPOSE_DIR}" ]] ||
       [[ ! -d "${POLARIS_DOCKER_COMPOSE_DIR}" ]]
    then
        operator_error \
            "Docker01 Compose staging directory has not been initialized."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        "docker compose ls --all --format json" \
        "${raw_projects_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! python3 - \
        "${raw_projects_file}" \
        "${parsed_projects_file}" \
        "${parser_counts_file}" <<'PY'
import json
import os
import sys
from typing import Any

source_path = sys.argv[1]
inventory_path = sys.argv[2]
counts_path = sys.argv[3]

with open(source_path, "r", encoding="utf-8") as source_file:
    raw_text = source_file.read().strip()

if not raw_text:
    raise SystemExit("Docker Compose project output is empty.")

def normalize_records(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        return [value]
    raise ValueError("Docker Compose JSON contains an unsupported top-level value.")

records: list[dict[str, Any]] = []

try:
    parsed = json.loads(raw_text)
    records.extend(normalize_records(parsed))
except json.JSONDecodeError:
    decoder = json.JSONDecoder()
    position = 0
    length = len(raw_text)

    while position < length:
        while position < length and raw_text[position].isspace():
            position += 1

        if position >= length:
            break

        value, next_position = decoder.raw_decode(raw_text, position)
        records.extend(normalize_records(value))
        position = next_position

if not records:
    raise SystemExit("Docker Compose reported no projects.")

inventory_rows: list[tuple[str, str, str, str]] = []
project_names: set[str] = set()

for project in records:
    if not isinstance(project, dict):
        raise SystemExit("Docker Compose project output contains an invalid record.")

    name = str(project.get("Name", "")).strip()
    status = str(project.get("Status", "")).strip()
    config_value = project.get("ConfigFiles", "")

    if not name:
        raise SystemExit("Docker Compose project record is missing a project name.")

    project_names.add(name)

    if isinstance(config_value, list):
        config_paths = [str(path).strip() for path in config_value if str(path).strip()]
    else:
        config_paths = [
            path.strip()
            for path in str(config_value).split(",")
            if path.strip()
        ]

    if not config_paths:
        raise SystemExit(
            f"Docker Compose project '{name}' has no reported configuration file."
        )

    for compose_path in config_paths:
        inventory_rows.append(
            (
                name,
                status,
                compose_path,
                os.path.dirname(compose_path),
            )
        )

inventory_rows.sort(key=lambda row: (row[0], row[2]))

with open(inventory_path, "w", encoding="utf-8", newline="\n") as inventory_file:
    for row in inventory_rows:
        inventory_file.write("\t".join(row) + "\n")

with open(counts_path, "w", encoding="utf-8", newline="\n") as counts_file:
    counts_file.write(f"docker_reported_projects={len(project_names)}\n")
    counts_file.write(f"parser_projects={len(project_names)}\n")
    counts_file.write(f"parser_compose_files={len(inventory_rows)}\n")
PY
    then
        operator_error \
            "Unable to parse Docker01 Compose project discovery output."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${parsed_projects_file}" ]] ||
       [[ ! -s "${parser_counts_file}" ]]
    then
        operator_error \
            "Docker01 Compose parser did not produce a complete inventory."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    # shellcheck disable=SC1090
    source "${parser_counts_file}"

    docker_reported_project_count="${docker_reported_projects:-0}"
    parser_project_count="${parser_projects:-0}"
    parser_compose_file_count="${parser_compose_files:-0}"

    if [[ ! "${docker_reported_project_count}" =~ ^[0-9]+$ ]] ||
       [[ ! "${parser_project_count}" =~ ^[0-9]+$ ]] ||
       [[ ! "${parser_compose_file_count}" =~ ^[0-9]+$ ]]
    then
        operator_error \
            "Docker01 Compose parser produced invalid inventory counts."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if (( docker_reported_project_count == 0 )) ||
       (( parser_project_count == 0 )) ||
       (( parser_compose_file_count == 0 ))
    then
        operator_error \
            "Docker01 Compose parser produced an empty inventory."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if (( docker_reported_project_count != parser_project_count )); then
        operator_error \
            "Docker01 Compose parser project count does not match Docker output."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_ssh "allow" \
                'find /opt /srv /home \
            -xdev \
            -type f \
            \( \
                -name compose.yml \
                -o -name compose.yaml \
                -o -name docker-compose.yml \
                -o -name docker-compose.yaml \
            \) \
            -print 2>/dev/null | sort' \
        > "${discovered_files_file}"
    then
        operator_error \
            "Unable to perform supplemental Docker01 Compose file discovery."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 \
        "${raw_projects_file}" \
        "${parsed_projects_file}" \
        "${parser_counts_file}" \
        "${discovered_files_file}"
    then
        operator_error \
            "Unable to secure temporary Docker01 Compose discovery artifacts."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! cat > "${output_file}" <<EOF
Project Polaris Docker01 Compose Discovery
==========================================

Target Host: ${POLARIS_DOCKER_HOST}
Discovery Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Authoritative Source: docker compose ls --all --format json

Active Docker Compose Projects
==============================
EOF
    then
        operator_error \
            "Unable to initialize Docker01 Compose project list."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    while IFS=$'\t' read -r \
        project_name \
        project_status \
        compose_file \
        working_directory
    do
        if [[ -z "${project_name}" ]] ||
           [[ -z "${compose_file}" ]] ||
           [[ -z "${working_directory}" ]]
        then
            operator_error \
                "Docker01 Compose discovery produced an incomplete project record."
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        printf -v quoted_compose_file '%q' "${compose_file}"

        if _docker_ssh "disable" \
                        "test -f ${quoted_compose_file} && test -r ${quoted_compose_file}"
        then
            validation_status="Readable"
        else
            operator_error \
                "Docker01 Compose file is missing or unreadable: ${compose_file}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        active_compose_files["${compose_file}"]=1

        if [[ -z "${validated_projects[${project_name}]+x}" ]]; then
            validated_projects["${project_name}"]=1
            ((++validated_project_count))
        fi

        ((++validated_compose_file_count))

        if ! cat >> "${output_file}" <<EOF

Project Name: ${project_name}
Status: ${project_status}
Compose File: ${compose_file}
Working Directory: ${working_directory}
Validation: ${validation_status}
------------------------------------------------------------
EOF
        then
            operator_error \
                "Unable to write Docker01 Compose project record."
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

    done < "${parsed_projects_file}"

    if (( validated_project_count != parser_project_count )); then
        operator_error \
            "Docker01 validated project count does not match the parsed inventory."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if (( validated_compose_file_count != parser_compose_file_count )); then
        operator_error \
            "Docker01 validated Compose file count does not match the parsed inventory."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! cat >> "${output_file}" <<EOF

Discovery Validation Counts
===========================
Docker Reported Projects: ${docker_reported_project_count}
Parser Projects: ${parser_project_count}
Parser Compose Files: ${parser_compose_file_count}
Validated Projects: ${validated_project_count}
Validated Compose Files: ${validated_compose_file_count}

Additional Compose Files Discovered
===================================
EOF
    then
        operator_error \
            "Unable to initialize supplemental Docker01 Compose discovery section."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    while IFS= read -r discovered_path; do
        [[ -z "${discovered_path}" ]] && continue

        if [[ -n "${active_compose_files[${discovered_path}]+x}" ]]; then
            continue
        fi

        ((++additional_file_count))

        if ! cat >> "${output_file}" <<EOF

Path: ${discovered_path}
Reason Not Selected: Not reported by Docker as an active or known Compose project.
------------------------------------------------------------
EOF
        then
            operator_error \
                "Unable to write supplemental Docker01 Compose discovery record."
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi
    done < "${discovered_files_file}"

    if (( additional_file_count == 0 )); then
        if ! cat >> "${output_file}" <<EOF

No additional Compose files were discovered.
EOF
        then
            operator_error \
                "Unable to finalize Docker01 Compose discovery report."
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi
    fi

    if ! printf '\nAdditional Compose File Count: %d\n' \
        "${additional_file_count}" \
        >> "${output_file}"
    then
        operator_error \
            "Unable to write Docker01 supplemental Compose file count."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error \
            "Unable to secure Docker01 Compose project list."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error \
            "Docker01 Compose project list is empty."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! rm -f -- \
        "${raw_projects_file}" \
        "${parser_counts_file}" \
        "${discovered_files_file}"
    then
        operator_error \
            "Unable to remove temporary Docker01 Compose discovery artifacts."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Docker01 Compose project discovery completed successfully."

    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Collect compose project files data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_collect_compose_project_files() {
    local inventory_file="${POLARIS_DOCKER_COMPOSE_DIR}/.compose-inventory.tsv"
    local projects_root="${POLARIS_DOCKER_COMPOSE_DIR}/projects"

    local project_name=""
    local project_status=""
    local compose_file=""
    local working_directory=""
    local project_directory=""
    local compose_basename=""
    local compose_destination=""
    local summary_file=""
    local quoted_remote_path=""
    local quoted_working_directory=""
    local remote_optional_list=""
    local remote_optional_path=""
    local optional_basename=""
    local optional_destination=""
    local env_count=0
    local override_count=0
    local project_count=0

    log_info "Collecting Docker01 Compose project files."

    if [[ ! -s "${inventory_file}" ]]; then
        operator_error \
            "Docker01 Compose inventory is unavailable for project collection."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! install -d -m 700 "${projects_root}"; then
        operator_error \
            "Unable to create the Docker01 Compose projects staging directory."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    while IFS=$'\t' read -r \
        project_name \
        project_status \
        compose_file \
        working_directory
    do
        if [[ -z "${project_name}" ]] ||
           [[ -z "${compose_file}" ]] ||
           [[ -z "${working_directory}" ]]
        then
            operator_error \
                "Docker01 Compose inventory contains an incomplete project record."
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        if [[ ! "${project_name}" =~ ^[A-Za-z0-9._-]+$ ]]; then
            operator_error \
                "Docker01 Compose project name is unsafe for local staging: ${project_name}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        project_directory="${projects_root}/${project_name}"
        compose_basename="$(basename -- "${compose_file}")"
        compose_destination="${project_directory}/${compose_basename}"
        summary_file="${project_directory}/compose-summary.txt"
        env_count=0
        override_count=0

        if ! install -d -m 700 "${project_directory}"; then
            operator_error \
                "Unable to create Docker01 Compose project directory: ${project_name}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        printf -v quoted_remote_path '%q' "${compose_file}"

        if ! _docker_ssh "disable" \
                        "cat -- ${quoted_remote_path}" \
            > "${compose_destination}"
        then
            operator_error \
                "Unable to collect Docker01 Compose file: ${compose_file}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        if ! chmod 600 "${compose_destination}"; then
            operator_error \
                "Unable to secure collected Docker01 Compose file: ${compose_destination}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        if [[ ! -s "${compose_destination}" ]]; then
            operator_error \
                "Collected Docker01 Compose file is empty: ${compose_file}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        printf -v quoted_working_directory '%q' "${working_directory}"

        if ! remote_optional_list="$(
            _docker_ssh "disable" \
                                "find ${quoted_working_directory} \
                    -mindepth 1 \
                    -maxdepth 1 \
                    -type f \
                    \\( \
                        -name '.env' \
                        -o -name '*.env' \
                        -o -name 'compose.override.yml' \
                        -o -name 'compose.override.yaml' \
                        -o -name 'docker-compose.override.yml' \
                        -o -name 'docker-compose.override.yaml' \
                    \\) \
                    -print 2>/dev/null | sort"
        )"
        then
            operator_error \
                "Unable to inventory optional Docker01 Compose files for project: ${project_name}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        while IFS= read -r remote_optional_path; do
            [[ -z "${remote_optional_path}" ]] && continue

            optional_basename="$(basename -- "${remote_optional_path}")"
            optional_destination="${project_directory}/${optional_basename}"
            printf -v quoted_remote_path '%q' "${remote_optional_path}"

            if ! _docker_ssh "disable" \
                                "cat -- ${quoted_remote_path}" \
                > "${optional_destination}"
            then
                operator_error \
                    "Unable to collect optional Docker01 Compose file: ${remote_optional_path}"
                return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
            fi

            if ! chmod 600 "${optional_destination}"; then
                operator_error \
                    "Unable to secure optional Docker01 Compose file: ${optional_destination}"
                return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
            fi

            if [[ ! -s "${optional_destination}" ]]; then
                operator_error \
                    "Collected optional Docker01 Compose file is empty: ${remote_optional_path}"
                return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
            fi

            case "${optional_basename}" in
                .env|*.env)
                    ((++env_count))
                    ;;
                compose.override.yml|compose.override.yaml|docker-compose.override.yml|docker-compose.override.yaml)
                    ((++override_count))
                    ;;
            esac
        done <<< "${remote_optional_list}"

        if (( env_count == 0 )); then
            _write_placeholder_artifact \
                "${project_directory}/env-placeholder.txt" \
                "${project_name} Compose environment files" \
                "No .env or *.env files are present in ${working_directory}" || \
                return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        if (( override_count == 0 )); then
            _write_placeholder_artifact \
                "${project_directory}/override-placeholder.txt" \
                "${project_name} Compose override files" \
                "No recognized Compose override files are present in ${working_directory}" || \
                return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        if ! cat > "${summary_file}" <<EOF
Project Polaris Docker01 Compose Project Summary
================================================

Project Name: ${project_name}
Runtime Status: ${project_status}
Remote Working Directory: ${working_directory}
Authoritative Compose File: ${compose_file}
Collected Compose File: ${compose_basename}
Environment Files Collected: ${env_count}
Override Files Collected: ${override_count}
Collection Status: Success
EOF
        then
            operator_error \
                "Unable to write Docker01 Compose summary for project: ${project_name}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        if ! chmod 600 "${summary_file}"; then
            operator_error \
                "Unable to secure Docker01 Compose summary for project: ${project_name}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        if [[ ! -s "${summary_file}" ]]; then
            operator_error \
                "Docker01 Compose summary is empty for project: ${project_name}"
            return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
        fi

        ((++project_count))
    done < "${inventory_file}"

    if (( project_count == 0 )); then
        operator_error \
            "Docker01 Compose project collection produced no project artifacts."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! rm -f -- "${inventory_file}"; then
        operator_error \
            "Unable to remove the temporary Docker01 Compose inventory."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Docker01 Compose project files collected successfully."

    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}


# Purpose: Collect container metadata data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_collect_container_metadata() {
    local container_list_file="${POLARIS_DOCKER_CONTAINER_DIR}/container-list.txt"
    local raw_inspect_file="${POLARIS_DOCKER_CONTAINER_DIR}/.container-inspect-raw.json"
    local inspect_file="${POLARIS_DOCKER_CONTAINER_DIR}/container-inspect.json"
    local summary_file="${POLARIS_DOCKER_CONTAINER_DIR}/container-summary.txt"

    log_info "Collecting Docker01 container metadata."

    if [[ -z "${POLARIS_DOCKER_CONTAINER_DIR}" ]] ||
       [[ ! -d "${POLARIS_DOCKER_CONTAINER_DIR}" ]]
    then
        operator_error \
            "Docker01 container staging directory has not been initialized."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        "docker ps -a --no-trunc" \
        "${container_list_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        'container_ids="$(docker ps -aq --no-trunc)";
         if [ -z "${container_ids}" ]; then
             printf "[]
";
         else
             docker inspect ${container_ids};
         fi' \
        "${raw_inspect_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! python3 - \
        "${raw_inspect_file}" \
        "${inspect_file}" \
        "${summary_file}" \
        "${POLARIS_DOCKER_HOST}" <<'PY'
import json
import sys
from datetime import datetime, timezone

raw_path = sys.argv[1]
output_path = sys.argv[2]
summary_path = sys.argv[3]
target_host = sys.argv[4]

with open(raw_path, "r", encoding="utf-8") as source_file:
    containers = json.load(source_file)

if not isinstance(containers, list):
    raise SystemExit("Docker inspect output is not a JSON list.")

filtered = []

for container in containers:
    if not isinstance(container, dict):
        raise SystemExit("Docker inspect output contains an invalid record.")

    config = container.get("Config") or {}
    host_config = container.get("HostConfig") or {}
    network_settings = container.get("NetworkSettings") or {}
    state = container.get("State") or {}

    filtered.append(
        {
            "id": container.get("Id"),
            "name": str(container.get("Name", "")).lstrip("/"),
            "created": container.get("Created"),
            "path": container.get("Path"),
            "args": container.get("Args"),
            "image_id": container.get("Image"),
            "config": {
                "hostname": config.get("Hostname"),
                "domainname": config.get("Domainname"),
                "user": config.get("User"),
                "image": config.get("Image"),
                "working_directory": config.get("WorkingDir"),
                "entrypoint": config.get("Entrypoint"),
                "command": config.get("Cmd"),
                "labels": config.get("Labels"),
                "exposed_ports": config.get("ExposedPorts"),
            },
            "host_config": {
                "binds": host_config.get("Binds"),
                "network_mode": host_config.get("NetworkMode"),
                "port_bindings": host_config.get("PortBindings"),
                "restart_policy": host_config.get("RestartPolicy"),
                "read_only_rootfs": host_config.get("ReadonlyRootfs"),
                "privileged": host_config.get("Privileged"),
                "cap_add": host_config.get("CapAdd"),
                "cap_drop": host_config.get("CapDrop"),
                "security_options": host_config.get("SecurityOpt"),
            },
            "state": {
                "status": state.get("Status"),
                "running": state.get("Running"),
                "paused": state.get("Paused"),
                "restarting": state.get("Restarting"),
                "oom_killed": state.get("OOMKilled"),
                "dead": state.get("Dead"),
                "exit_code": state.get("ExitCode"),
                "started_at": state.get("StartedAt"),
                "finished_at": state.get("FinishedAt"),
            },
            "mounts": container.get("Mounts"),
            "network_settings": {
                "ports": network_settings.get("Ports"),
                "networks": network_settings.get("Networks"),
            },
        }
    )

filtered.sort(key=lambda item: (item.get("name") or "", item.get("id") or ""))

with open(output_path, "w", encoding="utf-8", newline="\n") as output_file:
    json.dump(filtered, output_file, indent=2, sort_keys=True)
    output_file.write("\n")

running_count = sum(
    1 for container in filtered
    if container.get("state", {}).get("running") is True
)
stopped_count = len(filtered) - running_count

with open(summary_path, "w", encoding="utf-8", newline="\n") as summary_file:
    summary_file.write("Project Polaris Docker01 Container Summary\n")
    summary_file.write("==========================================\n\n")
    summary_file.write(f"Target Host: {target_host}\n")
    summary_file.write(
        "Collection Timestamp (UTC): "
        f"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    summary_file.write(f"Total Containers: {len(filtered)}\n")
    summary_file.write(f"Running Containers: {running_count}\n")
    summary_file.write(f"Stopped Containers: {stopped_count}\n")
    summary_file.write("Environment Variables Included: no\n")
    summary_file.write("Collection Status: Success\n\n")
    summary_file.write("Containers\n")
    summary_file.write("----------\n")

    if not filtered:
        summary_file.write("No containers were present.\n")
    else:
        for container in filtered:
            name = container.get("name") or "unnamed"
            image = container.get("config", {}).get("image") or "unknown"
            status = container.get("state", {}).get("status") or "unknown"
            restart = (
                container.get("host_config", {})
                .get("restart_policy", {})
                .get("Name")
                or "none"
            )
            summary_file.write(
                f"{name} | image={image} | status={status} "
                f"| restart={restart}\n"
            )
PY
    then
        operator_error \
            "Unable to process Docker01 container inspection metadata."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 \
        "${inspect_file}" \
        "${summary_file}"
    then
        operator_error \
            "Unable to secure Docker01 container metadata artifacts."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${inspect_file}" ]] ||
       [[ ! -s "${summary_file}" ]]
    then
        operator_error \
            "Docker01 container metadata artifacts are incomplete."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! rm -f -- "${raw_inspect_file}"; then
        operator_error \
            "Unable to remove temporary Docker01 raw inspection data."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Docker01 container metadata collected successfully."

    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}


# Purpose: Collect network metadata data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_collect_network_metadata() {
    local network_list_file="${POLARIS_DOCKER_NETWORK_DIR}/network-list.txt"
    local raw_inspect_file="${POLARIS_DOCKER_NETWORK_DIR}/.network-inspect-raw.json"
    local inspect_file="${POLARIS_DOCKER_NETWORK_DIR}/network-inspect.json"
    local summary_file="${POLARIS_DOCKER_NETWORK_DIR}/network-summary.txt"

    log_info "Collecting Docker01 network metadata."

    if [[ -z "${POLARIS_DOCKER_NETWORK_DIR}" ]] ||
       [[ ! -d "${POLARIS_DOCKER_NETWORK_DIR}" ]]
    then
        operator_error \
            "Docker01 network staging directory has not been initialized."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        "docker network ls --no-trunc" \
        "${network_list_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        'network_ids="$(docker network ls -q --no-trunc)";
         if [ -z "${network_ids}" ]; then
             printf "[]
";
         else
             docker network inspect ${network_ids};
         fi' \
        "${raw_inspect_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! python3 - \
        "${raw_inspect_file}" \
        "${inspect_file}" \
        "${summary_file}" \
        "${POLARIS_DOCKER_HOST}" <<'PY'
import json
import sys
from datetime import datetime, timezone

raw_path = sys.argv[1]
output_path = sys.argv[2]
summary_path = sys.argv[3]
target_host = sys.argv[4]

with open(raw_path, "r", encoding="utf-8") as source_file:
    networks = json.load(source_file)

if not isinstance(networks, list):
    raise SystemExit("Docker network inspect output is not a JSON list.")

filtered = []

for network in networks:
    if not isinstance(network, dict):
        raise SystemExit("Docker network inspect output contains an invalid record.")

    ipam = network.get("IPAM") or {}
    containers = network.get("Containers") or {}

    attached_containers = []

    if isinstance(containers, dict):
        for container_id, attachment in containers.items():
            attachment = attachment or {}
            attached_containers.append(
                {
                    "container_id": container_id,
                    "name": attachment.get("Name"),
                    "endpoint_id": attachment.get("EndpointID"),
                    "mac_address": attachment.get("MacAddress"),
                    "ipv4_address": attachment.get("IPv4Address"),
                    "ipv6_address": attachment.get("IPv6Address"),
                }
            )

    attached_containers.sort(
        key=lambda item: (
            item.get("name") or "",
            item.get("container_id") or "",
        )
    )

    filtered.append(
        {
            "id": network.get("Id"),
            "name": network.get("Name"),
            "created": network.get("Created"),
            "scope": network.get("Scope"),
            "driver": network.get("Driver"),
            "enable_ipv6": network.get("EnableIPv6"),
            "internal": network.get("Internal"),
            "attachable": network.get("Attachable"),
            "ingress": network.get("Ingress"),
            "config_only": network.get("ConfigOnly"),
            "options": network.get("Options"),
            "labels": network.get("Labels"),
            "ipam": {
                "driver": ipam.get("Driver"),
                "options": ipam.get("Options"),
                "config": ipam.get("Config"),
            },
            "attached_containers": attached_containers,
        }
    )

filtered.sort(key=lambda item: (item.get("name") or "", item.get("id") or ""))

with open(output_path, "w", encoding="utf-8", newline="\n") as output_file:
    json.dump(filtered, output_file, indent=2, sort_keys=True)
    output_file.write("\n")

builtin_names = {"bridge", "host", "none"}
builtin_count = sum(
    1 for network in filtered
    if (network.get("name") or "") in builtin_names
)
custom_count = len(filtered) - builtin_count

with open(summary_path, "w", encoding="utf-8", newline="\n") as summary_file:
    summary_file.write("Project Polaris Docker01 Network Summary\n")
    summary_file.write("========================================\n\n")
    summary_file.write(f"Target Host: {target_host}\n")
    summary_file.write(
        "Collection Timestamp (UTC): "
        f"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    summary_file.write(f"Total Networks: {len(filtered)}\n")
    summary_file.write(f"Built-in Networks: {builtin_count}\n")
    summary_file.write(f"Custom Networks: {custom_count}\n")
    summary_file.write("Collection Status: Success\n\n")
    summary_file.write("Networks\n")
    summary_file.write("--------\n")

    if not filtered:
        summary_file.write("No Docker networks were present.\n")
    else:
        for network in filtered:
            name = network.get("name") or "unnamed"
            driver = network.get("driver") or "unknown"
            scope = network.get("scope") or "unknown"
            attached = len(network.get("attached_containers") or [])
            subnets = []

            for config in network.get("ipam", {}).get("config") or []:
                if isinstance(config, dict) and config.get("Subnet"):
                    subnets.append(str(config.get("Subnet")))

            subnet_text = ",".join(subnets) if subnets else "none"

            summary_file.write(
                f"{name} | driver={driver} | scope={scope} "
                f"| subnets={subnet_text} | attached_containers={attached}\n"
            )
PY
    then
        operator_error \
            "Unable to process Docker01 network inspection metadata."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 \
        "${inspect_file}" \
        "${summary_file}"
    then
        operator_error \
            "Unable to secure Docker01 network metadata artifacts."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${inspect_file}" ]] ||
       [[ ! -s "${summary_file}" ]]
    then
        operator_error \
            "Docker01 network metadata artifacts are incomplete."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! rm -f -- "${raw_inspect_file}"; then
        operator_error \
            "Unable to remove temporary Docker01 raw network inspection data."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Docker01 network metadata collected successfully."

    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}


# Purpose: Collect volume metadata data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_collect_volume_metadata() {
    local volume_list_file="${POLARIS_DOCKER_VOLUME_DIR}/volume-list.txt"
    local raw_inspect_file="${POLARIS_DOCKER_VOLUME_DIR}/.volume-inspect-raw.json"
    local inspect_file="${POLARIS_DOCKER_VOLUME_DIR}/volume-inspect.json"
    local summary_file="${POLARIS_DOCKER_VOLUME_DIR}/volume-summary.txt"

    log_info "Collecting Docker01 volume metadata."

    if [[ -z "${POLARIS_DOCKER_VOLUME_DIR}" ]] ||
       [[ ! -d "${POLARIS_DOCKER_VOLUME_DIR}" ]]
    then
        operator_error \
            "Docker01 volume staging directory has not been initialized."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        "docker volume ls" \
        "${volume_list_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        'volume_names="$(docker volume ls -q)";
         if [ -z "${volume_names}" ]; then
             printf "[]
";
         else
             docker volume inspect ${volume_names};
         fi' \
        "${raw_inspect_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! python3 - \
        "${raw_inspect_file}" \
        "${inspect_file}" \
        "${summary_file}" \
        "${POLARIS_DOCKER_HOST}" <<'PY'
import json
import sys
from datetime import datetime, timezone

raw_path = sys.argv[1]
output_path = sys.argv[2]
summary_path = sys.argv[3]
target_host = sys.argv[4]

with open(raw_path, "r", encoding="utf-8") as source_file:
    volumes = json.load(source_file)

if not isinstance(volumes, list):
    raise SystemExit("Docker volume inspect output is not a JSON list.")

filtered = []

for volume in volumes:
    if not isinstance(volume, dict):
        raise SystemExit("Docker volume inspect output contains an invalid record.")

    usage_data = volume.get("UsageData") or {}

    filtered.append(
        {
            "name": volume.get("Name"),
            "driver": volume.get("Driver"),
            "mountpoint": volume.get("Mountpoint"),
            "created_at": volume.get("CreatedAt"),
            "scope": volume.get("Scope"),
            "labels": volume.get("Labels"),
            "options": volume.get("Options"),
            "usage_data": {
                "size": usage_data.get("Size"),
                "reference_count": usage_data.get("RefCount"),
            },
        }
    )

filtered.sort(key=lambda item: item.get("name") or "")

with open(output_path, "w", encoding="utf-8", newline="\n") as output_file:
    json.dump(filtered, output_file, indent=2, sort_keys=True)
    output_file.write("\n")

driver_counts = {}

for volume in filtered:
    driver = volume.get("driver") or "unknown"
    driver_counts[driver] = driver_counts.get(driver, 0) + 1

with open(summary_path, "w", encoding="utf-8", newline="\n") as summary_file:
    summary_file.write("Project Polaris Docker01 Volume Summary\n")
    summary_file.write("=======================================\n\n")
    summary_file.write(f"Target Host: {target_host}\n")
    summary_file.write(
        "Collection Timestamp (UTC): "
        f"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    summary_file.write(f"Total Volumes: {len(filtered)}\n")
    summary_file.write("Volume Contents Included: no\n")
    summary_file.write("Collection Status: Success\n\n")

    summary_file.write("Drivers\n")
    summary_file.write("-------\n")

    if not driver_counts:
        summary_file.write("No volume drivers were present.\n")
    else:
        for driver in sorted(driver_counts):
            summary_file.write(
                f"{driver}: {driver_counts[driver]}\n"
            )

    summary_file.write("\nVolumes\n")
    summary_file.write("-------\n")

    if not filtered:
        summary_file.write("No Docker volumes were present.\n")
    else:
        for volume in filtered:
            name = volume.get("name") or "unnamed"
            driver = volume.get("driver") or "unknown"
            scope = volume.get("scope") or "unknown"
            mountpoint = volume.get("mountpoint") or "unavailable"
            reference_count = (
                volume.get("usage_data", {}).get("reference_count")
            )

            reference_text = (
                str(reference_count)
                if reference_count is not None
                else "unavailable"
            )

            summary_file.write(
                f"{name} | driver={driver} | scope={scope} "
                f"| references={reference_text} "
                f"| mountpoint={mountpoint}\n"
            )
PY
    then
        operator_error \
            "Unable to process Docker01 volume inspection metadata."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 \
        "${inspect_file}" \
        "${summary_file}"
    then
        operator_error \
            "Unable to secure Docker01 volume metadata artifacts."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${inspect_file}" ]] ||
       [[ ! -s "${summary_file}" ]]
    then
        operator_error \
            "Docker01 volume metadata artifacts are incomplete."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! rm -f -- "${raw_inspect_file}"; then
        operator_error \
            "Unable to remove temporary Docker01 raw volume inspection data."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Docker01 volume metadata collected successfully."

    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}


# Purpose: Collect host metadata data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_collect_host_metadata() {
    local context_list_file="${POLARIS_DOCKER_HOST_DIR}/docker-context-list.txt"
    local context_inspect_file="${POLARIS_DOCKER_HOST_DIR}/docker-context-inspect.json"
    local plugin_list_file="${POLARIS_DOCKER_HOST_DIR}/docker-plugin-list.txt"
    local plugin_inspect_file="${POLARIS_DOCKER_HOST_DIR}/docker-plugin-inspect.json"
    local system_df_file="${POLARIS_DOCKER_HOST_DIR}/docker-system-df.txt"
    local os_release_file="${POLARIS_DOCKER_HOST_DIR}/os-release.txt"
    local uname_file="${POLARIS_DOCKER_HOST_DIR}/uname.txt"
    local packages_file="${POLARIS_DOCKER_HOST_DIR}/docker-packages.txt"
    local summary_file="${POLARIS_DOCKER_HOST_DIR}/host-summary.txt"

    log_info "Collecting Docker01 host and Docker platform metadata."

    if [[ -z "${POLARIS_DOCKER_HOST_DIR}" ]] ||
       [[ ! -d "${POLARIS_DOCKER_HOST_DIR}" ]]
    then
        operator_error \
            "Docker01 host metadata staging directory has not been initialized."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        "docker context ls" \
        "${context_list_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        "docker context inspect" \
        "${context_inspect_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        "docker plugin ls --no-trunc" \
        "${plugin_list_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        'plugin_names="$(docker plugin ls -q --no-trunc)";
         if [ -z "${plugin_names}" ]; then
             printf "[]
";
         else
             docker plugin inspect ${plugin_names};
         fi' \
        "${plugin_inspect_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        "docker system df -v" \
        "${system_df_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        "cat /etc/os-release" \
        "${os_release_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        "uname -a" \
        "${uname_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _docker_remote_execute \
        'if command -v dpkg-query >/dev/null 2>&1; then
             dpkg-query -W \
                 -f="${Package}\t${Version}\t${Architecture}\n" \
                 "docker*" "containerd*" 2>/dev/null \
                 | sort -u;
         else
             printf "Package inventory unavailable: dpkg-query not found.\n";
         fi' \
        "${packages_file}"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! python3 - \
        "${context_inspect_file}" \
        "${plugin_inspect_file}" \
        "${summary_file}" \
        "${POLARIS_DOCKER_HOST}" <<'PY'
import json
import sys
from datetime import datetime, timezone

context_path = sys.argv[1]
plugin_path = sys.argv[2]
summary_path = sys.argv[3]
target_host = sys.argv[4]

with open(context_path, "r", encoding="utf-8") as context_file:
    contexts = json.load(context_file)

with open(plugin_path, "r", encoding="utf-8") as plugin_file:
    plugins = json.load(plugin_file)

if not isinstance(contexts, list):
    raise SystemExit("Docker context inspect output is not a JSON list.")

if not isinstance(plugins, list):
    raise SystemExit("Docker plugin inspect output is not a JSON list.")

context_names = sorted(
    str(context.get("Name", "")).strip()
    for context in contexts
    if isinstance(context, dict) and str(context.get("Name", "")).strip()
)

plugin_names = sorted(
    str(plugin.get("Name", "")).strip()
    for plugin in plugins
    if isinstance(plugin, dict) and str(plugin.get("Name", "")).strip()
)

with open(summary_path, "w", encoding="utf-8", newline="\n") as summary_file:
    summary_file.write("Project Polaris Docker01 Host Summary\n")
    summary_file.write("=====================================\n\n")
    summary_file.write(f"Target Host: {target_host}\n")
    summary_file.write(
        "Collection Timestamp (UTC): "
        f"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    summary_file.write(f"Docker Context Count: {len(contexts)}\n")
    summary_file.write(f"Docker Plugin Count: {len(plugins)}\n")
    summary_file.write("Docker System Usage Included: yes\n")
    summary_file.write("Operating System Metadata Included: yes\n")
    summary_file.write("Package Inventory Included: yes\n")
    summary_file.write("Collection Status: Success\n\n")

    summary_file.write("Docker Contexts\n")
    summary_file.write("---------------\n")
    if context_names:
        for name in context_names:
            summary_file.write(f"{name}\n")
    else:
        summary_file.write("No Docker contexts were reported.\n")

    summary_file.write("\nDocker Plugins\n")
    summary_file.write("--------------\n")
    if plugin_names:
        for name in plugin_names:
            summary_file.write(f"{name}\n")
    else:
        summary_file.write("No Docker plugins were installed.\n")
PY
    then
        operator_error \
            "Unable to process Docker01 host metadata."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 \
        "${context_inspect_file}" \
        "${plugin_inspect_file}" \
        "${summary_file}"
    then
        operator_error \
            "Unable to secure Docker01 host metadata artifacts."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${context_inspect_file}" ]] ||
       [[ ! -s "${plugin_inspect_file}" ]] ||
       [[ ! -s "${summary_file}" ]]
    then
        operator_error \
            "Docker01 host metadata artifacts are incomplete."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Docker01 host and Docker platform metadata collected successfully."

    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}


# Purpose: Write collector info metadata used to validate and understand the backup.
# This comment documents intent; implementation behavior is unchanged.
_write_collector_info() {
    local output_file="${POLARIS_DOCKER_METADATA_DIR}/collector-info.txt"

    if ! cat > "${output_file}" <<EOF
Collector Name: ${POLARIS_DOCKER_MODULE_NAME}
Collector Display Name: ${POLARIS_DOCKER_MODULE_DISPLAY_NAME}
Collector Version: ${POLARIS_DOCKER_MODULE_VERSION}
Collector Author: ${POLARIS_DOCKER_MODULE_AUTHOR}
Collection Mode: ${POLARIS_DOCKER_COLLECTION_STATUS}
Framework Version: ${POLARIS_FRAMEWORK_VERSION}
Target Host: ${POLARIS_DOCKER_HOST}
Remote User: ${POLARIS_DOCKER_USER}
Transport: SSH
Hash Algorithm: SHA-256
EOF
    then
        operator_error "Unable to write Docker01 collector information."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    chmod 600 "${output_file}" || return 1
    [[ -s "${output_file}" ]] || return 1

    log_success "Docker01 collector information written successfully."
    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Write execution info metadata used to validate and understand the backup.
# This comment documents intent; implementation behavior is unchanged.
_write_execution_info() {
    local output_file="${POLARIS_DOCKER_METADATA_DIR}/execution.txt"
    local timestamp=""

    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" || return 1

    if ! cat > "${output_file}" <<EOF
Execution Timestamp (UTC): ${timestamp}
Collection Status: ${POLARIS_DOCKER_COLLECTION_STATUS}
Staging Root: ${POLARIS_DOCKER_STAGING_ROOT}
Configuration Directory: ${POLARIS_DOCKER_DOCKER_DIR}
Docker-Specific Collection Enabled: yes
Implemented Collection Stage: Docker Engine, Daemon Configuration, Compose Projects, Container Metadata, Network Metadata, Volume Metadata, and Host Metadata
EOF
    then
        operator_error "Unable to write Docker01 execution metadata."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    chmod 600 "${output_file}" || return 1
    [[ -s "${output_file}" ]] || return 1

    log_success "Docker01 execution metadata written successfully."
    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Write collection summary metadata used to validate and understand the backup.
# This comment documents intent; implementation behavior is unchanged.
_write_collection_summary() {
    local output_file="${POLARIS_DOCKER_METADATA_DIR}/collection-summary.txt"
    local timestamp=""

    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" || return 1

    if ! cat > "${output_file}" <<EOF
Project Polaris Docker01 Collector Summary
==========================================

Collector Version: ${POLARIS_DOCKER_MODULE_VERSION}
Execution Time (UTC): ${timestamp}
Status: SUCCESS
Target Host: ${POLARIS_DOCKER_HOST}

Implemented Artifacts
---------------------
[COLLECTED] Docker Engine version
[COLLECTED] Docker Compose version
[COLLECTED] Docker Engine information
[COLLECTED] Docker service status
[COLLECTED] Docker engine summary

Planned Artifacts
-----------------
[COLLECTED] Docker daemon configuration
[COLLECTED] Docker Compose project discovery
[COLLECTED] Docker Compose project files
[COLLECTED] Container metadata
[COLLECTED] Docker network metadata
[COLLECTED] Docker volume metadata
[COLLECTED] Docker host system metadata
EOF
    then
        operator_error "Unable to write Docker01 collection summary."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    chmod 600 "${output_file}" || return 1
    [[ -s "${output_file}" ]] || return 1

    log_success "Docker01 collection summary written successfully."
    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Write manifest metadata used to validate and understand the backup.
# This comment documents intent; implementation behavior is unchanged.
_write_manifest() {
    local output_file="${POLARIS_DOCKER_METADATA_DIR}/manifest.txt"

    if ! polaris_manifest_recursive \
        "${POLARIS_DOCKER_STAGING_ROOT}" \
        "${output_file}" \
        "Docker01"
    then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Docker01 integrity manifest written successfully."
    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Preserve failure artifacts so troubleshooting evidence survives a failed run.
# This comment documents intent; implementation behavior is unchanged.
_preserve_failure_artifacts() {
    local troubleshooting_root="${1:-}"
    local failure_reason="${2:-unspecified failure}"

    polaris_preserve_failure_staging \
        "${troubleshooting_root}" \
        "docker" \
        "Docker01" \
        "${POLARIS_DOCKER_MODULE_VERSION}" \
        "${POLARIS_DOCKER_COLLECTION_STATUS:-unavailable}" \
        "${failure_reason}" \
        "${POLARIS_DOCKER_STAGING_ROOT}" \
        "Target Host: ${POLARIS_DOCKER_HOST}" \
        "Remote User: ${POLARIS_DOCKER_USER}"
}

# Purpose: Own the cleanup step of the collector lifecycle.
# This comment documents intent; implementation behavior is unchanged.
_cleanup() {
    if [[ -z "${POLARIS_DOCKER_STAGING_ROOT}" ]]; then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
    fi

    if ! polaris_remove_staging_root "${POLARIS_DOCKER_STAGING_ROOT}" "Docker01"; then
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_DOCKER_STAGING_ROOT=""
    POLARIS_DOCKER_CONFIGURATION_DIR=""
    POLARIS_DOCKER_DOCKER_DIR=""
    POLARIS_DOCKER_ENGINE_DIR=""
    POLARIS_DOCKER_DAEMON_DIR=""
    POLARIS_DOCKER_COMPOSE_DIR=""
    POLARIS_DOCKER_CONTAINER_DIR=""
    POLARIS_DOCKER_NETWORK_DIR=""
    POLARIS_DOCKER_VOLUME_DIR=""
    POLARIS_DOCKER_HOST_DIR=""
    POLARIS_DOCKER_METADATA_DIR=""

    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Collect docker data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
collect_docker() {
    local staging_root="${1:-}"
    local troubleshooting_root="${2:-}"
    local failure_reason=""

    POLARIS_DOCKER_STAGING_ROOT=""
    POLARIS_DOCKER_CONFIGURATION_DIR=""
    POLARIS_DOCKER_DOCKER_DIR=""
    POLARIS_DOCKER_ENGINE_DIR=""
    POLARIS_DOCKER_DAEMON_DIR=""
    POLARIS_DOCKER_COMPOSE_DIR=""
    POLARIS_DOCKER_CONTAINER_DIR=""
    POLARIS_DOCKER_NETWORK_DIR=""
    POLARIS_DOCKER_VOLUME_DIR=""
    POLARIS_DOCKER_HOST_DIR=""
    POLARIS_DOCKER_METADATA_DIR=""
    POLARIS_DOCKER_COLLECTION_STATUS=""

    if [[ -z "${staging_root}" ]] || [[ -z "${troubleshooting_root}" ]]; then
        operator_error "Docker01 collector paths were not provided."
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_info "Starting Docker01 configuration and complete platform metadata collection."

    if ! _validate_environment; then
        failure_reason="environment validation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _initialize_staging "${staging_root}"; then
        failure_reason="staging initialization failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_engine_information; then
        failure_reason="Docker Engine information collection failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_daemon_configuration; then
        failure_reason="Docker daemon configuration collection failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_compose_discovery; then
        failure_reason="Docker Compose project discovery failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_compose_project_files; then
        failure_reason="Docker Compose project file collection failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_container_metadata; then
        failure_reason="Docker container metadata collection failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_network_metadata; then
        failure_reason="Docker network metadata collection failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_volume_metadata; then
        failure_reason="Docker volume metadata collection failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_host_metadata; then
        failure_reason="Docker host metadata collection failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_collector_info; then
        failure_reason="collector metadata generation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_execution_info; then
        failure_reason="execution metadata generation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_collection_summary; then
        failure_reason="collection summary generation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_manifest; then
        failure_reason="manifest generation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_DOCKER_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Docker01 configuration and complete platform metadata collection completed successfully."
    return "${POLARIS_DOCKER_COLLECTOR_RESULT_SUCCESS}"
}
