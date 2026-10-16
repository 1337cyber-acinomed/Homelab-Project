#!/usr/bin/env bash

[[ -n "${POLARIS_ADMIN01_SH_LOADED:-}" ]] && return 0
readonly POLARIS_ADMIN01_SH_LOADED=1

###############################################################################
# Project Polaris
# Admin01 Configuration Collector
###############################################################################

###############################################################################
# Framework Initialization
###############################################################################

POLARIS_ADMIN01_COLLECTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly POLARIS_ADMIN01_COLLECTOR_DIR

POLARIS_ADMIN01_FRAMEWORK_ROOT="$(cd -- "${POLARIS_ADMIN01_COLLECTOR_DIR}/../.." && pwd -P)"
readonly POLARIS_ADMIN01_FRAMEWORK_ROOT

readonly POLARIS_ADMIN01_LIB_DIR="${POLARIS_ADMIN01_FRAMEWORK_ROOT}/lib"

# shellcheck source=/dev/null
source "${POLARIS_ADMIN01_LIB_DIR}/polaris-common.sh"

###############################################################################
# Collector Result Codes
###############################################################################

readonly POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_ADMIN01_COLLECTOR_RESULT_NO_CHANGE=2

###############################################################################
# Module Metadata
###############################################################################

readonly POLARIS_ADMIN01_MODULE_NAME="admin01"
readonly POLARIS_ADMIN01_MODULE_DISPLAY_NAME="Admin01 Collector"
readonly POLARIS_ADMIN01_MODULE_VERSION="1.7.0"
readonly POLARIS_ADMIN01_MODULE_AUTHOR="Project Polaris"

readonly POLARIS_ADMIN01_HOST="192.168.10.30"
readonly POLARIS_ADMIN01_USER="lab-admin"

readonly POLARIS_ADMIN01_SSH_KEY="/root/.ssh/polaris-admin01-backup"

readonly POLARIS_ADMIN01_SSH_CONNECT_TIMEOUT=10

# Purpose: Execute one Admin01 command through the shared SSH transport.
# This comment documents intent; implementation behavior is unchanged.
_admin01_remote_execute() {
    local remote_command="${1:-}"

    polaris_ssh_execute \
        "${POLARIS_ADMIN01_HOST}" \
        "${POLARIS_ADMIN01_USER}" \
        "${POLARIS_ADMIN01_SSH_KEY}" \
        "${POLARIS_ADMIN01_SSH_CONNECT_TIMEOUT}" \
        "disable" \
        "no" \
        "${remote_command}"
}

# Purpose: Execute one Admin01 command and write its output directly to a staging artifact.
# This comment documents intent; implementation behavior is unchanged.
_admin01_remote_execute_to_file() {
    local remote_command="${1:-}"
    local output_file="${2:-}"

    if [[ -z "${remote_command}" ]]; then
        operator_error "Admin01 remote command was not provided."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ -z "${output_file}" ]]; then
        operator_error "Admin01 remote output path was not provided."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! polaris_ssh_execute_to_file \
        "${POLARIS_ADMIN01_HOST}" \
        "${POLARIS_ADMIN01_USER}" \
        "${POLARIS_ADMIN01_SSH_KEY}" \
        "${POLARIS_ADMIN01_SSH_CONNECT_TIMEOUT}" \
        "disable" \
        "no" \
        "${remote_command}" \
        "${output_file}" \
        "reject" \
        "Admin01"
    then
        operator_error "Admin01 remote command failed: ${remote_command}"
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}


###############################################################################
# Collector Constants
###############################################################################

readonly ADMIN01_COLLECTION_STATUS_COMPLETE_CONFIGURATION="complete-admin01-configuration-inventory"

###############################################################################
# Module State
###############################################################################

POLARIS_ADMIN01_STAGING_ROOT=""
POLARIS_ADMIN01_CONFIGURATION_DIR=""
POLARIS_ADMIN01_ADMIN_DIR=""
POLARIS_ADMIN01_OS_DIR=""
POLARIS_ADMIN01_NETWORK_DIR=""
POLARIS_ADMIN01_FILESYSTEM_DIR=""
POLARIS_ADMIN01_SERVICES_DIR=""
POLARIS_ADMIN01_PACKAGES_DIR=""
POLARIS_ADMIN01_ENVIRONMENT_DIR=""
POLARIS_ADMIN01_WORKSPACE_DIR=""
POLARIS_ADMIN01_METADATA_DIR=""
POLARIS_ADMIN01_COLLECTION_STATUS=""

###############################################################################
# Function: _validate_environment
#
# Purpose:
#   Verify the local framework requirements for the Stage 1A Admin01 collector.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Environment is valid.
#   1 - Validation failed.
###############################################################################

_validate_environment() {
    local required_commands=(
        awk
        date
        find
        install
        sha256sum
        ssh
        stat
    )
    local required_command=""

    log_info "Validating Admin01 collector environment."

    if ! is_root_user; then
        operator_error "Collector must be run as root."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    for required_command in "${required_commands[@]}"; do
        if ! command_exists "${required_command}"; then
            operator_error \
                "Required command is not available: ${required_command}"

            return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
        fi
    done

    if [[ ! -r "${POLARIS_ADMIN01_SSH_KEY}" ]]; then
        operator_error \
            "Admin01 SSH private key is not readable: ${POLARIS_ADMIN01_SSH_KEY}"

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _admin01_remote_execute \
        "hostname >/dev/null 2>&1 &&
         id >/dev/null 2>&1 &&
         command -v sudo >/dev/null 2>&1"
    then
        operator_error \
            "Unable to validate unattended SSH access to Admin01."

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin01 collector environment validation successful."

    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _initialize_staging
#
# Purpose:
#   Create the Stage 1A Admin01 configuration and metadata directories.
#
# Parameters:
#   $1 - Collector staging root.
#
# Returns:
#   0 - Staging initialized successfully.
#   1 - Initialization failed.
###############################################################################

_initialize_staging() {
    local staging_root="${1:-}"

    if [[ -z "${staging_root}" ]]; then
        operator_error "Admin01 staging root was not provided."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_ADMIN01_STAGING_ROOT="${staging_root}"
    POLARIS_ADMIN01_CONFIGURATION_DIR="${POLARIS_ADMIN01_STAGING_ROOT}/configuration"
    POLARIS_ADMIN01_ADMIN_DIR="${POLARIS_ADMIN01_CONFIGURATION_DIR}/admin01"
    POLARIS_ADMIN01_OS_DIR="${POLARIS_ADMIN01_ADMIN_DIR}/os"
    POLARIS_ADMIN01_NETWORK_DIR="${POLARIS_ADMIN01_ADMIN_DIR}/network"
    POLARIS_ADMIN01_FILESYSTEM_DIR="${POLARIS_ADMIN01_ADMIN_DIR}/filesystem"
    POLARIS_ADMIN01_SERVICES_DIR="${POLARIS_ADMIN01_ADMIN_DIR}/services"
    POLARIS_ADMIN01_PACKAGES_DIR="${POLARIS_ADMIN01_ADMIN_DIR}/packages"
    POLARIS_ADMIN01_ENVIRONMENT_DIR="${POLARIS_ADMIN01_ADMIN_DIR}/administrator-environment"
    POLARIS_ADMIN01_WORKSPACE_DIR="${POLARIS_ADMIN01_ADMIN_DIR}/project-polaris-workspace"
    POLARIS_ADMIN01_METADATA_DIR="${POLARIS_ADMIN01_STAGING_ROOT}/metadata"

    if ! polaris_prepare_staging_directories \
        "${POLARIS_ADMIN01_STAGING_ROOT}" \
        "Admin01" \
        "${POLARIS_ADMIN01_ADMIN_DIR}" \
        "${POLARIS_ADMIN01_OS_DIR}" \
        "${POLARIS_ADMIN01_NETWORK_DIR}" \
        "${POLARIS_ADMIN01_FILESYSTEM_DIR}" \
        "${POLARIS_ADMIN01_SERVICES_DIR}" \
        "${POLARIS_ADMIN01_PACKAGES_DIR}" \
        "${POLARIS_ADMIN01_ENVIRONMENT_DIR}" \
        "${POLARIS_ADMIN01_WORKSPACE_DIR}" \
        "${POLARIS_ADMIN01_METADATA_DIR}"
    then
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_ADMIN01_COLLECTION_STATUS="${ADMIN01_COLLECTION_STATUS_COMPLETE_CONFIGURATION}"

    log_success "Admin01 staging directories initialized."
    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}

# Purpose: Collect remote identity data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_collect_remote_identity() {
    local output_file="${POLARIS_ADMIN01_ADMIN_DIR}/remote-identity.txt"

    log_info "Collecting Admin01 remote identity."

    if [[ -z "${POLARIS_ADMIN01_ADMIN_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN01_ADMIN_DIR}" ]]
    then
        operator_error \
            "Admin01 configuration staging directory has not been initialized."

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! {
        printf 'Project Polaris Admin01 Remote Identity\n'
        printf '=======================================\n\n'
        printf 'Target Host: %s\n' "${POLARIS_ADMIN01_HOST}"
        printf 'Remote User: %s\n' "${POLARIS_ADMIN01_USER}"
        printf 'Transport: SSH\n'
        printf 'Collection Timestamp (UTC): %s\n\n' \
            "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

        _admin01_remote_execute '
            printf "Hostname: "
            hostname

            printf "Fully Qualified Hostname: "
            hostname --fqdn 2>/dev/null || hostname

            printf "Remote Identity: "
            id

            printf "Default Shell: "
            getent passwd "$(id -un)" | cut -d: -f7

            printf "Home Directory: "
            getent passwd "$(id -un)" | cut -d: -f6

            printf "Sudo Command Available: "
            if command -v sudo >/dev/null 2>&1; then
                printf "yes\n"
            else
                printf "no\n"
            fi
        '
    } > "${output_file}"
    then
        operator_error \
            "Unable to collect Admin01 remote identity."

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error \
            "Unable to secure Admin01 remote identity artifact."

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error \
            "Admin01 remote identity artifact is empty."

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin01 remote identity collected successfully."

    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}


###############################################################################
# Function: _collect_os_inventory
#
# Purpose:
#   Collect authoritative Admin01 operating-system identity and generate a
#   human-readable summary from the collected artifacts.
###############################################################################

_collect_os_inventory() {
    local os_release_file="${POLARIS_ADMIN01_OS_DIR}/os-release.txt"
    local hostnamectl_file="${POLARIS_ADMIN01_OS_DIR}/hostnamectl.txt"
    local uname_file="${POLARIS_ADMIN01_OS_DIR}/uname.txt"
    local machine_id_file="${POLARIS_ADMIN01_OS_DIR}/machine-id.txt"
    local summary_file="${POLARIS_ADMIN01_OS_DIR}/os-summary.txt"

    local pretty_name=""
    local kernel_line=""
    local machine_id=""
    local hostname_value=""
    local architecture=""

    log_info "Collecting Admin01 operating-system inventory."

    if [[ -z "${POLARIS_ADMIN01_OS_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN01_OS_DIR}" ]]
    then
        operator_error \
            "Admin01 OS staging directory has not been initialized."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    _admin01_remote_execute_to_file \
        "cat /etc/os-release" \
        "${os_release_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "hostnamectl" \
        "${hostnamectl_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "uname -a" \
        "${uname_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "cat /etc/machine-id" \
        "${machine_id_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    pretty_name="$(
        awk -F= '
            $1 == "PRETTY_NAME" {
                value=$2
                sub(/^"/, "", value)
                sub(/"$/, "", value)
                print value
                exit
            }
        ' "${os_release_file}"
    )"

    kernel_line="$(head -n 1 "${uname_file}")"
    machine_id="$(head -n 1 "${machine_id_file}")"

    hostname_value="$(
        awk -F: '
            /^[[:space:]]*Static hostname:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${hostnamectl_file}"
    )"

    architecture="$(
        awk -F: '
            /^[[:space:]]*Architecture:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${hostnamectl_file}"
    )"

    [[ -n "${pretty_name}" ]] || pretty_name="Unavailable"
    [[ -n "${kernel_line}" ]] || kernel_line="Unavailable"
    [[ -n "${machine_id}" ]] || machine_id="Unavailable"
    [[ -n "${hostname_value}" ]] || hostname_value="Unavailable"
    [[ -n "${architecture}" ]] || architecture="Unavailable"

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin01 Operating System Summary
================================================

Target Host: ${POLARIS_ADMIN01_HOST}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Operating System: ${pretty_name}
Hostname: ${hostname_value}
Architecture: ${architecture}
Kernel: ${kernel_line}
Machine ID: ${machine_id}
Collection Status: Success
EOF
    then
        operator_error "Unable to write Admin01 operating-system summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin01 operating-system summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin01 operating-system summary is empty."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin01 operating-system inventory collected successfully."
    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_network_inventory
#
# Purpose:
#   Collect authoritative Admin01 network state and generate a concise summary
#   from the collected artifacts.
###############################################################################

_collect_network_inventory() {
    local ip_address_file="${POLARIS_ADMIN01_NETWORK_DIR}/ip-address.txt"
    local ip_link_file="${POLARIS_ADMIN01_NETWORK_DIR}/ip-link.txt"
    local ip_route_file="${POLARIS_ADMIN01_NETWORK_DIR}/ip-route.txt"
    local ip_rule_file="${POLARIS_ADMIN01_NETWORK_DIR}/ip-rule.txt"
    local resolv_conf_file="${POLARIS_ADMIN01_NETWORK_DIR}/resolv.conf.txt"
    local hosts_file="${POLARIS_ADMIN01_NETWORK_DIR}/hosts.txt"
    local hostname_file="${POLARIS_ADMIN01_NETWORK_DIR}/hostname.txt"
    local summary_file="${POLARIS_ADMIN01_NETWORK_DIR}/network-summary.txt"

    local hostname_value=""
    local ipv4_count=0
    local ipv6_count=0
    local default_route_count=0
    local nameserver_count=0

    log_info "Collecting Admin01 network inventory."

    if [[ -z "${POLARIS_ADMIN01_NETWORK_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN01_NETWORK_DIR}" ]]
    then
        operator_error \
            "Admin01 network staging directory has not been initialized."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    _admin01_remote_execute_to_file \
        "ip -details address show" \
        "${ip_address_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "ip -details link show" \
        "${ip_link_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "ip route show table all" \
        "${ip_route_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "ip rule show" \
        "${ip_rule_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "cat /etc/resolv.conf" \
        "${resolv_conf_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "cat /etc/hosts" \
        "${hosts_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "hostname" \
        "${hostname_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    hostname_value="$(head -n 1 "${hostname_file}")"

    ipv4_count="$(
        awk '
            /^[[:space:]]*inet[[:space:]]/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${ip_address_file}"
    )"

    ipv6_count="$(
        awk '
            /^[[:space:]]*inet6[[:space:]]/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${ip_address_file}"
    )"

    default_route_count="$(
        awk '
            $1 == "default" {
                count++
            }
            END {
                print count + 0
            }
        ' "${ip_route_file}"
    )"

    nameserver_count="$(
        awk '
            /^[[:space:]]*nameserver[[:space:]]/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${resolv_conf_file}"
    )"

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin01 Network Summary
=======================================

Target Host: ${POLARIS_ADMIN01_HOST}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Hostname: ${hostname_value}
IPv4 Address Count: ${ipv4_count}
IPv6 Address Count: ${ipv6_count}
Default Route Count: ${default_route_count}
Configured Nameserver Count: ${nameserver_count}
Collection Status: Success

Collected Artifacts
-------------------
ip-address.txt
ip-link.txt
ip-route.txt
ip-rule.txt
resolv.conf.txt
hosts.txt
hostname.txt
EOF
    then
        operator_error "Unable to write Admin01 network summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin01 network summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin01 network summary is empty."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin01 network inventory collected successfully."
    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_filesystem_inventory
#
# Purpose:
#   Collect Admin01 filesystem, block-device, mount, and persistent-mount
#   configuration and generate a concise summary from the collected artifacts.
###############################################################################

_collect_filesystem_inventory() {
    local df_file="${POLARIS_ADMIN01_FILESYSTEM_DIR}/df.txt"
    local findmnt_file="${POLARIS_ADMIN01_FILESYSTEM_DIR}/findmnt.txt"
    local lsblk_file="${POLARIS_ADMIN01_FILESYSTEM_DIR}/lsblk.txt"
    local fstab_file="${POLARIS_ADMIN01_FILESYSTEM_DIR}/fstab.txt"
    local summary_file="${POLARIS_ADMIN01_FILESYSTEM_DIR}/filesystem-summary.txt"

    local root_source="Unavailable"
    local root_fstype="Unavailable"
    local mounted_filesystem_count=0
    local block_device_count=0
    local fstab_entry_count=0

    log_info "Collecting Admin01 filesystem and mount inventory."

    if [[ -z "${POLARIS_ADMIN01_FILESYSTEM_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN01_FILESYSTEM_DIR}" ]]
    then
        operator_error \
            "Admin01 filesystem staging directory has not been initialized."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    _admin01_remote_execute_to_file \
        "df -hT" \
        "${df_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "findmnt --real" \
        "${findmnt_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "lsblk -a -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT,UUID" \
        "${lsblk_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "cat /etc/fstab" \
        "${fstab_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    root_source="$(
        awk '
            NR > 1 && $NF == "/" {
                print $1
                exit
            }
        ' "${df_file}"
    )"

    root_fstype="$(
        awk '
            NR > 1 && $NF == "/" {
                print $2
                exit
            }
        ' "${df_file}"
    )"

    mounted_filesystem_count="$(
        awk '
            NR > 1 && NF > 0 {
                count++
            }
            END {
                print count + 0
            }
        ' "${findmnt_file}"
    )"

    block_device_count="$(
        awk '
            NR > 1 && $4 == "disk" {
                count++
            }
            END {
                print count + 0
            }
        ' "${lsblk_file}"
    )"

    fstab_entry_count="$(
        awk '
            /^[[:space:]]*#/ {
                next
            }

            /^[[:space:]]*$/ {
                next
            }

            {
                count++
            }

            END {
                print count + 0
            }
        ' "${fstab_file}"
    )"

    [[ -n "${root_source}" ]] || root_source="Unavailable"
    [[ -n "${root_fstype}" ]] || root_fstype="Unavailable"

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin01 Filesystem Summary
==========================================

Target Host: ${POLARIS_ADMIN01_HOST}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Root Filesystem Source: ${root_source}
Root Filesystem Type: ${root_fstype}
Mounted Filesystem Count: ${mounted_filesystem_count}
Block Device Count: ${block_device_count}
Persistent fstab Entry Count: ${fstab_entry_count}
Collection Status: Success

Collected Artifacts
-------------------
df.txt
findmnt.txt
lsblk.txt
fstab.txt
EOF
    then
        operator_error "Unable to write Admin01 filesystem summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin01 filesystem summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin01 filesystem summary is empty."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin01 filesystem and mount inventory collected successfully."
    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_services_inventory
#
# Purpose:
#   Collect Admin01 service, timer, and scheduled-job inventory and generate a
#   concise summary from the collected artifacts.
###############################################################################

_collect_services_inventory() {
    local services_all_file="${POLARIS_ADMIN01_SERVICES_DIR}/systemd-services-all.txt"
    local services_enabled_file="${POLARIS_ADMIN01_SERVICES_DIR}/systemd-services-enabled.txt"
    local services_failed_file="${POLARIS_ADMIN01_SERVICES_DIR}/systemd-services-failed.txt"
    local timers_file="${POLARIS_ADMIN01_SERVICES_DIR}/systemd-timers.txt"
    local user_crontab_file="${POLARIS_ADMIN01_SERVICES_DIR}/user-crontab.txt"
    local system_crontab_file="${POLARIS_ADMIN01_SERVICES_DIR}/system-crontab.txt"
    local cron_directories_file="${POLARIS_ADMIN01_SERVICES_DIR}/cron-directories.txt"
    local summary_file="${POLARIS_ADMIN01_SERVICES_DIR}/services-summary.txt"

    local total_service_count=0
    local enabled_service_count=0
    local failed_service_count=0
    local timer_count=0
    local user_cron_status="Unavailable"
    local system_cron_entry_count=0

    log_info "Collecting Admin01 services and scheduled-jobs inventory."

    if [[ -z "${POLARIS_ADMIN01_SERVICES_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN01_SERVICES_DIR}" ]]
    then
        operator_error \
            "Admin01 services staging directory has not been initialized."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    _admin01_remote_execute_to_file \
        "systemctl list-unit-files --type=service --no-pager --no-legend" \
        "${services_all_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        "systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend" \
        "${services_enabled_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'failed_output="$(systemctl --failed --type=service --no-pager --no-legend)";
         if [ -n "${failed_output}" ]; then
             printf "%s\n" "${failed_output}";
         else
             printf "No failed systemd services.\n";
         fi' \
        "${services_failed_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'timer_output="$(systemctl list-timers --all --no-pager --no-legend)";
         if [ -n "${timer_output}" ]; then
             printf "%s\n" "${timer_output}";
         else
             printf "No systemd timers.\n";
         fi' \
        "${timers_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'if crontab -l >/tmp/polaris-admin01-crontab.$$ 2>/dev/null; then
             cat /tmp/polaris-admin01-crontab.$$;
             rm -f /tmp/polaris-admin01-crontab.$$;
         else
             rm -f /tmp/polaris-admin01-crontab.$$;
             printf "No user crontab for %s.\n" "$(id -un)";
         fi' \
        "${user_crontab_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'if [ -r /etc/crontab ]; then
             cat /etc/crontab;
         else
             printf "/etc/crontab is unavailable or unreadable.\n";
         fi' \
        "${system_crontab_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'for cron_dir in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
             printf "=== %s ===\n" "${cron_dir}";
             if [ -d "${cron_dir}" ]; then
                 find "${cron_dir}" -mindepth 1 -maxdepth 1 -printf "%f\n" 2>/dev/null | sort;
             else
                 printf "Directory not present.\n";
             fi;
             printf "\n";
         done' \
        "${cron_directories_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    total_service_count="$(
        awk '
            NF > 0 {
                count++
            }
            END {
                print count + 0
            }
        ' "${services_all_file}"
    )"

    enabled_service_count="$(
        awk '
            NF > 0 {
                count++
            }
            END {
                print count + 0
            }
        ' "${services_enabled_file}"
    )"

    if grep -qx 'No failed systemd services\.' "${services_failed_file}"; then
        failed_service_count=0
    else
        failed_service_count="$(
            awk '
                NF > 0 {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${services_failed_file}"
        )"
    fi

    if grep -qx 'No systemd timers\.' "${timers_file}"; then
        timer_count=0
    else
        timer_count="$(
            awk '
                NF > 0 {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${timers_file}"
        )"
    fi

    if grep -q '^No user crontab for ' "${user_crontab_file}"; then
        user_cron_status="Not Present"
    else
        user_cron_status="Present"
    fi

    system_cron_entry_count="$(
        awk '
            /^[[:space:]]*#/ {
                next
            }

            /^[[:space:]]*$/ {
                next
            }

            {
                count++
            }

            END {
                print count + 0
            }
        ' "${system_crontab_file}"
    )"

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin01 Services Summary
========================================

Target Host: ${POLARIS_ADMIN01_HOST}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Systemd Service Unit Count: ${total_service_count}
Enabled Systemd Service Count: ${enabled_service_count}
Failed Systemd Service Count: ${failed_service_count}
Systemd Timer Count: ${timer_count}
User Crontab Status: ${user_cron_status}
System Crontab Entry Count: ${system_cron_entry_count}
Collection Status: Success

Collected Artifacts
-------------------
systemd-services-all.txt
systemd-services-enabled.txt
systemd-services-failed.txt
systemd-timers.txt
user-crontab.txt
system-crontab.txt
cron-directories.txt
EOF
    then
        operator_error "Unable to write Admin01 services summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin01 services summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin01 services summary is empty."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Admin01 services and scheduled-jobs inventory collected successfully."

    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_package_inventory
#
# Purpose:
#   Collect Admin01 package and application-manager inventories and generate a
#   concise summary from the collected artifacts.
###############################################################################

_collect_package_inventory() {
    local dpkg_packages_file="${POLARIS_ADMIN01_PACKAGES_DIR}/dpkg-packages.txt"
    local apt_manual_file="${POLARIS_ADMIN01_PACKAGES_DIR}/apt-manual-packages.txt"
    local snap_packages_file="${POLARIS_ADMIN01_PACKAGES_DIR}/snap-packages.txt"
    local flatpak_packages_file="${POLARIS_ADMIN01_PACKAGES_DIR}/flatpak-packages.txt"
    local summary_file="${POLARIS_ADMIN01_PACKAGES_DIR}/packages-summary.txt"

    local dpkg_package_count=0
    local apt_manual_count=0
    local snap_package_count=0
    local flatpak_package_count=0
    local snap_status="Unavailable"
    local flatpak_status="Unavailable"

    log_info "Collecting Admin01 package inventory."

    if [[ -z "${POLARIS_ADMIN01_PACKAGES_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN01_PACKAGES_DIR}" ]]
    then
        operator_error \
            "Admin01 package staging directory has not been initialized."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    _admin01_remote_execute_to_file \
        "dpkg-query -W -f='\${binary:Package}\t\${Version}\t\${Architecture}\n' | sort" \
        "${dpkg_packages_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'if command -v apt-mark >/dev/null 2>&1; then
             apt-mark showmanual | sort;
         else
             printf "apt-mark is unavailable.\n";
         fi' \
        "${apt_manual_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'if command -v snap >/dev/null 2>&1; then
             snap list;
         else
             printf "snap command is unavailable.\n";
         fi' \
        "${snap_packages_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'if command -v flatpak >/dev/null 2>&1; then
             flatpak list --columns=application,ref,version,branch,installation;
         else
             printf "flatpak command is unavailable.\n";
         fi' \
        "${flatpak_packages_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    dpkg_package_count="$(
        awk '
            NF > 0 {
                count++
            }
            END {
                print count + 0
            }
        ' "${dpkg_packages_file}"
    )"

    if grep -qx 'apt-mark is unavailable\.' "${apt_manual_file}"; then
        apt_manual_count=0
    else
        apt_manual_count="$(
            awk '
                NF > 0 {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${apt_manual_file}"
        )"
    fi

    if grep -qx 'snap command is unavailable\.' "${snap_packages_file}"; then
        snap_status="Unavailable"
        snap_package_count=0
    else
        snap_status="Available"
        snap_package_count="$(
            awk '
                NR > 1 && NF > 0 {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${snap_packages_file}"
        )"
    fi

    if grep -qx 'flatpak command is unavailable\.' "${flatpak_packages_file}"; then
        flatpak_status="Unavailable"
        flatpak_package_count=0
    else
        flatpak_status="Available"
        flatpak_package_count="$(
            awk '
                NF > 0 {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${flatpak_packages_file}"
        )"
    fi

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin01 Package Summary
=======================================

Target Host: ${POLARIS_ADMIN01_HOST}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Installed dpkg Package Count: ${dpkg_package_count}
Manually Installed APT Package Count: ${apt_manual_count}
Snap Availability: ${snap_status}
Installed Snap Package Count: ${snap_package_count}
Flatpak Availability: ${flatpak_status}
Installed Flatpak Package Count: ${flatpak_package_count}
Collection Status: Success

Collected Artifacts
-------------------
dpkg-packages.txt
apt-manual-packages.txt
snap-packages.txt
flatpak-packages.txt
EOF
    then
        operator_error "Unable to write Admin01 package summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin01 package summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin01 package summary is empty."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin01 package inventory collected successfully."
    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_administrator_environment
#
# Purpose:
#   Collect rebuild-relevant Admin01 administrator configuration without
#   collecting private SSH keys, tokens, credential stores, or unrelated data.
###############################################################################

_collect_administrator_environment() {
    local git_config_file="${POLARIS_ADMIN01_ENVIRONMENT_DIR}/git-config.txt"
    local shell_profile_file="${POLARIS_ADMIN01_ENVIRONMENT_DIR}/shell-profile.txt"
    local bashrc_file="${POLARIS_ADMIN01_ENVIRONMENT_DIR}/bashrc.txt"
    local ssh_config_file="${POLARIS_ADMIN01_ENVIRONMENT_DIR}/ssh-config.txt"
    local ssh_public_keys_file="${POLARIS_ADMIN01_ENVIRONMENT_DIR}/ssh-public-keys.txt"
    local authorized_keys_file="${POLARIS_ADMIN01_ENVIRONMENT_DIR}/authorized-keys.txt"
    local vscode_settings_file="${POLARIS_ADMIN01_ENVIRONMENT_DIR}/vscode-settings.json"
    local vscode_extensions_file="${POLARIS_ADMIN01_ENVIRONMENT_DIR}/vscode-extensions.txt"
    local tool_versions_file="${POLARIS_ADMIN01_ENVIRONMENT_DIR}/admin-tool-versions.txt"
    local summary_file="${POLARIS_ADMIN01_ENVIRONMENT_DIR}/administrator-environment-summary.txt"

    local git_config_status="Not Present"
    local ssh_config_status="Not Present"
    local ssh_public_key_count=0
    local authorized_key_count=0
    local vscode_settings_status="Not Present"
    local vscode_extension_count=0

    log_info "Collecting Admin01 administrator environment."

    if [[ -z "${POLARIS_ADMIN01_ENVIRONMENT_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN01_ENVIRONMENT_DIR}" ]]
    then
        operator_error \
            "Admin01 administrator-environment staging directory has not been initialized."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    _admin01_remote_execute_to_file \
        'if [ -r "${HOME}/.gitconfig" ]; then
             cat "${HOME}/.gitconfig";
         else
             printf "User Git configuration is not present.\n";
         fi' \
        "${git_config_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'if [ -r "${HOME}/.profile" ]; then
             cat "${HOME}/.profile";
         else
             printf "User shell profile is not present.\n";
         fi' \
        "${shell_profile_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'if [ -r "${HOME}/.bashrc" ]; then
             cat "${HOME}/.bashrc";
         else
             printf "User Bash configuration is not present.\n";
         fi' \
        "${bashrc_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'if [ -r "${HOME}/.ssh/config" ]; then
             cat "${HOME}/.ssh/config";
         else
             printf "User SSH client configuration is not present.\n";
         fi' \
        "${ssh_config_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'found=0;
         for key_file in "${HOME}"/.ssh/*.pub; do
             [ -f "${key_file}" ] || continue;
             found=1;
             printf "=== %s ===\n" "$(basename "${key_file}")";
             cat "${key_file}";
             printf "\n";
         done;
         if [ "${found}" -eq 0 ]; then
             printf "No SSH public keys are present.\n";
         fi' \
        "${ssh_public_keys_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'if [ -r "${HOME}/.ssh/authorized_keys" ]; then
             cat "${HOME}/.ssh/authorized_keys";
         else
             printf "User authorized_keys file is not present.\n";
         fi' \
        "${authorized_keys_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'settings="${HOME}/.config/Code/User/settings.json";
         if [ -r "${settings}" ]; then
             cat "${settings}";
         else
             printf "{\n  \"status\": \"VS Code settings are not present\"\n}\n";
         fi' \
        "${vscode_settings_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'if command -v code >/dev/null 2>&1; then
             code --list-extensions 2>/dev/null | sort;
         else
             printf "VS Code command is unavailable.\n";
         fi' \
        "${vscode_extensions_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'for tool in git ssh code pwsh tailscale rustdesk; do
             printf "%s: " "${tool}";
             case "${tool}" in
                 git)
                     if command -v git >/dev/null 2>&1; then git --version; else printf "unavailable\n"; fi
                     ;;
                 ssh)
                     if command -v ssh >/dev/null 2>&1; then ssh -V 2>&1; else printf "unavailable\n"; fi
                     ;;
                 code)
                     if command -v code >/dev/null 2>&1; then code --version 2>/dev/null | head -n 1; else printf "unavailable\n"; fi
                     ;;
                 pwsh)
                     if command -v pwsh >/dev/null 2>&1; then pwsh -NoLogo -NoProfile -Command "$PSVersionTable.PSVersion.ToString()" 2>/dev/null; else printf "unavailable\n"; fi
                     ;;
                 tailscale)
                     if command -v tailscale >/dev/null 2>&1; then tailscale version | head -n 1; else printf "unavailable\n"; fi
                     ;;
                 rustdesk)
                     if command -v rustdesk >/dev/null 2>&1; then rustdesk --version 2>/dev/null | head -n 1; else printf "unavailable\n"; fi
                     ;;
             esac
         done' \
        "${tool_versions_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    if ! grep -qx 'User Git configuration is not present\.' "${git_config_file}"; then
        git_config_status="Present"
    fi

    if ! grep -qx 'User SSH client configuration is not present\.' "${ssh_config_file}"; then
        ssh_config_status="Present"
    fi

    if grep -qx 'No SSH public keys are present\.' "${ssh_public_keys_file}"; then
        ssh_public_key_count=0
    else
        ssh_public_key_count="$(
            grep -c '^=== .*\.pub ===$' "${ssh_public_keys_file}" || true
        )"
    fi

    if grep -qx 'User authorized_keys file is not present\.' "${authorized_keys_file}"; then
        authorized_key_count=0
    else
        authorized_key_count="$(
            awk '
                /^[[:space:]]*#/ { next }
                /^[[:space:]]*$/ { next }
                { count++ }
                END { print count + 0 }
            ' "${authorized_keys_file}"
        )"
    fi

    if grep -q '"status": "VS Code settings are not present"' "${vscode_settings_file}"; then
        vscode_settings_status="Not Present"
    else
        vscode_settings_status="Present"
    fi

    if grep -qx 'VS Code command is unavailable\.' "${vscode_extensions_file}"; then
        vscode_extension_count=0
    else
        vscode_extension_count="$(
            awk '
                NF > 0 { count++ }
                END { print count + 0 }
            ' "${vscode_extensions_file}"
        )"
    fi

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin01 Administrator Environment Summary
=========================================================

Target Host: ${POLARIS_ADMIN01_HOST}
Remote User: ${POLARIS_ADMIN01_USER}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

User Git Configuration: ${git_config_status}
User SSH Client Configuration: ${ssh_config_status}
SSH Public Key Count: ${ssh_public_key_count}
Authorized Key Count: ${authorized_key_count}
VS Code Settings: ${vscode_settings_status}
VS Code Extension Count: ${vscode_extension_count}
Private SSH Keys Included: no
Credential Stores Included: no
Collection Status: Success

Collected Artifacts
-------------------
git-config.txt
shell-profile.txt
bashrc.txt
ssh-config.txt
ssh-public-keys.txt
authorized-keys.txt
vscode-settings.json
vscode-extensions.txt
admin-tool-versions.txt
EOF
    then
        operator_error \
            "Unable to write Admin01 administrator-environment summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error \
            "Unable to secure Admin01 administrator-environment summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error \
            "Admin01 administrator-environment summary is empty."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Admin01 administrator environment collected successfully."

    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_project_polaris_workspace
#
# Purpose:
#   Inventory Project Polaris workspaces and Git repositories on Admin01
#   without copying repository contents, credentials, private keys, or secrets.
###############################################################################

_collect_project_polaris_workspace() {
    local workspace_paths_file="${POLARIS_ADMIN01_WORKSPACE_DIR}/workspace-paths.txt"
    local repositories_file="${POLARIS_ADMIN01_WORKSPACE_DIR}/git-repositories.txt"
    local repository_status_file="${POLARIS_ADMIN01_WORKSPACE_DIR}/git-repository-status.txt"
    local repository_remotes_file="${POLARIS_ADMIN01_WORKSPACE_DIR}/git-repository-remotes.txt"
    local polaris_tools_file="${POLARIS_ADMIN01_WORKSPACE_DIR}/project-polaris-tools.txt"
    local summary_file="${POLARIS_ADMIN01_WORKSPACE_DIR}/workspace-summary.txt"

    local workspace_count=0
    local repository_count=0
    local dirty_repository_count=0
    local remote_count=0

    log_info "Collecting Admin01 Project Polaris workspace metadata."

    if [[ -z "${POLARIS_ADMIN01_WORKSPACE_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN01_WORKSPACE_DIR}" ]]
    then
        operator_error \
            "Admin01 Project Polaris workspace staging directory has not been initialized."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    _admin01_remote_execute_to_file \
        'for candidate in \
             "${HOME}/Git" \
             "${HOME}/Projects" \
             "${HOME}/project-polaris" \
             "${HOME}/ProjectPolaris" \
             "/opt/project-polaris"; do
             if [ -e "${candidate}" ]; then
                 if [ -d "${candidate}" ]; then
                     printf "directory\t%s\n" "${candidate}";
                 elif [ -f "${candidate}" ]; then
                     printf "file\t%s\n" "${candidate}";
                 fi;
             fi;
         done;
         found=0;
         for root in "${HOME}/Git" "${HOME}/Projects"; do
             [ -d "${root}" ] || continue;
             while IFS= read -r path; do
                 found=1;
                 printf "directory\t%s\n" "${path}";
             done < <(
                 find "${root}" \
                     -mindepth 1 \
                     -maxdepth 2 \
                     -type d \
                     \( -iname "*polaris*" -o -iname "*homelab*" \) \
                     -print 2>/dev/null | sort
             );
         done;
         if [ "${found}" -eq 0 ] && \
            ! [ -e "${HOME}/Git" ] && \
            ! [ -e "${HOME}/Projects" ] && \
            ! [ -e "${HOME}/project-polaris" ] && \
            ! [ -e "${HOME}/ProjectPolaris" ] && \
            ! [ -e "/opt/project-polaris" ]; then
             printf "No recognized Project Polaris workspace paths were found.\n";
         fi' \
        "${workspace_paths_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'found=0;
         for root in "${HOME}/Git" "${HOME}/Projects"; do
             [ -d "${root}" ] || continue;
             while IFS= read -r git_dir; do
                 found=1;
                 repository="${git_dir%/.git}";
                 printf "%s\n" "${repository}";
             done < <(
                 find "${root}" \
                     -mindepth 2 \
                     -maxdepth 4 \
                     -type d \
                     -name .git \
                     -print 2>/dev/null | sort
             );
         done;
         if [ "${found}" -eq 0 ]; then
             printf "No Git repositories were found in the recognized workspace roots.\n";
         fi' \
        "${repositories_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'found=0;
         for root in "${HOME}/Git" "${HOME}/Projects"; do
             [ -d "${root}" ] || continue;
             while IFS= read -r git_dir; do
                 found=1;
                 repository="${git_dir%/.git}";
                 printf "=== %s ===\n" "${repository}";
                 git -C "${repository}" status --short --branch 2>/dev/null || \
                     printf "Unable to read repository status.\n";
                 printf "\n";
             done < <(
                 find "${root}" \
                     -mindepth 2 \
                     -maxdepth 4 \
                     -type d \
                     -name .git \
                     -print 2>/dev/null | sort
             );
         done;
         if [ "${found}" -eq 0 ]; then
             printf "No Git repository status was available.\n";
         fi' \
        "${repository_status_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'found=0;
         for root in "${HOME}/Git" "${HOME}/Projects"; do
             [ -d "${root}" ] || continue;
             while IFS= read -r git_dir; do
                 found=1;
                 repository="${git_dir%/.git}";
                 printf "=== %s ===\n" "${repository}";
                 git -C "${repository}" remote -v 2>/dev/null | \
                     sed -E "s#(https?://)[^/@]+:[^/@]+@#\1[redacted]@#g";
                 printf "\n";
             done < <(
                 find "${root}" \
                     -mindepth 2 \
                     -maxdepth 4 \
                     -type d \
                     -name .git \
                     -print 2>/dev/null | sort
             );
         done;
         if [ "${found}" -eq 0 ]; then
             printf "No Git repository remotes were available.\n";
         fi' \
        "${repository_remotes_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    _admin01_remote_execute_to_file \
        'printf "Project Polaris Administrative Tool Locations\n";
         printf "=============================================\n\n";
         for tool in git ssh scp rsync code pwsh tailscale rustdesk curl wget jq yq; do
             printf "%s: " "${tool}";
             if command -v "${tool}" >/dev/null 2>&1; then
                 command -v "${tool}";
             else
                 printf "unavailable\n";
             fi;
         done' \
        "${polaris_tools_file}" || \
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"

    if grep -qx 'No recognized Project Polaris workspace paths were found\.' \
        "${workspace_paths_file}"
    then
        workspace_count=0
    else
        workspace_count="$(
            awk '
                NF > 0 { count++ }
                END { print count + 0 }
            ' "${workspace_paths_file}"
        )"
    fi

    if grep -qx 'No Git repositories were found in the recognized workspace roots\.' \
        "${repositories_file}"
    then
        repository_count=0
    else
        repository_count="$(
            awk '
                NF > 0 { count++ }
                END { print count + 0 }
            ' "${repositories_file}"
        )"
    fi

    if grep -qx 'No Git repository status was available\.' \
        "${repository_status_file}"
    then
        dirty_repository_count=0
    else
        dirty_repository_count="$(
            awk '
                /^=== / {
                    in_repository=1
                    repository_dirty=0
                    next
                }

                /^[? MADRCU!][? MADRCU!][[:space:]]/ {
                    repository_dirty=1
                }

                /^$/ {
                    if (in_repository && repository_dirty) {
                        count++
                    }

                    in_repository=0
                    repository_dirty=0
                }

                END {
                    if (in_repository && repository_dirty) {
                        count++
                    }

                    print count + 0
                }
            ' "${repository_status_file}"
        )"
    fi

    if grep -qx 'No Git repository remotes were available\.' \
        "${repository_remotes_file}"
    then
        remote_count=0
    else
        remote_count="$(
            awk '
                /^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+\((fetch|push)\)$/ {
                    count++
                }
                END { print count + 0 }
            ' "${repository_remotes_file}"
        )"
    fi

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin01 Workspace Summary
=========================================

Target Host: ${POLARIS_ADMIN01_HOST}
Remote User: ${POLARIS_ADMIN01_USER}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Recognized Workspace Path Count: ${workspace_count}
Git Repository Count: ${repository_count}
Repositories With Uncommitted Changes: ${dirty_repository_count}
Configured Git Remote Entry Count: ${remote_count}
Repository Contents Included: no
Git Credentials Included: no
Private Keys Included: no
Collection Status: Success

Collected Artifacts
-------------------
workspace-paths.txt
git-repositories.txt
git-repository-status.txt
git-repository-remotes.txt
project-polaris-tools.txt
EOF
    then
        operator_error \
            "Unable to write Admin01 Project Polaris workspace summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error \
            "Unable to secure Admin01 Project Polaris workspace summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error \
            "Admin01 Project Polaris workspace summary is empty."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Admin01 Project Polaris workspace metadata collected successfully."

    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}


###############################################################################
# Function: _write_collector_info
#
# Purpose:
#   Record static information describing the Admin01 collector.
###############################################################################

_write_collector_info() {
    local output_file="${POLARIS_ADMIN01_METADATA_DIR}/collector-info.txt"

    if ! cat > "${output_file}" <<EOF
Collector Name: ${POLARIS_ADMIN01_MODULE_NAME}
Collector Display Name: ${POLARIS_ADMIN01_MODULE_DISPLAY_NAME}
Collector Version: ${POLARIS_ADMIN01_MODULE_VERSION}
Collector Author: ${POLARIS_ADMIN01_MODULE_AUTHOR}
Collection Mode: ${POLARIS_ADMIN01_COLLECTION_STATUS}
Framework Version: ${POLARIS_FRAMEWORK_VERSION}
Hash Algorithm: SHA-256
EOF
    then
        operator_error "Unable to write Admin01 collector information."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error "Unable to secure Admin01 collector information."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error "Admin01 collector information file is empty."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin01 collector information written successfully."
    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _write_execution_info
#
# Purpose:
#   Record execution-specific information for this collector run.
###############################################################################

_write_execution_info() {
    local output_file="${POLARIS_ADMIN01_METADATA_DIR}/execution.txt"
    local timestamp=""

    if ! timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; then
        operator_error "Unable to generate the Admin01 execution timestamp."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! cat > "${output_file}" <<EOF
Execution Timestamp (UTC): ${timestamp}
Collection Status: ${POLARIS_ADMIN01_COLLECTION_STATUS}
Staging Root: ${POLARIS_ADMIN01_STAGING_ROOT}
Configuration Directory: ${POLARIS_ADMIN01_ADMIN_DIR}
Admin01-Specific Collection Enabled: yes
Implemented Collection Stage: Complete Admin01 Configuration Inventory
EOF
    then
        operator_error "Unable to write Admin01 execution metadata."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error "Unable to secure Admin01 execution metadata."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error "Admin01 execution metadata file is empty."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin01 execution metadata written successfully."
    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _write_collection_summary
#
# Purpose:
#   Describe the current Stage 1A implementation boundary.
###############################################################################

_write_collection_summary() {
    local output_file="${POLARIS_ADMIN01_METADATA_DIR}/collection-summary.txt"
    local timestamp=""

    if ! timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; then
        operator_error "Unable to generate the Admin01 summary timestamp."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! cat > "${output_file}" <<EOF
Project Polaris Admin01 Collector Summary
=========================================

Collector Version: ${POLARIS_ADMIN01_MODULE_VERSION}
Execution Time (UTC): ${timestamp}
Status: SUCCESS
Collection Mode: Remote Identity and OS Inventory

Implemented
-----------
[COLLECTED] Collector metadata
[COLLECTED] Execution metadata
[COLLECTED] Collection summary
[COLLECTED] Integrity manifest
[COLLECTED] Remote SSH identity
[COLLECTED] Linux operating-system inventory
[COLLECTED] Network inventory
[COLLECTED] Filesystem and mount inventory
[COLLECTED] Services and scheduled-jobs inventory
[COLLECTED] Package inventory
[COLLECTED] Administrator environment
[COLLECTED] Project Polaris workspace metadata

Planned
-------
EOF
    then
        operator_error "Unable to write Admin01 collection summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error "Unable to secure Admin01 collection summary."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error "Admin01 collection summary is empty."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin01 collection summary written successfully."
    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _write_manifest
#
# Purpose:
#   Generate an integrity manifest for all permanent Stage 1A artifacts.
###############################################################################

_write_manifest() {
    local output_file="${POLARIS_ADMIN01_METADATA_DIR}/manifest.txt"

    if ! polaris_manifest_recursive \
        "${POLARIS_ADMIN01_STAGING_ROOT}" \
        "${output_file}" \
        "Admin01"
    then
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin01 integrity manifest written successfully."
    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _preserve_failure_artifacts
#
# Purpose:
#   Preserve available Admin01 staging data for troubleshooting.
###############################################################################

_preserve_failure_artifacts() {
    local troubleshooting_root="${1:-}"
    local failure_reason="${2:-unspecified failure}"

    polaris_preserve_failure_staging \
        "${troubleshooting_root}" \
        "admin01" \
        "Admin01" \
        "${POLARIS_ADMIN01_MODULE_VERSION}" \
        "${POLARIS_ADMIN01_COLLECTION_STATUS:-unavailable}" \
        "${failure_reason}" \
        "${POLARIS_ADMIN01_STAGING_ROOT}"
}

###############################################################################
# Function: _cleanup
#
# Purpose:
#   Remove failed active staging while leaving successful staging available to
#   the orchestrator lifecycle processor.
###############################################################################

_cleanup() {
    if [[ -z "${POLARIS_ADMIN01_STAGING_ROOT}" ]]; then
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
    fi

    if ! polaris_remove_staging_root "${POLARIS_ADMIN01_STAGING_ROOT}" "Admin01"; then
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_ADMIN01_STAGING_ROOT=""
    POLARIS_ADMIN01_CONFIGURATION_DIR=""
    POLARIS_ADMIN01_ADMIN_DIR=""
    POLARIS_ADMIN01_OS_DIR=""
    POLARIS_ADMIN01_NETWORK_DIR=""
    POLARIS_ADMIN01_FILESYSTEM_DIR=""
    POLARIS_ADMIN01_SERVICES_DIR=""
    POLARIS_ADMIN01_PACKAGES_DIR=""
    POLARIS_ADMIN01_ENVIRONMENT_DIR=""
    POLARIS_ADMIN01_WORKSPACE_DIR=""
    POLARIS_ADMIN01_METADATA_DIR=""

    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: collect_admin01
#
# Purpose:
#   Coordinate the Stage 1C.8 complete Admin01 configuration collection.
#
# Parameters:
#   $1 - Collector staging root.
#   $2 - Troubleshooting root.
###############################################################################

collect_admin01() {
    local staging_root="${1:-}"
    local troubleshooting_root="${2:-}"
    local failure_reason=""

    POLARIS_ADMIN01_STAGING_ROOT=""
    POLARIS_ADMIN01_CONFIGURATION_DIR=""
    POLARIS_ADMIN01_ADMIN_DIR=""
    POLARIS_ADMIN01_OS_DIR=""
    POLARIS_ADMIN01_NETWORK_DIR=""
    POLARIS_ADMIN01_FILESYSTEM_DIR=""
    POLARIS_ADMIN01_SERVICES_DIR=""
    POLARIS_ADMIN01_PACKAGES_DIR=""
    POLARIS_ADMIN01_ENVIRONMENT_DIR=""
    POLARIS_ADMIN01_WORKSPACE_DIR=""
    POLARIS_ADMIN01_METADATA_DIR=""
    POLARIS_ADMIN01_COLLECTION_STATUS=""

    if [[ -z "${staging_root}" ]] || [[ -z "${troubleshooting_root}" ]]; then
        operator_error "Admin01 collector paths were not provided."
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_info "Starting complete Admin01 configuration collection."

    if ! _validate_environment; then
        failure_reason="environment validation failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _initialize_staging "${staging_root}"; then
        failure_reason="staging initialization failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_remote_identity; then
        failure_reason="remote identity collection failed"

        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _cleanup || true

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_os_inventory; then
        failure_reason="operating-system inventory collection failed"

        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _cleanup || true

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_network_inventory; then
        failure_reason="network inventory collection failed"

        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _cleanup || true

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_filesystem_inventory; then
        failure_reason="filesystem and mount inventory collection failed"

        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _cleanup || true

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_services_inventory; then
        failure_reason="services and scheduled-jobs inventory collection failed"

        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _cleanup || true

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_package_inventory; then
        failure_reason="package inventory collection failed"

        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _cleanup || true

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_administrator_environment; then
        failure_reason="administrator environment collection failed"

        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _cleanup || true

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_project_polaris_workspace; then
        failure_reason="Project Polaris workspace metadata collection failed"

        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true

        _cleanup || true

        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_collector_info; then
        failure_reason="collector metadata generation failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_execution_info; then
        failure_reason="execution metadata generation failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_collection_summary; then
        failure_reason="collection summary generation failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_manifest; then
        failure_reason="manifest generation failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN01_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Complete Admin01 configuration collection completed successfully."
    return "${POLARIS_ADMIN01_COLLECTOR_RESULT_SUCCESS}"
}
