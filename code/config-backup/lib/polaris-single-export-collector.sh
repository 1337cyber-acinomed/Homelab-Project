#!/usr/bin/env bash

[[ -n "${POLARIS_SINGLE_EXPORT_COLLECTOR_SH_LOADED:-}" ]] && return 0
readonly POLARIS_SINGLE_EXPORT_COLLECTOR_SH_LOADED=1

###############################################################################
# Project Polaris
# Shared Single-Export Collector Engine
#
# Purpose:
#   A sibling to polaris-firewall-collector.sh for devices that do not expose
#   a stable, already-existing config file to `cat` directly. Instead, a
#   remote command must be RUN to generate a fresh export artifact (a zip,
#   in the pihole01/Teleporter case), which is then fetched, and a single
#   known path INSIDE that artifact is what actually drives change-detection
#   (the rest of the artifact is real backup content, but not a trustworthy
#   change signal — see pihole01: pihole.toml is stable across two real
#   no-change exports, but the surrounding zip is not, and pihole-FTL.db/
#   dhcp.leases inside it are expected to differ on every run).
#
#   polaris-firewall-collector.sh is intentionally left untouched. It is
#   live and proven for pfSense/OPNsense/gateway01; this file exists so a
#   new "generate, then fetch, then compare one inner file" collector never
#   has to touch that proven engine to get the same reliability.
#
# Used By: pihole (pihole01)
###############################################################################

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/polaris-common.sh"

###############################################################################
# Shared Helper: polaris_register_single_export_collector()
# Purpose: Registers collector-specific single-export settings.
# Impact: Changes affect every registered collector. Validate all before release.
###############################################################################

declare -gA POLARIS_SINGLE_EXPORT_CONFIG=()

polaris_register_single_export_collector() {
    local collector_id="${1:-}"
    local product_name="${2:-}"
    local module_display_name="${3:-}"
    local module_version="${4:-}"
    local host="${5:-}"
    local user="${6:-}"
    local ssh_key="${7:-}"
    local connect_timeout="${8:-}"
    local remote_work_dir="${9:-}"
    local remote_export_command="${10:-}"
    local staged_artifact_name="${11:-}"
    local comparison_inner_path="${12:-}"

    if [[ -z "${collector_id}" || -z "${product_name}" || -z "${host}" ||
          -z "${user}" || -z "${ssh_key}" || -z "${remote_work_dir}" ||
          -z "${remote_export_command}" || -z "${staged_artifact_name}" ||
          -z "${comparison_inner_path}" ]]; then
        operator_error "Single-export collector registration is incomplete."
        return 1
    fi

    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},product_name"]="${product_name}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},module_name"]="${collector_id}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},module_display_name"]="${module_display_name}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},module_version"]="${module_version}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},module_author"]="Project Polaris"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},host"]="${host}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},user"]="${user}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},ssh_key"]="${ssh_key}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},connect_timeout"]="${connect_timeout:-10}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},remote_work_dir"]="${remote_work_dir}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},remote_export_command"]="${remote_export_command}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},staged_artifact_name"]="${staged_artifact_name}"
    POLARIS_SINGLE_EXPORT_CONFIG["${collector_id},comparison_inner_path"]="${comparison_inner_path}"
}

###############################################################################
# Shared Helper: _polaris_single_export_load_registry()
###############################################################################

_polaris_single_export_load_registry() {
    local collector_id="${1:-}"
    local key=""

    for key in product_name module_name module_display_name module_version \
               module_author host user ssh_key connect_timeout remote_work_dir \
               remote_export_command staged_artifact_name comparison_inner_path; do
        if [[ -z "${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},${key}]+x}" ]]; then
            operator_error "Single-export registry entry missing: ${collector_id}/${key}"
            return 1
        fi
    done

    POLARIS_SINGLE_EXPORT_PRODUCT_NAME="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},product_name]}"
    POLARIS_SINGLE_EXPORT_MODULE_NAME="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},module_name]}"
    POLARIS_SINGLE_EXPORT_MODULE_DISPLAY_NAME="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},module_display_name]}"
    POLARIS_SINGLE_EXPORT_MODULE_VERSION="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},module_version]}"
    POLARIS_SINGLE_EXPORT_MODULE_AUTHOR="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},module_author]}"
    POLARIS_SINGLE_EXPORT_HOST="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},host]}"
    POLARIS_SINGLE_EXPORT_USER="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},user]}"
    POLARIS_SINGLE_EXPORT_SSH_KEY="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},ssh_key]}"
    POLARIS_SINGLE_EXPORT_SSH_CONNECT_TIMEOUT="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},connect_timeout]}"
    POLARIS_SINGLE_EXPORT_REMOTE_WORK_DIR="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},remote_work_dir]}"
    POLARIS_SINGLE_EXPORT_REMOTE_EXPORT_COMMAND="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},remote_export_command]}"
    POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT_NAME="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},staged_artifact_name]}"
    POLARIS_SINGLE_EXPORT_COMPARISON_INNER_PATH="${POLARIS_SINGLE_EXPORT_CONFIG[${collector_id},comparison_inner_path]}"

    return 0
}

readonly POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_NO_CHANGE=2
readonly POLARIS_SINGLE_EXPORT_CONFIG_STATUS_NEW="new"
readonly POLARIS_SINGLE_EXPORT_CONFIG_STATUS_CHANGED="changed"
readonly POLARIS_SINGLE_EXPORT_CONFIG_STATUS_UNCHANGED="unchanged"

POLARIS_SINGLE_EXPORT_PRODUCT_NAME=""
POLARIS_SINGLE_EXPORT_MODULE_NAME=""
POLARIS_SINGLE_EXPORT_MODULE_DISPLAY_NAME=""
POLARIS_SINGLE_EXPORT_MODULE_VERSION=""
POLARIS_SINGLE_EXPORT_MODULE_AUTHOR=""
POLARIS_SINGLE_EXPORT_STAGING_ROOT=""
POLARIS_SINGLE_EXPORT_CONFIG_DIR=""
POLARIS_SINGLE_EXPORT_METADATA_DIR=""
POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT=""
POLARIS_SINGLE_EXPORT_HOST=""
POLARIS_SINGLE_EXPORT_USER=""
POLARIS_SINGLE_EXPORT_SSH_KEY=""
POLARIS_SINGLE_EXPORT_SSH_CONNECT_TIMEOUT=10
POLARIS_SINGLE_EXPORT_REMOTE_WORK_DIR=""
POLARIS_SINGLE_EXPORT_REMOTE_EXPORT_COMMAND=""
POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT_NAME=""
POLARIS_SINGLE_EXPORT_COMPARISON_INNER_PATH=""
POLARIS_SINGLE_EXPORT_LOCAL_BASELINE=""
POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT=""
POLARIS_SINGLE_EXPORT_COMPARISON_HASH=""
POLARIS_SINGLE_EXPORT_BASELINE_COMPARISON_HASH=""
POLARIS_SINGLE_EXPORT_CONFIG_STATUS=""

# Purpose: Own the remote execute step of the collector lifecycle.
_polaris_single_export_remote_execute() {
    local remote_command="${1:-}"

    polaris_ssh_execute \
        "${POLARIS_SINGLE_EXPORT_HOST}" \
        "${POLARIS_SINGLE_EXPORT_USER}" \
        "${POLARIS_SINGLE_EXPORT_SSH_KEY}" \
        "${POLARIS_SINGLE_EXPORT_SSH_CONNECT_TIMEOUT}" \
        "allow" \
        "no" \
        "${remote_command}"
}

###############################################################################
# Environment and Staging
###############################################################################

_polaris_single_export_validate_environment() {

    log_info "Validating ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} collector environment."

    if ! is_root_user; then
        operator_error "Collector must be run as root."
        return 1
    fi

    if ! command_exists ssh; then
        operator_error "ssh command is not available."
        return 1
    fi

    if ! command_exists sha256sum; then
        operator_error "sha256sum command is not available."
        return 1
    fi

    if ! command_exists unzip; then
        operator_error "unzip command is not available."
        return 1
    fi

    if ! command_exists mktemp; then
        operator_error "mktemp command is not available."
        return 1
    fi

    if [[ ! -r "${POLARIS_SINGLE_EXPORT_SSH_KEY}" ]]; then
        operator_error "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} SSH private key is not readable: ${POLARIS_SINGLE_EXPORT_SSH_KEY}"
        return 1
    fi

    if ! _polaris_single_export_remote_execute "true"; then
        operator_error "Unable to validate unattended SSH access to ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME}."
        return 1
    fi

    log_success "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} collector environment validation successful."

    return 0
}

_polaris_single_export_initialize_staging() {

    local staging_root="${1:-}"

    if [[ -z "${staging_root}" ]]; then
        operator_error "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} staging root was not provided."
        return 1
    fi

    POLARIS_SINGLE_EXPORT_STAGING_ROOT="${staging_root}"
    POLARIS_SINGLE_EXPORT_CONFIG_DIR="${POLARIS_SINGLE_EXPORT_STAGING_ROOT}/configuration"
    POLARIS_SINGLE_EXPORT_METADATA_DIR="${POLARIS_SINGLE_EXPORT_STAGING_ROOT}/metadata"
    POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT="${POLARIS_SINGLE_EXPORT_CONFIG_DIR}/${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT_NAME}"

    if ! install -d -m 700 \
        "${POLARIS_SINGLE_EXPORT_CONFIG_DIR}" \
        "${POLARIS_SINGLE_EXPORT_METADATA_DIR}"
    then
        operator_error "Unable to create ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} staging directories."
        return 1
    fi

    log_success "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} staging directories initialized."

    return 0
}

###############################################################################
# Function: _polaris_single_export_run_and_fetch
#
# Purpose:
#   Run the registered remote export command, parse the generated artifact's
#   filename from its own stdout (rather than guessing/globbing), and fetch
#   it into a local temporary file.
###############################################################################

_polaris_single_export_run_and_fetch() {

    local remote_output=""
    local remote_filename=""
    local remote_full_path=""

    log_info "Running ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} remote export command."

    if ! remote_output="$(
        _polaris_single_export_remote_execute \
            "${POLARIS_SINGLE_EXPORT_REMOTE_EXPORT_COMMAND}" 2>&1
    )"
    then
        operator_error "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} remote export command failed: ${remote_output}"
        return 1
    fi

    remote_filename="$(printf '%s\n' "${remote_output}" | tail -n 1)"
    remote_filename="${remote_filename//$'\r'/}"

    if [[ -z "${remote_filename}" ]]; then
        operator_error "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} export command produced no output filename."
        return 1
    fi

    if [[ ! "${remote_filename}" =~ ^[A-Za-z0-9._-]+$ ]]; then
        operator_error "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} export command's reported filename looks invalid: ${remote_filename}"
        return 1
    fi

    remote_full_path="${POLARIS_SINGLE_EXPORT_REMOTE_WORK_DIR%/}/${remote_filename}"

    log_info "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} export produced: ${remote_full_path}"

    POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT="$(mktemp)"

    if [[ -z "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}" ]]; then
        operator_error "Unable to create a temporary artifact file."
        return 1
    fi

    if ! _polaris_single_export_remote_execute \
                "cat -- '${remote_full_path}'" \
        > "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}"
    then
        rm -f "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}"
        operator_error "Unable to fetch the ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} export artifact."
        return 1
    fi

    chmod 600 "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}"

    if [[ ! -s "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}" ]]; then
        rm -f "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}"
        operator_error "Fetched ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} export artifact is empty."
        return 1
    fi

    log_success "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} export artifact fetched successfully."

    return 0
}

###############################################################################
# Function: _polaris_single_export_extract_comparison_hash
#
# Purpose:
#   Extract just the registered comparison-inner-path out of a given archive
#   into a throwaway scratch directory, hash it, then discard the scratch
#   directory. Never leaves loose extracted files behind. Used for both the
#   freshly-fetched artifact and (when present) the baseline artifact, so
#   both hashes are computed the exact same way.
#
# Parameters:
#   $1 - Path to the archive to extract from.
#
# Output:
#   Echoes the SHA-256 hash of the extracted inner file on success.
###############################################################################

_polaris_single_export_extract_comparison_hash() {

    local archive_path="${1:-}"
    local scratch_dir=""
    local extracted_file=""
    local hash_output=""

    if [[ -z "${archive_path}" ]] || [[ ! -f "${archive_path}" ]]; then
        operator_error "Cannot extract a comparison hash: archive does not exist: ${archive_path}"
        return 1
    fi

    scratch_dir="$(mktemp -d)"

    if [[ -z "${scratch_dir}" ]]; then
        operator_error "Unable to create a scratch extraction directory."
        return 1
    fi

    if ! unzip -q -o "${archive_path}" "${POLARIS_SINGLE_EXPORT_COMPARISON_INNER_PATH}" -d "${scratch_dir}"; then
        rm -rf "${scratch_dir}"
        operator_error "Unable to extract ${POLARIS_SINGLE_EXPORT_COMPARISON_INNER_PATH} from ${archive_path}."
        return 1
    fi

    extracted_file="${scratch_dir}/${POLARIS_SINGLE_EXPORT_COMPARISON_INNER_PATH}"

    if [[ ! -s "${extracted_file}" ]]; then
        rm -rf "${scratch_dir}"
        operator_error "Extracted comparison file is missing or empty: ${POLARIS_SINGLE_EXPORT_COMPARISON_INNER_PATH}"
        return 1
    fi

    if ! hash_output="$(sha256sum -- "${extracted_file}")"; then
        rm -rf "${scratch_dir}"
        operator_error "Unable to hash the extracted comparison file."
        return 1
    fi

    rm -rf "${scratch_dir}"

    hash_output="${hash_output%% *}"

    if [[ ! "${hash_output}" =~ ^[[:xdigit:]]{64}$ ]]; then
        operator_error "Extracted comparison file produced an invalid SHA-256 hash."
        return 1
    fi

    printf '%s\n' "${hash_output,,}"
    return 0
}

###############################################################################
# Function: _polaris_single_export_locate_baseline
#
# Parameters:
#   $1 - Path to the previous validated artifact, or empty if none exists.
###############################################################################

_polaris_single_export_locate_baseline() {

    local baseline_path="${1:-}"

    POLARIS_SINGLE_EXPORT_LOCAL_BASELINE=""
    POLARIS_SINGLE_EXPORT_BASELINE_COMPARISON_HASH=""

    if [[ -z "${baseline_path}" ]]; then
        log_info "No previous ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} artifact baseline was provided."
        return 0
    fi

    if [[ ! -f "${baseline_path}" ]] || [[ ! -r "${baseline_path}" ]] || [[ ! -s "${baseline_path}" ]]; then
        operator_error "The supplied ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} baseline artifact is missing, unreadable, or empty: ${baseline_path}"
        return 1
    fi

    if ! POLARIS_SINGLE_EXPORT_BASELINE_COMPARISON_HASH="$(
        _polaris_single_export_extract_comparison_hash "${baseline_path}"
    )"
    then
        operator_error "Unable to compute the ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} baseline comparison hash."
        return 1
    fi

    POLARIS_SINGLE_EXPORT_LOCAL_BASELINE="${baseline_path}"

    log_success "Previous ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} artifact baseline validated."

    return 0
}

_polaris_single_export_compare_hashes() {

    POLARIS_SINGLE_EXPORT_CONFIG_STATUS=""

    if [[ ! "${POLARIS_SINGLE_EXPORT_COMPARISON_HASH}" =~ ^[[:xdigit:]]{64}$ ]]; then
        operator_error "Current ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} comparison hash is unavailable or invalid."
        return 1
    fi

    if [[ -z "${POLARIS_SINGLE_EXPORT_BASELINE_COMPARISON_HASH}" ]]; then
        POLARIS_SINGLE_EXPORT_CONFIG_STATUS="${POLARIS_SINGLE_EXPORT_CONFIG_STATUS_NEW}"
        log_info "No previous ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} baseline exists. Current export will be staged."
        return 0
    fi

    if [[ "${POLARIS_SINGLE_EXPORT_COMPARISON_HASH}" == "${POLARIS_SINGLE_EXPORT_BASELINE_COMPARISON_HASH}" ]]; then
        POLARIS_SINGLE_EXPORT_CONFIG_STATUS="${POLARIS_SINGLE_EXPORT_CONFIG_STATUS_UNCHANGED}"
        log_info "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} configuration is unchanged."
        return 0
    fi

    POLARIS_SINGLE_EXPORT_CONFIG_STATUS="${POLARIS_SINGLE_EXPORT_CONFIG_STATUS_CHANGED}"
    log_info "A change was detected in the ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} configuration."
    return 0
}

###############################################################################
# Function: _polaris_single_export_finalize_artifact
#
# Purpose:
#   Place a validated artifact into the staging directory. New/changed runs
#   use the freshly fetched artifact; unchanged runs reuse the previous
#   validated artifact (via hard link, falling back to a copy) so a
#   provably-unchanged inner file never causes a redundant, differently-
#   bytes'd copy of the surrounding archive to be treated as authoritative.
#   Either way, the staged artifact is re-verified afterward by re-extracting
#   its comparison file and confirming the hash still matches — this is the
#   correct integrity check here, NOT a raw-artifact-hash check, since the
#   raw artifact's bytes are expected to vary even when nothing meaningful
#   changed (see pihole01 finding: the zip differs, pihole.toml doesn't).
###############################################################################

_polaris_single_export_finalize_artifact() {

    local expected_hash=""
    local verify_hash=""

    if [[ -z "${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}" ]]; then
        operator_error "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} staging paths have not been initialized."
        return 1
    fi

    if [[ -e "${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}" ]]; then
        operator_error "A ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} artifact already exists in staging: ${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}"
        return 1
    fi

    case "${POLARIS_SINGLE_EXPORT_CONFIG_STATUS}" in

        "${POLARIS_SINGLE_EXPORT_CONFIG_STATUS_NEW}"|"${POLARIS_SINGLE_EXPORT_CONFIG_STATUS_CHANGED}")

            if [[ -z "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}" ]] ||
               [[ ! -s "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}" ]]
            then
                operator_error "The fetched ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} artifact is unavailable."
                return 1
            fi

            if ! mv -- "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}" "${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}"; then
                operator_error "Unable to move the ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} artifact into staging."
                return 1
            fi

            POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT=""
            expected_hash="${POLARIS_SINGLE_EXPORT_COMPARISON_HASH}"
            ;;

        "${POLARIS_SINGLE_EXPORT_CONFIG_STATUS_UNCHANGED}")

            if [[ -z "${POLARIS_SINGLE_EXPORT_LOCAL_BASELINE}" ]] || [[ ! -s "${POLARIS_SINGLE_EXPORT_LOCAL_BASELINE}" ]]; then
                operator_error "The validated ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} baseline is unavailable for reuse."
                return 1
            fi

            rm -f -- "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}"
            POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT=""

            if ! ln -- "${POLARIS_SINGLE_EXPORT_LOCAL_BASELINE}" "${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}" 2>/dev/null; then
                log_info "Hard-link reuse was unavailable. Copying the validated ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} baseline."

                if ! cp --preserve=mode,timestamps -- \
                    "${POLARIS_SINGLE_EXPORT_LOCAL_BASELINE}" \
                    "${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}"
                then
                    operator_error "Unable to reuse the validated ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} baseline."
                    return 1
                fi
            fi

            chmod 600 "${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}"
            expected_hash="${POLARIS_SINGLE_EXPORT_BASELINE_COMPARISON_HASH}"
            ;;

        *)
            operator_error "The ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} configuration status is unavailable or invalid."
            return 1
            ;;
    esac

    if [[ ! -s "${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}" ]]; then
        operator_error "The finalized ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} artifact failed file validation."
        return 1
    fi

    if ! verify_hash="$(
        _polaris_single_export_extract_comparison_hash "${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}"
    )"
    then
        operator_error "Unable to verify the finalized ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} artifact's comparison file."
        return 1
    fi

    if [[ "${verify_hash}" != "${expected_hash}" ]]; then
        operator_error "The finalized ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} artifact's comparison hash does not match the expected value."
        return 1
    fi

    log_success "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} artifact finalized successfully."
    return 0
}

###############################################################################
# Metadata
###############################################################################

_polaris_single_export_write_collector_info() {

    local output_file="${POLARIS_SINGLE_EXPORT_METADATA_DIR}/collector-info.txt"

    if ! cat > "${output_file}" <<EOF
Collector Name: ${POLARIS_SINGLE_EXPORT_MODULE_NAME}
Collector Display Name: ${POLARIS_SINGLE_EXPORT_MODULE_DISPLAY_NAME}
Collector Version: ${POLARIS_SINGLE_EXPORT_MODULE_VERSION}
Collector Author: ${POLARIS_SINGLE_EXPORT_MODULE_AUTHOR}
Target Host: ${POLARIS_SINGLE_EXPORT_HOST}
Remote Export Command: ${POLARIS_SINGLE_EXPORT_REMOTE_EXPORT_COMMAND}
Comparison Inner Path: ${POLARIS_SINGLE_EXPORT_COMPARISON_INNER_PATH}
Hash Algorithm: SHA-256 (of the comparison inner path, not the raw artifact)
EOF
    then
        operator_error "Unable to write ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} collector information."
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    chmod 600 "${output_file}"
    log_success "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} collector information written successfully."
    return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_SUCCESS}"
}

_polaris_single_export_write_execution_info() {

    local output_file="${POLARIS_SINGLE_EXPORT_METADATA_DIR}/execution.txt"
    local timestamp=""
    local file_size="0"

    if [[ ! -f "${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}" ]]; then
        operator_error "Unable to generate execution metadata. No staged artifact exists."
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    file_size="$(stat -c '%s' "${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT}")"

    if ! cat > "${output_file}" <<EOF
Execution Timestamp (UTC): ${timestamp}
Configuration Status: ${POLARIS_SINGLE_EXPORT_CONFIG_STATUS}
Comparison Hash: ${POLARIS_SINGLE_EXPORT_COMPARISON_HASH}
Baseline Comparison Hash: ${POLARIS_SINGLE_EXPORT_BASELINE_COMPARISON_HASH}
Artifact Size (Bytes): ${file_size}
EOF
    then
        operator_error "Unable to write ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} execution metadata."
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    chmod 600 "${output_file}"
    log_success "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} execution metadata written successfully."
    return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_SUCCESS}"
}

_polaris_single_export_write_manifest() {
    local output_file="${POLARIS_SINGLE_EXPORT_METADATA_DIR}/manifest.txt"

    if ! polaris_manifest_required_files \
        "${POLARIS_SINGLE_EXPORT_STAGING_ROOT}" \
        "${output_file}" \
        "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME}" \
        "configuration/${POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT_NAME}" \
        "metadata/collector-info.txt" \
        "metadata/execution.txt"
    then
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} integrity manifest written successfully."
    return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Failure handling and cleanup
###############################################################################

_polaris_single_export_preserve_failure_artifacts() {

    local troubleshooting_root="${1:-}"
    local failure_reason="${2:-unspecified failure}"
    local failure_timestamp=""
    local failure_directory=""
    local preservation_failed=0

    if [[ -z "${troubleshooting_root}" ]]; then
        operator_error "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} troubleshooting root was not provided."
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    failure_timestamp="$(date -u '+%Y%m%d-%H%M%S')"
    failure_directory="${troubleshooting_root}/${POLARIS_SINGLE_EXPORT_MODULE_NAME}-failure-${failure_timestamp}-$$"

    if ! install -d -m 700 "${failure_directory}"; then
        operator_error "Unable to create the ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} troubleshooting directory: ${failure_directory}"
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ -n "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}" ]] && [[ -f "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}" ]]; then
        cp --preserve=mode,timestamps -- \
            "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}" \
            "${failure_directory}/temporary-artifact" || preservation_failed=1
    fi

    if [[ -n "${POLARIS_SINGLE_EXPORT_STAGING_ROOT}" ]] && [[ -d "${POLARIS_SINGLE_EXPORT_STAGING_ROOT}" ]]; then
        cp -a -- "${POLARIS_SINGLE_EXPORT_STAGING_ROOT}" "${failure_directory}/staging" || preservation_failed=1
    fi

    if ! cat > "${failure_directory}/failure-summary.txt" <<EOF_SUMMARY
Project Polaris ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} Collector Failure Summary
=================================================

Failure Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Failure Reason: ${failure_reason}
Collector Version: ${POLARIS_SINGLE_EXPORT_MODULE_VERSION}
Target Host: ${POLARIS_SINGLE_EXPORT_HOST}
Configuration Status: ${POLARIS_SINGLE_EXPORT_CONFIG_STATUS:-unavailable}
EOF_SUMMARY
    then
        preservation_failed=1
    else
        chmod 600 "${failure_directory}/failure-summary.txt" || preservation_failed=1
    fi

    if (( preservation_failed != 0 )); then
        operator_error "One or more ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} failure artifacts could not be preserved completely."
        log_info "Partial troubleshooting evidence: ${failure_directory}"
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    operator_warning "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} collector failure artifacts were preserved."
    log_info "Troubleshooting evidence: ${failure_directory}"
    return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_SUCCESS}"
}

_polaris_single_export_cleanup_temporary_artifact() {
    if [[ -n "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}" ]] && [[ -e "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}" ]]; then
        rm -f -- "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}"
    fi
    POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT=""
    return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: polaris_collect_single_export_configuration
#
# Parameters:
#   $1 - Registered collector ID.
#   $2 - Collector staging root.
#   $3 - Previous validated artifact baseline, or an empty value.
#   $4 - Troubleshooting root used to preserve failure evidence.
#
# Returns:
#   0 - A new or changed artifact was collected successfully.
#   1 - Collection failed.
#   2 - The comparison file inside the artifact is unchanged.
###############################################################################

polaris_collect_single_export_configuration() {

    local collector_id="${1:-}"
    local staging_root="${2:-}"
    local baseline_path="${3:-}"
    local troubleshooting_root="${4:-}"
    local failure_reason=""

    if ! _polaris_single_export_load_registry "${collector_id}"; then
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_SINGLE_EXPORT_STAGING_ROOT=""
    POLARIS_SINGLE_EXPORT_CONFIG_DIR=""
    POLARIS_SINGLE_EXPORT_METADATA_DIR=""
    POLARIS_SINGLE_EXPORT_STAGED_ARTIFACT=""
    POLARIS_SINGLE_EXPORT_LOCAL_BASELINE=""
    POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT=""
    POLARIS_SINGLE_EXPORT_COMPARISON_HASH=""
    POLARIS_SINGLE_EXPORT_BASELINE_COMPARISON_HASH=""
    POLARIS_SINGLE_EXPORT_CONFIG_STATUS=""

    if [[ -z "${staging_root}" ]] || [[ -z "${troubleshooting_root}" ]]; then
        operator_error "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} collector paths were not provided."
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    log_info "Starting ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} configuration collection."

    if ! _polaris_single_export_validate_environment; then
        failure_reason="environment validation failed"
        _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_single_export_initialize_staging "${staging_root}"; then
        failure_reason="staging initialization failed"
        _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_single_export_locate_baseline "${baseline_path}"; then
        failure_reason="baseline validation failed"
        _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_single_export_run_and_fetch; then
        failure_reason="export acquisition failed"
        _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _polaris_single_export_cleanup_temporary_artifact || true
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    if ! POLARIS_SINGLE_EXPORT_COMPARISON_HASH="$(
        _polaris_single_export_extract_comparison_hash "${POLARIS_SINGLE_EXPORT_TEMP_ARTIFACT}"
    )"
    then
        failure_reason="comparison-file extraction failed"
        _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _polaris_single_export_cleanup_temporary_artifact || true
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_single_export_compare_hashes; then
        failure_reason="configuration comparison failed"
        _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _polaris_single_export_cleanup_temporary_artifact || true
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ "${POLARIS_SINGLE_EXPORT_CONFIG_STATUS}" == "${POLARIS_SINGLE_EXPORT_CONFIG_STATUS_UNCHANGED}" ]]; then
        _polaris_single_export_cleanup_temporary_artifact || true

        if [[ -d "${POLARIS_SINGLE_EXPORT_STAGING_ROOT}" ]]; then
            if ! rm -rf -- "${POLARIS_SINGLE_EXPORT_STAGING_ROOT}"; then
                operator_error "Unable to remove the unused ${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} staging directory after an unchanged result."
                _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "unchanged-result staging cleanup failed" || true
                return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
            fi
        fi

        log_info "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} configuration is unchanged. No backup artifact was created."
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_NO_CHANGE}"
    fi

    if ! _polaris_single_export_finalize_artifact; then
        failure_reason="artifact finalization failed"
        _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        _polaris_single_export_cleanup_temporary_artifact || true
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_single_export_write_collector_info; then
        failure_reason="collector metadata generation failed"
        _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_single_export_write_execution_info; then
        failure_reason="execution metadata generation failed"
        _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _polaris_single_export_write_manifest; then
        failure_reason="manifest generation failed"
        _polaris_single_export_preserve_failure_artifacts "${troubleshooting_root}" "${failure_reason}" || true
        return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "${POLARIS_SINGLE_EXPORT_PRODUCT_NAME} configuration collection completed successfully."
    return "${POLARIS_SINGLE_EXPORT_COLLECTOR_RESULT_SUCCESS}"
}
