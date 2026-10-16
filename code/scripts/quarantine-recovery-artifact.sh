#!/usr/bin/env bash

set -Eeuo pipefail

IFS=$'\n\t'

readonly SCRIPT_NAME="quarantine-recovery-artifact.sh"

readonly RECOVERY_ROOT="/srv/recovery-artifacts"
readonly PUBLICATION_DIR="${RECOVERY_ROOT}/RecoveryArtifacts"
readonly QUARANTINE_ROOT="${RECOVERY_ROOT}/Quarantine"
readonly COMPONENT_LOG_DIR="${RECOVERY_ROOT}/Logs/quarantine"

readonly MANIFEST_NAME="checksums.sha256"
readonly README_NAME="README.md"
readonly MANIFEST_SNAPSHOT_NAME="checksums.sha256.snapshot"
readonly QUARANTINE_RECEIPT_NAME="quarantine-receipt.json"

readonly HELPER_LOG="${COMPONENT_LOG_DIR}/quarantine-recovery-artifact.log"

readonly RESULT_INSUFFICIENT_PRIVILEGES="INSUFFICIENT_PRIVILEGES"
readonly EXIT_INSUFFICIENT_PRIVILEGES=19
readonly RESULT_INVALID_ARGUMENT="INVALID_ARGUMENT"
readonly EXIT_INVALID_ARGUMENT=10
readonly RESULT_PROTECTED_FILE_REJECTED="PROTECTED_FILE_REJECTED"
readonly EXIT_PROTECTED_FILE_REJECTED=11
readonly RESULT_ARTIFACT_NOT_FOUND="ARTIFACT_NOT_FOUND"
readonly EXIT_ARTIFACT_NOT_FOUND=12
readonly RESULT_QUARANTINE_ALREADY_EXISTS="QUARANTINE_ALREADY_EXISTS"
readonly EXIT_QUARANTINE_ALREADY_EXISTS=17
readonly RESULT_MANIFEST_NOT_FOUND="MANIFEST_NOT_FOUND"
readonly EXIT_MANIFEST_NOT_FOUND=18
readonly RESULT_QUARANTINE_DIRECTORY_FAILED="QUARANTINE_DIRECTORY_FAILED"
readonly EXIT_QUARANTINE_DIRECTORY_FAILED=13
readonly RESULT_MANIFEST_SNAPSHOT_FAILED="MANIFEST_SNAPSHOT_FAILED"
readonly EXIT_MANIFEST_SNAPSHOT_FAILED=14
readonly RESULT_ARTIFACT_MOVE_FAILED="ARTIFACT_MOVE_FAILED"
readonly EXIT_ARTIFACT_MOVE_FAILED=15
readonly RESULT_QUARANTINE_CONFIRMATION_FAILED="QUARANTINE_CONFIRMATION_FAILED"
readonly EXIT_QUARANTINE_CONFIRMATION_FAILED=16
readonly RESULT_UNEXPECTED_FAILURE="UNEXPECTED_FAILURE"
readonly EXIT_UNEXPECTED_FAILURE=20
readonly RESULT_QUARANTINE_SUCCESS="QUARANTINE_SUCCESS"
readonly EXIT_QUARANTINE_SUCCESS=0

readonly ARTIFACT_NAME_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]*$'
readonly OPERATION_ID_PATTERN='^[A-Za-z0-9_-]+$'

ARTIFACT_NAME=""
OPERATION_ID=""
SOURCE_PATH=""
MANIFEST_PATH=""
QUARANTINE_DIR=""
MANIFEST_SNAPSHOT_PATH=""
QUARANTINED_ARTIFACT_PATH=""
QUARANTINE_RECEIPT_PATH=""

initialize_component_runtime() {
    if [[ ! -d "$COMPONENT_LOG_DIR" ]]; then
        install -d \
            -o root \
            -g root \
            -m 750 \
            "$COMPONENT_LOG_DIR"
    fi

    chown root:root "$COMPONENT_LOG_DIR"
    chmod 750 "$COMPONENT_LOG_DIR"

    [[ -d "$COMPONENT_LOG_DIR" ]]
    [[ -O "$COMPONENT_LOG_DIR" ]]
    [[ "$(stat -c '%U:%G' "$COMPONENT_LOG_DIR")" == "root:root" ]]
    [[ "$(stat -c '%a' "$COMPONENT_LOG_DIR")" == "750" ]]
}

initialize_helper_log() {
    if [[ ! -e "$HELPER_LOG" ]]; then
        if ! install \
            -o root \
            -g root \
            -m 640 \
            /dev/null \
            "$HELPER_LOG"
        then
            emit_result "$RESULT_UNEXPECTED_FAILURE"
            return "$EXIT_UNEXPECTED_FAILURE"
        fi
    fi

    if [[ ! -f "$HELPER_LOG" ]]; then
        emit_result "$RESULT_UNEXPECTED_FAILURE"
        return "$EXIT_UNEXPECTED_FAILURE"
    fi

    if ! chown root:root "$HELPER_LOG"; then
        emit_result "$RESULT_UNEXPECTED_FAILURE"
        return "$EXIT_UNEXPECTED_FAILURE"
    fi

    if ! chmod 640 "$HELPER_LOG"; then
        emit_result "$RESULT_UNEXPECTED_FAILURE"
        return "$EXIT_UNEXPECTED_FAILURE"
    fi

    if [[ "$(stat -c '%U:%G' "$HELPER_LOG")" != "root:root" ]]; then
        emit_result "$RESULT_UNEXPECTED_FAILURE"
        return "$EXIT_UNEXPECTED_FAILURE"
    fi

    if [[ "$(stat -c '%a' "$HELPER_LOG")" != "640" ]]; then
        emit_result "$RESULT_UNEXPECTED_FAILURE"
        return "$EXIT_UNEXPECTED_FAILURE"
    fi

    return 0
}

write_audit_log() {
    local event_name="$1"
    local result_name="$2"
    local exit_code="$3"
    local quarantine_path="${4:--}"
    local timestamp_utc

    timestamp_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    if ! printf \
        'timestamp_utc=%s operation_id=%s artifact=%s event=%s result=%s exit_code=%s quarantine_path=%s\n' \
        "$timestamp_utc" \
        "${OPERATION_ID:--}" \
        "${ARTIFACT_NAME:--}" \
        "$event_name" \
        "$result_name" \
        "$exit_code" \
        "$quarantine_path" \
        >> "$HELPER_LOG"
    then
        emit_result "$RESULT_UNEXPECTED_FAILURE"
        return "$EXIT_UNEXPECTED_FAILURE"
    fi

    return 0
}

write_terminal_failure_log() {
    local result_name="$1"
    local exit_code="$2"
    local quarantine_path="${3:--}"

    if [[ ! -f "$HELPER_LOG" ]]; then
        return 0
    fi

    write_audit_log \
        "HELPER_FAILED" \
        "$result_name" \
        "$exit_code" \
        "$quarantine_path" \
        >/dev/null 2>&1 \
        || true

    return 0
}

emit_result() {
    local result_name="$1"

    printf 'QUARANTINE_RESULT=%s\n' "$result_name"
}

parse_arguments() {
    ARTIFACT_NAME=""
    OPERATION_ID=""

    while (( $# > 0 )); do
        case "$1" in
            --artifact)
                if (( $# < 2 )) || [[ -z "$2" ]]; then
                    emit_result "$RESULT_INVALID_ARGUMENT"
                    return "$EXIT_INVALID_ARGUMENT"
                fi

                if [[ -n "$ARTIFACT_NAME" ]]; then
                    emit_result "$RESULT_INVALID_ARGUMENT"
                    return "$EXIT_INVALID_ARGUMENT"
                fi

                ARTIFACT_NAME="$2"
                shift 2
                ;;

            --operation-id)
                if (( $# < 2 )) || [[ -z "$2" ]]; then
                    emit_result "$RESULT_INVALID_ARGUMENT"
                    return "$EXIT_INVALID_ARGUMENT"
                fi

                if [[ -n "$OPERATION_ID" ]]; then
                    emit_result "$RESULT_INVALID_ARGUMENT"
                    return "$EXIT_INVALID_ARGUMENT"
                fi

                OPERATION_ID="$2"
                shift 2
                ;;

            *)
                emit_result "$RESULT_INVALID_ARGUMENT"
                return "$EXIT_INVALID_ARGUMENT"
                ;;
        esac
    done

    if [[ -z "$ARTIFACT_NAME" || -z "$OPERATION_ID" ]]; then
        emit_result "$RESULT_INVALID_ARGUMENT"
        return "$EXIT_INVALID_ARGUMENT"
    fi

    return 0
}

validate_artifact_name() {
    if [[ ! "$ARTIFACT_NAME" =~ $ARTIFACT_NAME_PATTERN ]]; then
        emit_result "$RESULT_INVALID_ARGUMENT"
        return "$EXIT_INVALID_ARGUMENT"
    fi

    case "${ARTIFACT_NAME,,}" in
        "${MANIFEST_NAME,,}"|"${README_NAME,,}")
            emit_result "$RESULT_PROTECTED_FILE_REJECTED"
            return "$EXIT_PROTECTED_FILE_REJECTED"
            ;;
    esac

    case "${ARTIFACT_NAME%%.*}" in
        [Cc][Oo][Nn]|[Pp][Rr][Nn]|[Aa][Uu][Xx]|[Nn][Uu][Ll])
            emit_result "$RESULT_INVALID_ARGUMENT"
            return "$EXIT_INVALID_ARGUMENT"
            ;;

        [Cc][Oo][Mm][1-9]|[Ll][Pp][Tt][1-9])
            emit_result "$RESULT_INVALID_ARGUMENT"
            return "$EXIT_INVALID_ARGUMENT"
            ;;
    esac

    return 0
}

validate_operation_id() {
    if [[ ! "$OPERATION_ID" =~ $OPERATION_ID_PATTERN ]]; then
        emit_result "$RESULT_INVALID_ARGUMENT"
        return "$EXIT_INVALID_ARGUMENT"
    fi

    return 0
}

construct_paths() {
    local expected_source_parent
    local actual_source_parent
    local expected_quarantine_parent
    local actual_quarantine_parent
    local actual_snapshot_parent
    local actual_quarantined_artifact_parent
    local actual_receipt_parent

    SOURCE_PATH="$(realpath -m -- \
        "${PUBLICATION_DIR}/${ARTIFACT_NAME}")"

    MANIFEST_PATH="$(realpath -m -- \
        "${PUBLICATION_DIR}/${MANIFEST_NAME}")"

    QUARANTINE_DIR="$(realpath -m -- \
        "${QUARANTINE_ROOT}/${OPERATION_ID}_${ARTIFACT_NAME}")"

    MANIFEST_SNAPSHOT_PATH="$(realpath -m -- \
        "${QUARANTINE_DIR}/${MANIFEST_SNAPSHOT_NAME}")"

    QUARANTINED_ARTIFACT_PATH="$(realpath -m -- \
    "${QUARANTINE_DIR}/${ARTIFACT_NAME}")"

    QUARANTINE_RECEIPT_PATH="$(realpath -m -- \
    "${QUARANTINE_DIR}/${QUARANTINE_RECEIPT_NAME}")"

    expected_source_parent="$(realpath -m -- "$PUBLICATION_DIR")"
    actual_source_parent="$(dirname -- "$SOURCE_PATH")"

    expected_quarantine_parent="$(realpath -m -- "$QUARANTINE_ROOT")"
    actual_quarantine_parent="$(dirname -- "$QUARANTINE_DIR")"

    actual_snapshot_parent="$(dirname -- "$MANIFEST_SNAPSHOT_PATH")"

    actual_quarantined_artifact_parent="$(dirname -- "$QUARANTINED_ARTIFACT_PATH")"

    actual_receipt_parent="$(dirname -- "$QUARANTINE_RECEIPT_PATH")"

    if [[ "$actual_source_parent" != "$expected_source_parent" ]]; then
        emit_result "$RESULT_INVALID_ARGUMENT"
        return "$EXIT_INVALID_ARGUMENT"
    fi

    if [[ "$MANIFEST_PATH" != "${expected_source_parent}/${MANIFEST_NAME}" ]]; then
        emit_result "$RESULT_INVALID_ARGUMENT"
        return "$EXIT_INVALID_ARGUMENT"
    fi

    if [[ "$actual_quarantine_parent" != "$expected_quarantine_parent" ]]; then
        emit_result "$RESULT_INVALID_ARGUMENT"
        return "$EXIT_INVALID_ARGUMENT"
    fi

    if [[ "$actual_snapshot_parent" != "$QUARANTINE_DIR" ]]; then
        emit_result "$RESULT_INVALID_ARGUMENT"
        return "$EXIT_INVALID_ARGUMENT"
    fi

    if [[ "$actual_quarantined_artifact_parent" != "$QUARANTINE_DIR" ]]; then
      emit_result "$RESULT_INVALID_ARGUMENT"
      return "$EXIT_INVALID_ARGUMENT"
    fi

    if [[ "$actual_receipt_parent" != "$QUARANTINE_DIR" ]]; then
    emit_result "$RESULT_INVALID_ARGUMENT"
    return "$EXIT_INVALID_ARGUMENT"
fi

    return 0
}

validate_repository_preconditions() {
    if [[ ! -f "$SOURCE_PATH" ]]; then
        emit_result "$RESULT_ARTIFACT_NOT_FOUND"
        return "$EXIT_ARTIFACT_NOT_FOUND"
    fi

    if [[ ! -f "$MANIFEST_PATH" ]]; then
        emit_result "$RESULT_MANIFEST_NOT_FOUND"
        return "$EXIT_MANIFEST_NOT_FOUND"
    fi

    if [[ -e "$QUARANTINE_DIR" ]]; then
        emit_result "$RESULT_QUARANTINE_ALREADY_EXISTS"
        return "$EXIT_QUARANTINE_ALREADY_EXISTS"
    fi

    return 0
}

create_quarantine_directory() {
    if ! install -d \
        -o root \
        -g root \
        -m 750 \
        "$QUARANTINE_DIR"
    then
        emit_result "$RESULT_QUARANTINE_DIRECTORY_FAILED"
        return "$EXIT_QUARANTINE_DIRECTORY_FAILED"
    fi

    if [[ ! -d "$QUARANTINE_DIR" ]]; then
        emit_result "$RESULT_QUARANTINE_DIRECTORY_FAILED"
        return "$EXIT_QUARANTINE_DIRECTORY_FAILED"
    fi

    if [[ "$(stat -c '%U:%G' "$QUARANTINE_DIR")" != "root:root" ]]; then
        emit_result "$RESULT_QUARANTINE_DIRECTORY_FAILED"
        return "$EXIT_QUARANTINE_DIRECTORY_FAILED"
    fi

    if [[ "$(stat -c '%a' "$QUARANTINE_DIR")" != "750" ]]; then
        emit_result "$RESULT_QUARANTINE_DIRECTORY_FAILED"
        return "$EXIT_QUARANTINE_DIRECTORY_FAILED"
    fi

    return 0
}

snapshot_manifest() {
    local source_hash_before
    local source_hash_after
    local snapshot_hash

    source_hash_before="$(sha256sum -- "$MANIFEST_PATH" | awk '{print $1}')"

    if ! cp --preserve=mode,timestamps \
        -- \
        "$MANIFEST_PATH" \
        "$MANIFEST_SNAPSHOT_PATH"
    then
        emit_result "$RESULT_MANIFEST_SNAPSHOT_FAILED"
        return "$EXIT_MANIFEST_SNAPSHOT_FAILED"
    fi

    if [[ ! -f "$MANIFEST_SNAPSHOT_PATH" ]]; then
        emit_result "$RESULT_MANIFEST_SNAPSHOT_FAILED"
        return "$EXIT_MANIFEST_SNAPSHOT_FAILED"
    fi

    chown root:root "$MANIFEST_SNAPSHOT_PATH"
    chmod 640 "$MANIFEST_SNAPSHOT_PATH"

    source_hash_after="$(sha256sum -- "$MANIFEST_PATH" | awk '{print $1}')"
    snapshot_hash="$(sha256sum -- "$MANIFEST_SNAPSHOT_PATH" | awk '{print $1}')"

    if [[ "$source_hash_before" != "$source_hash_after" ]]; then
        emit_result "$RESULT_MANIFEST_SNAPSHOT_FAILED"
        return "$EXIT_MANIFEST_SNAPSHOT_FAILED"
    fi

    if [[ "$source_hash_before" != "$snapshot_hash" ]]; then
        emit_result "$RESULT_MANIFEST_SNAPSHOT_FAILED"
        return "$EXIT_MANIFEST_SNAPSHOT_FAILED"
    fi

    if [[ "$(stat -c '%U:%G' "$MANIFEST_SNAPSHOT_PATH")" != "root:root" ]]; then
        emit_result "$RESULT_MANIFEST_SNAPSHOT_FAILED"
        return "$EXIT_MANIFEST_SNAPSHOT_FAILED"
    fi

    if [[ "$(stat -c '%a' "$MANIFEST_SNAPSHOT_PATH")" != "640" ]]; then
        emit_result "$RESULT_MANIFEST_SNAPSHOT_FAILED"
        return "$EXIT_MANIFEST_SNAPSHOT_FAILED"
    fi

    return 0
}

move_artifact_to_quarantine() {
    if ! mv -- \
        "$SOURCE_PATH" \
        "$QUARANTINED_ARTIFACT_PATH"
    then
        emit_result "$RESULT_ARTIFACT_MOVE_FAILED"
        return "$EXIT_ARTIFACT_MOVE_FAILED"
    fi

    if ! chown root:root "$QUARANTINED_ARTIFACT_PATH"; then
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if ! chmod 640 "$QUARANTINED_ARTIFACT_PATH"; then
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if [[ ! -f "$QUARANTINED_ARTIFACT_PATH" ]]; then
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if [[ -e "$SOURCE_PATH" ]]; then
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if [[ "$(stat -c '%U:%G' "$QUARANTINED_ARTIFACT_PATH")" != "root:root" ]]; then
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if [[ "$(stat -c '%a' "$QUARANTINED_ARTIFACT_PATH")" != "640" ]]; then
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    return 0
}

create_quarantine_receipt() {
    local timestamp_utc
    local temporary_receipt_path

    timestamp_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    temporary_receipt_path="${QUARANTINE_RECEIPT_PATH}.tmp"

    if ! printf '%s\n' \
        '{' \
        "  \"operation_id\": \"${OPERATION_ID}\"," \
        "  \"artifact_name\": \"${ARTIFACT_NAME}\"," \
        "  \"source_path\": \"${SOURCE_PATH}\"," \
        "  \"quarantine_path\": \"${QUARANTINE_DIR}\"," \
        "  \"manifest_snapshot\": \"${MANIFEST_SNAPSHOT_NAME}\"," \
        '  "result": "QUARANTINE_SUCCESS",' \
        '  "exit_code": 0,' \
        "  \"timestamp_utc\": \"${timestamp_utc}\"" \
        '}' \
        > "$temporary_receipt_path"
    then
        rm -f -- "$temporary_receipt_path"
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if ! chown root:root "$temporary_receipt_path"; then
        rm -f -- "$temporary_receipt_path"
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if ! chmod 640 "$temporary_receipt_path"; then
        rm -f -- "$temporary_receipt_path"
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if ! mv -- \
        "$temporary_receipt_path" \
        "$QUARANTINE_RECEIPT_PATH"
    then
        rm -f -- "$temporary_receipt_path"
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if [[ ! -f "$QUARANTINE_RECEIPT_PATH" ]]; then
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if [[ "$(stat -c '%U:%G' "$QUARANTINE_RECEIPT_PATH")" != "root:root" ]]; then
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if [[ "$(stat -c '%a' "$QUARANTINE_RECEIPT_PATH")" != "640" ]]; then
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    if ! python3 -m json.tool \
        "$QUARANTINE_RECEIPT_PATH" \
        >/dev/null
    then
        emit_result "$RESULT_QUARANTINE_CONFIRMATION_FAILED"
        return "$EXIT_QUARANTINE_CONFIRMATION_FAILED"
    fi

    return 0
}

validate_effective_privileges() {
    if (( EUID != 0 )); then
        emit_result "$RESULT_INSUFFICIENT_PRIVILEGES"
        return "$EXIT_INSUFFICIENT_PRIVILEGES"
    fi

    return 0
}

main() {
    local result

    if validate_effective_privileges; then
        :
    else
        result=$?
        return "$result"
    fi

    if initialize_component_runtime; then
        :
    else
        result=$?
        return "$result"
    fi

    if initialize_helper_log; then
        :
    else
        result=$?
        return "$result"
    fi

    if parse_arguments "$@"; then
        :
    else
        result=$?
        write_terminal_failure_log \
            "$RESULT_INVALID_ARGUMENT" \
            "$result"
        return "$result"
    fi

    if validate_artifact_name; then
        :
    else
        result=$?

        if (( result == EXIT_PROTECTED_FILE_REJECTED )); then
            write_terminal_failure_log \
                "$RESULT_PROTECTED_FILE_REJECTED" \
                "$result"
        else
            write_terminal_failure_log \
                "$RESULT_INVALID_ARGUMENT" \
                "$result"
        fi

        return "$result"
    fi

    if validate_operation_id; then
        :
    else
        result=$?
        write_terminal_failure_log \
            "$RESULT_INVALID_ARGUMENT" \
            "$result"
        return "$result"
    fi

    if construct_paths; then
        :
    else
        result=$?
        write_terminal_failure_log \
            "$RESULT_INVALID_ARGUMENT" \
            "$result"
        return "$result"
    fi

    if write_audit_log \
        "HELPER_INVOKED" \
        "PENDING" \
        "-" \
        "-"
    then
        :
    else
        result=$?
        return "$result"
    fi

    if validate_repository_preconditions; then
        :
    else
        result=$?

        case "$result" in
            "$EXIT_ARTIFACT_NOT_FOUND")
                write_terminal_failure_log \
                    "$RESULT_ARTIFACT_NOT_FOUND" \
                    "$result"
                ;;

            "$EXIT_MANIFEST_NOT_FOUND")
                write_terminal_failure_log \
                    "$RESULT_MANIFEST_NOT_FOUND" \
                    "$result"
                ;;

            "$EXIT_QUARANTINE_ALREADY_EXISTS")
                write_terminal_failure_log \
                    "$RESULT_QUARANTINE_ALREADY_EXISTS" \
                    "$result" \
                    "$QUARANTINE_DIR"
                ;;

            *)
                write_terminal_failure_log \
                    "$RESULT_UNEXPECTED_FAILURE" \
                    "$result"
                ;;
        esac

        return "$result"
    fi

    if create_quarantine_directory; then
        :
    else
        result=$?
        write_terminal_failure_log \
            "$RESULT_QUARANTINE_DIRECTORY_FAILED" \
            "$result" \
            "$QUARANTINE_DIR"
        return "$result"
    fi

    if snapshot_manifest; then
        :
    else
        result=$?
        write_terminal_failure_log \
            "$RESULT_MANIFEST_SNAPSHOT_FAILED" \
            "$result" \
            "$QUARANTINE_DIR"
        return "$result"
    fi

    if move_artifact_to_quarantine; then
        :
    else
        result=$?

        if (( result == EXIT_ARTIFACT_MOVE_FAILED )); then
            write_terminal_failure_log \
                "$RESULT_ARTIFACT_MOVE_FAILED" \
                "$result" \
                "$QUARANTINE_DIR"
        else
            write_terminal_failure_log \
                "$RESULT_QUARANTINE_CONFIRMATION_FAILED" \
                "$result" \
                "$QUARANTINE_DIR"
        fi

        return "$result"
    fi

    if create_quarantine_receipt; then
        :
    else
        result=$?
        write_terminal_failure_log \
            "$RESULT_QUARANTINE_CONFIRMATION_FAILED" \
            "$result" \
            "$QUARANTINE_DIR"
        return "$result"
    fi

    if write_audit_log \
        "ARTIFACT_QUARANTINED" \
        "$RESULT_QUARANTINE_SUCCESS" \
        "$EXIT_QUARANTINE_SUCCESS" \
        "$QUARANTINE_DIR"
    then
        :
    else
        result=$?
        return "$result"
    fi

    emit_result "$RESULT_QUARANTINE_SUCCESS"

    return "$EXIT_QUARANTINE_SUCCESS"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
