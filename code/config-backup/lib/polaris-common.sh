#!/usr/bin/env bash

[[ -n "${POLARIS_COMMON_SH_LOADED:-}" ]] && return 0
readonly POLARIS_COMMON_SH_LOADED=1

###############################################################################
# Defensive PATH
#
# Cron, SSH-invoked commands (as Ansible/n8n will use going forward), and
# other non-interactive execution contexts often inherit a minimal PATH that
# omits directories where Proxmox tooling and other utilities live, even
# though the same command works fine from an interactive shell. Setting an
# explicit, broad PATH here - the first thing every Project Polaris script
# does, since every script sources this file first - removes this whole
# class of "works when run by hand, fails when automated" failure regardless
# of how the framework is invoked. Existing PATH is preserved and appended
# rather than overwritten, in case something legitimate depends on it.
###############################################################################
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

###########################################################################################################################
# Purpose:
#
# Provides reusable framework services shared throughout the Project Polaris
# configuration backup system. This library centralizes common functionality to
# promote consistency, reduce duplication, and simplify long-term maintenance.
#
# Description:
#
# This file contains reusable functions, shared configuration defaults, and
# common utilities used by collectors and orchestrators within the Project
# Polaris configuration backup framework. The library defines functionality but
# performs no operational work when sourced.
#
# Execution:
#
# This file is intended to be sourced by other Project Polaris scripts.
# It is not intended to be executed directly.
#
# Dependencies:
#
# - Bash
# - Project Polaris directory structure
#
#Public API
#
#Configuration
#-------------
#POLARIS_PROJECT_ROOT
#POLARIS_CONFIG_BACKUP_ROOT
#POLARIS_CONFIG_DIR
#POLARIS_LOG_DIR
#POLARIS_TEMP_DIR
#POLARIS_DOCS_DIR
#
#Validation
#----------
#command_exists()
#directory_exists()
#file_exists()
#path_is_writable()
#is_root_user()
#
#Operator
#--------
#operator_info()
#operator_success()
#operator_warning()
#operator_error()
#
#Logging
#-------
#log_info()
#log_success()
#log_warning()
#log_error()
#
#File Operations
#---------------
#create_directory()
#safe_copy_directory()
#safe_copy_file()
#safe_move()# Related Documents:
#
# - GOV-002 Configuration Backup Expectations
# - SOP-002 Configuration Backup Framework
# - STD-001 Bash Coding Standards (planned)
#
# Version:
#
# 0.2.0
###############################################################################

# Orchestrator result codes. Shared here (rather than defined per-orchestrator)
# so bin/polaris-backup, bin/polaris-ai-backup, and any future single-purpose
# orchestrator all agree on the exact same contract - this is what n8n's
# Classification/Tiering logic keys off of, so every orchestrator must return
# these values identically.
readonly POLARIS_BACKUP_SUCCESS=0
readonly POLARIS_BACKUP_FAILED=1
readonly POLARIS_BACKUP_PREREQUISITE_FAILED=2
readonly POLARIS_BACKUP_NAS_FAILED=3
readonly POLARIS_BACKUP_INTERNAL_ERROR=4
readonly POLARIS_BACKUP_LOCKED=5

###############################################################################
# Framework Configuration
###############################################################################

readonly POLARIS_PROJECT_ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P
)"

# Root of the configuration-backup framework.
readonly POLARIS_CONFIG_BACKUP_ROOT="${POLARIS_PROJECT_ROOT}"

# Framework configuration.
readonly POLARIS_CONFIG_DIR="${POLARIS_PROJECT_ROOT}/config"

# Framework logs.
readonly POLARIS_LOG_DIR="${POLARIS_CONFIG_BACKUP_ROOT}/logs"

# Temporary working files.
readonly POLARIS_TEMP_DIR="${POLARIS_CONFIG_BACKUP_ROOT}/temp"

# Project documentation.
readonly POLARIS_DOCS_DIR="${POLARIS_PROJECT_ROOT}/docs"

###############################################################################
# Shared Constants
###############################################################################

# Define the current version of the Project Polaris common library.
readonly POLARIS_FRAMEWORK_VERSION="0.2.0"

readonly LEVEL_INFO="INFO"
readonly LEVEL_SUCCESS="SUCCESS"
readonly LEVEL_WARNING="WARNING"
readonly LEVEL_ERROR="ERROR"
readonly POLARIS_FRAMEWORK_LOG="${POLARIS_LOG_DIR}/framework.log"
readonly POLARIS_LOG_MAX_BYTES=5242880
readonly POLARIS_LOG_ROTATION_COUNT=5

POLARIS_ACTIVE_LOG_FILE="${POLARIS_FRAMEWORK_LOG}"

# Name of whichever collector is currently executing, set by the orchestrator
# immediately before invoking a collector and cleared immediately after.
# Empty means the message originates from the orchestrator itself rather than
# a specific collector. Used to tag warning/error output so an automated
# reviewer (or a human skimming the log) always knows which device raised it.
POLARIS_ACTIVE_COLLECTOR=""

###############################################################################
# Validation Functions
###############################################################################

#------------------------------------------------------------------------------
# Function: command_exists
#
# Purpose:
#   Determine whether a command is available in the current PATH.
#
# Parameters:
#   $1 - Command name.
#
# Returns:
#   0 - Command exists.
#   1 - Command does not exist.
#
# Notes:
#   Uses the Bash builtin 'command' rather than external utilities.
#------------------------------------------------------------------------------
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

#------------------------------------------------------------------------------
# Function: directory_exists
#
# Purpose:
#   Determine whether a directory exists.
#
# Parameters:
#   $1 - Directory path.
#
# Returns:
#   0 - Directory exists.
#   1 - Directory does not exist.
#------------------------------------------------------------------------------
directory_exists() {
    [[ -d "$1" ]]
}

#------------------------------------------------------------------------------
# Function: file_exists
#
# Purpose:
#   Determine whether a file exists.
#
# Parameters:
#   $1 - File path.
#
# Returns:
#   0 - File exists.
#   1 - File does not exist.
#------------------------------------------------------------------------------
file_exists() {
    [[ -f "$1" ]]
}

#------------------------------------------------------------------------------
# Function: path_is_writable
#
# Purpose:
#   Determine whether a path is writable.
#
# Parameters:
#   $1 - File or directory path.
#
# Returns:
#   0 - Path is writable.
#   1 - Path is not writable.
#------------------------------------------------------------------------------
path_is_writable() {
    [[ -w "$1" ]]
}

#------------------------------------------------------------------------------
# Function: is_root_user
#
# Purpose:
#   Determine whether the framework is running as the root user.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Current user is root.
#   1 - Current user is not root.
#
# Notes:
#   Uses the Bash-native EUID variable rather than an external utility.
#------------------------------------------------------------------------------
is_root_user() {
    [[ ${EUID} -eq 0 ]]
}

###############################################################################
# Console Output Contract
#
# operator_* functions write to the active console only.
# log_* functions write to the active log only.
# The former report_* compatibility layer has been removed to eliminate
# ambiguous destinations and duplicate caller behavior.
###############################################################################

###############################################################################
# Operator Services
###############################################################################

#-------------------------------------------------------------------------------
# Function: operator_info
#
# Purpose:
#   Display an informational message intended for the active operator.
#
# Parameters:
#   $1 - Message text.
#
# Returns:
#   0 - Message successfully written.
#-------------------------------------------------------------------------------

operator_info() {
    printf '[%s] %s\n' "${LEVEL_INFO}" "$1"
}

#-------------------------------------------------------------------------------
# Function: operator_success
#
# Purpose:
#   Display a success message intended for the active operator.
#
# Parameters:
#   $1 - Message text.
#
# Returns:
#   0 - Message successfully written.
#-------------------------------------------------------------------------------

operator_success() {
    printf '[%s] %s\n' "${LEVEL_SUCCESS}" "$1"
}

#-------------------------------------------------------------------------------
# Function: operator_warning
#
# Purpose:
#   Display a warning message intended for the active operator.
#
# Parameters:
#   $1 - Message text.
#
# Returns:
#   0 - Message successfully written.
#-------------------------------------------------------------------------------

###############################################################################
# Function: _diagnostic_tag
#
# Purpose:
#   Build the "[collector-name] " prefix used on warning/error output so the
#   origin of every diagnostic message is unambiguous, whether it's read on
#   screen, in the log file, or parsed by automation reviewing the log later.
###############################################################################
_diagnostic_tag() {
    printf '[%s] ' "${POLARIS_ACTIVE_COLLECTOR:-orchestrator}"
}

###############################################################################
# Function: _emit_diagnostic
# Used By: operator_warning | operator_error | log_warning | log_error
# Purpose: Warning and error severities are always written to BOTH the
#   operator screen and the persistent log file, tagged with whichever
#   collector is currently active. Info/success severities intentionally
#   remain split (operator_* for sparse operator-facing narration, log_* for
#   detailed file-only telemetry) since that separation already works as
#   intended and losing an info line is not operationally significant the way
#   losing a warning/error is.
# Impact: Framework-wide diagnostic behavior. Run full regression after
#   modification.
###############################################################################
_emit_diagnostic() {

    local level="$1"
    local message="$2"
    local tagged_message

    tagged_message="$(_diagnostic_tag)${message}"

    printf '[%s] %s\n' "${level}" "${tagged_message}"
    _log "${level}" "${tagged_message}"
}

operator_warning() {
    _emit_diagnostic "${LEVEL_WARNING}" "$1"
}

#-------------------------------------------------------------------------------
# Function: operator_error
#
# Purpose:
#   Display an error message intended for the active operator.
#
# Parameters:
#   $1 - Message text.
#
# Returns:
#   0 - Message successfully written.
#-------------------------------------------------------------------------------

operator_error() {
    _emit_diagnostic "${LEVEL_ERROR}" "$1"
}

###############################################################################
# Logging Services
###############################################################################

###############################################################################
# Shared Helper: _rotate_active_log_if_needed()
# Used By: ALL COLLECTORS | ORCHESTRATOR
# Purpose: Limits any active log file to the configured maximum size.
# Impact: Framework-wide logging change. Run full regression after modification.
###############################################################################
_rotate_active_log_if_needed() {

    local log_file="${1:-}"
    local current_size
    local index

    [[ -n "${log_file}" ]] || return 1
    [[ -f "${log_file}" ]] || return 0

    current_size="$(stat -c '%s' -- "${log_file}" 2>/dev/null)" || return 1

    if (( current_size < POLARIS_LOG_MAX_BYTES )); then
        return 0
    fi

    for (( index=POLARIS_LOG_ROTATION_COUNT; index>=1; index-- )); do
        if [[ -e "${log_file}.${index}" ]]; then
            if (( index == POLARIS_LOG_ROTATION_COUNT )); then
                rm -f -- "${log_file}.${index}" || return 1
            else
                mv -- "${log_file}.${index}" "${log_file}.$(( index + 1 ))" || return 1
            fi
        fi
    done

    mv -- "${log_file}" "${log_file}.1"
}

###############################################################################
# Shared Helper: _log()
# Used By: ALL COLLECTORS | ORCHESTRATOR
# Purpose: Writes one timestamped entry to the active log only.
# Impact: Framework-wide logging change. Run full regression after modification.
###############################################################################
_log() {

    local level="$1"
    local message="$2"
    local log_directory
    local log_timestamp

    if [[ -z "${POLARIS_ACTIVE_LOG_FILE:-}" ]]; then
        POLARIS_ACTIVE_LOG_FILE="${POLARIS_FRAMEWORK_LOG}"
    fi

    log_directory="$(
        dirname -- "${POLARIS_ACTIVE_LOG_FILE}"
    )"

    if ! create_directory "${log_directory}"; then
        printf \
            '[ERROR] Unable to create log directory: %s\n' \
            "${log_directory}" \
            >&2

        return 1
    fi

    if ! _rotate_active_log_if_needed "${POLARIS_ACTIVE_LOG_FILE}"; then
        printf \
            '[ERROR] Unable to rotate active log file: %s\n' \
            "${POLARIS_ACTIVE_LOG_FILE}" \
            >&2

        return 1
    fi

    log_timestamp="$(
        date '+%Y-%m-%d-%H%M%S'
    )"

    printf \
        '[%s] [%s] %s\n' \
        "${log_timestamp}" \
        "${level}" \
        "${message}" \
        >> "${POLARIS_ACTIVE_LOG_FILE}"
}

# Purpose: Write an informational event to the active framework log only.
# This comment documents intent; implementation behavior is unchanged.
log_info() {
    _log "${LEVEL_INFO}" "$1"
}

# Purpose: Write a successful completion event to the active framework log only.
# This comment documents intent; implementation behavior is unchanged.
log_success() {
    _log "${LEVEL_SUCCESS}" "$1"
}

# Purpose: Write a recoverable warning to the active framework log only.
# This comment documents intent; implementation behavior is unchanged.
log_warning() {
    _emit_diagnostic "${LEVEL_WARNING}" "$1"
}

# Purpose: Write a failure event to the active framework log only.
# This comment documents intent; implementation behavior is unchanged.
log_error() {
    _emit_diagnostic "${LEVEL_ERROR}" "$1"
}

###############################################################################
# Framework Utilities
###############################################################################

#------------------------------------------------------------------------------
# Function: generate_timestamp
#
# Purpose:
#   Generate a filesystem-safe timestamp suitable for backup names,
#   manifests, reports, and archives.
#
# Returns:
#   Timestamp formatted as:
#   YYYY-MM-DD_HH-MM-SS
#------------------------------------------------------------------------------
generate_timestamp() {
    date '+%Y-%m-%d-%H%M%S'
}

#------------------------------------------------------------------------------
# Function: create_directory
#
# Purpose:
#   Create a directory if it does not already exist.
#
# Parameters:
#   $1 - Directory path.
#
# Returns:
#   0 - Directory exists or was created successfully.
#   Non-zero - Directory could not be created.
#
# Notes:
#   Uses 'mkdir -p' to avoid errors when the directory already exists.
#------------------------------------------------------------------------------
create_directory() {

    local directory="$1"

    command mkdir -p -- "$directory"

}

#------------------------------------------------------------------------------
# Function: safe_copy
#
# Purpose:
#   Copy a file while preserving attributes.
#
# Parameters:
#   $1 - Source path.
#   $2 - Destination path.
#
# Returns:
#   0 - Copy successful.
#   Non-zero - Copy failed.
#
# Notes:
#   Uses 'cp -a' to preserve file attributes.
#------------------------------------------------------------------------------
safe_copy() {

    local source="$1"
    local destination="$2"

    command cp -a -- "$source" "$destination"

}

###############################################################################
# Function: safe_copy_directory
#
# Purpose:
#   Copy the complete contents of a directory while preserving file
#   attributes, ownership, permissions, timestamps, symbolic links, and
#   directory structure.
#
# Parameters:
#   $1 - Source directory.
#   $2 - Destination directory.
#
# Returns:
#   0 - Directory copy successful.
#   1 - Directory copy failed.
###############################################################################

safe_copy_directory() {

    local source_directory="$1"
    local destination_directory="$2"

    if [[ ! -d "${source_directory}" ]]; then
        operator_error \
            "Source directory does not exist: ${source_directory}"
        return 1
    fi

    create_directory "${destination_directory}" || {
        operator_error \
            "Unable to create destination directory: ${destination_directory}"
        return 1
    }

    command cp -a \
        "${source_directory}/." \
        "${destination_directory}/" || {
            operator_error \
                "Unable to copy directory: ${source_directory}"
            return 1
        }

    return 0
}

###############################################################################
# Function: safe_copy_file
#
# Purpose:
#   Copy a single file while preserving ownership, permissions,
#   timestamps, and symbolic links.
#
# Parameters:
#   $1 - Source file.
#   $2 - Destination file.
#
# Returns:
#   0 - File copy successful.
#   1 - File copy failed.
###############################################################################

safe_copy_file() {

    local source_file="$1"
    local destination_file="$2"
    local destination_directory

    if [[ ! -f "${source_file}" ]]; then
        operator_error \
            "Source file does not exist: ${source_file}"

        return 1
    fi

    destination_directory="$(
        dirname -- "${destination_file}"
    )"

    create_directory "${destination_directory}" || {
        operator_error \
            "Unable to create destination directory: ${destination_directory}"

        return 1
    }

    command cp -a \
        "${source_file}" \
        "${destination_file}" || {

        operator_error \
            "Unable to copy file: ${source_file}"

        return 1
    }

    return 0
}

#------------------------------------------------------------------------------
# Function: safe_move
#
# Purpose:
#   Move or rename a file or directory.
#
# Parameters:
#   $1 - Source path.
#   $2 - Destination path.
#
# Returns:
#   0 - Move successful.
#   Non-zero - Move failed.
#
# Notes:
#   Uses the system 'mv' command and returns its natural exit status.
#------------------------------------------------------------------------------
safe_move() {

    local source="$1"
    local destination="$2"

   command mv -- "$source" "$destination"

}

###############################################################################
# Function: collect_optional_directory
#
# Purpose:
#   Preserve an optional configuration directory. If the source directory does
#   not exist, or exists but contains no entries, create a placeholder artifact
#   documenting its state.
#
# Parameters:
#   $1 - Source directory.
#   $2 - Destination directory.
#   $3 - Human-readable artifact title.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

collect_optional_directory() {

    local source_directory="$1"
    local destination_directory="$2"
    local title="$3"

    create_directory "${destination_directory}" || {
        operator_error \
            "Unable to create optional directory destination: ${destination_directory}"
        return 1
    }

    if [[ ! -d "${source_directory}" ]]; then

        {
            echo "# ${title}"
            echo "# Status: Not present"
            echo "# Source: ${source_directory}"
        } > "${destination_directory}/.placeholder" || {
            operator_error \
                "Unable to write optional directory placeholder: ${destination_directory}"
            return 1
        }

        return 0
    fi

    if [[ -z "$(find "${source_directory}" -mindepth 1 -print -quit 2>/dev/null)" ]]; then

        {
            echo "# ${title}"
            echo "# Status: Present but empty"
            echo "# Source: ${source_directory}"
        } > "${destination_directory}/.placeholder" || {
            operator_error \
                "Unable to write empty-directory placeholder: ${destination_directory}"
            return 1
        }

        return 0
    fi

    rm -f "${destination_directory}/.placeholder" || {
        operator_error \
            "Unable to remove obsolete optional-directory placeholder."
        return 1
    }

    safe_copy_directory \
        "${source_directory}" \
        "${destination_directory}" || {
            operator_error \
                "Unable to copy optional directory: ${source_directory}"
            return 1
        }

    return 0
}

###############################################################################
# SSH Transport Services
###############################################################################

#------------------------------------------------------------------------------
# Function: polaris_ssh_execute
#
# Purpose:
#   Execute one unattended SSH command using a consistent transport primitive.
#   Collector-specific wrappers retain ownership of host identity and messages.
#
# Parameters:
#   $1 - Remote host.
#   $2 - Remote user.
#   $3 - Private key path.
#   $4 - Connect timeout in seconds.
#   $5 - Standard-input mode: "disable" adds ssh -n; "allow" preserves stdin.
#   $6 - Identity mode: "yes" adds IdentitiesOnly=yes; "no" preserves legacy behavior.
#   $7 - Remote command.
#
# Returns:
#   The natural SSH exit status.
#------------------------------------------------------------------------------
polaris_ssh_execute() {
    local remote_host="${1:-}"
    local remote_user="${2:-}"
    local private_key="${3:-}"
    local connect_timeout="${4:-}"
    local stdin_mode="${5:-allow}"
    local identities_only="${6:-no}"
    local remote_command="${7:-}"
    local control_path="${8:-}"
    local -a ssh_arguments=()

    if [[ -z "${remote_host}" ]] ||
       [[ -z "${remote_user}" ]] ||
       [[ -z "${private_key}" ]] ||
       [[ -z "${connect_timeout}" ]] ||
       [[ -z "${remote_command}" ]]
    then
        return 2
    fi

    case "${stdin_mode}" in
        disable)
            ssh_arguments+=( -n )
            ;;
        allow)
            ;;
        *)
            return 2
            ;;
    esac

    ssh_arguments+=(
        -i "${private_key}"
        -o BatchMode=yes
        -o "ConnectTimeout=${connect_timeout}"
    )

    case "${identities_only}" in
        yes)
            ssh_arguments+=( -o IdentitiesOnly=yes )
            ;;
        no)
            ;;
        *)
            return 2
            ;;
    esac

    # An optional control-socket path enables SSH connection multiplexing
    # for collectors that make many sequential calls to the same host.
    # Empty (the default for every existing caller) preserves current
    # behavior exactly - one independent connection per call. ControlMaster
    # =auto, not =yes, makes this fail open: if no shared session is
    # available for any reason, this call simply connects normally instead
    # of erroring.
    if [[ -n "${control_path}" ]]; then
        ssh_arguments+=(
            -o ControlMaster=auto
            -o "ControlPath=${control_path}"
            -o ControlPersist=30
        )
    fi

    command ssh \
        "${ssh_arguments[@]}" \
        "${remote_user}@${remote_host}" \
        "${remote_command}"
}

#------------------------------------------------------------------------------
# Function: polaris_ssh_execute_to_file
#
# Purpose:
#   Execute one SSH command, secure the captured artifact, and optionally reject
#   empty output. Diagnostic text is written to stderr by the shared helper so
#   collector wrappers can retain their existing result-code contract.
#
# Parameters:
#   $1-$6 - Same transport parameters as polaris_ssh_execute().
#   $7    - Remote command.
#   $8    - Local output file.
#   $9    - Empty-output mode: "reject" or "allow".
#   $10   - Human-readable target label used in diagnostics.
#
# Returns:
#   0 - Command completed and artifact validation passed.
#   1 - SSH, permission, or artifact validation failure.
#   2 - Invalid helper parameters.
#------------------------------------------------------------------------------
polaris_ssh_execute_to_file() {
    local remote_host="${1:-}"
    local remote_user="${2:-}"
    local private_key="${3:-}"
    local connect_timeout="${4:-}"
    local stdin_mode="${5:-allow}"
    local identities_only="${6:-no}"
    local remote_command="${7:-}"
    local output_file="${8:-}"
    local empty_mode="${9:-reject}"
    local target_label="${10:-Remote target}"
    local control_path="${11:-}"

    if [[ -z "${output_file}" ]]; then
        return 2
    fi

    if ! polaris_ssh_execute \
        "${remote_host}" \
        "${remote_user}" \
        "${private_key}" \
        "${connect_timeout}" \
        "${stdin_mode}" \
        "${identities_only}" \
        "${remote_command}" \
        "${control_path}" \
        > "${output_file}" 2>&1
    then
        return 1
    fi

    if ! chmod 600 "${output_file}"; then
        return 1
    fi

    case "${empty_mode}" in
        reject)
            if [[ ! -s "${output_file}" ]]; then
                return 1
            fi
            ;;
        allow)
            ;;
        *)
            return 2
            ;;
    esac

    return 0
}

#------------------------------------------------------------------------------
# Function: polaris_ssh_open_control_master
#
# Purpose:
#   Establish a background SSH multiplexing session that subsequent
#   polaris_ssh_execute()/polaris_ssh_execute_to_file() calls can share via
#   a matching control-socket path, avoiding a fresh handshake for every
#   individual remote command. Intended for collectors that make many
#   sequential calls to the same host in one run.
#
# Parameters:
#   $1 - Remote host.
#   $2 - Remote user.
#   $3 - Private key path.
#   $4 - Connect timeout in seconds.
#   $5 - Control-socket path.
#
# Returns:
#   0 - Master session established.
#   1 - Unable to establish the master session.
#   2 - Invalid helper parameters.
#
# Notes:
#   Failure here is never fatal to a caller - polaris_ssh_execute() and
#   polaris_ssh_execute_to_file() use ControlMaster=auto, which falls back
#   to an ordinary, independent connection when no master session is
#   available. Treat this function as a best-effort optimization, not a
#   prerequisite.
#------------------------------------------------------------------------------
polaris_ssh_open_control_master() {
    local remote_host="${1:-}"
    local remote_user="${2:-}"
    local private_key="${3:-}"
    local connect_timeout="${4:-}"
    local control_path="${5:-}"

    if [[ -z "${remote_host}" ]] ||
       [[ -z "${remote_user}" ]] ||
       [[ -z "${private_key}" ]] ||
       [[ -z "${connect_timeout}" ]] ||
       [[ -z "${control_path}" ]]
    then
        return 2
    fi

    command ssh \
        -i "${private_key}" \
        -o BatchMode=yes \
        -o "ConnectTimeout=${connect_timeout}" \
        -o ControlMaster=auto \
        -o "ControlPath=${control_path}" \
        -o ControlPersist=30 \
        -M \
        -N \
        -f \
        "${remote_user}@${remote_host}"
}

#------------------------------------------------------------------------------
# Function: polaris_ssh_close_control_master
#
# Purpose:
#   Explicitly close a background SSH multiplexing session opened by
#   polaris_ssh_open_control_master(), rather than waiting on its
#   ControlPersist expiry.
#
# Parameters:
#   $1 - Remote host.
#   $2 - Remote user.
#   $3 - Control-socket path.
#
# Returns:
#   Always 0. This is always best-effort - ControlPersist is the real
#   safety net regardless of whether this explicit close succeeds.
#------------------------------------------------------------------------------
polaris_ssh_close_control_master() {
    local remote_host="${1:-}"
    local remote_user="${2:-}"
    local control_path="${3:-}"

    if [[ -z "${remote_host}" ]] ||
       [[ -z "${remote_user}" ]] ||
       [[ -z "${control_path}" ]]
    then
        return 0
    fi

    command ssh \
        -o "ControlPath=${control_path}" \
        -O exit \
        "${remote_user}@${remote_host}" \
        >/dev/null 2>&1

    return 0
}

###############################################################################
# Shared Helper: polaris_manifest_recursive
#
# Used By:
#   - Admin01
#   - Admin-WS
#   - Docker01
#
# Purpose:
#   Create the standard tab-delimited Project Polaris manifest by recursively
#   inventorying every permanent file below a collector staging root, excluding
#   the manifest itself.
#
# Dependencies:
#   find, sort, stat, sha256sum, awk, chmod
###############################################################################
# Purpose: Own the polaris manifest recursive step of the collector lifecycle.
# This comment documents intent; implementation behavior is unchanged.
polaris_manifest_recursive() {
    local staging_root="${1:-}"
    local output_file="${2:-}"
    local collector_label="${3:-Collector}"
    local absolute_path=""
    local relative_path=""
    local file_size=""
    local file_hash=""
    local artifact_count=0

    if [[ -z "${staging_root}" || -z "${output_file}" ]]; then
        return 2
    fi

    if [[ ! -d "${staging_root}" ]]; then
        operator_error "${collector_label} staging root does not exist."
        return 1
    fi

    if ! printf '%s\t%s\t%s\n' \
        "Relative Path" \
        "Size" \
        "SHA256" \
        > "${output_file}"
    then
        operator_error "Unable to initialize the ${collector_label} manifest."
        return 1
    fi

    while IFS= read -r -d '' absolute_path; do
        relative_path="${absolute_path#${staging_root}/}"
        [[ "${absolute_path}" == "${output_file}" ]] && continue

        if [[ ! -r "${absolute_path}" || ! -s "${absolute_path}" ]]; then
            operator_error "Invalid ${collector_label} artifact: ${relative_path}"
            return 1
        fi

        if ! file_size="$(stat --format='%s' "${absolute_path}")"; then
            operator_error "Unable to determine the size of ${collector_label} artifact: ${relative_path}"
            return 1
        fi

        if [[ ! "${file_size}" =~ ^[0-9]+$ ]]; then
            operator_error "Invalid file size generated for ${collector_label} artifact: ${relative_path}"
            return 1
        fi

        if ! file_hash="$(sha256sum -- "${absolute_path}" | awk '{ print $1 }')"; then
            operator_error "Unable to calculate the SHA-256 hash of ${collector_label} artifact: ${relative_path}"
            return 1
        fi

        if [[ ! "${file_hash}" =~ ^[[:xdigit:]]{64}$ ]]; then
            operator_error "Invalid SHA-256 hash generated for ${collector_label} artifact: ${relative_path}"
            return 1
        fi

        if ! printf '%s\t%s\t%s\n' \
            "${relative_path}" \
            "${file_size}" \
            "${file_hash}" \
            >> "${output_file}"
        then
            operator_error "Unable to write ${collector_label} manifest entry: ${relative_path}"
            return 1
        fi

        ((++artifact_count))
    done < <(
        find "${staging_root}" \
            -type f \
            -print0 |
            sort -z
    )

    if (( artifact_count == 0 )); then
        operator_error "${collector_label} manifest contains no artifacts."
        return 1
    fi

    if ! printf '#\n# Artifact Count: %d\n' \
        "${artifact_count}" \
        >> "${output_file}"
    then
        operator_error "Unable to finalize the ${collector_label} manifest."
        return 1
    fi

    if ! chmod 600 "${output_file}" || [[ ! -s "${output_file}" ]]; then
        operator_error "Unable to secure the ${collector_label} manifest."
        return 1
    fi

    return 0
}

###############################################################################
# Shared Helper: polaris_manifest_required_files
#
# Used By:
#   - pfSense
#   - OPNsense
#   - Switch01
#   - NANO-AP
#   - NANO-STATION
#
# Purpose:
#   Create the standard tab-delimited Project Polaris manifest from an explicit
#   ordered list of required collector artifacts.
#
# Dependencies:
#   stat, sha256sum, awk, chmod
###############################################################################
# Purpose: Own the polaris manifest required files step of the collector lifecycle.
# This comment documents intent; implementation behavior is unchanged.
polaris_manifest_required_files() {
    local staging_root="${1:-}"
    local output_file="${2:-}"
    local collector_label="${3:-Collector}"
    shift 3 || return 2

    local relative_path=""
    local absolute_path=""
    local file_size=""
    local file_hash=""
    local artifact_count=0

    if [[ -z "${staging_root}" || -z "${output_file}" || "$#" -eq 0 ]]; then
        return 2
    fi

    if ! printf '%s\t%s\t%s\n' \
        "Relative Path" \
        "Size" \
        "SHA256" \
        > "${output_file}"
    then
        operator_error "Unable to initialize the ${collector_label} manifest."
        return 1
    fi

    for relative_path in "$@"; do
        absolute_path="${staging_root}/${relative_path}"

        if [[ ! -f "${absolute_path}" ]]; then
            operator_error "Unable to generate the ${collector_label} manifest. Required file is missing: ${relative_path}"
            return 1
        fi

        if [[ ! -r "${absolute_path}" ]]; then
            operator_error "Unable to generate the ${collector_label} manifest. Required file is unreadable: ${relative_path}"
            return 1
        fi

        if [[ ! -s "${absolute_path}" ]]; then
            operator_error "Unable to generate the ${collector_label} manifest. Required file is empty: ${relative_path}"
            return 1
        fi

        if ! file_size="$(stat --format='%s' "${absolute_path}")"; then
            operator_error "Unable to determine the size of ${collector_label} artifact: ${relative_path}"
            return 1
        fi

        if [[ ! "${file_size}" =~ ^[0-9]+$ ]]; then
            operator_error "Invalid file size generated for ${collector_label} artifact: ${relative_path}"
            return 1
        fi

        if ! file_hash="$(sha256sum -- "${absolute_path}" | awk '{ print $1 }')"; then
            operator_error "Unable to calculate the SHA-256 hash of ${collector_label} artifact: ${relative_path}"
            return 1
        fi

        if [[ ! "${file_hash}" =~ ^[[:xdigit:]]{64}$ ]]; then
            operator_error "Invalid SHA-256 hash generated for ${collector_label} artifact: ${relative_path}"
            return 1
        fi

        if ! printf '%s\t%s\t%s\n' \
            "${relative_path}" \
            "${file_size}" \
            "${file_hash}" \
            >> "${output_file}"
        then
            operator_error "Unable to write ${collector_label} manifest entry: ${relative_path}"
            return 1
        fi

        ((++artifact_count))
    done

    if (( artifact_count == 0 )); then
        operator_error "${collector_label} manifest contains no artifacts."
        return 1
    fi

    if ! printf '#\n# Artifact Count: %d\n' \
        "${artifact_count}" \
        >> "${output_file}"
    then
        operator_error "Unable to finalize the ${collector_label} manifest."
        return 1
    fi

    if ! chmod 600 "${output_file}" || [[ ! -s "${output_file}" ]]; then
        operator_error "Unable to secure the ${collector_label} manifest."
        return 1
    fi

    return 0
}



###############################################################################
# Shared Helper: polaris_prepare_staging_directories()
# Used By: Admin01 | Admin-WS | Docker01
# Purpose: Validate and create collector staging directories securely.
# Impact: Changes affect listed collectors. Validate all before release.
###############################################################################
polaris_prepare_staging_directories() {
    local staging_root="${1:-}"
    local collector_label="${2:-Collector}"
    shift 2 || return 2

    if [[ -z "${staging_root}" || "$#" -eq 0 ]]; then
        operator_error "${collector_label} staging parameters were not provided."
        return 1
    fi

    if [[ -e "${staging_root}" ]]; then
        operator_error "${collector_label} staging root already exists: ${staging_root}"
        return 1
    fi

    if ! install -d -m 700 "$@"; then
        operator_error "Unable to create ${collector_label} staging directories."
        return 1
    fi

    return 0
}

###############################################################################
# Shared Helper: polaris_remove_staging_root()
# Used By: Admin01 | Admin-WS | Docker01
# Purpose: Remove failed collector staging without touching validated output.
# Impact: Changes affect listed collectors. Validate all before release.
###############################################################################
polaris_remove_staging_root() {
    local staging_root="${1:-}"
    local collector_label="${2:-Collector}"

    [[ -n "${staging_root}" ]] || return 0

    if [[ -e "${staging_root}" ]] && ! rm -rf -- "${staging_root}"; then
        operator_error "Unable to remove the ${collector_label} staging directory."
        return 1
    fi

    return 0
}

###############################################################################
# Shared Helper: polaris_preserve_failure_staging()
# Used By: Admin01 | Admin-WS | Docker01
# Purpose: Preserve partial staging and write a standard failure summary.
# Impact: Changes affect listed collectors. Validate intentional failures.
###############################################################################
polaris_preserve_failure_staging() {
    local troubleshooting_root="${1:-}"
    local directory_prefix="${2:-collector}"
    local collector_label="${3:-Collector}"
    local collector_version="${4:-unknown}"
    local collection_status="${5:-unavailable}"
    local failure_reason="${6:-unspecified failure}"
    local staging_root="${7:-}"
    shift 7 || return 2

    local failure_timestamp=""
    local failure_directory=""
    local staging_status="missing"
    local preservation_failed=0
    local extra_line=""

    [[ -n "${troubleshooting_root}" ]] || return 1
    failure_timestamp="$(date -u '+%Y%m%d-%H%M%S')" || return 1
    failure_directory="${troubleshooting_root}/${directory_prefix}-failure-${failure_timestamp}-$$"
    install -d -m 700 "${failure_directory}" || return 1

    if [[ -n "${staging_root}" && -d "${staging_root}" ]]; then
        staging_status="present"
        if cp -a -- "${staging_root}" "${failure_directory}/staging"; then
            staging_status="preserved"
        else
            staging_status="preservation failed"
            preservation_failed=1
        fi
    fi

    {
        printf 'Project Polaris %s Collector Failure Summary\n' "${collector_label}"
        printf '%*s\n\n' "$((34 + ${#collector_label}))" '' | tr ' ' '='
        printf 'Failure Timestamp (UTC): %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf 'Failure Reason: %s\n' "${failure_reason}"
        printf 'Collector Version: %s\n' "${collector_version}"
        for extra_line in "$@"; do printf '%s\n' "${extra_line}"; done
        printf 'Collection Status: %s\n' "${collection_status}"
        printf 'Partial Staging Directory: %s\n' "${staging_status}"
    } > "${failure_directory}/failure-summary.txt" || preservation_failed=1

    chmod 600 "${failure_directory}/failure-summary.txt" 2>/dev/null || preservation_failed=1

    if (( preservation_failed != 0 )); then
        operator_error "One or more ${collector_label} failure artifacts could not be preserved completely."
        log_info "Partial troubleshooting evidence: ${failure_directory}"
        return 1
    fi

    operator_warning "${collector_label} collector failure artifacts were preserved."
    log_info "Troubleshooting evidence: ${failure_directory}"
    return 0
}

###############################################################################
# Shared Registry: Manual Export Collector Configuration
# Used By: Switch01 | NANO-AP | NANO-STATION
# Purpose: Stores explicit configuration for the shared manual-export workflow.
# Impact: Changes affect listed collectors. Validate all before release.
###############################################################################
declare -gA POLARIS_MANUAL_EXPORT_CONFIG=()

# Purpose: Own the polaris register manual export collector step of the collector lifecycle.
# This comment documents intent; implementation behavior is unchanged.
polaris_register_manual_export_collector() {
    local collector_id="${1:-}"
    local collector_label="${2:-}"
    local module_name="${3:-}"
    local module_display_name="${4:-}"
    local module_version="${5:-}"
    local artifact_prefix="${6:-}"
    local intake_directory="${7:-}"
    local intake_filename="${8:-}"

    if [[ -z "${collector_id}" || -z "${collector_label}" ||
          -z "${module_name}" || -z "${module_display_name}" ||
          -z "${module_version}" || -z "${artifact_prefix}" ||
          -z "${intake_directory}" || -z "${intake_filename}" ]]; then
        operator_error "Manual-export collector registration is incomplete."
        return 1
    fi

    POLARIS_MANUAL_EXPORT_CONFIG["${collector_id}:collector_label"]="${collector_label}"
    POLARIS_MANUAL_EXPORT_CONFIG["${collector_id}:module_name"]="${module_name}"
    POLARIS_MANUAL_EXPORT_CONFIG["${collector_id}:module_display_name"]="${module_display_name}"
    POLARIS_MANUAL_EXPORT_CONFIG["${collector_id}:module_version"]="${module_version}"
    POLARIS_MANUAL_EXPORT_CONFIG["${collector_id}:artifact_prefix"]="${artifact_prefix}"
    POLARIS_MANUAL_EXPORT_CONFIG["${collector_id}:intake_directory"]="${intake_directory}"
    POLARIS_MANUAL_EXPORT_CONFIG["${collector_id}:intake_filename"]="${intake_filename}"
    POLARIS_MANUAL_EXPORT_CONFIG["${collector_id}:intake_path"]="${intake_directory}/${intake_filename}"
}

# Purpose: Own the polaris manual export config value step of the collector lifecycle.
# This comment documents intent; implementation behavior is unchanged.
_polaris_manual_export_config_value() {
    local collector_id="${1:-}"
    local key="${2:-}"
    local registry_key="${collector_id}:${key}"

    if [[ ! -v "POLARIS_MANUAL_EXPORT_CONFIG[${registry_key}]" ]]; then
        operator_error "Manual-export registry entry missing: collector=${collector_id}, key=${key}"
        return 1
    fi

    printf '%s' "${POLARIS_MANUAL_EXPORT_CONFIG[${registry_key}]}"
}

###############################################################################
# Shared Helper: polaris_collect_manual_export_configuration()
# Used By: Switch01 | NANO-AP | NANO-STATION
# Purpose: Validate, stage, describe, and manifest one registered manual export.
# Impact: Changes affect listed collectors. Validate all before release.
###############################################################################
polaris_collect_manual_export_configuration() {
    local collector_id="${1:-}"
    local staging_root="${2:-}"
    local collector_label=""
    local module_name=""
    local module_display_name=""
    local module_version=""
    local artifact_prefix=""
    local intake_directory=""
    local intake_filename=""

    local intake_path=""
    local config_directory=""
    local metadata_directory=""
    local staged_config=""
    local metadata_file=""
    local manifest_file=""
    local config_relative_path=""
    local source_hash_output=""
    local staged_hash_output=""
    local source_hash=""
    local staged_hash=""

    if [[ -z "${collector_id}" || -z "${staging_root}" ]]; then
        operator_error "Manual-export collection requires a collector ID and staging root."
        return 1
    fi

    collector_label="$(_polaris_manual_export_config_value "${collector_id}" collector_label)" || return 1
    module_name="$(_polaris_manual_export_config_value "${collector_id}" module_name)" || return 1
    module_display_name="$(_polaris_manual_export_config_value "${collector_id}" module_display_name)" || return 1
    module_version="$(_polaris_manual_export_config_value "${collector_id}" module_version)" || return 1
    artifact_prefix="$(_polaris_manual_export_config_value "${collector_id}" artifact_prefix)" || return 1
    intake_directory="$(_polaris_manual_export_config_value "${collector_id}" intake_directory)" || return 1
    intake_filename="$(_polaris_manual_export_config_value "${collector_id}" intake_filename)" || return 1
    intake_path="$(_polaris_manual_export_config_value "${collector_id}" intake_path)" || return 1

    if [[ -z "${POLARIS_RUN_TIMESTAMP:-}" ]]; then
        operator_error \
            "Project Polaris run timestamp has not been initialized by the orchestrator."
        return 1
    fi

    log_info "Validating ${collector_label} collector environment."

    if ! is_root_user; then
        operator_error "${collector_label} collector must be run as root."
        return 1
    fi

    if ! command_exists sha256sum; then
        operator_error "sha256sum command is not available."
        return 1
    fi

    if ! command_exists mv; then
        operator_error "mv command is not available."
        return 1
    fi

    if [[ ! -d "${intake_directory}" ]]; then
        operator_error \
            "${collector_label} intake directory does not exist: ${intake_directory}"
        return 1
    fi

    if [[ ! -r "${intake_directory}" ]]; then
        operator_error \
            "${collector_label} intake directory is not readable: ${intake_directory}"
        return 1
    fi

    if [[ ! -w "${intake_directory}" ]]; then
        operator_error \
            "${collector_label} intake directory is not writable: ${intake_directory}"
        return 1
    fi

    log_success "${collector_label} collector environment validation successful."

    config_directory="${staging_root}/configuration"
    metadata_directory="${staging_root}/metadata"

    if ! create_directory "${config_directory}"; then
        operator_error \
            "Unable to create ${collector_label} configuration directory: ${config_directory}"
        return 1
    fi

    if ! create_directory "${metadata_directory}"; then
        operator_error \
            "Unable to create ${collector_label} metadata directory: ${metadata_directory}"
        return 1
    fi

    staged_config="${config_directory}/${artifact_prefix}-${POLARIS_RUN_TIMESTAMP}.cfg"
    intake_path="${intake_directory}/${intake_filename}"

    log_success "${collector_label} staging initialized successfully."
    log_info "Checking for a ${collector_label} configuration export."

    if [[ ! -e "${intake_path}" ]]; then
        log_info \
            "No ${collector_label} configuration export is available: ${intake_path}"
        log_info \
            "${collector_label} collector found no manual configuration export to process."

        if ! polaris_remove_staging_root "${staging_root}" "${collector_label}"; then
            operator_error \
                "Unable to remove empty ${collector_label} no-change staging workspace."
            return 1
        fi

        return 2
    fi

    if [[ -L "${intake_path}" ]]; then
        operator_error \
            "${collector_label} intake file must not be a symbolic link: ${intake_path}"
        return 1
    fi

    if [[ ! -f "${intake_path}" ]]; then
        operator_error \
            "${collector_label} intake path is not a regular file: ${intake_path}"
        return 1
    fi

    if [[ ! -r "${intake_path}" ]]; then
        operator_error \
            "${collector_label} intake file is not readable: ${intake_path}"
        return 1
    fi

    if [[ ! -s "${intake_path}" ]]; then
        operator_error \
            "${collector_label} intake file is empty: ${intake_path}"
        return 1
    fi

    if [[ -e "${staged_config}" ]]; then
        operator_error \
            "${collector_label} staged configuration already exists: ${staged_config}"
        return 1
    fi

    if ! source_hash_output="$(sha256sum -- "${intake_path}")"; then
        operator_error "Unable to hash the ${collector_label} intake file."
        return 1
    fi

    source_hash="${source_hash_output%% *}"

    if [[ -z "${source_hash}" ]]; then
        operator_error "${collector_label} intake file produced an empty SHA-256 hash."
        return 1
    fi

    if ! mv -- "${intake_path}" "${staged_config}"; then
        operator_error \
            "Unable to move the ${collector_label} export into the staging workspace."
        return 1
    fi

    if [[ ! -f "${staged_config}" ]]; then
        operator_error \
            "${collector_label} staged configuration is not a regular file: ${staged_config}"
        return 1
    fi

    if [[ ! -r "${staged_config}" ]]; then
        operator_error \
            "${collector_label} staged configuration is not readable: ${staged_config}"
        return 1
    fi

    if [[ ! -s "${staged_config}" ]]; then
        operator_error \
            "${collector_label} staged configuration is empty: ${staged_config}"
        return 1
    fi

    if ! staged_hash_output="$(sha256sum -- "${staged_config}")"; then
        operator_error "Unable to hash the staged ${collector_label} configuration."
        return 1
    fi

    staged_hash="${staged_hash_output%% *}"

    if [[ -z "${staged_hash}" ]]; then
        operator_error \
            "Staged ${collector_label} configuration produced an empty SHA-256 hash."
        return 1
    fi

    if [[ "${source_hash}" != "${staged_hash}" ]]; then
        operator_error \
            "${collector_label} configuration hash changed during intake processing."
        return 1
    fi

    log_success "${collector_label} configuration export staged successfully."

    metadata_file="${metadata_directory}/collector.metadata"

    if ! cat > "${metadata_file}" <<EOF_METADATA
collector=${module_name}
display_name=${module_display_name}
version=${module_version}
artifact=$(basename -- "${staged_config}")
status=new
sha256=${staged_hash}
source_path=${intake_path}
collection_method=manual_export
EOF_METADATA
    then
        operator_error "Unable to write ${collector_label} collector metadata."
        return 1
    fi

    if [[ ! -s "${metadata_file}" ]]; then
        operator_error \
            "${collector_label} collector metadata is missing or empty: ${metadata_file}"
        return 1
    fi

    log_success "${collector_label} collector metadata written successfully."

    manifest_file="${metadata_directory}/manifest.txt"
    config_relative_path="configuration/${staged_config##*/}"

    if ! polaris_manifest_required_files \
        "${staging_root}" \
        "${manifest_file}" \
        "${collector_label}" \
        "${config_relative_path}" \
        "metadata/collector.metadata"
    then
        return 1
    fi

    log_success "${collector_label} integrity manifest written successfully."
    log_success "${collector_label} collector completed successfully."

    return 0
}
