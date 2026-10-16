#!/usr/bin/env bash

[[ -n "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_SH_LOADED:-}" ]] && return 0
readonly POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_SH_LOADED=1

###############################################################################
# Project Polaris
# CyberRange Node Proxmox Configuration Collector
#
# Deliberately NOT forked from collectors/proxmox/proxmox.sh or
# collectors/proxmox-ai/proxmox_ai_collector.sh, unlike how the AI node's
# collector was built. Those collect via local shell commands run ON the
# target host itself (pveversion, reading /etc/pve/*, etc.), which would
# mean a standing root SSH credential living on the one host in this
# environment deliberately designed to run intentionally hostile
# software. cyberrange holds no Project Polaris credential of any kind.
#
# Instead, this entire collector runs on CT402 (orchestrator-n8n) and
# reads the cyberrange Proxmox host's own REST API over the LAN,
# read-only, using a narrowly-scoped PVEAuditor token
# (polaris-cyberrange-collector@pve) proven during the isolation design
# session to cover exactly: the node itself, and the two persistent VMs
# (cyber-fw01/300, kali01/301). Blackarchlinux01 and analysis-probe01 are
# deliberately excluded - they are expected to be destroyed and rebuilt
# repeatedly under new VMIDs, and Proxmox's VM-level ACL grants are
# per-VMID with no "all VMs on this node" shortcut, so tracking them
# would mean re-granting the token's ACL on every rebuild. This mirrors
# the project's existing precedent of deliberately not tracking things
# expected to constantly churn (Admin01/Docker01's inventory-mode
# collectors, for the same reason).
#
# Host-level configuration only - VM/CT inventory, storage, network
# bridges. This collector never reaches into any guest VM's own
# filesystem or shell, on either of the two tracked VMs or otherwise.
#
# See the cyberrange isolation design session (2026-09-15 runbook
# addendum) for the full reasoning behind every choice above.
###############################################################################

###############################################################################
# Framework Initialization
###############################################################################

POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_DIR

POLARIS_PROXMOX_CYBERRANGE_FRAMEWORK_ROOT="$(cd -- "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_DIR}/../.." && pwd -P)"
readonly POLARIS_PROXMOX_CYBERRANGE_FRAMEWORK_ROOT

readonly POLARIS_PROXMOX_CYBERRANGE_LIB_DIR="${POLARIS_PROXMOX_CYBERRANGE_FRAMEWORK_ROOT}/lib"

# shellcheck source=/dev/null
source "${POLARIS_PROXMOX_CYBERRANGE_LIB_DIR}/polaris-common.sh"

###############################################################################
# Collector Result Contract
###############################################################################

readonly POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_NO_CHANGE=2

###############################################################################
# Module Metadata
###############################################################################

readonly MODULE_NAME="proxmox-cyberrange"
readonly MODULE_DISPLAY_NAME="CyberRange Node Proxmox Collector"
readonly MODULE_VERSION="1.0.0"
readonly MODULE_AUTHOR="Project Polaris"

###############################################################################
# API Configuration
#
# Read-only. The six ACL grants this token actually has - proven by
# direct curl test during the design session, not assumed - are exactly:
# /nodes/cyberrange, /vms/300, /vms/301, /storage/NAS-ISO-Repo-CyberRange,
# /storage/local, /storage/local-lvm, /storage/Cyber_VM. The endpoints
# below stay within that boundary deliberately.
###############################################################################

readonly POLARIS_PROXMOX_CYBERRANGE_API_HOST="192.168.10.119"
readonly POLARIS_PROXMOX_CYBERRANGE_API_PORT="8006"
readonly POLARIS_PROXMOX_CYBERRANGE_API_BASE="https://${POLARIS_PROXMOX_CYBERRANGE_API_HOST}:${POLARIS_PROXMOX_CYBERRANGE_API_PORT}/api2/json"
readonly POLARIS_PROXMOX_CYBERRANGE_NODE_NAME="cyberrange"
readonly POLARIS_PROXMOX_CYBERRANGE_TOKEN_FILE="/root/.polaris_cyberrange_token"
readonly POLARIS_PROXMOX_CYBERRANGE_CURL_MAX_TIME=30

# vmid:friendly-name pairs for the two persistent, tracked VMs only.
# See the header comment above for why the disposable VMs are excluded.
readonly POLARIS_PROXMOX_CYBERRANGE_TRACKED_VMS=(
    "300:cyber-fw01"
    "301:kali01"
)

###############################################################################
# Artifact Inventory
###############################################################################
#
# host/
#   version.json
#
# network/
#   interfaces.json
#
# storage/
#   storage.json
#
# virtual-machines/
#   300-cyber-fw01.json
#   301-kali01.json
#
# metadata/
#   collector-info.txt
#   manifest.txt
#
###############################################################################

###############################################################################
# Module State
###############################################################################

# Absolute destination directory supplied by the calling orchestrator.
POLARIS_PROXMOX_CYBERRANGE_STAGING_ROOT=""

# Read once per run in _polaris_proxmox_cyberrange_validate_environment().
POLARIS_PROXMOX_CYBERRANGE_API_TOKEN=""

###############################################################################
# Environment and Staging
###############################################################################

###############################################################################
# Function: _polaris_proxmox_cyberrange_validate_environment
#
# Purpose:
#   Verify required commands are available and the API token can be read.
#
# Returns:
#   0 - Environment is valid.
#   1 - Validation failed.
###############################################################################

_polaris_proxmox_cyberrange_validate_environment() {

    log_info "Validating CyberRange collector environment."

    if ! command_exists curl; then
        operator_error "Required command not found: curl"
        return 1
    fi

    if ! command_exists jq; then
        operator_error "Required command not found: jq"
        return 1
    fi

    if [[ ! -f "${POLARIS_PROXMOX_CYBERRANGE_TOKEN_FILE}" ]]; then
        operator_error "CyberRange API token file not found: ${POLARIS_PROXMOX_CYBERRANGE_TOKEN_FILE}"
        return 1
    fi

    if [[ ! -r "${POLARIS_PROXMOX_CYBERRANGE_TOKEN_FILE}" ]]; then
        operator_error "CyberRange API token file is not readable: ${POLARIS_PROXMOX_CYBERRANGE_TOKEN_FILE}"
        return 1
    fi

    POLARIS_PROXMOX_CYBERRANGE_API_TOKEN="$(< "${POLARIS_PROXMOX_CYBERRANGE_TOKEN_FILE}")"

    if [[ -z "${POLARIS_PROXMOX_CYBERRANGE_API_TOKEN}" ]]; then
        operator_error "CyberRange API token file is empty: ${POLARIS_PROXMOX_CYBERRANGE_TOKEN_FILE}"
        return 1
    fi

    log_success "Environment validation successful."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_cyberrange_create_staging
#
# Purpose:
#   Create the staging directory structure used by this collector.
#
# Returns:
#   0 - Staging area created successfully.
#   1 - Failed to create one or more directories.
###############################################################################

_polaris_proxmox_cyberrange_create_staging() {

    local staging_root="${POLARIS_PROXMOX_CYBERRANGE_STAGING_ROOT}"

    log_info "Creating CyberRange staging directory: ${staging_root}"

    if [[ -z "${staging_root}" ]]; then
        operator_error "CyberRange staging destination was not provided."
        return 1
    fi

    if [[ -e "${staging_root}" && ! -d "${staging_root}" ]]; then
        operator_error "CyberRange staging destination exists but is not a directory: ${staging_root}"
        return 1
    fi

    create_directory "${staging_root}" || return 1
    create_directory "${staging_root}/host" || return 1
    create_directory "${staging_root}/network" || return 1
    create_directory "${staging_root}/storage" || return 1
    create_directory "${staging_root}/virtual-machines" || return 1
    create_directory "${staging_root}/metadata" || return 1

    log_success "Staging directory ready."

    return 0
}

###############################################################################
# API Transport
###############################################################################

###############################################################################
# Function: _polaris_proxmox_cyberrange_api_get
#
# Purpose:
#   Perform one read-only Proxmox API GET call, validate the HTTP status
#   and JSON structure, and write the canonicalized (key-sorted) response
#   body to disk. Canonicalizing via `jq -S` means field reordering alone
#   in Proxmox's own JSON output can never register as a spurious content
#   change if genuine hash-based diffing is added on top of this
#   collector later - the same class of bug that hit OPNsense/Admin01 in
#   3r/3p is designed out from the start here rather than discovered
#   after the fact.
#
# Parameters:
#   $1 - API path, relative to POLARIS_PROXMOX_CYBERRANGE_API_BASE.
#   $2 - Destination file for the canonicalized JSON response.
#   $3 - Human-readable label for diagnostics.
#
# Returns:
#   0 - Success.
#   1 - Transport, HTTP, or JSON-validation failure.
###############################################################################

_polaris_proxmox_cyberrange_api_get() {

    local api_path="$1"
    local destination_file="$2"
    local label="$3"

    local url="${POLARIS_PROXMOX_CYBERRANGE_API_BASE}/${api_path}"
    local response_file
    local http_status

    response_file="$(mktemp)" || {
        operator_error "Unable to create temporary file for ${label}."
        return 1
    }

    log_info "Requesting ${label}: ${url}"

    if ! http_status="$(
        curl \
            --silent \
            --show-error \
            --insecure \
            --max-time "${POLARIS_PROXMOX_CYBERRANGE_CURL_MAX_TIME}" \
            --header "Authorization: PVEAPIToken=${POLARIS_PROXMOX_CYBERRANGE_API_TOKEN}" \
            --output "${response_file}" \
            --write-out '%{http_code}' \
            "${url}"
    )"; then
        operator_error "curl transport failure requesting ${label}."
        rm -f -- "${response_file}"
        return 1
    fi

    if [[ "${http_status}" != "200" ]]; then
        operator_error "${label} request returned HTTP ${http_status}."
        log_error "${label} response body: $(cat -- "${response_file}" 2>/dev/null)"
        rm -f -- "${response_file}"
        return 1
    fi

    if ! jq -e '.' "${response_file}" >/dev/null 2>&1; then
        operator_error "${label} response was not valid JSON."
        rm -f -- "${response_file}"
        return 1
    fi

    if ! jq -e 'has("data")' "${response_file}" >/dev/null 2>&1; then
        operator_error "${label} response did not contain a 'data' field."
        rm -f -- "${response_file}"
        return 1
    fi

    if ! jq -S '.' "${response_file}" > "${destination_file}"; then
        operator_error "Unable to canonicalize ${label} response."
        rm -f -- "${response_file}"
        return 1
    fi

    rm -f -- "${response_file}"

    if [[ ! -s "${destination_file}" ]]; then
        operator_error "${label} artifact was not written or is empty: ${destination_file}"
        return 1
    fi

    log_success "${label} collected."

    return 0
}

###############################################################################
# Collectors
###############################################################################

# Purpose: Collect the cyberrange Proxmox host's own version information.
_polaris_proxmox_cyberrange_collect_version() {

    local output_file="${POLARIS_PROXMOX_CYBERRANGE_STAGING_ROOT}/host/version.json"

    _polaris_proxmox_cyberrange_api_get \
        "version" \
        "${output_file}" \
        "CyberRange Proxmox version" || return 1

    return 0
}

# Purpose: Collect the cyberrange node's network/bridge configuration.
_polaris_proxmox_cyberrange_collect_network() {

    local output_file="${POLARIS_PROXMOX_CYBERRANGE_STAGING_ROOT}/network/interfaces.json"

    _polaris_proxmox_cyberrange_api_get \
        "nodes/${POLARIS_PROXMOX_CYBERRANGE_NODE_NAME}/network" \
        "${output_file}" \
        "CyberRange network interfaces" || return 1

    return 0
}

# Purpose: Collect the storage definitions visible to this token
# (deliberately only the four attached to this host - see the ACL
# grants noted in the API Configuration section above).
_polaris_proxmox_cyberrange_collect_storage() {

    local output_file="${POLARIS_PROXMOX_CYBERRANGE_STAGING_ROOT}/storage/storage.json"

    _polaris_proxmox_cyberrange_api_get \
        "storage" \
        "${output_file}" \
        "CyberRange storage definitions" || return 1

    return 0
}

# Purpose: Collect the Proxmox configuration for each persistent,
# tracked VM. Deliberately does not enumerate or discover VMs
# dynamically - the tracked list is explicit and fixed, matching the
# token's own per-VMID ACL grants exactly.
_polaris_proxmox_cyberrange_collect_vms() {

    local vm_entry
    local vmid
    local vm_name
    local output_file

    for vm_entry in "${POLARIS_PROXMOX_CYBERRANGE_TRACKED_VMS[@]}"; do

        vmid="${vm_entry%%:*}"
        vm_name="${vm_entry#*:}"

        output_file="${POLARIS_PROXMOX_CYBERRANGE_STAGING_ROOT}/virtual-machines/${vmid}-${vm_name}.json"

        _polaris_proxmox_cyberrange_api_get \
            "nodes/${POLARIS_PROXMOX_CYBERRANGE_NODE_NAME}/qemu/${vmid}/config" \
            "${output_file}" \
            "CyberRange VM ${vmid} (${vm_name}) config" || return 1

    done

    return 0
}

###############################################################################
# Function: _polaris_proxmox_cyberrange_collect_metadata
#
# Purpose:
#   Write collector-info.txt and the manifest covering every artifact
#   this collector produces. Uses the shared
#   polaris_manifest_required_files() helper (an explicit, ordered file
#   list) rather than the recursive walker, since this collector's
#   output is a small, fixed set of known files - the same category of
#   manifest already used by pfSense/OPNsense/Switch01.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_cyberrange_collect_metadata() {

    local metadata_dir="${POLARIS_PROXMOX_CYBERRANGE_STAGING_ROOT}/metadata"
    local manifest_file="${metadata_dir}/manifest.txt"
    local info_file="${metadata_dir}/collector-info.txt"
    local vm_entry
    local vmid
    local vm_name
    local -a required_files=()

    log_info "Collecting metadata."

    {
        echo "Project Polaris Collector Information"
        echo "====================================="
        echo
        printf "%-24s %s\n" "Collector Name"    "${MODULE_DISPLAY_NAME}"
        printf "%-24s %s\n" "Module"            "${MODULE_NAME}"
        printf "%-24s %s\n" "Project"           "Project Polaris"
        printf "%-24s %s\n" "Collector Version" "${MODULE_VERSION}"
        printf "%-24s %s\n" "Collector Author"  "${MODULE_AUTHOR}"
        printf "%-24s %s\n" "API Host"          "${POLARIS_PROXMOX_CYBERRANGE_API_HOST}"
        printf "%-24s %s\n" "Tracked VMs"       "${POLARIS_PROXMOX_CYBERRANGE_TRACKED_VMS[*]}"
        printf "%-24s %s\n" "Generated"         "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    } > "${info_file}" || {
        operator_error "Unable to write collector information."
        return 1
    }

    required_files=(
        "host/version.json"
        "network/interfaces.json"
        "storage/storage.json"
    )

    for vm_entry in "${POLARIS_PROXMOX_CYBERRANGE_TRACKED_VMS[@]}"; do
        vmid="${vm_entry%%:*}"
        vm_name="${vm_entry#*:}"
        required_files+=( "virtual-machines/${vmid}-${vm_name}.json" )
    done

    required_files+=( "metadata/collector-info.txt" )

    polaris_manifest_required_files \
        "${POLARIS_PROXMOX_CYBERRANGE_STAGING_ROOT}" \
        "${manifest_file}" \
        "${MODULE_DISPLAY_NAME}" \
        "${required_files[@]}" || return 1

    log_success "Metadata collection complete."

    return 0
}

###############################################################################
# Public Interface
###############################################################################

###############################################################################
# Function: collect_proxmox_cyberrange
#
# Purpose:
#   Execute the complete Project Polaris cyberrange node Proxmox
#   collection workflow using the destination directory supplied by the
#   calling orchestrator.
#
#   Named distinctly from collect_proxmox()/collect_proxmox_ai() so there
#   is zero namespace collision risk if collector scripts were ever
#   sourced in the same shell session.
#
# Parameters:
#   $1 - Absolute destination directory for collector output.
#
# Returns:
#   0 - Collection completed successfully.
#   1 - Input validation or one or more collection stages failed.
###############################################################################

collect_proxmox_cyberrange() {

    local destination_directory="${1:-}"

    if [[ -z "${destination_directory}" ]]; then
        operator_error "No CyberRange collection destination was provided."
        return "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_PROXMOX_CYBERRANGE_STAGING_ROOT="${destination_directory}"

    log_info "Starting ${MODULE_DISPLAY_NAME} v${MODULE_VERSION}."
    log_info "Collector destination: ${POLARIS_PROXMOX_CYBERRANGE_STAGING_ROOT}"

    _polaris_proxmox_cyberrange_validate_environment || return "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_cyberrange_create_staging || return "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_cyberrange_collect_version || return "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_cyberrange_collect_network || return "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_cyberrange_collect_storage || return "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_cyberrange_collect_vms || return "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_cyberrange_collect_metadata || return "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_ERROR}"

    log_success "CyberRange collection complete."

    return "${POLARIS_PROXMOX_CYBERRANGE_COLLECTOR_RESULT_SUCCESS}"
}
