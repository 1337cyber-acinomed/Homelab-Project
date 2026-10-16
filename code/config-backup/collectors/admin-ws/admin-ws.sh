#!/usr/bin/env bash

[[ -n "${POLARIS_ADMIN_WS_SH_LOADED:-}" ]] && return 0
readonly POLARIS_ADMIN_WS_SH_LOADED=1

###############################################################################
# Project Polaris
# Admin-WS Configuration Collector
###############################################################################

###############################################################################
# Framework Initialization
###############################################################################

POLARIS_ADMIN_WS_COLLECTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly POLARIS_ADMIN_WS_COLLECTOR_DIR

POLARIS_ADMIN_WS_FRAMEWORK_ROOT="$(cd -- "${POLARIS_ADMIN_WS_COLLECTOR_DIR}/../.." && pwd -P)"
readonly POLARIS_ADMIN_WS_FRAMEWORK_ROOT

readonly POLARIS_ADMIN_WS_LIB_DIR="${POLARIS_ADMIN_WS_FRAMEWORK_ROOT}/lib"

# shellcheck source=/dev/null
source "${POLARIS_ADMIN_WS_LIB_DIR}/polaris-common.sh"

###############################################################################
# Collector Result Codes
###############################################################################

readonly POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_ADMIN_WS_COLLECTOR_RESULT_NO_CHANGE=2

###############################################################################
# Module Metadata
###############################################################################

readonly POLARIS_ADMIN_WS_MODULE_NAME="admin-ws"
readonly POLARIS_ADMIN_WS_MODULE_DISPLAY_NAME="Admin-WS Collector"
readonly POLARIS_ADMIN_WS_MODULE_VERSION="1.7.0"
readonly POLARIS_ADMIN_WS_MODULE_AUTHOR="Project Polaris"

###############################################################################
# Remote Access
###############################################################################

readonly POLARIS_ADMIN_WS_HOST="192.168.10.41"
readonly POLARIS_ADMIN_WS_USER="polaris-admws-backup"
readonly POLARIS_ADMIN_WS_SSH_KEY="/root/.ssh/polaris-admws-backup"
readonly POLARIS_ADMIN_WS_SSH_CONNECT_TIMEOUT=20

###############################################################################
# Collector Constants
###############################################################################

readonly ADMIN_WS_COLLECTION_STATUS_COMPLETE_CONFIGURATION="complete-admin-ws-configuration-inventory"

###############################################################################
# Module State
###############################################################################

POLARIS_ADMIN_WS_STAGING_ROOT=""
POLARIS_ADMIN_WS_CONFIGURATION_DIR=""
POLARIS_ADMIN_WS_HOST_DIR=""
POLARIS_ADMIN_WS_OS_DIR=""
POLARIS_ADMIN_WS_NETWORK_DIR=""
POLARIS_ADMIN_WS_STORAGE_DIR=""
POLARIS_ADMIN_WS_SERVICES_DIR=""
POLARIS_ADMIN_WS_SOFTWARE_DIR=""
POLARIS_ADMIN_WS_ENVIRONMENT_DIR=""
POLARIS_ADMIN_WS_WORKSPACE_DIR=""
POLARIS_ADMIN_WS_METADATA_DIR=""
POLARIS_ADMIN_WS_COLLECTION_STATUS=""

###############################################################################
# Function: _admin_ws_remote_execute
#
# Purpose:
#   Execute one noninteractive command on Admin-WS through OpenSSH.
###############################################################################

_admin_ws_remote_execute() {
    local remote_command="${1:-}"

    if [[ -z "${remote_command}" ]]; then
        operator_error "Admin-WS remote command was not provided."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    polaris_ssh_execute \
        "${POLARIS_ADMIN_WS_HOST}" \
        "${POLARIS_ADMIN_WS_USER}" \
        "${POLARIS_ADMIN_WS_SSH_KEY}" \
        "${POLARIS_ADMIN_WS_SSH_CONNECT_TIMEOUT}" \
        "disable" \
        "yes" \
        "${remote_command}"
}

###############################################################################
# Function: _admin_ws_remote_execute_to_file
#
# Purpose:
#   Execute one Admin-WS command and preserve its output as a secured artifact.
###############################################################################

_admin_ws_remote_execute_to_file() {
    local remote_command="${1:-}"
    local output_file="${2:-}"

    if [[ -z "${remote_command}" ]]; then
        operator_error "Admin-WS remote command was not provided."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ -z "${output_file}" ]]; then
        operator_error "Admin-WS remote output path was not provided."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! polaris_ssh_execute_to_file \
        "${POLARIS_ADMIN_WS_HOST}" \
        "${POLARIS_ADMIN_WS_USER}" \
        "${POLARIS_ADMIN_WS_SSH_KEY}" \
        "${POLARIS_ADMIN_WS_SSH_CONNECT_TIMEOUT}" \
        "disable" \
        "yes" \
        "${remote_command}" \
        "${output_file}" \
        "reject" \
        "Admin-WS" \
        "${POLARIS_ADMIN_WS_SSH_CONTROL_PATH:-}"
    then
        operator_error "Admin-WS remote command failed: ${remote_command}"
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    # PowerShell's native output uses CRLF line endings. Nothing in the
    # shared SSH transport (polaris_ssh_execute_to_file, used by every
    # collector in this framework) converts this, since Admin-WS is the
    # only Windows target - every other collector's remote output is
    # already LF-only. Left uncorrected, a trailing \r silently breaks
    # every exact-match marker check (grep -qx) and every last-field
    # awk comparison ($NF == "...") throughout this entire file, since
    # "Installed\r" never equals the bareword "Installed". Normalized
    # once, here, immediately after every remote command's output is
    # captured, so nothing downstream ever has to account for it.
    if ! sed -i 's/\r$//' "${output_file}"; then
        operator_error "Unable to normalize Admin-WS remote command output: ${remote_command}"
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _validate_environment
#
# Purpose:
#   Validate local framework requirements and unattended Admin-WS SSH access.
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

    log_info "Validating Admin-WS collector environment."

    if ! is_root_user; then
        operator_error "Collector must be run as root."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    for required_command in "${required_commands[@]}"; do
        if ! command_exists "${required_command}"; then
            operator_error \
                "Required command is not available: ${required_command}"
            return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
        fi
    done

    if [[ ! -r "${POLARIS_ADMIN_WS_SSH_KEY}" ]]; then
        operator_error \
            "Admin-WS SSH private key is not readable: ${POLARIS_ADMIN_WS_SSH_KEY}"
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _admin_ws_remote_execute \
        'hostname >NUL 2>&1 && whoami >NUL 2>&1 && powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$PSVersionTable.PSVersion.ToString()" >NUL 2>&1'
    then
        operator_error \
            "Unable to validate unattended SSH and PowerShell access to Admin-WS."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin-WS collector environment validation successful."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _initialize_staging
#
# Purpose:
#   Create the Stage 2C.1 Admin-WS configuration and metadata directories.
###############################################################################

_initialize_staging() {
    local staging_root="${1:-}"

    if [[ -z "${staging_root}" ]]; then
        operator_error "Admin-WS staging root was not provided."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_ADMIN_WS_STAGING_ROOT="${staging_root}"
    POLARIS_ADMIN_WS_CONFIGURATION_DIR="${POLARIS_ADMIN_WS_STAGING_ROOT}/configuration"
    POLARIS_ADMIN_WS_HOST_DIR="${POLARIS_ADMIN_WS_CONFIGURATION_DIR}/admin-ws"
    POLARIS_ADMIN_WS_OS_DIR="${POLARIS_ADMIN_WS_HOST_DIR}/os"
    POLARIS_ADMIN_WS_NETWORK_DIR="${POLARIS_ADMIN_WS_HOST_DIR}/network"
    POLARIS_ADMIN_WS_STORAGE_DIR="${POLARIS_ADMIN_WS_HOST_DIR}/storage"
    POLARIS_ADMIN_WS_SERVICES_DIR="${POLARIS_ADMIN_WS_HOST_DIR}/services"
    POLARIS_ADMIN_WS_SOFTWARE_DIR="${POLARIS_ADMIN_WS_HOST_DIR}/software"
    POLARIS_ADMIN_WS_ENVIRONMENT_DIR="${POLARIS_ADMIN_WS_HOST_DIR}/administrator-environment"
    POLARIS_ADMIN_WS_WORKSPACE_DIR="${POLARIS_ADMIN_WS_HOST_DIR}/project-polaris-workspace"
    POLARIS_ADMIN_WS_METADATA_DIR="${POLARIS_ADMIN_WS_STAGING_ROOT}/metadata"

    if ! polaris_prepare_staging_directories \
        "${POLARIS_ADMIN_WS_STAGING_ROOT}" \
        "Admin-WS" \
        "${POLARIS_ADMIN_WS_HOST_DIR}" \
        "${POLARIS_ADMIN_WS_OS_DIR}" \
        "${POLARIS_ADMIN_WS_NETWORK_DIR}" \
        "${POLARIS_ADMIN_WS_STORAGE_DIR}" \
        "${POLARIS_ADMIN_WS_SERVICES_DIR}" \
        "${POLARIS_ADMIN_WS_SOFTWARE_DIR}" \
        "${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}" \
        "${POLARIS_ADMIN_WS_WORKSPACE_DIR}" \
        "${POLARIS_ADMIN_WS_METADATA_DIR}"
    then
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_ADMIN_WS_COLLECTION_STATUS="${ADMIN_WS_COLLECTION_STATUS_COMPLETE_CONFIGURATION}"

    log_success "Admin-WS staging directories initialized."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _collect_remote_identity
#
# Purpose:
#   Collect simple authoritative Windows identity artifacts and generate the
#   human-readable remote identity summary locally.
###############################################################################

_collect_remote_identity() {
    local hostname_file="${POLARIS_ADMIN_WS_HOST_DIR}/hostname.txt"
    local whoami_file="${POLARIS_ADMIN_WS_HOST_DIR}/whoami.txt"
    local user_profile_file="${POLARIS_ADMIN_WS_HOST_DIR}/user-profile.txt"
    local command_shell_file="${POLARIS_ADMIN_WS_HOST_DIR}/command-shell.txt"
    local powershell_version_file="${POLARIS_ADMIN_WS_HOST_DIR}/powershell-version.txt"
    local operating_system_file="${POLARIS_ADMIN_WS_HOST_DIR}/operating-system.txt"
    local domain_file="${POLARIS_ADMIN_WS_HOST_DIR}/domain.txt"
    local summary_file="${POLARIS_ADMIN_WS_HOST_DIR}/remote-identity.txt"

    local hostname_value=""
    local identity_value=""
    local user_profile_value=""
    local command_shell_value=""
    local powershell_version_value=""
    local operating_system_value=""
    local domain_value=""

    log_info "Collecting Admin-WS remote identity."

    if [[ -z "${POLARIS_ADMIN_WS_HOST_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN_WS_HOST_DIR}" ]]
    then
        operator_error \
            "Admin-WS configuration staging directory has not been initialized."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    _admin_ws_remote_execute_to_file \
        'hostname' \
        "${hostname_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'whoami' \
        "${whoami_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$env:USERPROFILE"' \
        "${user_profile_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$env:COMSPEC"' \
        "${command_shell_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$PSVersionTable.PSVersion.ToString()"' \
        "${powershell_version_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "(Get-CimInstance Win32_OperatingSystem).Caption"' \
        "${operating_system_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "(Get-CimInstance Win32_ComputerSystem).Domain"' \
        "${domain_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    hostname_value="$(head -n 1 "${hostname_file}")"
    identity_value="$(head -n 1 "${whoami_file}")"
    user_profile_value="$(head -n 1 "${user_profile_file}")"
    command_shell_value="$(head -n 1 "${command_shell_file}")"
    powershell_version_value="$(head -n 1 "${powershell_version_file}")"
    operating_system_value="$(head -n 1 "${operating_system_file}")"
    domain_value="$(head -n 1 "${domain_file}")"

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin-WS Remote Identity
========================================

Target Host: ${POLARIS_ADMIN_WS_HOST}
Remote User: ${POLARIS_ADMIN_WS_USER}
Transport: OpenSSH
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Hostname: ${hostname_value}
Remote Identity: ${identity_value}
User Profile: ${user_profile_value}
Command Shell: ${command_shell_value}
PowerShell Version: ${powershell_version_value}
Operating System: ${operating_system_value}
Domain: ${domain_value}
Collection Status: Success
EOF
    then
        operator_error "Unable to write Admin-WS remote identity summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin-WS remote identity summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin-WS remote identity summary is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin-WS remote identity collected successfully."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_os_inventory
#
# Purpose:
#   Collect authoritative Windows operating-system and computer identity
#   artifacts and generate a concise local summary.
###############################################################################

_collect_os_inventory() {
    local computer_info_file="${POLARIS_ADMIN_WS_OS_DIR}/computer-info.txt"
    local operating_system_file="${POLARIS_ADMIN_WS_OS_DIR}/operating-system.txt"
    local computer_system_file="${POLARIS_ADMIN_WS_OS_DIR}/computer-system.txt"
    local bios_file="${POLARIS_ADMIN_WS_OS_DIR}/bios.txt"
    local hotfixes_file="${POLARIS_ADMIN_WS_OS_DIR}/hotfixes.txt"
    local powershell_version_file="${POLARIS_ADMIN_WS_OS_DIR}/powershell-version.txt"
    local summary_file="${POLARIS_ADMIN_WS_OS_DIR}/os-summary.txt"

    local os_caption="Unavailable"
    local os_version="Unavailable"
    local os_build="Unavailable"
    local architecture="Unavailable"
    local domain="Unavailable"
    local manufacturer="Unavailable"
    local model="Unavailable"
    local bios_version="Unavailable"
    local hotfix_count=0
    local powershell_version="Unavailable"

    log_info "Collecting Admin-WS operating-system inventory."

    if [[ -z "${POLARIS_ADMIN_WS_OS_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN_WS_OS_DIR}" ]]
    then
        operator_error \
            "Admin-WS OS staging directory has not been initialized."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-ComputerInfo | Format-List *"' \
        "${computer_info_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture,InstallDate,LastBootUpTime,WindowsDirectory,SystemDirectory | Format-List"' \
        "${operating_system_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-CimInstance Win32_ComputerSystem | Select-Object Name,Domain,DomainRole,Manufacturer,Model,SystemType,TotalPhysicalMemory,UserName | Format-List"' \
        "${computer_system_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-CimInstance Win32_BIOS | Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate,SerialNumber | Format-List"' \
        "${bios_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$items = Get-HotFix | Sort-Object InstalledOn,HotFixID; if ($items) { $items | Select-Object HotFixID,Description,InstalledBy,InstalledOn | Format-Table -AutoSize } else { Write-Output ''No installed hotfixes were reported.'' }"' \
        "${hotfixes_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$PSVersionTable | Format-List *"' \
        "${powershell_version_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    os_caption="$(
        awk -F: '
            /^[[:space:]]*Caption[[:space:]]*:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${operating_system_file}"
    )"

    os_version="$(
        awk -F: '
            /^[[:space:]]*Version[[:space:]]*:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${operating_system_file}"
    )"

    os_build="$(
        awk -F: '
            /^[[:space:]]*BuildNumber[[:space:]]*:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${operating_system_file}"
    )"

    architecture="$(
        awk -F: '
            /^[[:space:]]*OSArchitecture[[:space:]]*:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${operating_system_file}"
    )"

    domain="$(
        awk -F: '
            /^[[:space:]]*Domain[[:space:]]*:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${computer_system_file}"
    )"

    manufacturer="$(
        awk -F: '
            /^[[:space:]]*Manufacturer[[:space:]]*:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${computer_system_file}"
    )"

    model="$(
        awk -F: '
            /^[[:space:]]*Model[[:space:]]*:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${computer_system_file}"
    )"

    bios_version="$(
        awk -F: '
            /^[[:space:]]*SMBIOSBIOSVersion[[:space:]]*:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${bios_file}"
    )"

    if grep -qx 'No installed hotfixes were reported\.' "${hotfixes_file}"; then
        hotfix_count=0
    else
        hotfix_count="$(
            awk '
                /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]+/ {
                    if ($1 != "HotFixID" && $1 !~ /^-+$/) {
                        count++
                    }
                }
                END {
                    print count + 0
                }
            ' "${hotfixes_file}"
        )"
    fi

    powershell_version="$(
        awk -F: '
            /^[[:space:]]*PSVersion[[:space:]]*:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                print value
                exit
            }
        ' "${powershell_version_file}"
    )"

    [[ -n "${os_caption}" ]] || os_caption="Unavailable"
    [[ -n "${os_version}" ]] || os_version="Unavailable"
    [[ -n "${os_build}" ]] || os_build="Unavailable"
    [[ -n "${architecture}" ]] || architecture="Unavailable"
    [[ -n "${domain}" ]] || domain="Unavailable"
    [[ -n "${manufacturer}" ]] || manufacturer="Unavailable"
    [[ -n "${model}" ]] || model="Unavailable"
    [[ -n "${bios_version}" ]] || bios_version="Unavailable"
    [[ -n "${powershell_version}" ]] || powershell_version="Unavailable"

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin-WS Operating System Summary
=================================================

Target Host: ${POLARIS_ADMIN_WS_HOST}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Operating System: ${os_caption}
OS Version: ${os_version}
OS Build: ${os_build}
Architecture: ${architecture}
Domain: ${domain}
Manufacturer: ${manufacturer}
Model: ${model}
BIOS Version: ${bios_version}
Installed Hotfix Count: ${hotfix_count}
PowerShell Version: ${powershell_version}
Collection Status: Success

Collected Artifacts
-------------------
computer-info.txt
operating-system.txt
computer-system.txt
bios.txt
hotfixes.txt
powershell-version.txt
EOF
    then
        operator_error "Unable to write Admin-WS operating-system summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin-WS operating-system summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin-WS operating-system summary is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin-WS operating-system inventory collected successfully."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_network_inventory
#
# Purpose:
#   Collect authoritative Admin-WS network configuration and generate a concise
#   local summary from the collected artifacts.
###############################################################################

_collect_network_inventory() {
    local adapters_file="${POLARIS_ADMIN_WS_NETWORK_DIR}/network-adapters.txt"
    local ip_configuration_file="${POLARIS_ADMIN_WS_NETWORK_DIR}/ip-configuration.txt"
    local ip_addresses_file="${POLARIS_ADMIN_WS_NETWORK_DIR}/ip-addresses.txt"
    local routes_file="${POLARIS_ADMIN_WS_NETWORK_DIR}/routes.txt"
    local dns_client_file="${POLARIS_ADMIN_WS_NETWORK_DIR}/dns-client.txt"
    local dns_servers_file="${POLARIS_ADMIN_WS_NETWORK_DIR}/dns-servers.txt"
    local connection_profiles_file="${POLARIS_ADMIN_WS_NETWORK_DIR}/connection-profiles.txt"
    local firewall_profiles_file="${POLARIS_ADMIN_WS_NETWORK_DIR}/firewall-profiles.txt"
    local summary_file="${POLARIS_ADMIN_WS_NETWORK_DIR}/network-summary.txt"

    local adapter_count=0
    local active_adapter_count=0
    local ipv4_count=0
    local ipv6_count=0
    local default_route_count=0
    local dns_server_count=0
    local domain_profile_count=0

    log_info "Collecting Admin-WS network inventory."

    if [[ -z "${POLARIS_ADMIN_WS_NETWORK_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN_WS_NETWORK_DIR}" ]]
    then
        operator_error \
            "Admin-WS network staging directory has not been initialized."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-NetAdapter | Sort-Object Name | Select-Object Name,InterfaceDescription,Status,MacAddress,LinkSpeed,MediaConnectionState | Format-Table -AutoSize"' \
        "${adapters_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-NetIPConfiguration | Sort-Object InterfaceAlias | Format-List InterfaceAlias,InterfaceIndex,IPv4Address,IPv6Address,IPv4DefaultGateway,DNSServer,NetProfile"' \
        "${ip_configuration_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-NetIPAddress | Sort-Object InterfaceAlias,AddressFamily,IPAddress | Select-Object InterfaceAlias,InterfaceIndex,AddressFamily,IPAddress,PrefixLength,AddressState,PrefixOrigin,SuffixOrigin | Format-Table -AutoSize"' \
        "${ip_addresses_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-NetRoute | Sort-Object AddressFamily,DestinationPrefix,RouteMetric | Select-Object InterfaceAlias,AddressFamily,DestinationPrefix,NextHop,RouteMetric,Protocol,State | Format-Table -AutoSize"' \
        "${routes_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-DnsClient | Sort-Object InterfaceAlias | Select-Object InterfaceAlias,InterfaceIndex,ConnectionSpecificSuffix,RegisterThisConnectionsAddress,UseSuffixWhenRegistering | Format-Table -AutoSize"' \
        "${dns_client_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-DnsClientServerAddress | Sort-Object InterfaceAlias,AddressFamily | Select-Object InterfaceAlias,InterfaceIndex,AddressFamily,ServerAddresses | Format-List"' \
        "${dns_servers_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-NetConnectionProfile | Sort-Object InterfaceAlias | Select-Object Name,InterfaceAlias,InterfaceIndex,NetworkCategory,IPv4Connectivity,IPv6Connectivity | Format-Table -AutoSize"' \
        "${connection_profiles_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-NetFirewallProfile | Sort-Object Name | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction,AllowInboundRules,AllowLocalFirewallRules,LogAllowed,LogBlocked | Format-List"' \
        "${firewall_profiles_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    adapter_count="$(
        awk '
            /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]+/ {
                if ($1 != "Name" && $1 !~ /^-+$/) {
                    count++
                }
            }
            END {
                print count + 0
            }
        ' "${adapters_file}"
    )"

    active_adapter_count="$(
        awk '
            /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]+/ {
                if ($0 ~ /[[:space:]]Up[[:space:]]/) {
                    count++
                }
            }
            END {
                print count + 0
            }
        ' "${adapters_file}"
    )"

    ipv4_count="$(
        awk '
            /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]+[0-9]+[[:space:]]+IPv4[[:space:]]+/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${ip_addresses_file}"
    )"

    ipv6_count="$(
        awk '
            /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]+[0-9]+[[:space:]]+IPv6[[:space:]]+/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${ip_addresses_file}"
    )"

    default_route_count="$(
        awk '
            /(^|[[:space:]])0\.0\.0\.0\/0([[:space:]]|$)/ ||
            /(^|[[:space:]])::\/0([[:space:]]|$)/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${routes_file}"
    )"

    dns_server_count="$(
        awk -F: '
            /^[[:space:]]*ServerAddresses[[:space:]]*:/ {
                value=$2
                sub(/^[[:space:]]+/, "", value)
                gsub(/[{},]/, " ", value)
                count += split(value, items, /[[:space:]]+/)
            }
            END {
                print count + 0
            }
        ' "${dns_servers_file}"
    )"

    domain_profile_count="$(
        awk '
            /DomainAuthenticated/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${connection_profiles_file}"
    )"

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin-WS Network Summary
========================================

Target Host: ${POLARIS_ADMIN_WS_HOST}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Network Adapter Count: ${adapter_count}
Active Network Adapter Count: ${active_adapter_count}
IPv4 Address Count: ${ipv4_count}
IPv6 Address Count: ${ipv6_count}
Default Route Count: ${default_route_count}
Configured DNS Server Count: ${dns_server_count}
Domain-Authenticated Connection Profile Count: ${domain_profile_count}
Collection Status: Success

Collected Artifacts
-------------------
network-adapters.txt
ip-configuration.txt
ip-addresses.txt
routes.txt
dns-client.txt
dns-servers.txt
connection-profiles.txt
firewall-profiles.txt
EOF
    then
        operator_error "Unable to write Admin-WS network summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin-WS network summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin-WS network summary is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin-WS network inventory collected successfully."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_storage_inventory
#
# Purpose:
#   Collect authoritative Admin-WS disk, partition, volume, and logical-drive
#   configuration and generate a concise local summary.
###############################################################################

_collect_storage_inventory() {
    local disks_file="${POLARIS_ADMIN_WS_STORAGE_DIR}/disks.txt"
    local partitions_file="${POLARIS_ADMIN_WS_STORAGE_DIR}/partitions.txt"
    local volumes_file="${POLARIS_ADMIN_WS_STORAGE_DIR}/volumes.txt"
    local logical_disks_file="${POLARIS_ADMIN_WS_STORAGE_DIR}/logical-disks.txt"
    local filesystem_drives_file="${POLARIS_ADMIN_WS_STORAGE_DIR}/filesystem-drives.txt"
    local storage_pools_file="${POLARIS_ADMIN_WS_STORAGE_DIR}/storage-pools.txt"
    local summary_file="${POLARIS_ADMIN_WS_STORAGE_DIR}/storage-summary.txt"

    local disk_count=0
    local online_disk_count=0
    local partition_count=0
    local volume_count=0
    local fixed_logical_disk_count=0
    local storage_pool_count=0
    local system_drive="Unavailable"
    local system_drive_filesystem="Unavailable"

    log_info "Collecting Admin-WS storage inventory."

    if [[ -z "${POLARIS_ADMIN_WS_STORAGE_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN_WS_STORAGE_DIR}" ]]
    then
        operator_error \
            "Admin-WS storage staging directory has not been initialized."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$items = Get-Disk -ErrorAction SilentlyContinue | Sort-Object Number; if ($items) { $items | Select-Object Number,FriendlyName,SerialNumber,BusType,PartitionStyle,OperationalStatus,HealthStatus,Size,IsBoot,IsSystem,IsReadOnly,IsOffline | Format-Table -AutoSize } else { Write-Output ''No physical disks were reported.'' }"' \
        "${disks_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$items = Get-Partition -ErrorAction SilentlyContinue | Sort-Object DiskNumber,PartitionNumber; if ($items) { $items | Select-Object DiskNumber,PartitionNumber,DriveLetter,Type,GptType,MbrType,Size,Offset,IsBoot,IsSystem,IsActive,IsHidden | Format-Table -AutoSize } else { Write-Output ''No partitions were reported.'' }"' \
        "${partitions_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$items = Get-Volume -ErrorAction SilentlyContinue | Sort-Object DriveLetter,FileSystemLabel; if ($items) { $items | Select-Object DriveLetter,FileSystemLabel,FileSystem,DriveType,HealthStatus,OperationalStatus,Size,SizeRemaining,Path | Format-Table -AutoSize } else { Write-Output ''No volumes were reported.'' }"' \
        "${volumes_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-CimInstance Win32_LogicalDisk | Sort-Object DeviceID | Select-Object DeviceID,VolumeName,FileSystem,DriveType,Size,FreeSpace,ProviderName | Format-Table -AutoSize"' \
        "${logical_disks_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-PSDrive -PSProvider FileSystem | Sort-Object Name | Select-Object Name,Root,Description,Used,Free,CurrentLocation,DisplayRoot | Format-Table -AutoSize"' \
        "${filesystem_drives_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$items = Get-StoragePool -ErrorAction SilentlyContinue | Sort-Object FriendlyName; if ($items) { $items | Select-Object FriendlyName,OperationalStatus,HealthStatus,IsPrimordial,Size,AllocatedSize | Format-Table -AutoSize } else { Write-Output ''No storage pools were reported.'' }"' \
        "${storage_pools_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    if grep -qx 'No physical disks were reported\.' "${disks_file}"; then
        disk_count=0
        online_disk_count=0
    else
        disk_count="$(
            awk '
                /^[[:space:]]*[0-9]+[[:space:]]+/ {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${disks_file}"
        )"

        online_disk_count="$(
            awk '
                /^[[:space:]]*[0-9]+[[:space:]]+/ &&
                $0 ~ /[[:space:]]Online[[:space:]]/ {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${disks_file}"
        )"
    fi

    if grep -qx 'No partitions were reported\.' "${partitions_file}"; then
        partition_count=0
    else
        partition_count="$(
            awk '
                /^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+/ {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${partitions_file}"
        )"
    fi

    if grep -qx 'No volumes were reported\.' "${volumes_file}"; then
        volume_count=0
    else
        volume_count="$(
            awk '
                /^[[:space:]]*[A-Z]?[[:space:]]+/ {
                    if ($1 != "DriveLetter" && $1 !~ /^-+$/) {
                        count++
                    }
                }
                END {
                    print count + 0
                }
            ' "${volumes_file}"
        )"
    fi

    fixed_logical_disk_count="$(
        awk '
            /^[[:space:]]*[A-Z]:[[:space:]]+/ &&
            $0 ~ /[[:space:]]3[[:space:]]/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${logical_disks_file}"
    )"

    if grep -qx 'No storage pools were reported\.' "${storage_pools_file}"; then
        storage_pool_count=0
    else
        storage_pool_count="$(
            awk '
                NR > 2 && NF > 0 {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${storage_pools_file}"
        )"
    fi

    system_drive="$(
        awk '
            /^[[:space:]]*C:[[:space:]]+/ {
                print $1
                exit
            }
        ' "${logical_disks_file}"
    )"

    system_drive_filesystem="$(
        awk '
            /^[[:space:]]*C:[[:space:]]+/ {
                print $3
                exit
            }
        ' "${logical_disks_file}"
    )"

    [[ -n "${system_drive}" ]] || system_drive="Unavailable"
    [[ -n "${system_drive_filesystem}" ]] || system_drive_filesystem="Unavailable"

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin-WS Storage Summary
========================================

Target Host: ${POLARIS_ADMIN_WS_HOST}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Physical Disk Count: ${disk_count}
Online Disk Count: ${online_disk_count}
Partition Count: ${partition_count}
Volume Count: ${volume_count}
Fixed Logical Disk Count: ${fixed_logical_disk_count}
Storage Pool Count: ${storage_pool_count}
System Drive: ${system_drive}
System Drive Filesystem: ${system_drive_filesystem}
Collection Status: Success

Collected Artifacts
-------------------
disks.txt
partitions.txt
volumes.txt
logical-disks.txt
filesystem-drives.txt
storage-pools.txt

Note: disks.txt/partitions.txt/volumes.txt (Get-Disk/Get-Partition/
Get-Volume) fail soft under polaris-admws-backup's intentionally
non-administrator privileges - these go through a separate DCOM-hosted
storage provider that was not granted access, by design, to avoid a
machine-wide DCOM security change for one device-level detail field.
logical-disks.txt and filesystem-drives.txt (Win32_LogicalDisk,
Get-PSDrive) do not depend on that provider and remain fully populated.
EOF
    then
        operator_error "Unable to write Admin-WS storage summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin-WS storage summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin-WS storage summary is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin-WS storage inventory collected successfully."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_services_inventory
#
# Purpose:
#   Collect authoritative Admin-WS Windows service and scheduled-task metadata
#   and generate a concise local summary from the collected artifacts.
###############################################################################

_collect_services_inventory() {
    local services_all_file="${POLARIS_ADMIN_WS_SERVICES_DIR}/services-all.txt"
    local services_running_file="${POLARIS_ADMIN_WS_SERVICES_DIR}/services-running.txt"
    local services_automatic_file="${POLARIS_ADMIN_WS_SERVICES_DIR}/services-automatic.txt"
    local services_stopped_automatic_file="${POLARIS_ADMIN_WS_SERVICES_DIR}/services-stopped-automatic.txt"
    local scheduled_tasks_file="${POLARIS_ADMIN_WS_SERVICES_DIR}/scheduled-tasks.txt"
    local scheduled_tasks_non_microsoft_file="${POLARIS_ADMIN_WS_SERVICES_DIR}/scheduled-tasks-non-microsoft.txt"
    local scheduled_tasks_failed_file="${POLARIS_ADMIN_WS_SERVICES_DIR}/scheduled-tasks-failed.txt"
    local summary_file="${POLARIS_ADMIN_WS_SERVICES_DIR}/services-summary.txt"

    local total_service_count=0
    local running_service_count=0
    local automatic_service_count=0
    local stopped_automatic_count=0
    local scheduled_task_count=0
    local non_microsoft_task_count=0
    local failed_task_count=0

    log_info "Collecting Admin-WS services and scheduled-task inventory."

    if [[ -z "${POLARIS_ADMIN_WS_SERVICES_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN_WS_SERVICES_DIR}" ]]
    then
        operator_error \
            "Admin-WS services staging directory has not been initialized."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-CimInstance Win32_Service | Sort-Object Name | Select-Object Name,DisplayName,State,StartMode,Status,StartName,PathName,ProcessId | Format-Table -AutoSize"' \
        "${services_all_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-CimInstance Win32_Service | Where-Object State -EQ Running | Sort-Object Name | Select-Object Name,DisplayName,StartMode,StartName,ProcessId | Format-Table -AutoSize"' \
        "${services_running_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-CimInstance Win32_Service | Where-Object StartMode -EQ Auto | Sort-Object Name | Select-Object Name,DisplayName,State,StartName | Format-Table -AutoSize"' \
        "${services_automatic_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$items = Get-CimInstance Win32_Service | Where-Object StartMode -EQ Auto | Where-Object State -NE Running | Sort-Object Name; if ($items) { $items | Select-Object Name,DisplayName,State,StartMode,Status,StartName | Format-Table -AutoSize } else { Write-Output NO_STOPPED_AUTOMATIC_SERVICES }"' \
        "${services_stopped_automatic_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-ScheduledTask | Sort-Object TaskPath,TaskName | Select-Object TaskPath,TaskName,State,Author,Description | Format-Table -AutoSize"' \
        "${scheduled_tasks_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$items = Get-ScheduledTask | Where-Object TaskPath -NotLike \Microsoft\* | Sort-Object TaskPath,TaskName; if ($items) { $items | Select-Object TaskPath,TaskName,State,Author,Description | Format-Table -AutoSize } else { Write-Output NO_NON_MICROSOFT_SCHEDULED_TASKS }"' \
        "${scheduled_tasks_non_microsoft_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$items = Get-ScheduledTask | ForEach-Object { $info = $_ | Get-ScheduledTaskInfo; [pscustomobject]@{ TaskPath = $_.TaskPath; TaskName = $_.TaskName; State = $_.State; LastRunTime = $info.LastRunTime; LastTaskResult = $info.LastTaskResult; NextRunTime = $info.NextRunTime } } | Where-Object { $_.LastTaskResult -notin 0,267009,267011 -and $_.LastRunTime -gt [datetime]::MinValue } | Sort-Object TaskPath,TaskName; if ($items) { $items | Format-Table -AutoSize } else { Write-Output NO_FAILED_SCHEDULED_TASKS }"' \
        "${scheduled_tasks_failed_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    total_service_count="$(
        awk '
            /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]+/ {
                if ($1 != "Name" && $1 !~ /^-+$/) {
                    count++
                }
            }
            END {
                print count + 0
            }
        ' "${services_all_file}"
    )"

    running_service_count="$(
        awk '
            /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]+/ {
                if ($1 != "Name" && $1 !~ /^-+$/) {
                    count++
                }
            }
            END {
                print count + 0
            }
        ' "${services_running_file}"
    )"

    automatic_service_count="$(
        awk '
            /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]+/ {
                if ($1 != "Name" && $1 !~ /^-+$/) {
                    count++
                }
            }
            END {
                print count + 0
            }
        ' "${services_automatic_file}"
    )"

    if grep -qx 'NO_STOPPED_AUTOMATIC_SERVICES' \
        "${services_stopped_automatic_file}"
    then
        stopped_automatic_count=0
    else
        stopped_automatic_count="$(
            awk '
                /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]+/ {
                    if ($1 != "Name" && $1 !~ /^-+$/) {
                        count++
                    }
                }
                END {
                    print count + 0
                }
            ' "${services_stopped_automatic_file}"
        )"
    fi

    scheduled_task_count="$(
        awk '
            /^[[:space:]]*\\[[:alnum:]_. -]+/ ||
            /^[[:space:]]*\\Microsoft\\/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${scheduled_tasks_file}"
    )"

    if grep -qx 'NO_NON_MICROSOFT_SCHEDULED_TASKS' \
        "${scheduled_tasks_non_microsoft_file}"
    then
        non_microsoft_task_count=0
    else
        non_microsoft_task_count="$(
            awk '
                /^[[:space:]]*\\/ {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${scheduled_tasks_non_microsoft_file}"
        )"
    fi

    if grep -qx 'NO_FAILED_SCHEDULED_TASKS' \
        "${scheduled_tasks_failed_file}"
    then
        failed_task_count=0
    else
        failed_task_count="$(
            awk '
                /^[[:space:]]*\\/ {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${scheduled_tasks_failed_file}"
        )"
    fi

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin-WS Services Summary
=========================================

Target Host: ${POLARIS_ADMIN_WS_HOST}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Windows Service Count: ${total_service_count}
Running Service Count: ${running_service_count}
Automatic Service Count: ${automatic_service_count}
Stopped Automatic Service Count: ${stopped_automatic_count}
Scheduled Task Count: ${scheduled_task_count}
Non-Microsoft Scheduled Task Count: ${non_microsoft_task_count}
Scheduled Tasks With Non-Success Results: ${failed_task_count}
Collection Status: Success

Collected Artifacts
-------------------
services-all.txt
services-running.txt
services-automatic.txt
services-stopped-automatic.txt
scheduled-tasks.txt
scheduled-tasks-non-microsoft.txt
scheduled-tasks-failed.txt

Note: Win32_Service enumeration was initially denied under
polaris-admws-backup's intentionally non-administrator privileges - this
was governed by the Service Control Manager's own security descriptor
(distinct from WMI namespace permissions), which by default withholds
enumerate rights from non-interactive network logons (e.g. SSH sessions)
for any non-admin account, regardless of WMI configuration. Resolved via
a narrow, additive entry on the SCM's SDDL security descriptor (sc
sdset scmanager) granting this specific account's SID the same
Connect+Enumerate+ReadControl rights (CCLCRPRC) already granted by
Windows default to Interactive Users and Service logon accounts -
deliberately not broadened to Administrators, to keep this backup
account's authority scoped to exactly what it needs. See the runbook's
3q section for the full diagnosis and the exact SDDL change applied.
EOF
    then
        operator_error "Unable to write Admin-WS services summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin-WS services summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin-WS services summary is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Admin-WS services and scheduled-task inventory collected successfully."

    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_software_inventory
#
# Purpose:
#   Collect installed applications, Windows capabilities and features, package
#   manager inventories, and PowerShell modules from Admin-WS.
###############################################################################

_collect_software_inventory() {
    local installed_applications_file="${POLARIS_ADMIN_WS_SOFTWARE_DIR}/installed-applications.txt"
    local windows_capabilities_file="${POLARIS_ADMIN_WS_SOFTWARE_DIR}/windows-capabilities.txt"
    local optional_features_file="${POLARIS_ADMIN_WS_SOFTWARE_DIR}/optional-features.txt"
    local appx_packages_file="${POLARIS_ADMIN_WS_SOFTWARE_DIR}/appx-packages.txt"
    local winget_packages_file="${POLARIS_ADMIN_WS_SOFTWARE_DIR}/winget-packages.txt"
    local powershell_modules_file="${POLARIS_ADMIN_WS_SOFTWARE_DIR}/powershell-modules.txt"
    local summary_file="${POLARIS_ADMIN_WS_SOFTWARE_DIR}/software-summary.txt"

    local installed_application_count=0
    local installed_capability_count=0
    local enabled_optional_feature_count=0
    local appx_package_count=0
    local winget_status="Unavailable"
    local winget_package_count=0
    local powershell_module_count=0

    log_info "Collecting Admin-WS software inventory."

    if [[ -z "${POLARIS_ADMIN_WS_SOFTWARE_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN_WS_SOFTWARE_DIR}" ]]
    then
        operator_error \
            "Admin-WS software staging directory has not been initialized."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*,HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | Where-Object DisplayName | Sort-Object DisplayName,DisplayVersion | Select-Object DisplayName,DisplayVersion,Publisher,InstallDate,InstallLocation,UninstallString | Format-Table -AutoSize; exit 0"' \
        "${installed_applications_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "try { Get-WindowsCapability -Online -ErrorAction Stop | Sort-Object Name | Select-Object Name,State | Format-Table -AutoSize } catch { Write-Output WINDOWS_CAPABILITY_STATE_UNAVAILABLE }"' \
        "${windows_capabilities_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "try { Get-WindowsOptionalFeature -Online -ErrorAction Stop | Sort-Object FeatureName | Select-Object FeatureName,State | Format-Table -AutoSize } catch { Write-Output OPTIONAL_FEATURE_STATE_UNAVAILABLE }"' \
        "${optional_features_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "try { Get-AppxPackage -AllUsers -ErrorAction Stop | Sort-Object Name,Version | Select-Object Name,PackageFullName,Version,Publisher,InstallLocation,IsFramework,NonRemovable | Format-Table -AutoSize } catch { Write-Output APPX_PACKAGE_STATE_UNAVAILABLE }"' \
        "${appx_packages_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "if (Get-Command winget.exe -ErrorAction SilentlyContinue) { winget list --accept-source-agreements --disable-interactivity } else { Write-Output WINGET_UNAVAILABLE }"' \
        "${winget_packages_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-Module -ListAvailable | Sort-Object Name,Version -Unique | Select-Object Name,Version,ModuleType,Path | Format-Table -AutoSize"' \
        "${powershell_modules_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    installed_application_count="$(
        awk '
            NR > 2 && NF > 0 && $1 !~ /^-+$/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${installed_applications_file}"
    )"

    if grep -qx 'WINDOWS_CAPABILITY_STATE_UNAVAILABLE' "${windows_capabilities_file}"; then
        installed_capability_count=0
    else
        installed_capability_count="$(
            awk '
                NR > 2 && NF > 0 && $NF == "Installed" {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${windows_capabilities_file}"
        )"
    fi

    if grep -qx 'OPTIONAL_FEATURE_STATE_UNAVAILABLE' "${optional_features_file}"; then
        enabled_optional_feature_count=0
    else
        enabled_optional_feature_count="$(
            awk '
                NR > 2 && NF > 0 && $NF == "Enabled" {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${optional_features_file}"
        )"
    fi

    if grep -qx 'APPX_PACKAGE_STATE_UNAVAILABLE' "${appx_packages_file}"; then
        appx_package_count=0
    else
        appx_package_count="$(
            awk '
                NR > 2 && NF > 0 && $1 !~ /^-+$/ {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${appx_packages_file}"
        )"
    fi

    if grep -qx 'WINGET_UNAVAILABLE' "${winget_packages_file}"; then
        winget_status="Unavailable"
        winget_package_count=0
    else
        winget_status="Available"
        winget_package_count="$(
            awk '
                NR > 2 && NF > 0 && $1 !~ /^-+$/ {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${winget_packages_file}"
        )"
    fi

    powershell_module_count="$(
        awk '
            NR > 2 && NF > 0 && $1 !~ /^-+$/ {
                count++
            }
            END {
                print count + 0
            }
        ' "${powershell_modules_file}"
    )"

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin-WS Software Summary
=========================================

Target Host: ${POLARIS_ADMIN_WS_HOST}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Installed Application Count: ${installed_application_count}
Installed Windows Capability Count: ${installed_capability_count}
Enabled Optional Feature Count: ${enabled_optional_feature_count}
Installed Appx Package Count: ${appx_package_count}
WinGet Availability: ${winget_status}
WinGet Package Count: ${winget_package_count}
PowerShell Module Count: ${powershell_module_count}
Collection Status: Success

Collected Artifacts
-------------------
installed-applications.txt
windows-capabilities.txt
optional-features.txt
appx-packages.txt
winget-packages.txt
powershell-modules.txt

Note: Windows Capability and Optional Feature state (windows-capabilities.txt,
optional-features.txt) require administrator elevation via DISM, and
Get-AppxPackage -AllUsers (appx-packages.txt) has the identical requirement
per Microsoft's own documentation - these are hard, unconditional checks in
their respective interfaces, not scoped ACLs like the WMI namespace or
Service Control Manager gaps found elsewhere in this collector, so there is
no narrow-grant equivalent to apply here. Dropping -AllUsers instead was
deliberately rejected - it would return this service account's own
near-empty profile, not the real primary user's installed apps, which is
misleading rather than honestly incomplete. All three deliberately report
unavailable under polaris-admws-backup's intentionally non-administrator
privileges, per the 3q decision to hold the backup account's authority to
exactly what it needs rather than grant it the broader access this would
require. Enabled capabilities/features on this machine (at minimum, OpenSSH
Server, since that is how this account itself connects) should be tracked
manually and reviewed at rebuild time until this gap is revisited - see the
runbook's 3q section for the full decision record, including why
Administrator access cannot be safely scoped down after the fact even with
agent-side tool restrictions, and the plan to re-review this specific gap
when the multi-agent "foreman" and its tool-call boundaries are actually
built.
EOF
    then
        operator_error "Unable to write Admin-WS software summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error "Unable to secure Admin-WS software summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error "Admin-WS software summary is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin-WS software inventory collected successfully."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_administrator_environment
#
# Purpose:
#   Collect rebuild-relevant Admin-WS administrator tooling and configuration
#   without collecting private keys, password stores, tokens, or user documents.
###############################################################################

_collect_administrator_environment() {
    local git_config_file="${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}/git-config.txt"
    local ssh_config_file="${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}/ssh-config.txt"
    local ssh_public_keys_file="${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}/ssh-public-keys.txt"
    local authorized_keys_file="${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}/authorized-keys.txt"
    local powershell_profiles_file="${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}/powershell-profiles.txt"
    local vscode_settings_file="${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}/vscode-settings.json"
    local vscode_extensions_file="${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}/vscode-extensions.txt"
    local terminal_settings_file="${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}/windows-terminal-settings.json"
    local tool_versions_file="${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}/admin-tool-versions.txt"
    local summary_file="${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}/administrator-environment-summary.txt"

    local git_config_status="Not Present"
    local ssh_config_status="Not Present"
    local ssh_public_key_count=0
    local authorized_key_count=0
    local powershell_profile_count=0
    local vscode_settings_status="Not Present"
    local vscode_extension_count=0
    local terminal_settings_status="Not Present"

    log_info "Collecting Admin-WS administrator environment."

    if [[ -z "${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN_WS_ENVIRONMENT_DIR}" ]]
    then
        operator_error \
            "Admin-WS administrator-environment staging directory has not been initialized."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "if (Test-Path $HOME\.gitconfig) { Get-Content $HOME\.gitconfig } else { Write-Output GIT_CONFIG_NOT_PRESENT }"' \
        "${git_config_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "if (Test-Path $HOME\.ssh\config) { Get-Content $HOME\.ssh\config } else { Write-Output SSH_CONFIG_NOT_PRESENT }"' \
        "${ssh_config_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$items = Get-ChildItem $HOME\.ssh\*.pub -File -ErrorAction SilentlyContinue | Sort-Object Name; if ($items) { foreach ($item in $items) { Write-Output ([string]::Concat([char]61,[char]61,[char]61,[char]32,$item.Name,[char]32,[char]61,[char]61,[char]61)); Get-Content $item.FullName; Write-Output ([string]::Empty) } } else { Write-Output NO_SSH_PUBLIC_KEYS }"' \
        "${ssh_public_keys_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "if (Test-Path $HOME\.ssh\authorized_keys) { Get-Content $HOME\.ssh\authorized_keys } else { Write-Output AUTHORIZED_KEYS_NOT_PRESENT }"' \
        "${authorized_keys_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$paths = @($PROFILE.AllUsersAllHosts,$PROFILE.AllUsersCurrentHost,$PROFILE.CurrentUserAllHosts,$PROFILE.CurrentUserCurrentHost) | Select-Object -Unique; $found = $false; foreach ($path in $paths) { if (Test-Path $path) { $found = $true; Write-Output ([string]::Concat([char]61,[char]61,[char]61,[char]32,$path,[char]32,[char]61,[char]61,[char]61)); Get-Content $path; Write-Output ([string]::Empty) } }; if (-not $found) { Write-Output NO_POWERSHELL_PROFILES }"' \
        "${powershell_profiles_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$path = Join-Path $env:APPDATA Code\User\settings.json; if (Test-Path $path) { Get-Content $path } else { Write-Output VSCODE_SETTINGS_NOT_PRESENT }"' \
        "${vscode_settings_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "if (Get-Command code.cmd -ErrorAction SilentlyContinue) { code.cmd --list-extensions | Sort-Object } elseif (Get-Command code.exe -ErrorAction SilentlyContinue) { code.exe --list-extensions | Sort-Object } else { Write-Output VSCODE_COMMAND_UNAVAILABLE }"' \
        "${vscode_extensions_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$path1 = Join-Path $env:LOCALAPPDATA Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json; $path2 = Join-Path $env:LOCALAPPDATA Microsoft\Windows` Terminal\settings.json; $path = @($path1,$path2) | Where-Object { Test-Path $_ } | Select-Object -First 1; if ($path) { Get-Content $path } else { Write-Output WINDOWS_TERMINAL_SETTINGS_NOT_PRESENT }"' \
        "${terminal_settings_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "function Show-PolarisTool($tool) { $command = Get-Command $tool -ErrorAction SilentlyContinue | Select-Object -First 1; if ($command) { Write-Output ([string]::Concat($tool,[char]58,[char]32,$command.Source)) } else { Write-Output ([string]::Concat($tool,[char]58,[char]32,[string]::Concat([char]117,[char]110,[char]97,[char]118,[char]97,[char]105,[char]108,[char]97,[char]98,[char]108,[char]101))) } }; Show-PolarisTool git.exe; Show-PolarisTool ssh.exe; Show-PolarisTool code.cmd; Show-PolarisTool code.exe; Show-PolarisTool pwsh.exe; Show-PolarisTool powershell.exe; Show-PolarisTool winget.exe; Show-PolarisTool tailscale.exe; Show-PolarisTool rustdesk.exe"' \
        "${tool_versions_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    if ! grep -qx 'GIT_CONFIG_NOT_PRESENT' "${git_config_file}"; then
        git_config_status="Present"
    fi

    if ! grep -qx 'SSH_CONFIG_NOT_PRESENT' "${ssh_config_file}"; then
        ssh_config_status="Present"
    fi

    if grep -qx 'NO_SSH_PUBLIC_KEYS' "${ssh_public_keys_file}"; then
        ssh_public_key_count=0
    else
        ssh_public_key_count="$(
            grep -c '^=== .*\.pub ===$' "${ssh_public_keys_file}" || true
        )"
    fi

    if grep -qx 'AUTHORIZED_KEYS_NOT_PRESENT' "${authorized_keys_file}"; then
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

    if grep -qx 'NO_POWERSHELL_PROFILES' "${powershell_profiles_file}"; then
        powershell_profile_count=0
    else
        powershell_profile_count="$(
            grep -c '^=== .* ===$' "${powershell_profiles_file}" || true
        )"
    fi

    if grep -qx 'VSCODE_SETTINGS_NOT_PRESENT' \
        "${vscode_settings_file}"
    then
        vscode_settings_status="Not Present"
    else
        vscode_settings_status="Present"
    fi

    if grep -qx 'VSCODE_COMMAND_UNAVAILABLE' "${vscode_extensions_file}"; then
        vscode_extension_count=0
    else
        vscode_extension_count="$(
            awk '
                NF > 0 { count++ }
                END { print count + 0 }
            ' "${vscode_extensions_file}"
        )"
    fi

    if grep -qx 'WINDOWS_TERMINAL_SETTINGS_NOT_PRESENT' \
        "${terminal_settings_file}"
    then
        terminal_settings_status="Not Present"
    else
        terminal_settings_status="Present"
    fi

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin-WS Administrator Environment Summary
==========================================================

Target Host: ${POLARIS_ADMIN_WS_HOST}
Remote User: ${POLARIS_ADMIN_WS_USER}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

User Git Configuration: ${git_config_status}
User SSH Client Configuration: ${ssh_config_status}
SSH Public Key Count: ${ssh_public_key_count}
Authorized Key Count: ${authorized_key_count}
PowerShell Profile Count: ${powershell_profile_count}
VS Code Settings: ${vscode_settings_status}
VS Code Extension Count: ${vscode_extension_count}
Windows Terminal Settings: ${terminal_settings_status}
Private SSH Keys Included: no
Credential Stores Included: no
User Documents Included: no
Collection Status: Success

Collected Artifacts
-------------------
git-config.txt
ssh-config.txt
ssh-public-keys.txt
authorized-keys.txt
powershell-profiles.txt
vscode-settings.json
vscode-extensions.txt
windows-terminal-settings.json
admin-tool-versions.txt
EOF
    then
        operator_error \
            "Unable to write Admin-WS administrator-environment summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    chmod 600 "${summary_file}" || return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    if [[ ! -s "${summary_file}" ]]; then
        operator_error \
            "Admin-WS administrator-environment summary is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Admin-WS administrator environment collected successfully."

    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}



###############################################################################
# Function: _collect_project_polaris_workspace
#
# Purpose:
#   Inventory Project Polaris workspace locations and Git metadata on Admin-WS
#   without copying repository contents, credentials, private keys, or secrets.
###############################################################################

_collect_project_polaris_workspace() {
    local workspace_paths_file="${POLARIS_ADMIN_WS_WORKSPACE_DIR}/workspace-paths.txt"
    local repositories_file="${POLARIS_ADMIN_WS_WORKSPACE_DIR}/git-repositories.txt"
    local repository_status_file="${POLARIS_ADMIN_WS_WORKSPACE_DIR}/git-repository-status.txt"
    local repository_remotes_file="${POLARIS_ADMIN_WS_WORKSPACE_DIR}/git-repository-remotes.txt"
    local workspace_inventory_file="${POLARIS_ADMIN_WS_WORKSPACE_DIR}/workspace-inventory.txt"
    local summary_file="${POLARIS_ADMIN_WS_WORKSPACE_DIR}/workspace-summary.txt"

    local workspace_count=0
    local repository_count=0
    local dirty_repository_count=0
    local remote_count=0
    local inventory_entry_count=0

    log_info "Collecting Admin-WS Project Polaris workspace metadata."

    if [[ -z "${POLARIS_ADMIN_WS_WORKSPACE_DIR}" ]] ||
       [[ ! -d "${POLARIS_ADMIN_WS_WORKSPACE_DIR}" ]]
    then
        operator_error \
            "Admin-WS Project Polaris workspace staging directory has not been initialized."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$candidates = @(); $candidates += Join-Path $HOME Git; $candidates += Join-Path $HOME Projects; $candidates += Join-Path $HOME project-polaris; $candidates += Join-Path $HOME ProjectPolaris; if ($env:OneDrive) { $candidates += Join-Path $env:OneDrive Documents\Proxmox; $candidates += Join-Path $env:OneDrive Documents\Git; $candidates += Join-Path $env:OneDrive Documents\Projects }; $items = $candidates | Select-Object -Unique | Where-Object { Test-Path $_ }; if ($items) { $items } else { Write-Output NO_RECOGNIZED_WORKSPACE_PATHS }"' \
        "${workspace_paths_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$roots = @(); $roots += Join-Path $HOME Git; $roots += Join-Path $HOME Projects; if ($env:OneDrive) { $roots += Join-Path $env:OneDrive Documents\Git; $roots += Join-Path $env:OneDrive Documents\Projects; $roots += Join-Path $env:OneDrive Documents\Proxmox }; $repos = foreach ($root in ($roots | Select-Object -Unique)) { if (Test-Path $root) { Get-ChildItem $root -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName .git) } | Select-Object -ExpandProperty FullName } }; $repos = $repos | Sort-Object -Unique; if ($repos) { $repos } else { Write-Output NO_GIT_REPOSITORIES }"' \
        "${repositories_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$roots = @(); $roots += Join-Path $HOME Git; $roots += Join-Path $HOME Projects; if ($env:OneDrive) { $roots += Join-Path $env:OneDrive Documents\Git; $roots += Join-Path $env:OneDrive Documents\Projects; $roots += Join-Path $env:OneDrive Documents\Proxmox }; $repos = foreach ($root in ($roots | Select-Object -Unique)) { if (Test-Path $root) { Get-ChildItem $root -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName .git) } | Select-Object -ExpandProperty FullName } }; $repos = $repos | Sort-Object -Unique; if ($repos) { foreach ($repo in $repos) { Write-Output ([string]::Concat([char]61,[char]61,[char]61,[char]32,$repo,[char]32,[char]61,[char]61,[char]61)); git.exe -C $repo status --short --branch; Write-Output ([string]::Empty) } } else { Write-Output NO_GIT_REPOSITORY_STATUS }"' \
        "${repository_status_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$roots = @(); $roots += Join-Path $HOME Git; $roots += Join-Path $HOME Projects; if ($env:OneDrive) { $roots += Join-Path $env:OneDrive Documents\Git; $roots += Join-Path $env:OneDrive Documents\Projects; $roots += Join-Path $env:OneDrive Documents\Proxmox }; $repos = foreach ($root in ($roots | Select-Object -Unique)) { if (Test-Path $root) { Get-ChildItem $root -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName .git) } | Select-Object -ExpandProperty FullName } }; $repos = $repos | Sort-Object -Unique; if ($repos) { foreach ($repo in $repos) { Write-Output ([string]::Concat([char]61,[char]61,[char]61,[char]32,$repo,[char]32,[char]61,[char]61,[char]61)); git.exe -C $repo remote -v; Write-Output ([string]::Empty) } } else { Write-Output NO_GIT_REPOSITORY_REMOTES }"' \
        "${repository_remotes_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    _admin_ws_remote_execute_to_file \
        'powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$candidates = @(); $candidates += Join-Path $HOME Git; $candidates += Join-Path $HOME Projects; $candidates += Join-Path $HOME project-polaris; $candidates += Join-Path $HOME ProjectPolaris; if ($env:OneDrive) { $candidates += Join-Path $env:OneDrive Documents\Proxmox; $candidates += Join-Path $env:OneDrive Documents\Git; $candidates += Join-Path $env:OneDrive Documents\Projects }; $roots = $candidates | Select-Object -Unique | Where-Object { Test-Path $_ }; if ($roots) { foreach ($root in $roots) { Write-Output ([string]::Concat([char]61,[char]61,[char]61,[char]32,$root,[char]32,[char]61,[char]61,[char]61)); Get-ChildItem $root -Force -ErrorAction SilentlyContinue | Sort-Object PSIsContainer,Name | Select-Object Name,PSIsContainer,Length,LastWriteTime | Format-Table -AutoSize; Write-Output ([string]::Empty) } } else { Write-Output NO_WORKSPACE_INVENTORY }"' \
        "${workspace_inventory_file}" || \
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"

    if grep -qx 'NO_RECOGNIZED_WORKSPACE_PATHS' "${workspace_paths_file}"; then
        workspace_count=0
    else
        workspace_count="$(
            awk 'NF > 0 { count++ } END { print count + 0 }' \
                "${workspace_paths_file}"
        )"
    fi

    if grep -qx 'NO_GIT_REPOSITORIES' "${repositories_file}"; then
        repository_count=0
    else
        repository_count="$(
            awk 'NF > 0 { count++ } END { print count + 0 }' \
                "${repositories_file}"
        )"
    fi

    if grep -qx 'NO_GIT_REPOSITORY_STATUS' "${repository_status_file}"; then
        dirty_repository_count=0
    else
        dirty_repository_count="$(
            awk '
                /^=== / {
                    in_repository=1
                    repository_dirty=0
                    next
                }

                /^## / {
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

    if grep -qx 'NO_GIT_REPOSITORY_REMOTES' "${repository_remotes_file}"; then
        remote_count=0
    else
        remote_count="$(
            awk '
                /\((fetch|push)\)$/ {
                    count++
                }
                END {
                    print count + 0
                }
            ' "${repository_remotes_file}"
        )"
    fi

    if grep -qx 'NO_WORKSPACE_INVENTORY' "${workspace_inventory_file}"; then
        inventory_entry_count=0
    else
        inventory_entry_count="$(
            awk '
                /^=== / { next }
                /^[[:space:]]*Name[[:space:]]+/ { next }
                /^[[:space:]]*-+[[:space:]]+/ { next }
                NF > 0 { count++ }
                END { print count + 0 }
            ' "${workspace_inventory_file}"
        )"
    fi

    if ! cat > "${summary_file}" <<EOF
Project Polaris Admin-WS Workspace Summary
==========================================

Target Host: ${POLARIS_ADMIN_WS_HOST}
Remote User: ${POLARIS_ADMIN_WS_USER}
Collection Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')

Recognized Workspace Path Count: ${workspace_count}
Git Repository Count: ${repository_count}
Repositories With Uncommitted Changes: ${dirty_repository_count}
Configured Git Remote Entry Count: ${remote_count}
Workspace Inventory Entry Count: ${inventory_entry_count}
Repository Contents Included: no
Git Credentials Included: no
Private Keys Included: no
User Documents Included: no
Collection Status: Success

Collected Artifacts
-------------------
workspace-paths.txt
git-repositories.txt
git-repository-status.txt
git-repository-remotes.txt
workspace-inventory.txt
EOF
    then
        operator_error \
            "Unable to write Admin-WS Project Polaris workspace summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${summary_file}"; then
        operator_error \
            "Unable to secure Admin-WS Project Polaris workspace summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${summary_file}" ]]; then
        operator_error \
            "Admin-WS Project Polaris workspace summary is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Admin-WS Project Polaris workspace metadata collected successfully."

    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}


###############################################################################
# Function: _write_collector_info
#
# Purpose:
#   Record static information describing the Admin-WS collector.
###############################################################################

_write_collector_info() {
    local output_file="${POLARIS_ADMIN_WS_METADATA_DIR}/collector-info.txt"

    if ! cat > "${output_file}" <<EOF
Collector Name: ${POLARIS_ADMIN_WS_MODULE_NAME}
Collector Display Name: ${POLARIS_ADMIN_WS_MODULE_DISPLAY_NAME}
Collector Version: ${POLARIS_ADMIN_WS_MODULE_VERSION}
Collector Author: ${POLARIS_ADMIN_WS_MODULE_AUTHOR}
Collection Mode: ${POLARIS_ADMIN_WS_COLLECTION_STATUS}
Framework Version: ${POLARIS_FRAMEWORK_VERSION}
Hash Algorithm: SHA-256
EOF
    then
        operator_error "Unable to write Admin-WS collector information."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error "Unable to secure Admin-WS collector information."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error "Admin-WS collector information file is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin-WS collector information written successfully."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _write_execution_info
#
# Purpose:
#   Record execution-specific metadata for the Admin-WS collector.
###############################################################################

_write_execution_info() {
    local output_file="${POLARIS_ADMIN_WS_METADATA_DIR}/execution.txt"
    local timestamp=""

    if ! timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; then
        operator_error "Unable to generate the Admin-WS execution timestamp."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! cat > "${output_file}" <<EOF
Execution Timestamp (UTC): ${timestamp}
Collection Status: ${POLARIS_ADMIN_WS_COLLECTION_STATUS}
Staging Root: ${POLARIS_ADMIN_WS_STAGING_ROOT}
Configuration Directory: ${POLARIS_ADMIN_WS_HOST_DIR}
Admin-WS-Specific Collection Enabled: yes
Implemented Collection Stage: Complete Admin-WS Configuration Inventory
EOF
    then
        operator_error "Unable to write Admin-WS execution metadata."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error "Unable to secure Admin-WS execution metadata."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error "Admin-WS execution metadata file is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin-WS execution metadata written successfully."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _write_collection_summary
#
# Purpose:
#   Describe the Stage 2C.1 implementation boundary.
###############################################################################

_write_collection_summary() {
    local output_file="${POLARIS_ADMIN_WS_METADATA_DIR}/collection-summary.txt"
    local timestamp=""

    if ! timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"; then
        operator_error "Unable to generate the Admin-WS summary timestamp."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! cat > "${output_file}" <<EOF
Project Polaris Admin-WS Collector Summary
==========================================

Collector Version: ${POLARIS_ADMIN_WS_MODULE_VERSION}
Execution Time (UTC): ${timestamp}
Status: SUCCESS
Collection Mode: Remote Identity

Implemented
-----------
[COLLECTED] Collector metadata
[COLLECTED] Execution metadata
[COLLECTED] Collection summary
[COLLECTED] Integrity manifest
[COLLECTED] Remote Windows identity summary
[COLLECTED] Authoritative Windows identity artifacts
[COLLECTED] OpenSSH and PowerShell transport validation
[COLLECTED] Windows operating-system inventory
[COLLECTED] Windows network inventory
[COLLECTED] Windows storage inventory
[COLLECTED] Windows services and scheduled-task inventory
[COLLECTED] Installed software, Windows features, and PowerShell modules
[COLLECTED] Administrator environment
[COLLECTED] Project Polaris workspace metadata

Planned
-------
EOF
    then
        operator_error "Unable to write Admin-WS collection summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! chmod 600 "${output_file}"; then
        operator_error "Unable to secure Admin-WS collection summary."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if [[ ! -s "${output_file}" ]]; then
        operator_error "Admin-WS collection summary is empty."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin-WS collection summary written successfully."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _write_manifest
#
# Purpose:
#   Generate an integrity manifest for all permanent Stage 2C.1 artifacts.
###############################################################################

_write_manifest() {
    local output_file="${POLARIS_ADMIN_WS_METADATA_DIR}/manifest.txt"

    if ! polaris_manifest_recursive \
        "${POLARIS_ADMIN_WS_STAGING_ROOT}" \
        "${output_file}" \
        "Admin-WS"
    then
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success "Admin-WS integrity manifest written successfully."
    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: _preserve_failure_artifacts
#
# Purpose:
#   Preserve available Admin-WS staging data for troubleshooting.
###############################################################################

_preserve_failure_artifacts() {
    local troubleshooting_root="${1:-}"
    local failure_reason="${2:-unspecified failure}"

    polaris_preserve_failure_staging \
        "${troubleshooting_root}" \
        "admin-ws" \
        "Admin-WS" \
        "${POLARIS_ADMIN_WS_MODULE_VERSION}" \
        "${POLARIS_ADMIN_WS_COLLECTION_STATUS:-unavailable}" \
        "${failure_reason}" \
        "${POLARIS_ADMIN_WS_STAGING_ROOT}"
}

###############################################################################
# Function: _cleanup
#
# Purpose:
#   Remove failed active staging while preserving successful staging for the
#   orchestrator lifecycle processor.
###############################################################################

_cleanup() {
    if [[ -z "${POLARIS_ADMIN_WS_STAGING_ROOT}" ]]; then
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
    fi

    if ! polaris_remove_staging_root "${POLARIS_ADMIN_WS_STAGING_ROOT}" "Admin-WS"; then
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_ADMIN_WS_STAGING_ROOT=""
    POLARIS_ADMIN_WS_CONFIGURATION_DIR=""
    POLARIS_ADMIN_WS_HOST_DIR=""
    POLARIS_ADMIN_WS_OS_DIR=""
    POLARIS_ADMIN_WS_NETWORK_DIR=""
    POLARIS_ADMIN_WS_STORAGE_DIR=""
    POLARIS_ADMIN_WS_SERVICES_DIR=""
    POLARIS_ADMIN_WS_SOFTWARE_DIR=""
    POLARIS_ADMIN_WS_ENVIRONMENT_DIR=""
    POLARIS_ADMIN_WS_WORKSPACE_DIR=""
    POLARIS_ADMIN_WS_METADATA_DIR=""
    POLARIS_ADMIN_WS_COLLECTION_STATUS=""

    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}

###############################################################################
# Function: collect_admin_ws
#
# Purpose:
#   Coordinate the Stage 2C.8 complete Admin-WS configuration collection.
#
# Parameters:
#   $1 - Collector staging root.
#   $2 - Troubleshooting root.
###############################################################################

collect_admin_ws() {
    local staging_root="${1:-}"
    local troubleshooting_root="${2:-}"
    local failure_reason=""

    POLARIS_ADMIN_WS_STAGING_ROOT=""
    POLARIS_ADMIN_WS_CONFIGURATION_DIR=""
    POLARIS_ADMIN_WS_HOST_DIR=""
    POLARIS_ADMIN_WS_OS_DIR=""
    POLARIS_ADMIN_WS_NETWORK_DIR=""
    POLARIS_ADMIN_WS_STORAGE_DIR=""
    POLARIS_ADMIN_WS_SERVICES_DIR=""
    POLARIS_ADMIN_WS_SOFTWARE_DIR=""
    POLARIS_ADMIN_WS_ENVIRONMENT_DIR=""
    POLARIS_ADMIN_WS_WORKSPACE_DIR=""
    POLARIS_ADMIN_WS_METADATA_DIR=""
    POLARIS_ADMIN_WS_COLLECTION_STATUS=""

    if [[ -z "${staging_root}" ]] || [[ -z "${troubleshooting_root}" ]]; then
        operator_error "Admin-WS collector paths were not provided."
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_info "Starting complete Admin-WS configuration collection."

    if ! _validate_environment; then
        failure_reason="environment validation failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _initialize_staging "${staging_root}"; then
        failure_reason="staging initialization failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_remote_identity; then
        failure_reason="remote identity collection failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_os_inventory; then
        failure_reason="operating-system inventory collection failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_network_inventory; then
        failure_reason="network inventory collection failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_storage_inventory; then
        failure_reason="storage inventory collection failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_services_inventory; then
        failure_reason="services and scheduled-task inventory collection failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_software_inventory; then
        failure_reason="software inventory collection failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_administrator_environment; then
        failure_reason="administrator environment collection failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _collect_project_polaris_workspace; then
        failure_reason="Project Polaris workspace metadata collection failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_collector_info; then
        failure_reason="collector metadata generation failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_execution_info; then
        failure_reason="execution metadata generation failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_collection_summary; then
        failure_reason="collection summary generation failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    if ! _write_manifest; then
        failure_reason="manifest generation failed"
        _preserve_failure_artifacts \
            "${troubleshooting_root}" \
            "${failure_reason}" || true
        _cleanup || true
        return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_ERROR}"
    fi

    log_success \
        "Complete Admin-WS configuration collection completed successfully."

    return "${POLARIS_ADMIN_WS_COLLECTOR_RESULT_SUCCESS}"
}
