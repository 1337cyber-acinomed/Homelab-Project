#!/usr/bin/env bash

[[ -n "${POLARIS_SWITCH_SH_LOADED:-}" ]] && return 0
readonly POLARIS_SWITCH_SH_LOADED=1

###############################################################################
# Project Polaris
# Switch Configuration Collector (Netgear GS324TP, Playwright-driven)
###############################################################################

###############################################################################
# Framework Initialization
###############################################################################

POLARIS_SWITCH_COLLECTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly POLARIS_SWITCH_COLLECTOR_DIR

POLARIS_SWITCH_FRAMEWORK_ROOT="$(cd -- "${POLARIS_SWITCH_COLLECTOR_DIR}/../.." && pwd -P)"
readonly POLARIS_SWITCH_FRAMEWORK_ROOT

readonly POLARIS_SWITCH_LIB_DIR="${POLARIS_SWITCH_FRAMEWORK_ROOT}/lib"

# shellcheck source=/dev/null
source "${POLARIS_SWITCH_LIB_DIR}/polaris-common.sh"

###############################################################################
# Collector Result Codes
###############################################################################

readonly POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_SWITCH_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_SWITCH_COLLECTOR_RESULT_NO_CHANGE=2

###############################################################################
# Module Metadata
###############################################################################

readonly POLARIS_SWITCH_MODULE_NAME="switch"
readonly POLARIS_SWITCH_MODULE_DISPLAY_NAME="Switch Collector"
readonly POLARIS_SWITCH_MODULE_VERSION="1.0.0"
readonly POLARIS_SWITCH_MODULE_AUTHOR="Project Polaris"

readonly POLARIS_SWITCH_HOST="192.168.10.126"
readonly POLARIS_SWITCH_CREDENTIALS_FILE="/root/.polaris_switch_credentials"

readonly POLARIS_SWITCH_VENV_PYTHON="/opt/polaris-switch-automation/venv/bin/python3"
readonly POLARIS_SWITCH_EXPORT_SCRIPT="${POLARIS_SWITCH_COLLECTOR_DIR}/switch-export.py"

# Purpose: Run the Playwright export script and capture its diagnostic output
# on failure, so the reason (timeout, missing library, login failure, etc.)
# reaches the log rather than only "exit code 1".
_switch_run_export() {
    local config_output_file="${1:-}"
    local tech_support_output_file="${2:-}"
    local export_output=""
    local export_exit_code=0

    export_output="$(
        "${POLARIS_SWITCH_VENV_PYTHON}" "${POLARIS_SWITCH_EXPORT_SCRIPT}" \
            --host "${POLARIS_SWITCH_HOST}" \
            --credentials "${POLARIS_SWITCH_CREDENTIALS_FILE}" \
            --output-config "${config_output_file}" \
            --output-tech-support "${tech_support_output_file}" \
            2>&1
    )"
    export_exit_code=$?

    if [[ ${export_exit_code} -ne 0 ]]; then
        operator_error "Switch export script failed: ${export_output}"
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    log_info "Switch export script output: ${export_output}"
    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Module State
###############################################################################

POLARIS_SWITCH_STAGING_ROOT=""
POLARIS_SWITCH_CONFIGURATION_DIR=""
POLARIS_SWITCH_SWITCH_DIR=""
POLARIS_SWITCH_METADATA_DIR=""
POLARIS_SWITCH_COLLECTION_STATUS=""
POLARIS_SWITCH_LOCAL_BASELINE=""
POLARIS_SWITCH_CONFIG_HASH=""
POLARIS_SWITCH_BASELINE_HASH=""
POLARIS_SWITCH_CONFIG_STATUS=""

readonly POLARIS_SWITCH_CONFIG_STATUS_NEW="new"
readonly POLARIS_SWITCH_CONFIG_STATUS_CHANGED="changed"
readonly POLARIS_SWITCH_CONFIG_STATUS_UNCHANGED="unchanged"

###############################################################################
# Function: _validate_environment
#
# Purpose:
#   Verify the local framework requirements for the switch collector.
###############################################################################

_validate_environment() {
    local required_commands=(
        date
        install
        sha256sum
        stat
    )
    local required_command=""

    log_info "Validating switch collector environment."

    if ! is_root_user; then
        operator_error "Collector must be run as root."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    for required_command in "${required_commands[@]}"; do
        if ! command_exists "${required_command}"; then
            operator_error "Required command is not available: ${required_command}"
            return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
        fi
    done

    if [[ ! -x "${POLARIS_SWITCH_VENV_PYTHON}" ]]; then
        operator_error \
            "Switch collector Python venv is not available: ${POLARIS_SWITCH_VENV_PYTHON}"
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -r "${POLARIS_SWITCH_EXPORT_SCRIPT}" ]]; then
        operator_error \
            "Switch export script is not readable: ${POLARIS_SWITCH_EXPORT_SCRIPT}"
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -r "${POLARIS_SWITCH_CREDENTIALS_FILE}" ]]; then
        operator_error \
            "Switch credentials file is not readable: ${POLARIS_SWITCH_CREDENTIALS_FILE}"
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Switch collector environment validation successful."
    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _initialize_staging
#
# Purpose:
#   Create the switch configuration and metadata staging directories.
###############################################################################

_initialize_staging() {
    local staging_root="${1:-}"

    if [[ -z "${staging_root}" ]]; then
        operator_error "Switch staging root was not provided."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_SWITCH_STAGING_ROOT="${staging_root}"
    POLARIS_SWITCH_CONFIGURATION_DIR="${POLARIS_SWITCH_STAGING_ROOT}/configuration"
    POLARIS_SWITCH_SWITCH_DIR="${POLARIS_SWITCH_CONFIGURATION_DIR}/switch"
    POLARIS_SWITCH_METADATA_DIR="${POLARIS_SWITCH_STAGING_ROOT}/metadata"

    if ! polaris_prepare_staging_directories \
        "${POLARIS_SWITCH_STAGING_ROOT}" \
        "Switch" \
        "${POLARIS_SWITCH_SWITCH_DIR}" \
        "${POLARIS_SWITCH_METADATA_DIR}"
    then
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_SWITCH_COLLECTION_STATUS="complete-switch-configuration-export"

    log_success "Switch staging directories initialized."
    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _collect_switch_exports
#
# Purpose:
#   Run the Playwright export (Text Configuration + Tech Support, one
#   browser session) and validate both resulting artifacts.
###############################################################################

_collect_switch_exports() {
    local config_file="${POLARIS_SWITCH_SWITCH_DIR}/switch-configuration.txt"
    local tech_support_file="${POLARIS_SWITCH_SWITCH_DIR}/switch-tech-support.txt"

    log_info "Collecting switch configuration and tech-support exports."

    if [[ -z "${POLARIS_SWITCH_SWITCH_DIR}" ]] ||
       [[ ! -d "${POLARIS_SWITCH_SWITCH_DIR}" ]]
    then
        operator_error "Switch staging directory has not been initialized."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _switch_run_export "${config_file}" "${tech_support_file}"; then
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${config_file}" ]]; then
        operator_error "Switch configuration export artifact is empty."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${tech_support_file}" ]]; then
        operator_error "Switch tech-support export artifact is empty."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    chmod 600 "${config_file}" "${tech_support_file}" || {
        operator_error "Unable to secure switch export artifacts."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    }

    log_success "Switch configuration and tech-support exports collected successfully."
    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _locate_baseline
#
# Purpose:
#   Validate a previously validated switch-configuration.txt and hash it for
#   comparison. Deliberately scoped to the config file alone - tech-support
#   is a live diagnostics dump (confirmed to vary run-to-run even with zero
#   real config change) and must never influence this comparison.
#
# Parameters:
#   $1 - Path to the previous validated switch-configuration.txt, or empty
#        if no baseline exists yet.
###############################################################################

_locate_baseline() {
    local baseline_path="${1:-}"
    local hash_output=""

    POLARIS_SWITCH_LOCAL_BASELINE=""
    POLARIS_SWITCH_BASELINE_HASH=""

    if [[ -z "${baseline_path}" ]]; then
        log_info "No previous switch configuration baseline was provided."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
    fi

    if [[ ! -f "${baseline_path}" ]] || [[ ! -r "${baseline_path}" ]] || [[ ! -s "${baseline_path}" ]]; then
        operator_error "The supplied switch configuration baseline is missing, unreadable, or empty: ${baseline_path}"
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! hash_output="$(sha256sum -- "${baseline_path}")"; then
        operator_error "Unable to calculate the switch baseline checksum."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    hash_output="${hash_output%% *}"

    if [[ ! "${hash_output}" =~ ^[[:xdigit:]]{64}$ ]]; then
        operator_error "The switch baseline produced an invalid SHA-256 checksum."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_SWITCH_LOCAL_BASELINE="${baseline_path}"
    POLARIS_SWITCH_BASELINE_HASH="${hash_output,,}"

    log_success "Previous switch configuration baseline validated."
    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _compare_configuration
#
# Purpose:
#   Hash the freshly collected switch-configuration.txt and compare it to
#   the baseline hash (if any). Sets POLARIS_SWITCH_CONFIG_STATUS to one of
#   new/changed/unchanged. tech-support is never part of this comparison.
#
# Parameters:
#   $1 - Path to the freshly collected switch-configuration.txt.
###############################################################################

_compare_configuration() {
    local config_file="${1:-}"
    local hash_output=""

    POLARIS_SWITCH_CONFIG_STATUS=""

    if [[ -z "${config_file}" ]] || [[ ! -s "${config_file}" ]]; then
        operator_error "Cannot compare switch configuration: collected file is missing or empty."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! hash_output="$(sha256sum -- "${config_file}")"; then
        operator_error "Unable to calculate the switch configuration checksum."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    hash_output="${hash_output%% *}"
    POLARIS_SWITCH_CONFIG_HASH="${hash_output,,}"

    if [[ -z "${POLARIS_SWITCH_BASELINE_HASH}" ]]; then
        POLARIS_SWITCH_CONFIG_STATUS="${POLARIS_SWITCH_CONFIG_STATUS_NEW}"
        log_info "No previous switch configuration baseline exists. Current export will be staged."
    elif [[ "${POLARIS_SWITCH_CONFIG_HASH}" == "${POLARIS_SWITCH_BASELINE_HASH}" ]]; then
        POLARIS_SWITCH_CONFIG_STATUS="${POLARIS_SWITCH_CONFIG_STATUS_UNCHANGED}"
        log_info "Switch configuration is unchanged."
    else
        POLARIS_SWITCH_CONFIG_STATUS="${POLARIS_SWITCH_CONFIG_STATUS_CHANGED}"
        log_info "A change was detected in the switch configuration."
    fi

    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _write_collector_info
###############################################################################

_write_collector_info() {
    local output_file="${POLARIS_SWITCH_METADATA_DIR}/collector-info.txt"

    if ! cat > "${output_file}" <<EOF
Collector Name: ${POLARIS_SWITCH_MODULE_NAME}
Collector Display Name: ${POLARIS_SWITCH_MODULE_DISPLAY_NAME}
Collector Version: ${POLARIS_SWITCH_MODULE_VERSION}
Collector Author: ${POLARIS_SWITCH_MODULE_AUTHOR}
Collection Mode: ${POLARIS_SWITCH_COLLECTION_STATUS}
Framework Version: ${POLARIS_FRAMEWORK_VERSION}
Hash Algorithm: SHA-256
EOF
    then
        operator_error "Unable to write switch collector information."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error "Unable to secure switch collector information."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error "Switch collector information file is empty."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Switch collector information written successfully."
    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _write_execution_info
###############################################################################

_write_execution_info() {
    local output_file="${POLARIS_SWITCH_METADATA_DIR}/execution.txt"
    local timestamp=""

    if ! timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; then
        operator_error "Unable to generate the switch execution timestamp."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! cat > "${output_file}" <<EOF
Execution Timestamp (UTC): ${timestamp}
Collection Status: ${POLARIS_SWITCH_COLLECTION_STATUS}
Configuration Status: ${POLARIS_SWITCH_CONFIG_STATUS}
Configuration Hash (switch-configuration.txt only): ${POLARIS_SWITCH_CONFIG_HASH}
Baseline Hash: ${POLARIS_SWITCH_BASELINE_HASH}
Staging Root: ${POLARIS_SWITCH_STAGING_ROOT}
Configuration Directory: ${POLARIS_SWITCH_SWITCH_DIR}
Collection Method: Playwright browser automation (HTTP File Export)
Note: tech-support is intentionally excluded from the comparison above - it
is a live diagnostics dump, not configuration, and is expected to vary on
every run regardless of real device state.
EOF
    then
        operator_error "Unable to write switch execution metadata."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error "Unable to secure switch execution metadata."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error "Switch execution metadata file is empty."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Switch execution metadata written successfully."
    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _write_collection_summary
###############################################################################

_write_collection_summary() {
    local output_file="${POLARIS_SWITCH_METADATA_DIR}/collection-summary.txt"
    local timestamp=""

    if ! timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; then
        operator_error "Unable to generate the switch summary timestamp."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! cat > "${output_file}" <<EOF
Project Polaris Switch Collector Summary
=========================================

Collector Version: ${POLARIS_SWITCH_MODULE_VERSION}
Execution Time (UTC): ${timestamp}
Status: SUCCESS
Collection Mode: Text Configuration and Tech Support Export

Implemented
-----------
[COLLECTED] Collector metadata
[COLLECTED] Execution metadata
[COLLECTED] Collection summary
[COLLECTED] Integrity manifest
[COLLECTED] Switch text configuration export
[COLLECTED] Switch tech-support export

Planned
-------
EOF
    then
        operator_error "Unable to write switch collection summary."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error "Unable to secure switch collection summary."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error "Switch collection summary is empty."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Switch collection summary written successfully."
    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _write_manifest
###############################################################################

_write_manifest() {
    local output_file="${POLARIS_SWITCH_METADATA_DIR}/manifest.txt"

    if ! polaris_manifest_recursive \
        "${POLARIS_SWITCH_STAGING_ROOT}" \
        "${output_file}" \
        "Switch"
    then
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Switch integrity manifest written successfully."
    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _preserve_failure_artifacts
###############################################################################

_preserve_failure_artifacts() {
    local troubleshooting_root="${1:-}"
    local failure_reason="${2:-unspecified failure}"

    polaris_preserve_failure_staging \
        "${troubleshooting_root}" \
        "switch" \
        "Switch" \
        "${POLARIS_SWITCH_MODULE_VERSION}" \
        "${POLARIS_SWITCH_COLLECTION_STATUS:-unavailable}" \
        "${failure_reason}" \
        "${POLARIS_SWITCH_STAGING_ROOT}"
}

###############################################################################
# Function: _cleanup
###############################################################################

_cleanup() {
    if [[ -z "${POLARIS_SWITCH_STAGING_ROOT}" ]]; then
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
    fi

    if ! polaris_remove_staging_root "${POLARIS_SWITCH_STAGING_ROOT}" "Switch"; then
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_SWITCH_STAGING_ROOT=""
    POLARIS_SWITCH_CONFIGURATION_DIR=""
    POLARIS_SWITCH_SWITCH_DIR=""
    POLARIS_SWITCH_METADATA_DIR=""

    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: collect_switch
#
# Purpose:
#   Coordinate the switch configuration and tech-support export collection,
#   then determine change status from switch-configuration.txt ALONE.
#   tech-support is still collected and (when the run is promoted) backed
#   up every time, but it never influences whether this run is treated as
#   new/changed/unchanged.
#
# Parameters:
#   $1 - Collector staging root.
#   $2 - Troubleshooting root.
#   $3 - Previous validated switch-configuration.txt baseline, or empty.
###############################################################################

collect_switch() {
    local staging_root="${1:-}"
    local troubleshooting_root="${2:-}"
    local baseline_path="${3:-}"
    local failure_reason=""

    POLARIS_SWITCH_STAGING_ROOT=""
    POLARIS_SWITCH_CONFIGURATION_DIR=""
    POLARIS_SWITCH_SWITCH_DIR=""
    POLARIS_SWITCH_METADATA_DIR=""
    POLARIS_SWITCH_COLLECTION_STATUS=""
    POLARIS_SWITCH_LOCAL_BASELINE=""
    POLARIS_SWITCH_CONFIG_HASH=""
    POLARIS_SWITCH_BASELINE_HASH=""
    POLARIS_SWITCH_CONFIG_STATUS=""

    if [[ -z "${staging_root}" ]] || [[ -z "${troubleshooting_root}" ]]; then
        operator_error "Switch collector paths were not provided."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    log_info "Starting switch configuration and tech-support export collection."

    if ! _validate_environment; then
        failure_reason="environment validation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _initialize_staging "${staging_root}"; then
        failure_reason="staging initialization failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _locate_baseline "${baseline_path}"; then
        failure_reason="baseline validation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_switch_exports; then
        failure_reason="switch export collection failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _compare_configuration "${POLARIS_SWITCH_SWITCH_DIR}/switch-configuration.txt"; then
        failure_reason="configuration comparison failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ "${POLARIS_SWITCH_CONFIG_STATUS}" == "${POLARIS_SWITCH_CONFIG_STATUS_UNCHANGED}" ]]; then
        if ! _cleanup; then
            operator_error "Unable to remove the unused switch staging directory after an unchanged result."
            _preserve_failure_artifacts "${troubleshooting_root}" "unchanged-result staging cleanup failed" || true
            return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
        fi

        log_info "Switch configuration is unchanged. No backup artifact was created (tech-support from this run was discarded along with it)."
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_NO_CHANGE}"
    fi

    if ! _write_collector_info; then
        failure_reason="collector metadata generation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_execution_info; then
        failure_reason="execution metadata generation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_collection_summary; then
        failure_reason="collection summary generation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_manifest; then
        failure_reason="manifest generation failed"
        _preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_SWITCH_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Switch configuration and tech-support export collection completed successfully."
    return "${POLARIS_SWITCH_COLLECTOR_RESULT_SUCCESS}"
}
