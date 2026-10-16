
#!/usr/bin/env bash

###############################################################################
#
# Project Polaris
#
# Module:
#     verify-manifest.sh
#
# Component:
#     Backup Configuration Validation
#
# Version:
#     0.2.0
#
# Purpose:
#     Verify the completeness and integrity of a Project Polaris collector
#     staging directory by comparing each artifact with metadata recorded in
#     metadata/manifest.txt.
#
# Public Interface:
#     verify_manifest <collector-staging-directory>
#
# Manifest Format:
#     Relative Path<TAB>Size<TAB>SHA-256
#
# Dependencies:
#     lib/polaris-common.sh
#     sha256sum
#     stat
#
###############################################################################

###############################################################################
# Load Project Polaris common functions
###############################################################################

readonly POLARIS_VERIFY_COMMON_LIBRARY_RELATIVE_PATH="../lib/polaris-common.sh"

POLARIS_VERIFY_SCRIPT_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

POLARIS_VERIFY_COMMON_LIBRARY="$(
    realpath "${POLARIS_VERIFY_SCRIPT_DIRECTORY}/${POLARIS_VERIFY_COMMON_LIBRARY_RELATIVE_PATH}"
)"

if [[ ! -r "${POLARIS_VERIFY_COMMON_LIBRARY}" ]]; then
    printf 'ERROR: Project Polaris common library not found or unreadable: %s\n' \
        "${POLARIS_VERIFY_COMMON_LIBRARY}" >&2

    if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
        return 4
    fi

    exit 4
fi

# shellcheck source=/dev/null
source "${POLARIS_VERIFY_COMMON_LIBRARY}"

###############################################################################
# Constants
###############################################################################

readonly POLARIS_VERIFY_MODULE_NAME="Manifest Verification Utility"
readonly POLARIS_VERIFY_MODULE_VERSION="1.0.0"

readonly POLARIS_VERIFY_SUCCESS=0
readonly POLARIS_VERIFY_FAILED=1
readonly POLARIS_VERIFY_MANIFEST_MISSING=2
readonly POLARIS_VERIFY_STAGING_MISSING=3
readonly POLARIS_VERIFY_INTERNAL_ERROR=4

readonly POLARIS_VERIFY_MANIFEST_RELATIVE_PATH="metadata/manifest.txt"
readonly POLARIS_VERIFY_OUTPUT_DIRECTORY_NAME="verification"
readonly POLARIS_VERIFY_REPORT_FILENAME="verification-report.txt"
readonly POLARIS_VERIFY_SUMMARY_FILENAME="verification-summary.txt"

###############################################################################
# Module State
###############################################################################

POLARIS_VERIFY_STAGING_DIRECTORY=""
POLARIS_VERIFY_MANIFEST_FILE=""
POLARIS_VERIFY_OUTPUT_DIRECTORY=""
POLARIS_VERIFY_REPORT_FILE=""
POLARIS_VERIFY_SUMMARY_FILE=""
POLARIS_VERIFY_STARTED_AT=""
POLARIS_VERIFY_COMPLETED_AT=""

POLARIS_VERIFY_TOTAL_COUNT=0
POLARIS_VERIFY_PASS_COUNT=0
POLARIS_VERIFY_FAIL_COUNT=0
POLARIS_VERIFY_MISSING_COUNT=0
POLARIS_VERIFY_ERROR_COUNT=0

###############################################################################
# Function:
#     verify_manifest
#
# Purpose:
#     Coordinate the complete manifest verification workflow.
#
# Parameters:
#     $1 - Collector staging directory
#
# Returns:
#     0 - Verification successful
#     1 - Verification completed with one or more failed artifacts
#     2 - Manifest missing
#     3 - Staging directory missing or invalid
#     4 - Internal verifier error
###############################################################################
verify_manifest() {

    local staging_directory="${1:-}"
    local verification_result
    local report_result

    log_info "Starting ${POLARIS_VERIFY_MODULE_NAME} v${POLARIS_VERIFY_MODULE_VERSION}"

    _validate_input "${staging_directory}"
    verification_result=$?

    if (( verification_result != POLARIS_VERIFY_SUCCESS )); then
        return "${verification_result}"
    fi

    _initialize_verification
    verification_result=$?

    if (( verification_result != POLARIS_VERIFY_SUCCESS )); then
        return "${verification_result}"
    fi

    _execute_verification
    verification_result=$?

    _generate_reports "${verification_result}"
    report_result=$?

    if (( report_result != POLARIS_VERIFY_SUCCESS )); then
        return "${report_result}"
    fi

    if (( verification_result == POLARIS_VERIFY_SUCCESS )); then
        log_success "Manifest verification completed successfully."
    else
        operator_error "Manifest verification completed with failures."
    fi

    return "${verification_result}"
}

###############################################################################
# Function:
#     _validate_input
#
# Purpose:
#     Validate the supplied staging directory, required commands, and manifest.
###############################################################################
_validate_input() {

    local staging_directory="$1"

    if [[ -z "${staging_directory}" ]]; then
        operator_error "No staging directory specified."
        return "${POLARIS_VERIFY_STAGING_MISSING}"
    fi

    if [[ ! -d "${staging_directory}" ]]; then
        operator_error "Staging directory not found: ${staging_directory}"
        return "${POLARIS_VERIFY_STAGING_MISSING}"
    fi

    if ! command -v sha256sum >/dev/null 2>&1; then
        operator_error "Required command not found: sha256sum"
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    fi

    if ! command -v stat >/dev/null 2>&1; then
        operator_error "Required command not found: stat"
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    fi

    POLARIS_VERIFY_STAGING_DIRECTORY="$(cd -- "${staging_directory}" 2>/dev/null && pwd -P)" || {
        operator_error "Unable to resolve staging directory: ${staging_directory}"
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    }

    POLARIS_VERIFY_MANIFEST_FILE="${POLARIS_VERIFY_STAGING_DIRECTORY}/${POLARIS_VERIFY_MANIFEST_RELATIVE_PATH}"

    if [[ ! -f "${POLARIS_VERIFY_MANIFEST_FILE}" ]]; then
        operator_error "Manifest not found: ${POLARIS_VERIFY_MANIFEST_FILE}"
        return "${POLARIS_VERIFY_MANIFEST_MISSING}"
    fi

    if [[ ! -r "${POLARIS_VERIFY_MANIFEST_FILE}" ]]; then
        operator_error "Manifest is not readable: ${POLARIS_VERIFY_MANIFEST_FILE}"
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    fi

    POLARIS_VERIFY_OUTPUT_DIRECTORY="${POLARIS_VERIFY_STAGING_DIRECTORY}/${POLARIS_VERIFY_OUTPUT_DIRECTORY_NAME}"

    if ! mkdir -p -- "${POLARIS_VERIFY_OUTPUT_DIRECTORY}"; then
        operator_error "Unable to create verification output directory: ${POLARIS_VERIFY_OUTPUT_DIRECTORY}"
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    fi

    POLARIS_VERIFY_REPORT_FILE="${POLARIS_VERIFY_OUTPUT_DIRECTORY}/${POLARIS_VERIFY_REPORT_FILENAME}"
    POLARIS_VERIFY_SUMMARY_FILE="${POLARIS_VERIFY_OUTPUT_DIRECTORY}/${POLARIS_VERIFY_SUMMARY_FILENAME}"

    log_info "Staging directory validated: ${POLARIS_VERIFY_STAGING_DIRECTORY}"
    log_info "Manifest located: ${POLARIS_VERIFY_MANIFEST_FILE}"

    return "${POLARIS_VERIFY_SUCCESS}"
}

###############################################################################
# Function:
#     _initialize_verification
#
# Purpose:
#     Reset counters and prepare fresh report files.
###############################################################################
_initialize_verification() {

    POLARIS_VERIFY_TOTAL_COUNT=0
    POLARIS_VERIFY_PASS_COUNT=0
    POLARIS_VERIFY_FAIL_COUNT=0
    POLARIS_VERIFY_MISSING_COUNT=0
    POLARIS_VERIFY_ERROR_COUNT=0

    POLARIS_VERIFY_STARTED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
    POLARIS_VERIFY_COMPLETED_AT=""

    if ! : > "${POLARIS_VERIFY_REPORT_FILE}"; then
        operator_error "Unable to create verification report: ${POLARIS_VERIFY_REPORT_FILE}"
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    fi

    if ! : > "${POLARIS_VERIFY_SUMMARY_FILE}"; then
        operator_error "Unable to create verification summary: ${POLARIS_VERIFY_SUMMARY_FILE}"
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    fi

    {
        echo "==============================================================="
        echo "Project Polaris Manifest Verification Report"
        echo "==============================================================="
        echo
        echo "Module Version       : ${POLARIS_VERIFY_MODULE_VERSION}"
        echo "Verification Started : ${POLARIS_VERIFY_STARTED_AT}"
        echo "Staging Directory    : ${POLARIS_VERIFY_STAGING_DIRECTORY}"
        echo "Manifest             : ${POLARIS_VERIFY_MANIFEST_FILE}"
        echo
        echo "---------------------------------------------------------------"
        printf '%-8s %-12s %-12s %s\n' "STATUS" "SIZE" "HASH" "FILE"
        echo "---------------------------------------------------------------"
    } >> "${POLARIS_VERIFY_REPORT_FILE}" || {
        operator_error "Unable to write verification report header."
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    }

    log_info "Verification environment initialized."

    return "${POLARIS_VERIFY_SUCCESS}"
}

###############################################################################
# Function:
#     _execute_verification
#
# Purpose:
#     Read each manifest entry and verify the corresponding artifact.
###############################################################################
_execute_verification() {

    local relative_path
    local recorded_size
    local recorded_hash
    local extra_field

    while IFS=$'\t' read -r relative_path recorded_size recorded_hash extra_field || \
          [[ -n "${relative_path}${recorded_size}${recorded_hash}${extra_field}" ]]; do

        [[ -z "${relative_path}" ]] && continue
        [[ "${relative_path}" == \#* ]] && continue
        [[ "${relative_path}" == "Relative Path" ]] && continue

        ((++POLARIS_VERIFY_TOTAL_COUNT))

        if [[ -z "${recorded_size}" || -z "${recorded_hash}" || -n "${extra_field}" ]]; then
            ((++POLARIS_VERIFY_ERROR_COUNT))
            _record_result "ERROR" "${relative_path}" "INVALID" "INVALID"
            continue
        fi

        if [[ "${relative_path}" == /* || "${relative_path}" == ".." || "${relative_path}" == ../* || "${relative_path}" == */../* ]]; then
            ((++POLARIS_VERIFY_ERROR_COUNT))
            _record_result "ERROR" "${relative_path}" "UNSAFE" "UNSAFE"
            continue
        fi

        _verify_artifact "${relative_path}" "${recorded_size}" "${recorded_hash}"

    done < "${POLARIS_VERIFY_MANIFEST_FILE}" || {
        operator_error "Unable to read manifest: ${POLARIS_VERIFY_MANIFEST_FILE}"
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    }

    if (( POLARIS_VERIFY_TOTAL_COUNT == 0 )); then
        operator_error "Manifest contains no artifact entries."
        return "${POLARIS_VERIFY_FAILED}"
    fi

    if (( POLARIS_VERIFY_FAIL_COUNT > 0 ||
          POLARIS_VERIFY_MISSING_COUNT > 0 ||
          POLARIS_VERIFY_ERROR_COUNT > 0 )); then
        return "${POLARIS_VERIFY_FAILED}"
    fi

    return "${POLARIS_VERIFY_SUCCESS}"
}

###############################################################################
# Function:
#     _verify_artifact
#
# Purpose:
#     Verify one artifact's existence, size, and SHA-256 hash.
###############################################################################
_verify_artifact() {

    local relative_path="$1"
    local recorded_size="$2"
    local recorded_hash="$3"
    local artifact_path
    local actual_size
    local actual_hash

    artifact_path="${POLARIS_VERIFY_STAGING_DIRECTORY}/${relative_path}"

    if [[ ! -f "${artifact_path}" ]]; then
        ((++POLARIS_VERIFY_MISSING_COUNT))
        _record_result "MISSING" "${relative_path}" "-" "-"
        return "${POLARIS_VERIFY_FAILED}"
    fi

    if [[ ! -r "${artifact_path}" ]]; then
        ((++POLARIS_VERIFY_ERROR_COUNT))
        _record_result "ERROR" "${relative_path}" "UNREADABLE" "-"
        return "${POLARIS_VERIFY_FAILED}"
    fi

    if ! actual_size="$(stat -c '%s' -- "${artifact_path}" 2>/dev/null)"; then
        ((++POLARIS_VERIFY_ERROR_COUNT))
        _record_result "ERROR" "${relative_path}" "STAT" "-"
        return "${POLARIS_VERIFY_FAILED}"
    fi

    if [[ "${actual_size}" != "${recorded_size}" ]]; then
        ((++POLARIS_VERIFY_FAIL_COUNT))
        _record_result "FAIL" "${relative_path}" "${actual_size}/${recorded_size}" "-"
        return "${POLARIS_VERIFY_FAILED}"
    fi

    if ! actual_hash="$(sha256sum -- "${artifact_path}" 2>/dev/null)"; then
        ((++POLARIS_VERIFY_ERROR_COUNT))
        _record_result "ERROR" "${relative_path}" "${actual_size}" "HASH-READ"
        return "${POLARIS_VERIFY_FAILED}"
    fi

    actual_hash="${actual_hash%% *}"

    if [[ "${actual_hash}" != "${recorded_hash}" ]]; then
        ((++POLARIS_VERIFY_FAIL_COUNT))
        _record_result "FAIL" "${relative_path}" "${actual_size}" "${actual_hash}"
        return "${POLARIS_VERIFY_FAILED}"
    fi

    ((++POLARIS_VERIFY_PASS_COUNT))
    _record_result "PASS" "${relative_path}" "${actual_size}" "${actual_hash}"

    return "${POLARIS_VERIFY_SUCCESS}"
}

###############################################################################
# Function:
#     _record_result
#
# Purpose:
#     Append one artifact result to the detailed verification report.
###############################################################################
_record_result() {

    local status="$1"
    local relative_path="$2"
    local size="$3"
    local hash="$4"
    local display_hash="${hash}"

    if [[ "${hash}" =~ ^[[:xdigit:]]{64}$ ]]; then
        display_hash="${hash:0:12}"
    fi

    if ! printf '%-8s %-12s %-12s %s\n' \
        "${status}" \
        "${size}" \
        "${display_hash}" \
        "${relative_path}" \
        >> "${POLARIS_VERIFY_REPORT_FILE}"; then

        operator_error "Unable to record verification result for: ${relative_path}"
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    fi

    return "${POLARIS_VERIFY_SUCCESS}"
}

###############################################################################
# Function:
#     _generate_reports
#
# Purpose:
#     Finalize the detailed report and write the verification summary.
#
# Parameters:
#     $1 - Overall verification result from _execute_verification
###############################################################################
_generate_reports() {

    local verification_result="$1"
    local overall_status="FAILED"

    POLARIS_VERIFY_COMPLETED_AT="$(date '+%Y-%m-%d %H:%M:%S')"

    if (( verification_result == POLARIS_VERIFY_SUCCESS )); then
        overall_status="SUCCESS"
    fi

    {
        echo "---------------------------------------------------------------"
        echo
        echo "Verification Completed : ${POLARIS_VERIFY_COMPLETED_AT}"
        echo "Overall Status         : ${overall_status}"
        echo "Artifacts Processed    : ${POLARIS_VERIFY_TOTAL_COUNT}"
        echo "Passed                 : ${POLARIS_VERIFY_PASS_COUNT}"
        echo "Failed                 : ${POLARIS_VERIFY_FAIL_COUNT}"
        echo "Missing                : ${POLARIS_VERIFY_MISSING_COUNT}"
        echo "Errors                 : ${POLARIS_VERIFY_ERROR_COUNT}"
    } >> "${POLARIS_VERIFY_REPORT_FILE}" || {
        operator_error "Unable to finalize verification report."
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    }

    {
        echo "Project Polaris Manifest Verification Summary"
        echo
        echo "Module Version       : ${POLARIS_VERIFY_MODULE_VERSION}"
        echo "Verification Started : ${POLARIS_VERIFY_STARTED_AT}"
        echo "Verification Ended   : ${POLARIS_VERIFY_COMPLETED_AT}"
        echo "Staging Directory    : ${POLARIS_VERIFY_STAGING_DIRECTORY}"
        echo "Manifest             : ${POLARIS_VERIFY_MANIFEST_FILE}"
        echo "Status               : ${overall_status}"
        echo
        echo "Artifacts Processed  : ${POLARIS_VERIFY_TOTAL_COUNT}"
        echo "Passed               : ${POLARIS_VERIFY_PASS_COUNT}"
        echo "Failed               : ${POLARIS_VERIFY_FAIL_COUNT}"
        echo "Missing              : ${POLARIS_VERIFY_MISSING_COUNT}"
        echo "Errors               : ${POLARIS_VERIFY_ERROR_COUNT}"
    } > "${POLARIS_VERIFY_SUMMARY_FILE}" || {
        operator_error "Unable to write verification summary."
        return "${POLARIS_VERIFY_INTERNAL_ERROR}"
    }

    log_info "Verification report written: ${POLARIS_VERIFY_REPORT_FILE}"
    log_info "Verification summary written: ${POLARIS_VERIFY_SUMMARY_FILE}"

    return "${POLARIS_VERIFY_SUCCESS}"
}

###############################################################################
# Direct execution entry point
###############################################################################

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then

    if (( $# != 1 )); then
        printf 'Usage: %s <collector-staging-directory>\n' "$0" >&2
        exit ${POLARIS_VERIFY_STAGING_MISSING}
    fi

    verify_manifest "$1"
    exit $?

fi
