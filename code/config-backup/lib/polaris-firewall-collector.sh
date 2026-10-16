#!/usr/bin/env bash

[[ -n "${POLARIS_FIREWALL_COLLECTOR_SH_LOADED:-}" ]] && return 0
readonly POLARIS_FIREWALL_COLLECTOR_SH_LOADED=1

###############################################################################
# Project Polaris
# Shared Firewall Configuration Collector Engine
###############################################################################

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/polaris-common.sh"

###############################################################################
# Shared Helper: polaris_register_firewall_collector()
# Used By: pfSense | OPNsense
# Purpose: Registers collector-specific firewall configuration settings.
# Impact: Changes affect listed collectors. Validate both before release.
###############################################################################

declare -gA POLARIS_FIREWALL_CONFIG=()

polaris_register_firewall_collector() {
    local collector_id="${1:-}"
    local product_name="${2:-}"
    local module_display_name="${3:-}"
    local module_version="${4:-}"
    local host="${5:-}"
    local user="${6:-}"
    local ssh_key="${7:-}"
    local connect_timeout="${8:-}"
    local remote_config="${9:-}"

    if [[ -z "${collector_id}" || -z "${product_name}" || -z "${host}" ||
          -z "${user}" || -z "${ssh_key}" || -z "${remote_config}" ]]; then
        operator_error "Firewall collector registration is incomplete."
        return 1
    fi

    POLARIS_FIREWALL_CONFIG["${collector_id},product_name"]="${product_name}"
    POLARIS_FIREWALL_CONFIG["${collector_id},module_name"]="${collector_id}"
    POLARIS_FIREWALL_CONFIG["${collector_id},module_display_name"]="${module_display_name}"
    POLARIS_FIREWALL_CONFIG["${collector_id},module_version"]="${module_version}"
    POLARIS_FIREWALL_CONFIG["${collector_id},module_author"]="Project Polaris"
    POLARIS_FIREWALL_CONFIG["${collector_id},host"]="${host}"
    POLARIS_FIREWALL_CONFIG["${collector_id},user"]="${user}"
    POLARIS_FIREWALL_CONFIG["${collector_id},ssh_key"]="${ssh_key}"
    POLARIS_FIREWALL_CONFIG["${collector_id},connect_timeout"]="${connect_timeout:-10}"
    POLARIS_FIREWALL_CONFIG["${collector_id},remote_config"]="${remote_config}"
}

###############################################################################
# Shared Helper: _polaris_firewall_load_registry()
# Used By: pfSense | OPNsense
# Purpose: Loads one registered firewall collector into shared runtime state.
# Impact: Changes affect listed collectors. Validate both before release.
###############################################################################

_polaris_firewall_load_registry() {
    local collector_id="${1:-}"
    local key=""

    for key in product_name module_name module_display_name module_version \
               module_author host user ssh_key connect_timeout remote_config; do
        if [[ -z "${POLARIS_FIREWALL_CONFIG[${collector_id},${key}]+x}" ]]; then
            operator_error "Firewall registry entry missing: ${collector_id}/${key}"
            return 1
        fi
    done

    POLARIS_FIREWALL_PRODUCT_NAME="${POLARIS_FIREWALL_CONFIG[${collector_id},product_name]}"
    POLARIS_FIREWALL_MODULE_NAME="${POLARIS_FIREWALL_CONFIG[${collector_id},module_name]}"
    POLARIS_FIREWALL_MODULE_DISPLAY_NAME="${POLARIS_FIREWALL_CONFIG[${collector_id},module_display_name]}"
    POLARIS_FIREWALL_MODULE_VERSION="${POLARIS_FIREWALL_CONFIG[${collector_id},module_version]}"
    POLARIS_FIREWALL_MODULE_AUTHOR="${POLARIS_FIREWALL_CONFIG[${collector_id},module_author]}"
    POLARIS_FIREWALL_HOST="${POLARIS_FIREWALL_CONFIG[${collector_id},host]}"
    POLARIS_FIREWALL_USER="${POLARIS_FIREWALL_CONFIG[${collector_id},user]}"
    POLARIS_FIREWALL_SSH_KEY="${POLARIS_FIREWALL_CONFIG[${collector_id},ssh_key]}"
    POLARIS_FIREWALL_SSH_CONNECT_TIMEOUT="${POLARIS_FIREWALL_CONFIG[${collector_id},connect_timeout]}"
    POLARIS_FIREWALL_REMOTE_CONFIG="${POLARIS_FIREWALL_CONFIG[${collector_id},remote_config]}"

    return 0
}

readonly POLARIS_FIREWALL_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_FIREWALL_COLLECTOR_RESULT_NO_CHANGE=2
readonly POLARIS_FIREWALL_CONFIG_STATUS_NEW="new"
readonly POLARIS_FIREWALL_CONFIG_STATUS_CHANGED="changed"
readonly POLARIS_FIREWALL_CONFIG_STATUS_UNCHANGED="unchanged"

POLARIS_FIREWALL_PRODUCT_NAME=""
POLARIS_FIREWALL_MODULE_NAME=""
POLARIS_FIREWALL_MODULE_DISPLAY_NAME=""
POLARIS_FIREWALL_MODULE_VERSION=""
POLARIS_FIREWALL_MODULE_AUTHOR=""
POLARIS_FIREWALL_STAGING_ROOT=""
POLARIS_FIREWALL_CONFIG_DIR=""
POLARIS_FIREWALL_METADATA_DIR=""
POLARIS_FIREWALL_STAGED_CONFIG=""
POLARIS_FIREWALL_HOST=""
POLARIS_FIREWALL_USER=""
POLARIS_FIREWALL_SSH_KEY=""
POLARIS_FIREWALL_SSH_CONNECT_TIMEOUT=10
POLARIS_FIREWALL_REMOTE_CONFIG=""
POLARIS_FIREWALL_LOCAL_BASELINE=""
POLARIS_FIREWALL_TEMP_CONFIG=""
POLARIS_FIREWALL_CONFIG_HASH=""
POLARIS_FIREWALL_BASELINE_HASH=""
POLARIS_FIREWALL_CONFIG_STATUS=""

# Purpose: Own the remote execute step of the collector lifecycle.
# This comment documents intent; implementation behavior is unchanged.
_polaris_firewall_remote_execute() {
    local remote_command="${1:-}"

    polaris_ssh_execute \
        "${POLARIS_FIREWALL_HOST}" \
        "${POLARIS_FIREWALL_USER}" \
        "${POLARIS_FIREWALL_SSH_KEY}" \
        "${POLARIS_FIREWALL_SSH_CONNECT_TIMEOUT}" \
        "allow" \
        "no" \
        "${remote_command}"
}

###############################################################################
# Environment and Staging
###############################################################################

###############################################################################
# Function: _polaris_firewall_validate_environment
#
# Purpose:
#   Verify that the ${POLARIS_FIREWALL_PRODUCT_NAME} collector can perform unattended configuration
#   retrieval through SSH and SCP.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Environment is valid.
#   1 - Validation failed.
###############################################################################

_polaris_firewall_validate_environment() {

    log_info "Validating ${POLARIS_FIREWALL_PRODUCT_NAME} collector environment."

    if ! is_root_user; then
        operator_error "Collector must be run as root."
        return 1
    fi

    if ! command_exists ssh; then
        operator_error "ssh command is not available."
        return 1
    fi

    if ! command_exists scp; then
        operator_error "scp command is not available."
        return 1
    fi

    if ! command_exists sha256sum; then
        operator_error "sha256sum command is not available."
        return 1
    fi

    if [[ ! -r "${POLARIS_FIREWALL_SSH_KEY}" ]]; then
        operator_error "${POLARIS_FIREWALL_PRODUCT_NAME} SSH private key is not readable: ${POLARIS_FIREWALL_SSH_KEY}"
        return 1
    fi

    if ! _polaris_firewall_remote_execute \
                "test -r '${POLARIS_FIREWALL_REMOTE_CONFIG}'"
    then
        operator_error "Unable to access the ${POLARIS_FIREWALL_PRODUCT_NAME} configuration through SSH."
        return 1
    fi

    log_success "${POLARIS_FIREWALL_PRODUCT_NAME} collector environment validation successful."

    return 0
}

###############################################################################
# Function: _polaris_firewall_initialize_staging
#
# Purpose:
#   Initialize the ${POLARIS_FIREWALL_PRODUCT_NAME} collector staging paths and create the required
#   configuration and metadata directories.
#
# Parameters:
#   $1 - Collector staging root.
#
# Returns:
#   0 - Staging initialized successfully.
#   1 - Initialization failed.
###############################################################################

_polaris_firewall_initialize_staging() {

    local staging_root="${1:-}"

    if [[ -z "${staging_root}" ]]; then
        operator_error "${POLARIS_FIREWALL_PRODUCT_NAME} staging root was not provided."
        return 1
    fi

    POLARIS_FIREWALL_STAGING_ROOT="${staging_root}"
    POLARIS_FIREWALL_CONFIG_DIR="${POLARIS_FIREWALL_STAGING_ROOT}/configuration"
    POLARIS_FIREWALL_METADATA_DIR="${POLARIS_FIREWALL_STAGING_ROOT}/metadata"
    POLARIS_FIREWALL_STAGED_CONFIG="${POLARIS_FIREWALL_CONFIG_DIR}/config.xml"

    if ! install -d -m 700 \
        "${POLARIS_FIREWALL_CONFIG_DIR}" \
        "${POLARIS_FIREWALL_METADATA_DIR}"
    then
        operator_error "Unable to create ${POLARIS_FIREWALL_PRODUCT_NAME} staging directories."
        return 1
    fi

    log_success "${POLARIS_FIREWALL_PRODUCT_NAME} staging directories initialized."

    return 0
}

###############################################################################
# Function: _polaris_firewall_acquire_configuration
#
# Purpose:
#   Retrieve the authoritative ${POLARIS_FIREWALL_PRODUCT_NAME} configuration into a temporary file and
#   calculate its SHA-256 checksum.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Configuration acquired successfully.
#   1 - Acquisition failed.
###############################################################################

_polaris_firewall_acquire_configuration() {

    log_info "Retrieving ${POLARIS_FIREWALL_PRODUCT_NAME} configuration."

    POLARIS_FIREWALL_TEMP_CONFIG="$(mktemp)"

    if [[ -z "${POLARIS_FIREWALL_TEMP_CONFIG}" ]]; then
        operator_error "Unable to create temporary configuration file."
        return 1
    fi

    if ! _polaris_firewall_remote_execute \
                "cat '${POLARIS_FIREWALL_REMOTE_CONFIG}'" \
        > "${POLARIS_FIREWALL_TEMP_CONFIG}"
    then
        rm -f "${POLARIS_FIREWALL_TEMP_CONFIG}"
        operator_error "Unable to retrieve the ${POLARIS_FIREWALL_PRODUCT_NAME} configuration."
        return 1
    fi

    chmod 600 "${POLARIS_FIREWALL_TEMP_CONFIG}"

    if [[ ! -s "${POLARIS_FIREWALL_TEMP_CONFIG}" ]]; then
        rm -f "${POLARIS_FIREWALL_TEMP_CONFIG}"
        operator_error "Retrieved ${POLARIS_FIREWALL_PRODUCT_NAME} configuration is empty."
        return 1
    fi

    POLARIS_FIREWALL_CONFIG_HASH="$(
        sha256sum "${POLARIS_FIREWALL_TEMP_CONFIG}" | awk '{print $1}'
    )"

    if [[ ! "${POLARIS_FIREWALL_CONFIG_HASH}" =~ ^[[:xdigit:]]{64}$ ]]; then
        rm -f "${POLARIS_FIREWALL_TEMP_CONFIG}"
        operator_error "Unable to calculate the configuration checksum."
        return 1
    fi

    log_success "${POLARIS_FIREWALL_PRODUCT_NAME} configuration acquired successfully."

    return 0
}

###############################################################################
# Function: _polaris_firewall_get_remote_config_hash
#
# Purpose:
#   Calculate the SHA-256 checksum of the authoritative ${POLARIS_FIREWALL_PRODUCT_NAME} configuration
#   without transferring the configuration file.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Remote checksum retrieved successfully.
#   1 - Remote checksum retrieval failed.
###############################################################################

_polaris_firewall_get_remote_config_hash() {

    local remote_output=""

    log_info "Calculating remote ${POLARIS_FIREWALL_PRODUCT_NAME} configuration checksum."

    if ! remote_output="$(
        _polaris_firewall_remote_execute \
                    "sha256 -q '${POLARIS_FIREWALL_REMOTE_CONFIG}'"
    )"
    then
        operator_error "Unable to calculate the remote ${POLARIS_FIREWALL_PRODUCT_NAME} configuration checksum."
        return 1
    fi

    remote_output="${remote_output//$'\r'/}"
    remote_output="${remote_output//$'\n'/}"

    if [[ ! "${remote_output}" =~ ^[[:xdigit:]]{64}$ ]]; then
        operator_error "${POLARIS_FIREWALL_PRODUCT_NAME} returned an invalid SHA-256 checksum."
        return 1
    fi

    POLARIS_FIREWALL_REMOTE_HASH="${remote_output,,}"

    log_success "Remote ${POLARIS_FIREWALL_PRODUCT_NAME} configuration checksum retrieved."

    return 0
}

###############################################################################
# Function: _polaris_firewall_locate_baseline
#
# Purpose:
#   Validate a previously promoted ${POLARIS_FIREWALL_PRODUCT_NAME} configuration and calculate its
#   SHA-256 checksum for comparison with the current configuration.
#
# Parameters:
#   $1 - Path to the previous validated ${POLARIS_FIREWALL_PRODUCT_NAME} config.xml. An empty value
#        indicates that no baseline currently exists.
#
# Returns:
#   0 - Baseline processed successfully, including the first-run case.
#   1 - A supplied baseline exists but is invalid or cannot be hashed.
###############################################################################

_polaris_firewall_locate_baseline() {

    local baseline_path="${1:-}"
    local hash_output=""

    POLARIS_FIREWALL_LOCAL_BASELINE=""
    POLARIS_FIREWALL_BASELINE_HASH=""

    if [[ -z "${baseline_path}" ]]; then
        log_info \
            "No previous ${POLARIS_FIREWALL_PRODUCT_NAME} configuration baseline was provided."

        return 0
    fi

    if [[ ! -f "${baseline_path}" ]]; then
        operator_error \
            "The supplied ${POLARIS_FIREWALL_PRODUCT_NAME} configuration baseline does not exist: ${baseline_path}"

        return 1
    fi

    if [[ ! -r "${baseline_path}" ]]; then
        operator_error \
            "The supplied ${POLARIS_FIREWALL_PRODUCT_NAME} configuration baseline is not readable: ${baseline_path}"

        return 1
    fi

    if [[ ! -s "${baseline_path}" ]]; then
        operator_error \
            "The supplied ${POLARIS_FIREWALL_PRODUCT_NAME} configuration baseline is empty: ${baseline_path}"

        return 1
    fi

    if ! hash_output="$(
        sha256sum -- "${baseline_path}"
    )"
    then
        operator_error \
            "Unable to calculate the ${POLARIS_FIREWALL_PRODUCT_NAME} baseline checksum."

        return 1
    fi

    hash_output="${hash_output%% *}"

    if [[ ! "${hash_output}" =~ ^[[:xdigit:]]{64}$ ]]; then
        operator_error \
            "The ${POLARIS_FIREWALL_PRODUCT_NAME} baseline produced an invalid SHA-256 checksum."

        return 1
    fi

    POLARIS_FIREWALL_LOCAL_BASELINE="${baseline_path}"
    POLARIS_FIREWALL_BASELINE_HASH="${hash_output,,}"

    log_success \
        "Previous ${POLARIS_FIREWALL_PRODUCT_NAME} configuration baseline validated."

    return 0
}

###############################################################################
# Function: _polaris_firewall_compare_hashes
#
# Purpose:
#   Compare the current ${POLARIS_FIREWALL_PRODUCT_NAME} configuration checksum with the previous
#   validated baseline checksum.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Comparison completed successfully.
#   1 - Current configuration checksum is unavailable.
###############################################################################

_polaris_firewall_compare_hashes() {

    POLARIS_FIREWALL_CONFIG_STATUS=""

    if [[ ! "${POLARIS_FIREWALL_CONFIG_HASH}" =~ ^[[:xdigit:]]{64}$ ]]; then
        operator_error \
            "Current ${POLARIS_FIREWALL_PRODUCT_NAME} configuration checksum is unavailable or invalid."

        return 1
    fi

    if [[ -z "${POLARIS_FIREWALL_BASELINE_HASH}" ]]; then
        POLARIS_FIREWALL_CONFIG_STATUS="${POLARIS_FIREWALL_CONFIG_STATUS_NEW}"

        log_info \
            "No previous ${POLARIS_FIREWALL_PRODUCT_NAME} configuration baseline exists. Current configuration will be staged."

        return 0
    fi

    if [[ ! "${POLARIS_FIREWALL_BASELINE_HASH}" =~ ^[[:xdigit:]]{64}$ ]]; then
        operator_error \
            "Previous ${POLARIS_FIREWALL_PRODUCT_NAME} baseline checksum is invalid."

        return 1
    fi

    if [[ "${POLARIS_FIREWALL_CONFIG_HASH}" == \
          "${POLARIS_FIREWALL_BASELINE_HASH}" ]]
    then
        POLARIS_FIREWALL_CONFIG_STATUS="${POLARIS_FIREWALL_CONFIG_STATUS_UNCHANGED}"

        log_info \
            "${POLARIS_FIREWALL_PRODUCT_NAME} configuration is unchanged."

        return 0
    fi

    POLARIS_FIREWALL_CONFIG_STATUS="${POLARIS_FIREWALL_CONFIG_STATUS_CHANGED}"

    log_info \
        "A change was detected in the ${POLARIS_FIREWALL_PRODUCT_NAME} configuration."

    return 0
}

###############################################################################
# Function: _polaris_firewall_finalize_configuration
#
# Purpose:
#   Place a complete, validated ${POLARIS_FIREWALL_PRODUCT_NAME} config.xml into the current staging
#   directory. New or changed configurations are moved from the temporary
#   workspace. Unchanged configurations reuse the previous validated baseline.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Configuration finalized successfully.
#   1 - Finalization failed.
###############################################################################

_polaris_firewall_finalize_configuration() {

    local finalized_hash=""

    if [[ -z "${POLARIS_FIREWALL_STAGED_CONFIG}" ]]; then
        operator_error \
            "${POLARIS_FIREWALL_PRODUCT_NAME} staging paths have not been initialized."

        return 1
    fi

    if [[ -e "${POLARIS_FIREWALL_STAGED_CONFIG}" ]]; then
        operator_error \
            "A ${POLARIS_FIREWALL_PRODUCT_NAME} configuration already exists in the staging directory: ${POLARIS_FIREWALL_STAGED_CONFIG}"

        return 1
    fi

    case "${POLARIS_FIREWALL_CONFIG_STATUS}" in

        "${POLARIS_FIREWALL_CONFIG_STATUS_NEW}"|"${POLARIS_FIREWALL_CONFIG_STATUS_CHANGED}")

            if [[ -z "${POLARIS_FIREWALL_TEMP_CONFIG}" ]] ||
               [[ ! -f "${POLARIS_FIREWALL_TEMP_CONFIG}" ]] ||
               [[ ! -s "${POLARIS_FIREWALL_TEMP_CONFIG}" ]]
            then
                operator_error \
                    "The acquired ${POLARIS_FIREWALL_PRODUCT_NAME} configuration is unavailable."

                return 1
            fi

            if ! mv -- \
                "${POLARIS_FIREWALL_TEMP_CONFIG}" \
                "${POLARIS_FIREWALL_STAGED_CONFIG}"
            then
                operator_error \
                    "Unable to move the ${POLARIS_FIREWALL_PRODUCT_NAME} configuration into staging."

                return 1
            fi

            POLARIS_FIREWALL_TEMP_CONFIG=""

            if ! chmod 600 "${POLARIS_FIREWALL_STAGED_CONFIG}"; then
                operator_error \
                    "Unable to secure the staged ${POLARIS_FIREWALL_PRODUCT_NAME} configuration."

                return 1
            fi
            ;;

        "${POLARIS_FIREWALL_CONFIG_STATUS_UNCHANGED}")

            if [[ -z "${POLARIS_FIREWALL_LOCAL_BASELINE}" ]] ||
               [[ ! -f "${POLARIS_FIREWALL_LOCAL_BASELINE}" ]] ||
               [[ ! -r "${POLARIS_FIREWALL_LOCAL_BASELINE}" ]] ||
               [[ ! -s "${POLARIS_FIREWALL_LOCAL_BASELINE}" ]]
            then
                operator_error \
                    "The validated ${POLARIS_FIREWALL_PRODUCT_NAME} baseline is unavailable for reuse."

                return 1
            fi

            rm -f -- "${POLARIS_FIREWALL_TEMP_CONFIG}"
            POLARIS_FIREWALL_TEMP_CONFIG=""

            if ln -- \
                "${POLARIS_FIREWALL_LOCAL_BASELINE}" \
                "${POLARIS_FIREWALL_STAGED_CONFIG}" 2>/dev/null
            then
                log_info \
                    "Reused the unchanged ${POLARIS_FIREWALL_PRODUCT_NAME} configuration through a hard link."
            else
                log_info \
                    "Hard-link reuse was unavailable. Copying the validated ${POLARIS_FIREWALL_PRODUCT_NAME} baseline."

                if ! cp --preserve=mode,timestamps -- \
                    "${POLARIS_FIREWALL_LOCAL_BASELINE}" \
                    "${POLARIS_FIREWALL_STAGED_CONFIG}"
                then
                    operator_error \
                        "Unable to reuse the validated ${POLARIS_FIREWALL_PRODUCT_NAME} configuration baseline."

                    return 1
                fi

                if ! chmod 600 "${POLARIS_FIREWALL_STAGED_CONFIG}"; then
                    operator_error \
                        "Unable to secure the copied ${POLARIS_FIREWALL_PRODUCT_NAME} configuration."

                    return 1
                fi
            fi
            ;;

        *)

            operator_error \
                "The ${POLARIS_FIREWALL_PRODUCT_NAME} configuration status is unavailable or invalid."

            return 1
            ;;
    esac

    if [[ ! -r "${POLARIS_FIREWALL_STAGED_CONFIG}" ]] ||
       [[ ! -s "${POLARIS_FIREWALL_STAGED_CONFIG}" ]]
    then
        operator_error \
            "The finalized ${POLARIS_FIREWALL_PRODUCT_NAME} configuration failed file validation."

        return 1
    fi

    if ! finalized_hash="$(
        sha256sum -- "${POLARIS_FIREWALL_STAGED_CONFIG}"
    )"
    then
        operator_error \
            "Unable to verify the finalized ${POLARIS_FIREWALL_PRODUCT_NAME} configuration checksum."

        return 1
    fi

    finalized_hash="${finalized_hash%% *}"
    finalized_hash="${finalized_hash,,}"

    if [[ "${finalized_hash}" != "${POLARIS_FIREWALL_CONFIG_HASH}" ]]; then
        operator_error \
            "The finalized ${POLARIS_FIREWALL_PRODUCT_NAME} configuration checksum does not match the acquired configuration."

        return 1
    fi

    log_success \
        "${POLARIS_FIREWALL_PRODUCT_NAME} configuration finalized successfully."

    return 0
}

###############################################################################
# Function: _polaris_firewall_write_collector_info
#
# Purpose:
#   Record static information describing the ${POLARIS_FIREWALL_PRODUCT_NAME} collector and the
#   authoritative configuration source used during the backup.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Collector information written successfully.
#   1 - Metadata generation failed.
###############################################################################

_polaris_firewall_write_collector_info() {

    local output_file="${POLARIS_FIREWALL_METADATA_DIR}/collector-info.txt"

    if [[ -z "${POLARIS_FIREWALL_METADATA_DIR}" ]] ||
       [[ ! -d "${POLARIS_FIREWALL_METADATA_DIR}" ]]
    then
        operator_error \
            "${POLARIS_FIREWALL_PRODUCT_NAME} metadata directory has not been initialized."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! cat > "${output_file}" <<EOF
Collector Name: ${POLARIS_FIREWALL_MODULE_NAME}
Collector Display Name: ${POLARIS_FIREWALL_MODULE_DISPLAY_NAME}
Collector Version: ${POLARIS_FIREWALL_MODULE_VERSION}
Collector Author: ${POLARIS_FIREWALL_MODULE_AUTHOR}
Target Host: ${POLARIS_FIREWALL_HOST}
Remote Configuration: ${POLARIS_FIREWALL_REMOTE_CONFIG}
Hash Algorithm: SHA-256
EOF
    then
        operator_error \
            "Unable to write ${POLARIS_FIREWALL_PRODUCT_NAME} collector information."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error \
            "Unable to secure ${POLARIS_FIREWALL_PRODUCT_NAME} collector information."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error \
            "${POLARIS_FIREWALL_PRODUCT_NAME} collector information file is empty."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "${POLARIS_FIREWALL_PRODUCT_NAME} collector information written successfully."

    return "${POLARIS_FIREWALL_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _polaris_firewall_write_execution_info
#
# Purpose:
#   Record execution-specific information for this collector run.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Execution metadata written successfully.
#   1 - Metadata generation failed.
###############################################################################

_polaris_firewall_write_execution_info() {

    local output_file="${POLARIS_FIREWALL_METADATA_DIR}/execution.txt"
    local file_size="0"
    local timestamp=""

    if [[ ! -f "${POLARIS_FIREWALL_STAGED_CONFIG}" ]]; then
        operator_error \
            "Unable to generate execution metadata. No staged configuration exists."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    file_size="$(stat -c '%s' "${POLARIS_FIREWALL_STAGED_CONFIG}")"

    if ! cat > "${output_file}" <<EOF
Execution Timestamp (UTC): ${timestamp}
Configuration Status: ${POLARIS_FIREWALL_CONFIG_STATUS}
Configuration Hash: ${POLARIS_FIREWALL_CONFIG_HASH}
Baseline Hash: ${POLARIS_FIREWALL_BASELINE_HASH}
Configuration Size (Bytes): ${file_size}
EOF
    then
        operator_error \
            "Unable to write ${POLARIS_FIREWALL_PRODUCT_NAME} execution metadata."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error \
            "Unable to secure ${POLARIS_FIREWALL_PRODUCT_NAME} execution metadata."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error \
            "${POLARIS_FIREWALL_PRODUCT_NAME} execution metadata file is empty."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "${POLARIS_FIREWALL_PRODUCT_NAME} execution metadata written successfully."

    return "${POLARIS_FIREWALL_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _polaris_firewall_write_manifest
#
# Purpose:
#     Generate a Project Polaris-compatible integrity manifest for the
#     permanent files produced by the ${POLARIS_FIREWALL_PRODUCT_NAME} collector.
#
# Parameters:
#     None.
#
# Returns:
#     0 - Manifest written successfully.
#     1 - Manifest generation failed.
###############################################################################

_polaris_firewall_write_manifest() {
    local output_file="${POLARIS_FIREWALL_METADATA_DIR}/manifest.txt"

    if ! polaris_manifest_required_files \
        "${POLARIS_FIREWALL_STAGING_ROOT}" \
        "${output_file}" \
        "${POLARIS_FIREWALL_PRODUCT_NAME}" \
        "configuration/config.xml" \
        "metadata/collector-info.txt" \
        "metadata/execution.txt"
    then
        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "${POLARIS_FIREWALL_PRODUCT_NAME} integrity manifest written successfully."
    return "${POLARIS_FIREWALL_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _polaris_firewall_preserve_failure_artifacts
#
# Purpose:
#   Preserve available ${POLARIS_FIREWALL_PRODUCT_NAME} collector artifacts when collection fails so the
#   failure can be investigated without leaving data in the active workspace.
#
# Parameters:
#   $1 - Troubleshooting root for ${POLARIS_FIREWALL_PRODUCT_NAME} collector failures.
#   $2 - Failure stage or reason.
#
# Returns:
#   0 - Available artifacts were preserved, or no artifacts were available.
#   1 - One or more available artifacts could not be preserved.
###############################################################################

_polaris_firewall_preserve_failure_artifacts() {

    local troubleshooting_root="${1:-}"
    local failure_reason="${2:-unspecified failure}"
    local failure_timestamp=""
    local failure_directory=""
    local preservation_failed=0
    local temporary_config_status="missing"
    local staging_status="missing"

    if [[ -z "${troubleshooting_root}" ]]; then
        operator_error \
            "${POLARIS_FIREWALL_PRODUCT_NAME} troubleshooting root was not provided."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! failure_timestamp="$(date -u '+%Y%m%d-%H%M%S')"; then
        operator_error \
            "Unable to generate the ${POLARIS_FIREWALL_PRODUCT_NAME} troubleshooting timestamp."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    failure_directory="${troubleshooting_root}/pfsense-failure-${failure_timestamp}-$$"

    if ! install -d -m 700 "${failure_directory}"; then
        operator_error \
            "Unable to create the ${POLARIS_FIREWALL_PRODUCT_NAME} troubleshooting directory: ${failure_directory}"

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ -n "${POLARIS_FIREWALL_TEMP_CONFIG}" ]] &&
       [[ -f "${POLARIS_FIREWALL_TEMP_CONFIG}" ]]; then

        temporary_config_status="present"

        if cp --preserve=mode,timestamps -- \
            "${POLARIS_FIREWALL_TEMP_CONFIG}" \
            "${failure_directory}/temporary-config.xml"; then

            temporary_config_status="preserved"
        else
            temporary_config_status="preservation failed"
            preservation_failed=1
        fi
    fi

    if [[ -n "${POLARIS_FIREWALL_STAGING_ROOT}" ]] &&
       [[ -d "${POLARIS_FIREWALL_STAGING_ROOT}" ]]; then

        staging_status="present"

        if cp -a -- \
            "${POLARIS_FIREWALL_STAGING_ROOT}" \
            "${failure_directory}/staging"; then

            staging_status="preserved"
        else
            staging_status="preservation failed"
            preservation_failed=1
        fi
    fi

    if ! cat > "${failure_directory}/failure-summary.txt" <<EOF_SUMMARY
Project Polaris ${POLARIS_FIREWALL_PRODUCT_NAME} Collector Failure Summary
=================================================

Failure Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Failure Reason: ${failure_reason}
Collector Version: ${POLARIS_FIREWALL_MODULE_VERSION}
Target Host: ${POLARIS_FIREWALL_HOST}
Configuration Status: ${POLARIS_FIREWALL_CONFIG_STATUS:-unavailable}
Current Configuration Hash: ${POLARIS_FIREWALL_CONFIG_HASH:-unavailable}
Baseline Hash: ${POLARIS_FIREWALL_BASELINE_HASH:-unavailable}
Temporary Configuration: ${temporary_config_status}
Partial Staging Directory: ${staging_status}
EOF_SUMMARY
    then
        operator_error \
            "Unable to write the ${POLARIS_FIREWALL_PRODUCT_NAME} failure summary."

        preservation_failed=1
    else
        chmod 600 "${failure_directory}/failure-summary.txt" || \
            preservation_failed=1
    fi

    if (( preservation_failed != 0 )); then
        operator_error \
            "One or more ${POLARIS_FIREWALL_PRODUCT_NAME} failure artifacts could not be preserved completely."

        log_info \
            "Partial troubleshooting evidence: ${failure_directory}"

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    operator_warning \
        "${POLARIS_FIREWALL_PRODUCT_NAME} collector failure artifacts were preserved."

    log_info \
        "Troubleshooting evidence: ${failure_directory}"

    return "${POLARIS_FIREWALL_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _polaris_firewall_cleanup_temporary_configuration
#
# Purpose:
#   Remove any remaining temporary ${POLARIS_FIREWALL_PRODUCT_NAME} configuration file.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Cleanup completed successfully.
#   1 - Cleanup failed.
###############################################################################

_polaris_firewall_cleanup_temporary_configuration() {

    if [[ -z "${POLARIS_FIREWALL_TEMP_CONFIG}" ]]; then
        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_SUCCESS}"
    fi

    if [[ ! -e "${POLARIS_FIREWALL_TEMP_CONFIG}" ]]; then
        POLARIS_FIREWALL_TEMP_CONFIG=""
        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_SUCCESS}"
    fi

    if ! rm -f -- "${POLARIS_FIREWALL_TEMP_CONFIG}"; then
        operator_error \
            "Unable to remove the temporary ${POLARIS_FIREWALL_PRODUCT_NAME} configuration file."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_FIREWALL_TEMP_CONFIG=""

    return "${POLARIS_FIREWALL_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: collect_pfsense
#
# Purpose:
#   Coordinate the complete ${POLARIS_FIREWALL_PRODUCT_NAME} configuration collection workflow.
#
# Parameters:
#   $1 - Collector staging root.
#   $2 - Previous validated config.xml baseline, or an empty value.
#   $3 - Troubleshooting root used to preserve failure evidence.
#
# Returns:
#   0 - A new or changed configuration was collected successfully.
#   1 - Collection failed.
#   2 - The authoritative configuration is unchanged.
###############################################################################

polaris_collect_firewall_configuration() {

    local collector_id="${1:-}"
    local staging_root="${2:-}"
    local baseline_path="${3:-}"
    local troubleshooting_root="${4:-}"
    local failure_reason=""

    if ! _polaris_firewall_load_registry "${collector_id}"; then
        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_FIREWALL_STAGING_ROOT=""
    POLARIS_FIREWALL_CONFIG_DIR=""
    POLARIS_FIREWALL_METADATA_DIR=""
    POLARIS_FIREWALL_STAGED_CONFIG=""
    POLARIS_FIREWALL_LOCAL_BASELINE=""
    POLARIS_FIREWALL_TEMP_CONFIG=""
    POLARIS_FIREWALL_CONFIG_HASH=""
    POLARIS_FIREWALL_BASELINE_HASH=""
    POLARIS_FIREWALL_CONFIG_STATUS=""

    if [[ -z "${staging_root}" ]]; then
        operator_error \
            "${POLARIS_FIREWALL_PRODUCT_NAME} collector staging root was not provided."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ -z "${troubleshooting_root}" ]]; then
        operator_error \
            "${POLARIS_FIREWALL_PRODUCT_NAME} collector troubleshooting root was not provided."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    log_info \
        "Starting ${POLARIS_FIREWALL_PRODUCT_NAME} configuration collection."

    if ! _polaris_firewall_validate_environment; then
        failure_reason="environment validation failed"
        _polaris_firewall_preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_firewall_initialize_staging "${staging_root}"; then
        failure_reason="staging initialization failed"
        _polaris_firewall_preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_firewall_locate_baseline "${baseline_path}"; then
        failure_reason="baseline validation failed"
        _polaris_firewall_preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_firewall_acquire_configuration; then
        failure_reason="configuration acquisition failed"
        _polaris_firewall_preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _polaris_firewall_cleanup_temporary_configuration || true
        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_firewall_compare_hashes; then
        failure_reason="configuration comparison failed"
        _polaris_firewall_preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _polaris_firewall_cleanup_temporary_configuration || true
        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ "${POLARIS_FIREWALL_CONFIG_STATUS}" == "${POLARIS_FIREWALL_CONFIG_STATUS_UNCHANGED}" ]]; then
        if ! _polaris_firewall_cleanup_temporary_configuration; then
            failure_reason="temporary-file cleanup failed after unchanged result"
            _polaris_firewall_preserve_failure_artifacts \
                "${troubleshooting_root}" \
                "${failure_reason}" || true

            return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
        fi

        if [[ -d "${POLARIS_FIREWALL_STAGING_ROOT}" ]]; then
            if ! rm -rf -- "${POLARIS_FIREWALL_STAGING_ROOT}"; then
                operator_error \
                    "Unable to remove the unused ${POLARIS_FIREWALL_PRODUCT_NAME} staging directory after an unchanged result."

                _polaris_firewall_preserve_failure_artifacts \
                    "${troubleshooting_root}" \
                    "unchanged-result staging cleanup failed" || true

                return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
            fi
        fi

        log_info \
            "${POLARIS_FIREWALL_PRODUCT_NAME} configuration is unchanged. No backup artifact was created."

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_NO_CHANGE}"
    fi

    if ! _polaris_firewall_finalize_configuration; then
        failure_reason="configuration finalization failed"
        _polaris_firewall_preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _polaris_firewall_cleanup_temporary_configuration || true
        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_firewall_write_collector_info; then
        failure_reason="collector metadata generation failed"
        _polaris_firewall_preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_firewall_write_execution_info; then
        failure_reason="execution metadata generation failed"
        _polaris_firewall_preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_firewall_write_manifest; then
        failure_reason="manifest generation failed"
        _polaris_firewall_preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        return "${POLARIS_FIREWALL_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "${POLARIS_FIREWALL_PRODUCT_NAME} configuration collection completed successfully."

    return "${POLARIS_FIREWALL_COLLECTOR_RESULT_SUCCESS}"
}
