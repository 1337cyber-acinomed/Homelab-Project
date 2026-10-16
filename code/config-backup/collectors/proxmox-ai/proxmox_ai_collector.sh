#!/usr/bin/env bash

[[ -n "${POLARIS_PROXMOX_AI_COLLECTOR_SH_LOADED:-}" ]] && return 0
readonly POLARIS_PROXMOX_AI_COLLECTOR_SH_LOADED=1

###############################################################################
# Project Polaris
# AI Node Proxmox Configuration Collector
#
# Forked from collectors/proxmox/proxmox.sh (2026-09-14, straight fork, no
# logic changes yet - see the 3n runbook addendum). collect_proxmox()'s
# actual collection logic is host-agnostic and works unmodified here; the
# fork exists so the AI node's version can be deliberately trimmed/adapted
# later (e.g. cluster/HA/SDN sections that make more sense for Homelab's
# setup than a standalone node) without touching Homelab's own collector or
# its production history.
###############################################################################

###############################################################################
# Framework Initialization
###############################################################################

POLARIS_PROXMOX_COLLECTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly POLARIS_PROXMOX_COLLECTOR_DIR

POLARIS_PROXMOX_FRAMEWORK_ROOT="$(cd -- "${POLARIS_PROXMOX_COLLECTOR_DIR}/../.." && pwd -P)"
readonly POLARIS_PROXMOX_FRAMEWORK_ROOT

readonly POLARIS_PROXMOX_LIB_DIR="${POLARIS_PROXMOX_FRAMEWORK_ROOT}/lib"

# shellcheck source=/dev/null
source "${POLARIS_PROXMOX_LIB_DIR}/polaris-common.sh"

###############################################################################
# Collector Result Contract
###############################################################################

readonly POLARIS_PROXMOX_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_PROXMOX_COLLECTOR_RESULT_NO_CHANGE=2

###############################################################################
# Module Metadata
###############################################################################

readonly MODULE_NAME="proxmox-ai"
readonly MODULE_DISPLAY_NAME="AI Node Proxmox Collector"
readonly MODULE_VERSION="1.1.0"
readonly MODULE_AUTHOR="Project Polaris"


###############################################################################
# Module State
###############################################################################

# Absolute destination directory supplied by the calling orchestrator.
POLARIS_PROXMOX_STAGING_ROOT=""


###############################################################################
# Artifact Inventory
###############################################################################
#
# host/
#   hostname.txt
#   version.txt
#   kernel.txt
#   cpuinfo.txt
#   full_cpuinfo.txt
#   memoryinfo.txt
#   full_memoryinfo.txt
#   installed_packages.txt
#
# storage/
#   block_devices.txt
#   lsblk_tree.txt
#   filesystems.txt
#   disk_usage.txt
#   mounts.txt
#   storage.cfg
#   zfs_pools.txt
#   zfs_datasets.txt
#   fstab
#   physical_volumes.txt
#   volume_groups.txt
#   logical_volumes.txt
#
# network/
#   interfaces
#   interfaces.txt
#   physical_interfaces.txt
#   ip_addresses.txt
#   routes.txt
#   resolv.conf
#   bridges.txt
#   neighbors.txt
#   listening_ports.txt
#
###############################################################################

###############################################################################
# Environment and Staging
###############################################################################

###############################################################################
# Function: _polaris_proxmox_validate_environment
#
# Purpose:
#   Verify that the collector is running on a supported Proxmox VE host.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Environment is valid.
#   1 - Validation failed.
###############################################################################

_polaris_proxmox_validate_environment() {

    log_info "Validating Proxmox environment."

    if ! is_root_user; then
        operator_error "Collector must be run as root."
        return 1
    fi

    if ! command_exists pveversion; then
        operator_error "Proxmox VE does not appear to be installed."
        return 1
    fi

    log_success "Environment validation successful."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_create_staging
#
# Purpose:
#   Create the staging directory structure used by the Proxmox collector.
#
# Returns:
#   0 - Staging area created successfully.
#   1 - Failed to create one or more directories.
###############################################################################

_polaris_proxmox_create_staging() {

    local staging_root="${POLARIS_PROXMOX_STAGING_ROOT}"

    log_info "Creating Proxmox staging directory: ${staging_root}"

    if [[ -z "${staging_root}" ]]; then
        operator_error "Proxmox staging destination was not provided."
        return 1
    fi

    if [[ -e "${staging_root}" && ! -d "${staging_root}" ]]; then
        operator_error "Proxmox staging destination exists but is not a directory: ${staging_root}"
        return 1
    fi

    create_directory "${staging_root}" || return 1
    create_directory "${staging_root}/host" || return 1
    create_directory "${staging_root}/cluster" || return 1
    create_directory "${staging_root}/network" || return 1
    create_directory "${staging_root}/storage" || return 1
    create_directory "${staging_root}/virtual-machines" || return 1
    create_directory "${staging_root}/containers" || return 1
    create_directory "${staging_root}/certificates" || return 1
    create_directory "${staging_root}/cron" || return 1
    create_directory "${staging_root}/metadata" || return 1
    create_directory "${staging_root}/configuration" || return 1

    create_directory "${staging_root}/network/firewall" || return 1
    create_directory "${staging_root}/network/firewall/pve-firewall" || return 1
    create_directory "${staging_root}/network/firewall/iptables" || return 1
    create_directory "${staging_root}/network/firewall/ip6tables" || return 1
    create_directory "${staging_root}/network/firewall/nftables" || return 1

    log_success "Staging directory ready."

    return 0
}

###############################################################################
# Host Collectors
###############################################################################

# Purpose: Collect host data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_host() {

    local host_dir="${POLARIS_PROXMOX_STAGING_ROOT}/host"

    log_info "Collecting host information."

    _polaris_proxmox_collect_hostname "${host_dir}" || return 1
    _polaris_proxmox_collect_version "${host_dir}" || return 1
    _polaris_proxmox_collect_kernel "${host_dir}" || return 1
    _polaris_proxmox_collect_cpu "${host_dir}" || return 1
    _polaris_proxmox_collect_memory "${host_dir}" || return 1
    _polaris_proxmox_collect_packages "${host_dir}" || return 1

    log_success "Host collection complete."

    return 0
}

# Purpose: Collect hostname data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_hostname() {

    local host_dir="$1"

    log_info "Collecting hostname."

    hostname > "${host_dir}/hostname.txt" || return 1

    log_success "Hostname collected."

    return 0
}

# Purpose: Collect version data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_version() {

    local host_dir="$1"
    local output_file="${host_dir}/version.txt"

    log_info "Collecting Proxmox version."

    pveversion > "${output_file}" || {
        operator_error "Unable to collect Proxmox version."
        return 1
    }

    log_success "Proxmox version collected."

    return 0
}

# Purpose: Collect kernel data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_kernel() {

    local host_dir="$1"
    local output_file="${host_dir}/kernel.txt"

    log_info "Collecting kernel version."

    uname -r > "${output_file}" || {
        operator_error "Unable to collect kernel version."
        return 1
    }

    log_success "Kernel version collected."

    return 0
}

# Purpose: Collect cpu data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_cpu() {

    local host_dir="$1"
    local cpuinfo_file="${host_dir}/cpuinfo.txt"
    local full_cpuinfo_file="${host_dir}/full_cpuinfo.txt"

    log_info "Collecting CPU information."

    lscpu > "${cpuinfo_file}" || {
        operator_error "Unable to collect CPU information."
        return 1
    }

    cat /proc/cpuinfo > "${full_cpuinfo_file}" || {
        operator_error "Unable to collect full CPU information."
        return 1
    }

    log_success "CPU information collected."

    return 0
}

# Purpose: Collect memory data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_memory() {

    local host_dir="$1"
    local memoryinfo_file="${host_dir}/memoryinfo.txt"
    local full_memoryinfo_file="${host_dir}/full_memoryinfo.txt"

    log_info "Collecting memory information."

    free -h > "${memoryinfo_file}" || {
        operator_error "Unable to collect memory information."
        return 1
    }

    cat /proc/meminfo > "${full_memoryinfo_file}" || {
        operator_error "Unable to collect full memory information."
        return 1
    }

    log_success "Memory information collected."

    return 0
}

# Purpose: Collect packages data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_packages() {

    local host_dir="$1"
    local output_file="${host_dir}/installed_packages.txt"

    log_info "Collecting installed packages."

    dpkg-query -W -f='${Package}\t${Version}\n' > "${output_file}" || {
        operator_error "Unable to collect installed packages."
        return 1
    }

    log_success "Installed packages collected."

    return 0
}

###############################################################################
# Storage Collectors
###############################################################################

# Purpose: Collect storage data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_storage() {

    local storage_dir="${POLARIS_PROXMOX_STAGING_ROOT}/storage"

    log_info "Collecting storage information."

    create_directory "${storage_dir}" || {
        operator_error "Unable to create storage staging directory."
        return 1
    }

    _polaris_proxmox_collect_block_devices "${storage_dir}" || return 1
    _polaris_proxmox_collect_lsblk_tree "${storage_dir}" || return 1
    _polaris_proxmox_collect_filesystems "${storage_dir}" || return 1
    _polaris_proxmox_collect_disk_usage "${storage_dir}" || return 1
    _polaris_proxmox_collect_mounts "${storage_dir}" || return 1
    _polaris_proxmox_collect_storage_cfg "${storage_dir}" || return 1
    _polaris_proxmox_collect_zfs_pools "${storage_dir}" || return 1
    _polaris_proxmox_collect_zfs_datasets "${storage_dir}" || return 1
    _polaris_proxmox_collect_fstab "${storage_dir}" || return 1
    _polaris_proxmox_collect_physical_volumes "${storage_dir}" || return 1
    _polaris_proxmox_collect_volume_groups "${storage_dir}" || return 1
    _polaris_proxmox_collect_logical_volumes "${storage_dir}" || return 1

    log_success "Storage collection complete."

    return 0
}

# Purpose: Collect block devices data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_block_devices() {

    local storage_dir="$1"
    local output_file="${storage_dir}/block_devices.txt"

    log_info "Collecting block device information."

    lsblk -d -e 230 -o NAME,SIZE,MODEL,SERIAL,TYPE > "${output_file}" || {
        operator_error "Unable to collect block device information."
        return 1
    }

    log_success "Block device information collected."

    return 0
}

# Purpose: Collect lsblk tree data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_lsblk_tree() {

    local storage_dir="$1"
    local output_file="${storage_dir}/lsblk_tree.txt"

    log_info "Collecting block device hierarchy."

    lsblk -f > "${output_file}" || {
        operator_error "Unable to collect block device hierarchy."
        return 1
    }

    log_success "Block device hierarchy collected."

    return 0
}

# Purpose: Collect filesystems data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_filesystems() {

    local storage_dir="$1"
    local output_file="${storage_dir}/filesystems.txt"

    log_info "Collecting filesystem information."

    df -Th > "${output_file}" || {
        operator_error "Unable to collect filesystem information."
        return 1
    }

    log_success "Filesystem information collected."

    return 0
}

# Purpose: Collect disk usage data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_disk_usage() {

    local storage_dir="$1"
    local output_file="${storage_dir}/disk_usage.txt"

    log_info "Collecting disk usage information."

    df -h > "${output_file}" || {
        operator_error "Unable to collect disk usage information."
        return 1
    }

    log_success "Disk usage information collected."

    return 0
}

# Purpose: Collect mounts data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_mounts() {

    local storage_dir="$1"
    local output_file="${storage_dir}/mounts.txt"

    log_info "Collecting mount information."

    mount > "${output_file}" || {
        operator_error "Unable to collect mount information."
        return 1
    }

    log_success "Mount information collected."

    return 0
}

# Purpose: Collect storage cfg data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_storage_cfg() {

    local storage_dir="$1"
    local output_file="${storage_dir}/storage.cfg"

    log_info "Collecting Proxmox storage configuration."

    safe_copy "/etc/pve/storage.cfg" "${output_file}" || {
        operator_error "Unable to collect Proxmox storage configuration."
        return 1
    }

    log_success "Proxmox storage configuration collected."

    return 0
}

# Purpose: Collect zfs pools data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_zfs_pools() {

    local storage_dir="$1"
    local output_file="${storage_dir}/zfs_pools.txt"

    log_info "Collecting ZFS pool information."

    zpool status > "${output_file}" || {
        operator_error "Unable to collect ZFS pool information."
        return 1
    }

    log_success "ZFS pool information collected."

    return 0
}

# Purpose: Collect zfs datasets data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_zfs_datasets() {

    local storage_dir="$1"
    local output_file="${storage_dir}/zfs_datasets.txt"

    log_info "Collecting ZFS dataset information."

    zfs list > "${output_file}" || {
        operator_error "Unable to collect ZFS dataset information."
        return 1
    }

    log_success "ZFS dataset information collected."

    return 0
}

# Purpose: Collect fstab data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_fstab() {

    local storage_dir="$1"
    local output_file="${storage_dir}/fstab"

    log_info "Collecting filesystem table."

    safe_copy "/etc/fstab" "${output_file}" || {
        operator_error "Unable to collect filesystem table."
        return 1
    }

    log_success "Filesystem table collected."

    return 0
}

# Purpose: Collect physical volumes data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_physical_volumes() {

    local storage_dir="$1"
    local output_file="${storage_dir}/physical_volumes.txt"

    log_info "Collecting LVM physical volumes."

    pvs > "${output_file}" || {
        operator_error "Unable to collect LVM physical volumes."
        return 1
    }

    log_success "LVM physical volumes collected."

    return 0
}

# Purpose: Collect volume groups data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_volume_groups() {

    local storage_dir="$1"
    local output_file="${storage_dir}/volume_groups.txt"

    log_info "Collecting LVM volume groups."

    vgs > "${output_file}" || {
        operator_error "Unable to collect LVM volume groups."
        return 1
    }

    log_success "LVM volume groups collected."

    return 0
}

# Purpose: Collect logical volumes data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_logical_volumes() {

    local storage_dir="$1"
    local output_file="${storage_dir}/logical_volumes.txt"

    log_info "Collecting LVM logical volumes."

    lvs > "${output_file}" || {
        operator_error "Unable to collect LVM logical volumes."
        return 1
    }

    log_success "LVM logical volumes collected."

    return 0
}

###############################################################################
# Network Collectors
###############################################################################

# Purpose: Collect network data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_network() {

    local network_dir="${POLARIS_PROXMOX_STAGING_ROOT}/network"

    log_info "Collecting network information."

    create_directory "${network_dir}" || {
        operator_error "Unable to create network staging directory."
        return 1
    }

    _polaris_proxmox_collect_interfaces "${network_dir}" || return 1
    _polaris_proxmox_collect_physical_interfaces "${network_dir}" || return 1
    _polaris_proxmox_collect_ip_addresses "${network_dir}" || return 1
    _polaris_proxmox_collect_routes "${network_dir}" || return 1
    _polaris_proxmox_collect_resolv_conf "${network_dir}" || return 1
    _polaris_proxmox_collect_network_interfaces_config "${network_dir}" || return 1
    _polaris_proxmox_collect_bridges "${network_dir}" || return 1
    _polaris_proxmox_collect_neighbors "${network_dir}" || return 1
    _polaris_proxmox_collect_listening_ports "${network_dir}" || return 1
    _polaris_proxmox_collect_firewall "${network_dir}" || return 1
 
    log_success "Network collection complete."

    return 0
}

# Purpose: Collect interfaces data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_interfaces() {

    local network_dir="$1"
    local output_file="${network_dir}/interfaces.txt"

    log_info "Collecting network interfaces."

    ip -br link > "${output_file}" || {
        operator_error "Unable to collect network interfaces."
        return 1
    }

    log_success "Network interfaces collected."

    return 0
}

# Purpose: Collect physical interfaces data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_physical_interfaces() {

    local network_dir="$1"
    local output_file="${network_dir}/physical_interfaces.txt"

    log_info "Collecting physical network interfaces."

    {
        printf "%-16s %-18s %-17s %-8s\n" "INTERFACE" "MAC ADDRESS" "STATE" "MTU"

        for interface_path in /sys/class/net/*; do
            local interface
            local mac
            local state
            local mtu

            interface="$(basename "${interface_path}")"

            [[ -e "${interface_path}/device" ]] || continue

            mac="$(cat "${interface_path}/address")"
            state="$(cat "${interface_path}/operstate")"
            mtu="$(cat "${interface_path}/mtu")"

            printf "%-16s %-18s %-17s %-8s\n" \
                "${interface}" \
                "${mac}" \
                "${state}" \
                "${mtu}"
        done
    } > "${output_file}" || {
        operator_error "Unable to collect physical network interfaces."
        return 1
    }

    log_success "Physical network interfaces collected."

    return 0
}

# Purpose: Collect ip addresses data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_ip_addresses() {

    local network_dir="$1"
    local output_file="${network_dir}/ip_addresses.txt"

    log_info "Collecting IP address information."

    ip addr > "${output_file}" || {
        operator_error "Unable to collect IP address information."
        return 1
    }

    log_success "IP address information collected."

    return 0
}

# Purpose: Collect routes data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_routes() {

    local network_dir="$1"
    local output_file="${network_dir}/routes.txt"

    log_info "Collecting routing information."

    ip route > "${output_file}" || {
        operator_error "Unable to collect routing information."
        return 1
    }

    log_success "Routing information collected."

    return 0
}

# Purpose: Collect resolv conf data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_resolv_conf() {

    local network_dir="$1"
    local output_file="${network_dir}/resolv.conf"

    log_info "Collecting DNS resolver configuration."

    safe_copy "/etc/resolv.conf" "${output_file}" || {
        operator_error "Unable to collect DNS resolver configuration."
        return 1
    }

    log_success "DNS resolver configuration collected."

    return 0
}

# Purpose: Collect network interfaces config data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_network_interfaces_config() {

    local network_dir="$1"
    local output_file="${network_dir}/interfaces"

    log_info "Collecting network interface configuration."

    safe_copy "/etc/network/interfaces" "${output_file}" || {
        operator_error "Unable to collect network interface configuration."
        return 1
    }

    log_success "Network interface configuration collected."

    return 0
}

# Purpose: Collect bridges data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_bridges() {

    local network_dir="$1"
    local output_file="${network_dir}/bridges.txt"

    log_info "Collecting bridge information."

    bridge link > "${output_file}" || {
        operator_error "Unable to collect bridge information."
        return 1
    }

    log_success "Bridge information collected."

    return 0
}

# Purpose: Collect neighbors data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_neighbors() {

    local network_dir="$1"
    local output_file="${network_dir}/neighbors.txt"

    log_info "Collecting neighbor table."

    ip neigh > "${output_file}" || {
        operator_error "Unable to collect neighbor table."
        return 1
    }

    log_success "Neighbor table collected."

    return 0
}

# Purpose: Collect listening ports data for the collector’s staged backup set.
# This comment documents intent; implementation behavior is unchanged.
_polaris_proxmox_collect_listening_ports() {

    local network_dir="$1"
    local output_file="${network_dir}/listening_ports.txt"

    log_info "Collecting listening ports."

    ss -tulpen > "${output_file}" || {
        operator_error "Unable to collect listening ports."
        return 1
    }

    log_success "Listening ports collected."

    return 0
}

###############################################################################
# Firewall Collectors
###############################################################################

###############################################################################
# Function: _polaris_proxmox_collect_firewall
#
# Purpose:
#   Coordinate collection of firewall inventory, configuration, and runtime
#   information.
#
# Parameters:
#   $1 - Network staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_firewall() {

    local network_dir="$1"
    local firewall_dir="${network_dir}/firewall"

    log_info "Collecting firewall information."

    create_directory "${firewall_dir}" || {
        operator_error "Unable to create firewall staging directory."
        return 1
    }

    _polaris_proxmox_collect_firewall_capabilities "${firewall_dir}" || return 1
    _polaris_proxmox_collect_firewall_summary "${firewall_dir}" || return 1
    _polaris_proxmox_collect_iptables "${firewall_dir}" || return 1
    _polaris_proxmox_collect_ip6tables "${firewall_dir}" || return 1
    _polaris_proxmox_collect_nftables "${firewall_dir}" || return 1
    _polaris_proxmox_collect_pve_firewall "${firewall_dir}" || return 1

    log_success "Firewall collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_firewall_capabilities
#
# Purpose:
#   Identify firewall technologies, packages, services, runtime rules, and
#   Proxmox firewall configuration present on the host.
#
# Parameters:
#   $1 - Firewall staging directory.
#
# Returns:
#   0 - Capability assessment collected successfully.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_firewall_capabilities() {

    local firewall_dir="$1"
    local output_file="${firewall_dir}/capabilities.txt"

    local pve_package_status="Not installed"
    local pve_command_status="Not available"
    local pve_service_active="Unknown"
    local pve_service_enabled="Unknown"
    local pve_config_directory="Not present"
    local pve_firewall_file_count="0"
    local datacenter_firewall_setting="Not configured"

    local iptables_package_status="Not installed"
    local iptables_command_status="Not available"
    local iptables_version="Unavailable"
    local iptables_filter_rules="No"
    local iptables_nat_rules="No"

    local ip6tables_command_status="Not available"
    local ip6tables_version="Unavailable"
    local ip6tables_filter_rules="No"
    local ip6tables_nat_rules="No"

    local nftables_package_status="Not installed"
    local nftables_command_status="Not available"
    local nftables_version="Unavailable"
    local nftables_service_active="Unknown"
    local nftables_service_enabled="Unknown"
    local nftables_rules_present="No"

    log_info "Assessing firewall capabilities."

    #
    # Proxmox Firewall
    #

    if dpkg-query -W -f='${Status}' proxmox-firewall 2>/dev/null |
        grep -q "install ok installed"; then
        pve_package_status="Installed: proxmox-firewall"
    elif dpkg-query -W -f='${Status}' pve-firewall 2>/dev/null |
        grep -q "install ok installed"; then
        pve_package_status="Installed: pve-firewall"
    fi

    if command_exists pve-firewall; then
        pve_command_status="Available"
    fi

    if systemctl list-unit-files pve-firewall.service \
        --no-legend 2>/dev/null | grep -q '^pve-firewall\.service'; then

        if systemctl is-active --quiet pve-firewall.service; then
            pve_service_active="Active"
        else
            pve_service_active="Inactive"
        fi

        if systemctl is-enabled --quiet pve-firewall.service 2>/dev/null; then
            pve_service_enabled="Enabled"
        else
            pve_service_enabled="Disabled"
        fi
    else
        pve_service_active="Service not installed"
        pve_service_enabled="Service not installed"
    fi

    if [[ -d /etc/pve/firewall ]]; then
        pve_config_directory="Present"
    fi

    if [[ -d /etc/pve ]]; then
        pve_firewall_file_count="$(
            find /etc/pve -type f -name '*.fw' 2>/dev/null | wc -l
        )"
    fi

    if [[ -f /etc/pve/datacenter.cfg ]]; then
        if grep -Eq '^[[:space:]]*firewall:[[:space:]]*1([[:space:]]|$)' \
            /etc/pve/datacenter.cfg; then
            datacenter_firewall_setting="Enabled"
        elif grep -Eq '^[[:space:]]*firewall:[[:space:]]*0([[:space:]]|$)' \
            /etc/pve/datacenter.cfg; then
            datacenter_firewall_setting="Disabled"
        fi
    fi

    #
    # iptables
    #

    if dpkg-query -W -f='${Status}' iptables 2>/dev/null |
        grep -q "install ok installed"; then
        iptables_package_status="Installed"
    fi

    if command_exists iptables; then
        iptables_command_status="Available"
        iptables_version="$(iptables --version 2>/dev/null || printf 'Unavailable')"

        if iptables -S 2>/dev/null | grep -Eq '^(-A|-N)[[:space:]]'; then
            iptables_filter_rules="Yes"
        fi

        if iptables -t nat -S 2>/dev/null |
            grep -Eq '^(-A|-N)[[:space:]]'; then
            iptables_nat_rules="Yes"
        fi
    fi

    #
    # ip6tables
    #

    if command_exists ip6tables; then
        ip6tables_command_status="Available"
        ip6tables_version="$(
            ip6tables --version 2>/dev/null || printf 'Unavailable'
        )"

        if ip6tables -S 2>/dev/null | grep -Eq '^(-A|-N)[[:space:]]'; then
            ip6tables_filter_rules="Yes"
        fi

        if ip6tables -t nat -S 2>/dev/null |
            grep -Eq '^(-A|-N)[[:space:]]'; then
            ip6tables_nat_rules="Yes"
        fi
    fi

    #
    # nftables
    #

    if dpkg-query -W -f='${Status}' nftables 2>/dev/null |
        grep -q "install ok installed"; then
        nftables_package_status="Installed"
    fi

    if command_exists nft; then
        nftables_command_status="Available"
        nftables_version="$(
            nft --version 2>/dev/null || printf 'Unavailable'
        )"

        if nft list ruleset 2>/dev/null | grep -q '[^[:space:]]'; then
            nftables_rules_present="Yes"
        fi
    fi

    if systemctl list-unit-files nftables.service \
        --no-legend 2>/dev/null | grep -q '^nftables\.service'; then

        if systemctl is-active --quiet nftables.service; then
            nftables_service_active="Active"
        else
            nftables_service_active="Inactive"
        fi

        if systemctl is-enabled --quiet nftables.service 2>/dev/null; then
            nftables_service_enabled="Enabled"
        else
            nftables_service_enabled="Disabled"
        fi
    else
        nftables_service_active="Service not installed"
        nftables_service_enabled="Service not installed"
    fi

    #
    # Write Artifact
    #

    {
        printf '%s\n' "Project Polaris Firewall Capability Assessment"
        printf '%s\n' "=============================================="
        printf 'Generated: %s\n\n' "$(date --iso-8601=seconds)"

        printf '%s\n' "Proxmox Firewall"
        printf '%s\n' "----------------"
        printf 'Package:                   %s\n' "${pve_package_status}"
        printf 'Command:                   %s\n' "${pve_command_status}"
        printf 'Service Active:            %s\n' "${pve_service_active}"
        printf 'Service Enabled:           %s\n' "${pve_service_enabled}"
        printf 'Configuration Directory:   %s\n' "${pve_config_directory}"
        printf 'Firewall Files Found:      %s\n' "${pve_firewall_file_count}"
        printf 'Datacenter Setting:        %s\n\n' \
            "${datacenter_firewall_setting}"

        printf '%s\n' "iptables"
        printf '%s\n' "--------"
        printf 'Package:                   %s\n' "${iptables_package_status}"
        printf 'Command:                   %s\n' "${iptables_command_status}"
        printf 'Version:                   %s\n' "${iptables_version}"
        printf 'Filter Rules Present:      %s\n' "${iptables_filter_rules}"
        printf 'NAT Rules Present:         %s\n\n' "${iptables_nat_rules}"

        printf '%s\n' "ip6tables"
        printf '%s\n' "---------"
        printf 'Command:                   %s\n' "${ip6tables_command_status}"
        printf 'Version:                   %s\n' "${ip6tables_version}"
        printf 'Filter Rules Present:      %s\n' "${ip6tables_filter_rules}"
        printf 'NAT Rules Present:         %s\n\n' "${ip6tables_nat_rules}"

        printf '%s\n' "nftables"
        printf '%s\n' "--------"
        printf 'Package:                   %s\n' "${nftables_package_status}"
        printf 'Command:                   %s\n' "${nftables_command_status}"
        printf 'Version:                   %s\n' "${nftables_version}"
        printf 'Service Active:            %s\n' "${nftables_service_active}"
        printf 'Service Enabled:           %s\n' "${nftables_service_enabled}"
        printf 'Runtime Rules Present:     %s\n' "${nftables_rules_present}"
    } > "${output_file}" || {
        operator_error "Unable to write firewall capability assessment."
        return 1
    }

    log_success "Firewall capability assessment collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_firewall_summary
#
# Purpose:
#   Generate a human-readable operational summary of the firewall subsystem
#   using previously collected artifacts. This function does not query the
#   operating system directly.
#
# Parameters:
#   $1 - Firewall staging directory.
#
# Returns:
#   0 - Summary generated successfully.
#   1 - Summary generation failed.
###############################################################################

_polaris_proxmox_collect_firewall_summary() {

    local firewall_dir="$1"

    local capabilities_file="${firewall_dir}/capabilities.txt"
    local output_file="${firewall_dir}/firewall_summary.txt"

    log_info "Generating firewall summary."

    if [[ ! -f "${capabilities_file}" ]]; then
        operator_error "Firewall capability assessment not found."
        return 1
    fi

    local pve_service
    local datacenter_setting
    local firewall_files

    local iptables_rules
    local ip6tables_rules

    local nft_service
    local nft_rules

    pve_service="$(awk -F':' '/Service Active/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' "${capabilities_file}")"
    datacenter_setting="$(awk -F':' '/Datacenter Setting/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' "${capabilities_file}")"
    firewall_files="$(awk -F':' '/Firewall Files Found/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' "${capabilities_file}")"

    iptables_rules="$(awk -F':' '/Filter Rules Present/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' "${capabilities_file}")"
    ip6tables_rules="$(awk '
        /^ip6tables$/ {section=1; next}
        /^nftables$/ {section=0}
        section && /Filter Rules Present/ {
            split($0,a,":")
            gsub(/^[ \t]+/,"",a[2])
            print a[2]
            exit
        }' "${capabilities_file}")"

    nft_service="$(awk '
        /^nftables$/ {section=1; next}
        section && /Service Active/ {
            split($0,a,":")
            gsub(/^[ \t]+/,"",a[2])
            print a[2]
            exit
        }' "${capabilities_file}")"

    nft_rules="$(awk '
        /^nftables$/ {section=1; next}
        section && /Runtime Rules Present/ {
            split($0,a,":")
            gsub(/^[ \t]+/,"",a[2])
            print a[2]
            exit
        }' "${capabilities_file}")"

    {
        echo "Project Polaris Firewall Summary"
        echo "================================"
        echo

        echo "Overall Status"
        echo "--------------"

        if [[ "${pve_service}" == "Active" ]]; then
            echo "Firewall Status ............. Operational"
        else
            echo "Firewall Status ............. Limited"
        fi

        echo
        echo "Firewall Technologies"
        echo "---------------------"

        printf "%-30s %s\n" "Proxmox Firewall" "${pve_service}"
        printf "%-30s %s\n" "iptables" "${iptables_rules}"
        printf "%-30s %s\n" "ip6tables" "${ip6tables_rules}"
        printf "%-30s %s\n" "nftables" "${nft_service}"

        echo
        echo "Configuration"
        echo "-------------"

        printf "%-30s %s\n" "Datacenter Firewall" "${datacenter_setting}"
        printf "%-30s %s\n" "Firewall Rule Files" "${firewall_files}"

        echo
        echo "Observations"
        echo "------------"

        [[ "${pve_service}" == "Active" ]] \
            && echo "• Proxmox firewall service is operational." \
            || echo "• Proxmox firewall service is not running."

        [[ "${datacenter_setting}" == "Not configured" ]] \
            && echo "• No datacenter firewall policy is configured."

        [[ "${firewall_files}" == "0" ]] \
            && echo "• No Proxmox firewall rule files were detected."

        [[ "${iptables_rules}" == "Yes" ]] \
            && echo "• IPv4 runtime packet filtering is present."

        [[ "${ip6tables_rules}" == "Yes" ]] \
            && echo "• IPv6 runtime packet filtering is present."

        [[ "${nft_service}" == "Inactive" ]] \
            && echo "• nftables is installed but not active."

        [[ "${nft_rules}" == "No" ]] \
            && echo "• No active nftables ruleset was detected."

    } > "${output_file}" || {
        operator_error "Unable to generate firewall summary."
        return 1
    }

    log_success "Firewall summary generated."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_iptables
#
# Purpose:
#   Collect the runtime IPv4 iptables configuration for all available tables.
#   Each table is exported individually using iptables-save to preserve an
#   accurate backup of the active firewall configuration.
#
# Parameters:
#   $1 - Firewall staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_iptables() {

    local firewall_dir="$1"
    local iptables_dir="${firewall_dir}/iptables"

    log_info "Collecting IPv4 iptables configuration."

    create_directory "${iptables_dir}" || {
        operator_error "Unable to create iptables staging directory."
        return 1
    }

    if ! command_exists iptables-save; then
        operator_warning "iptables-save not available. Skipping IPv4 iptables collection."
        return 0
    fi

    local tables=(
        filter
        nat
        mangle
        raw
        security
    )

    local table
    local output_file

    for table in "${tables[@]}"; do

        output_file="${iptables_dir}/${table}.txt"

        if iptables-save -t "${table}" > "${output_file}" 2>/dev/null; then

            log_success "Collected iptables ${table} table."

        else

            rm -f "${output_file}"

            log_info "iptables ${table} table not present."

        fi

    done

    log_success "IPv4 iptables collection complete."

    return 0

}

###############################################################################
# Function: _polaris_proxmox_collect_ip6tables
#
# Purpose:
#   Collect the runtime IPv6 ip6tables configuration for all available tables.
#   Each table is exported individually using ip6tables-save to preserve an
#   accurate backup of the active IPv6 firewall configuration.
#
# Parameters:
#   $1 - Firewall staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_ip6tables() {

    local firewall_dir="$1"
    local ip6tables_dir="${firewall_dir}/ip6tables"

    log_info "Collecting IPv6 ip6tables configuration."

    create_directory "${ip6tables_dir}" || {
        operator_error "Unable to create ip6tables staging directory."
        return 1
    }

    if ! command_exists ip6tables-save; then
        operator_warning "ip6tables-save not available. Skipping IPv6 ip6tables collection."
        return 0
    fi

    local tables=(
        filter
        nat
        mangle
        raw
        security
    )

    local table
    local output_file

    for table in "${tables[@]}"; do

        output_file="${ip6tables_dir}/${table}.txt"

        if ip6tables-save -t "${table}" > "${output_file}" 2>/dev/null; then
            log_success "Collected ip6tables ${table} table."
        else
            rm -f "${output_file}"
            log_info "ip6tables ${table} table not present."
        fi

    done

    log_success "IPv6 ip6tables collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_nftables
#
# Purpose:
#   Collect the active nftables runtime configuration. The complete ruleset is
#   exported using nft list ruleset to preserve an accurate backup of the
#   firewall configuration.
#
# Parameters:
#   $1 - Firewall staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_nftables() {

    local firewall_dir="$1"
    local nftables_dir="${firewall_dir}/nftables"

    log_info "Collecting nftables configuration."

    create_directory "${nftables_dir}" || {
        operator_error "Unable to create nftables staging directory."
        return 1
    }

    if ! command_exists nft; then
        operator_warning "nft command not available. Skipping nftables collection."
        return 0
    fi

    local output_file="${nftables_dir}/ruleset.txt"

    if nft list ruleset > "${output_file}" 2>/dev/null; then

        log_success "Collected nftables ruleset."

    else

        rm -f "${output_file}"

        log_info "No active nftables ruleset present."

    fi

    log_success "nftables collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_pve_firewall
#
# Purpose:
#   Collect Proxmox VE firewall configuration files from the cluster-wide,
#   guest-specific, and node-specific configuration locations.
#
# Parameters:
#   $1 - Firewall staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_pve_firewall() {

    local firewall_dir="$1"
    local pve_firewall_dir="${firewall_dir}/pve-firewall"

    local cluster_dir="${pve_firewall_dir}/cluster"
    local nodes_dir="${pve_firewall_dir}/nodes"

    local source_cluster_dir="/etc/pve/firewall"
    local source_nodes_dir="/etc/pve/nodes"

    local collected_count=0
    local source_file
    local filename
    local node_name
    local destination_dir

    log_info "Collecting Proxmox firewall configuration."

    create_directory "${cluster_dir}" || {
        operator_error "Unable to create Proxmox cluster firewall staging directory."
        return 1
    }

    create_directory "${nodes_dir}" || {
        operator_error "Unable to create Proxmox node firewall staging directory."
        return 1
    }

    #
    # Collect cluster-wide and guest-specific firewall files.
    #

    if [[ -d "${source_cluster_dir}" ]]; then

        while IFS= read -r -d '' source_file; do

            filename="$(basename "${source_file}")"

            if cp --preserve=mode,timestamps \
                "${source_file}" \
                "${cluster_dir}/${filename}"; then

                log_success "Collected Proxmox firewall file: ${filename}"
                ((collected_count += 1))

            else

                operator_error "Unable to collect Proxmox firewall file: ${source_file}"
                return 1

            fi

        done < <(
            find "${source_cluster_dir}" \
                -maxdepth 1 \
                -type f \
                -name "*.fw" \
                -print0 2>/dev/null
        )

    fi

    #
    # Collect node-specific host firewall files.
    #

    if [[ -d "${source_nodes_dir}" ]]; then

        while IFS= read -r -d '' source_file; do

            node_name="$(basename "$(dirname "${source_file}")")"
            destination_dir="${nodes_dir}/${node_name}"

            create_directory "${destination_dir}" || {
                operator_error \
                    "Unable to create firewall staging directory for node: ${node_name}"
                return 1
            }

            if cp --preserve=mode,timestamps \
                "${source_file}" \
                "${destination_dir}/host.fw"; then

                log_success \
                    "Collected Proxmox host firewall file for node: ${node_name}"

                ((collected_count += 1))

            else

                operator_error \
                    "Unable to collect Proxmox host firewall file for node: ${node_name}"

                return 1

            fi

        done < <(
            find "${source_nodes_dir}" \
                -mindepth 2 \
                -maxdepth 2 \
                -type f \
                -name "host.fw" \
                -print0 2>/dev/null
        )

    fi

    if (( collected_count == 0 )); then
        log_info "No Proxmox firewall configuration files were present."
    fi

    log_success "Proxmox firewall configuration collection complete."

    return 0
}

###############################################################################
# Virtual Machine Collectors
###############################################################################

###############################################################################
# Function: _polaris_proxmox_collect_vms
#
# Purpose:
#   Coordinate virtual machine and container collection.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_vms() {

    local staging_root="${POLARIS_PROXMOX_STAGING_ROOT}"
    local vm_dir="${staging_root}/virtual-machines"
    local container_dir="${staging_root}/containers"

    log_info "Collecting virtual machine and container information."

    create_directory "${vm_dir}" || {
        operator_error "Unable to create virtual machine staging directory."
        return 1
    }

    create_directory "${container_dir}" || {
        operator_error "Unable to create container staging directory."
        return 1
    }

    _polaris_proxmox_collect_vm_inventory "${vm_dir}" || return 1
    _polaris_proxmox_collect_cluster_vm_inventory "${vm_dir}" || return 1

    _polaris_proxmox_collect_qemu_configs "${vm_dir}" || return 1
    _polaris_proxmox_collect_qemu_status "${vm_dir}" || return 1
    _polaris_proxmox_collect_qemu_snapshots "${vm_dir}" || return 1
    _polaris_proxmox_collect_qemu_disks "${vm_dir}" || return 1
    _polaris_proxmox_collect_qemu_network "${vm_dir}" || return 1

    _polaris_proxmox_collect_lxc_configs "${vm_dir}" "${container_dir}" || return 1
    _polaris_proxmox_collect_lxc_status "${vm_dir}" "${container_dir}" || return 1
    _polaris_proxmox_collect_lxc_mounts "${vm_dir}" "${container_dir}" || return 1
    _polaris_proxmox_collect_lxc_network "${vm_dir}" "${container_dir}" || return 1

    _polaris_proxmox_collect_vm_summary "${vm_dir}" "${container_dir}" || return 1

    log_success "Virtual machine and container collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_vm_inventory
#
# Purpose:
#   Collect an inventory of all QEMU virtual machines and LXC containers.
#
# Parameters:
#   $1 - VM staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_vm_inventory() {

    local vm_dir="$1"
    local output_file="${vm_dir}/inventory.txt"

    log_info "Collecting virtual machine inventory."

    {
        echo "Project Polaris Virtual Machine Inventory"
        echo "========================================="
        echo
        echo "Collection Time"
        echo "---------------"
        date -u '+%Y-%m-%d %H:%M:%S UTC'
        echo

        echo "QEMU Virtual Machines"
        echo "---------------------"

        if command_exists qm; then
            qm list
        else
            echo "QEMU tools not available."
        fi

        echo
        echo "LXC Containers"
        echo "--------------"

        if command_exists pct; then
            pct list
        else
            echo "LXC tools not available."
        fi

    } > "${output_file}" || {
        operator_error "Unable to write VM inventory."
        return 1
    }

    log_success "Virtual machine inventory collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_cluster_vm_inventory
#
# Purpose:
#   Collect a cluster-wide inventory of QEMU virtual machines and LXC
#   containers using the Proxmox cluster resource database.
#
# Parameters:
#   $1 - Virtual machine staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_cluster_vm_inventory() {

    local vm_dir="$1"
    local output_file="${vm_dir}/cluster-inventory.txt"
    local temporary_json="${vm_dir}/.cluster-inventory.json"

    log_info "Collecting cluster-wide guest inventory."

    if ! command_exists pvesh; then
        operator_error "pvesh command is not available."
        return 1
    fi

    if ! command_exists jq; then
        operator_error "jq command is required for cluster guest inventory collection."
        return 1
    fi

    if ! command_exists column; then
        operator_error "column command is required for cluster guest inventory formatting."
        return 1
    fi

    if ! pvesh get /cluster/resources \
        --type vm \
        --output-format json \
        > "${temporary_json}" 2>/dev/null; then

        rm -f "${temporary_json}"
        operator_error "Unable to query cluster guest inventory."
        return 1
    fi

    if ! jq -e 'type == "array"' "${temporary_json}" >/dev/null 2>&1; then
        rm -f "${temporary_json}"
        operator_error "Cluster guest inventory returned invalid JSON."
        return 1
    fi

    {
        echo "Project Polaris Cluster Guest Inventory"
        echo "======================================="
        echo
        echo "Collection Time"
        echo "---------------"
        date -u '+%Y-%m-%d %H:%M:%S UTC'
        echo

        echo "QEMU Virtual Machines"
        echo "---------------------"
        echo

        jq -r '
            .[]
            | select(.type == "qemu")
            | [
                (.vmid | tostring),
                (.name // "-"),
                (.node // "-"),
                (.status // "-")
              ]
            | @tsv
        ' "${temporary_json}" | column -t

        echo
        echo "LXC Containers"
        echo "--------------"
        echo

        jq -r '
            .[]
            | select(.type == "lxc")
            | [
                (.vmid | tostring),
                (.name // "-"),
                (.node // "-"),
                (.status // "-")
              ]
            | @tsv
        ' "${temporary_json}" | column -t

    } > "${output_file}" || {
        rm -f "${temporary_json}" "${output_file}"
        operator_error "Unable to write cluster guest inventory."
        return 1
    }

    rm -f "${temporary_json}"

    log_success "Cluster guest inventory collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_qemu_configs
#
# Purpose:
#   Collect the configuration of all QEMU virtual machines.
#
# Parameters:
#   $1 - Virtual machine staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_qemu_configs() {

    local vm_dir="$1"
    local qemu_dir="${vm_dir}/qemu"

    log_info "Collecting QEMU virtual machine configurations."

    create_directory "${qemu_dir}" || {
        operator_error "Unable to create QEMU staging directory."
        return 1
    }

    if ! command_exists qm; then
        operator_warning "qm command not available. Skipping QEMU configuration collection."
        return 0
    fi

    local vmid
    local vm_name
    local vm_path

    while read -r vmid vm_name _; do

        [[ "${vmid}" == "VMID" ]] && continue
        [[ -z "${vmid}" ]] && continue

        vm_path="${qemu_dir}/${vmid}"

        create_directory "${vm_path}" || {
            operator_error "Unable to create staging directory for VM ${vmid}."
            return 1
        }

        if qm config "${vmid}" > "${vm_path}/config.conf"; then
            log_success "Collected configuration for VM ${vmid} (${vm_name})."
        else
            operator_error "Unable to collect configuration for VM ${vmid}."
            return 1
        fi

    done < <(qm list)

    log_success "QEMU configuration collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_qemu_status
#
# Purpose:
#   Collect the current runtime status of every QEMU virtual machine listed in
#   the previously generated virtual machine inventory artifact.
#
# Parameters:
#   $1 - Virtual machine staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_qemu_status() {

    local vm_dir="$1"

    local inventory_file="${vm_dir}/inventory.txt"
    local qemu_dir="${vm_dir}/qemu"

    local vmid
    local vm_name
    local vm_path
    local output_file

    log_info "Collecting QEMU virtual machine runtime status."

    if [[ ! -f "${inventory_file}" ]]; then
        operator_error "Virtual machine inventory artifact not found."
        return 1
    fi

    create_directory "${qemu_dir}" || {
        operator_error "Unable to create QEMU staging directory."
        return 1
    }

    if ! command_exists qm; then
        operator_warning "qm command not available. Skipping QEMU status collection."
        return 0
    fi

    while read -r vmid vm_name; do

        [[ -z "${vmid}" ]] && continue

        vm_path="${qemu_dir}/${vmid}"
        output_file="${vm_path}/status.txt"

        create_directory "${vm_path}" || {
            operator_error "Unable to create staging directory for VM ${vmid}."
            return 1
        }

        if qm status "${vmid}" --verbose > "${output_file}" 2>/dev/null; then
            log_success "Collected runtime status for VM ${vmid} (${vm_name})."
        else
            rm -f "${output_file}"
            operator_error "Unable to collect runtime status for VM ${vmid}."
            return 1
        fi

    done < <(
        awk '
            /^QEMU Virtual Machines$/ {
                in_qemu = 1
                next
            }

            /^LXC Containers$/ {
                in_qemu = 0
            }

            in_qemu && $1 ~ /^[0-9]+$/ {
                print $1, $2
            }
        ' "${inventory_file}"
    )

    log_success "QEMU runtime status collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_qemu_snapshots
#
# Purpose:
#   Collect the snapshot inventory for every QEMU virtual machine listed in
#   the previously generated virtual machine inventory artifact.
#
# Parameters:
#   $1 - Virtual machine staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_qemu_snapshots() {

    local vm_dir="$1"

    local inventory_file="${vm_dir}/inventory.txt"
    local qemu_dir="${vm_dir}/qemu"

    local vmid
    local vm_name
    local vm_path
    local output_file

    log_info "Collecting QEMU virtual machine snapshots."

    if [[ ! -f "${inventory_file}" ]]; then
        operator_error "Virtual machine inventory artifact not found."
        return 1
    fi

    create_directory "${qemu_dir}" || {
        operator_error "Unable to create QEMU staging directory."
        return 1
    }

    if ! command_exists qm; then
        operator_warning "qm command not available. Skipping QEMU snapshot collection."
        return 0
    fi

    while read -r vmid vm_name; do

        [[ -z "${vmid}" ]] && continue

        vm_path="${qemu_dir}/${vmid}"
        output_file="${vm_path}/snapshots.txt"

        create_directory "${vm_path}" || {
            operator_error "Unable to create staging directory for VM ${vmid}."
            return 1
        }

        if qm listsnapshot "${vmid}" > "${output_file}" 2>/dev/null; then
            log_success "Collected snapshot inventory for VM ${vmid} (${vm_name})."
        else
            rm -f "${output_file}"
            operator_error "Unable to collect snapshot inventory for VM ${vmid}."
            return 1
        fi

    done < <(
        awk '
            /^QEMU Virtual Machines$/ {
                in_qemu = 1
                next
            }

            /^LXC Containers$/ {
                in_qemu = 0
            }

            in_qemu && $1 ~ /^[0-9]+$/ {
                print $1, $2
            }
        ' "${inventory_file}"
    )

    log_success "QEMU snapshot collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_qemu_disks
#
# Purpose:
#   Collect the virtual disk configuration for each QEMU virtual machine.
#
# Parameters:
#   $1 - Virtual machine staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_qemu_disks() {

    local vm_dir="$1"

    local inventory_file="${vm_dir}/inventory.txt"
    local qemu_dir="${vm_dir}/qemu"

    local vmid
    local vm_name
    local vm_path
    local output_file

    log_info "Collecting QEMU virtual disk configuration."

    if [[ ! -f "${inventory_file}" ]]; then
        operator_error "Virtual machine inventory artifact not found."
        return 1
    fi

    if ! command_exists qm; then
        operator_warning "qm command not available. Skipping QEMU disk collection."
        return 0
    fi

    while read -r vmid vm_name; do

        [[ -z "${vmid}" ]] && continue

        vm_path="${qemu_dir}/${vmid}"
        output_file="${vm_path}/disks.txt"

        create_directory "${vm_path}" || {
            operator_error "Unable to create staging directory for VM ${vmid}."
            return 1
        }

        if qm config "${vmid}" | grep -E \
            '^(virtio|scsi|sata|ide|efidisk|tpmstate|unused)[0-9]*:' \
            > "${output_file}"; then

            log_success "Collected disk inventory for VM ${vmid} (${vm_name})."

        else

            : > "${output_file}"

            log_info "No virtual disks detected for VM ${vmid}."

        fi

    done < <(
        awk '
            /^QEMU Virtual Machines$/ { in_qemu=1; next }
            /^LXC Containers$/ { in_qemu=0 }
            in_qemu && $1 ~ /^[0-9]+$/ { print $1, $2 }
        ' "${inventory_file}"
    )

    log_success "QEMU disk collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_qemu_network
#
# Purpose:
#   Collect the virtual network interface configuration for each QEMU virtual
#   machine listed in the virtual machine inventory artifact.
#
# Parameters:
#   $1 - Virtual machine staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_qemu_network() {

    local vm_dir="$1"

    local inventory_file="${vm_dir}/inventory.txt"
    local qemu_dir="${vm_dir}/qemu"

    local vmid
    local vm_name
    local vm_path
    local output_file

    log_info "Collecting QEMU virtual network configuration."

    if [[ ! -f "${inventory_file}" ]]; then
        operator_error "Virtual machine inventory artifact not found."
        return 1
    fi

    if ! command_exists qm; then
        operator_warning "qm command not available. Skipping QEMU network collection."
        return 0
    fi

    while read -r vmid vm_name; do

        [[ -z "${vmid}" ]] && continue

        vm_path="${qemu_dir}/${vmid}"
        output_file="${vm_path}/network.txt"

        create_directory "${vm_path}" || {
            operator_error "Unable to create staging directory for VM ${vmid}."
            return 1
        }

        if qm config "${vmid}" \
            | grep -E '^net[0-9]+:' \
            > "${output_file}"; then

            log_success \
                "Collected network inventory for VM ${vmid} (${vm_name})."

        else

            : > "${output_file}"

            log_info \
                "No virtual network interfaces detected for VM ${vmid}."

        fi

    done < <(
        awk '
            /^QEMU Virtual Machines$/ {
                in_qemu = 1
                next
            }

            /^LXC Containers$/ {
                in_qemu = 0
            }

            in_qemu && $1 ~ /^[0-9]+$/ {
                print $1, $2
            }
        ' "${inventory_file}"
    )

    log_success "QEMU network collection complete."

    return 0
}

###############################################################################
# Container Collectors
###############################################################################

###############################################################################
# Function: _polaris_proxmox_collect_lxc_configs
#
# Purpose:
#   Collect the configuration of every LXC container listed in the previously
#   generated virtual machine inventory artifact.
#
# Parameters:
#   $1 - Virtual machine staging directory containing inventory.txt.
#   $2 - Container staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_lxc_configs() {

    local vm_dir="$1"
    local container_dir="$2"

    local inventory_file="${vm_dir}/inventory.txt"

    local vmid
    local container_name
    local container_path
    local output_file
    local container_count=0

    log_info "Collecting LXC container configurations."

    if [[ ! -f "${inventory_file}" ]]; then
        operator_error "Virtual machine inventory artifact not found."
        return 1
    fi

    create_directory "${container_dir}" || {
        operator_error "Unable to create container staging directory."
        return 1
    }

    if ! command_exists pct; then
        operator_warning \
            "pct command not available. Skipping LXC configuration collection."
        return 0
    fi

    while read -r vmid container_name; do

        [[ -z "${vmid}" ]] && continue

        ((container_count += 1))

        container_path="${container_dir}/${vmid}"
        output_file="${container_path}/config.conf"

        create_directory "${container_path}" || {
            operator_error \
                "Unable to create staging directory for container ${vmid}."
            return 1
        }

        if pct config "${vmid}" > "${output_file}" 2>/dev/null; then
            log_success \
                "Collected configuration for container ${vmid} (${container_name})."
        else
            rm -f "${output_file}"
            operator_error \
                "Unable to collect configuration for container ${vmid}."
            return 1
        fi

    done < <(
        awk '
            /^LXC Containers$/ {
                in_lxc = 1
                next
            }

            in_lxc && $1 ~ /^[0-9]+$/ {
                print $1, $2
            }
        ' "${inventory_file}"
    )

    if (( container_count == 0 )); then
        log_info "No LXC containers were present in the inventory."
    fi

    log_success "LXC configuration collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_lxc_status
#
# Purpose:
#   Collect the runtime status of every LXC container listed in the previously
#   generated virtual machine inventory artifact.
#
# Parameters:
#   $1 - Virtual machine staging directory.
#   $2 - Container staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_lxc_status() {

    local vm_dir="$1"
    local container_dir="$2"

    local inventory_file="${vm_dir}/inventory.txt"

    local vmid
    local container_name
    local container_path
    local output_file
    local container_count=0

    log_info "Collecting LXC container runtime status."

    if [[ ! -f "${inventory_file}" ]]; then
        operator_error "Virtual machine inventory artifact not found."
        return 1
    fi

    if ! command_exists pct; then
        operator_warning \
            "pct command not available. Skipping LXC runtime status collection."
        return 0
    fi

    while read -r vmid container_name; do

        [[ -z "${vmid}" ]] && continue

        ((container_count += 1))

        container_path="${container_dir}/${vmid}"
        output_file="${container_path}/status.txt"

        create_directory "${container_path}" || {
            operator_error \
                "Unable to create staging directory for container ${vmid}."
            return 1
        }

        if pct status "${vmid}" > "${output_file}" 2>/dev/null; then

            log_success \
                "Collected runtime status for container ${vmid} (${container_name})."

        else

            rm -f "${output_file}"

            operator_error \
                "Unable to collect runtime status for container ${vmid}."

            return 1

        fi

    done < <(
        awk '
            /^LXC Containers$/ {
                in_lxc=1
                next
            }

            in_lxc && $1 ~ /^[0-9]+$/ {
                print $1,$2
            }
        ' "${inventory_file}"
    )

    if (( container_count == 0 )); then
        log_info "No LXC containers were present in the inventory."
    fi

    log_success "LXC runtime status collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_lxc_mounts
#
# Purpose:
#   Collect mount point configuration for every LXC container listed in the
#   virtual machine inventory artifact.
#
# Parameters:
#   $1 - Virtual machine staging directory.
#   $2 - Container staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_lxc_mounts() {

    local vm_dir="$1"
    local container_dir="$2"

    local inventory_file="${vm_dir}/inventory.txt"

    local vmid
    local container_name
    local container_path
    local output_file
    local container_count=0

    log_info "Collecting LXC container mount configuration."

    if [[ ! -f "${inventory_file}" ]]; then
        operator_error "Virtual machine inventory artifact not found."
        return 1
    fi

    if ! command_exists pct; then
        operator_warning \
            "pct command not available. Skipping LXC mount collection."
        return 0
    fi

    while read -r vmid container_name; do

        [[ -z "${vmid}" ]] && continue

        ((container_count += 1))

        container_path="${container_dir}/${vmid}"
        output_file="${container_path}/mounts.txt"

        create_directory "${container_path}" || {
            operator_error \
                "Unable to create staging directory for container ${vmid}."
            return 1
        }

        if pct config "${vmid}" \
            | grep -E '^(rootfs|mp[0-9]+):' \
            > "${output_file}"; then

            log_success \
                "Collected mount configuration for container ${vmid} (${container_name})."

        else

            : > "${output_file}"

            log_info \
                "No mount points detected for container ${vmid}."

        fi

    done < <(
        awk '
            /^LXC Containers$/ {
                in_lxc=1
                next
            }

            in_lxc && $1 ~ /^[0-9]+$/ {
                print $1,$2
            }
        ' "${inventory_file}"
    )

    if (( container_count == 0 )); then
        log_info "No LXC containers were present in the inventory."
    fi

    log_success "LXC mount collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_lxc_network
#
# Purpose:
#   Collect virtual network interface configuration for every LXC container
#   listed in the virtual machine inventory artifact.
#
# Parameters:
#   $1 - Virtual machine staging directory.
#   $2 - Container staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_lxc_network() {

    local vm_dir="$1"
    local container_dir="$2"

    local inventory_file="${vm_dir}/inventory.txt"

    local vmid
    local container_name
    local container_path
    local output_file
    local container_count=0

    log_info "Collecting LXC container network configuration."

    if [[ ! -f "${inventory_file}" ]]; then
        operator_error "Virtual machine inventory artifact not found."
        return 1
    fi

    if ! command_exists pct; then
        operator_warning \
            "pct command not available. Skipping LXC network collection."
        return 0
    fi

    while read -r vmid container_name; do

        [[ -z "${vmid}" ]] && continue

        ((container_count += 1))

        container_path="${container_dir}/${vmid}"
        output_file="${container_path}/network.txt"

        create_directory "${container_path}" || {
            operator_error \
                "Unable to create staging directory for container ${vmid}."
            return 1
        }

        if pct config "${vmid}" \
            | grep -E '^net[0-9]+:' \
            > "${output_file}"; then

            log_success \
                "Collected network configuration for container ${vmid} (${container_name})."

        else

            : > "${output_file}"

            log_info \
                "No virtual network interfaces detected for container ${vmid}."

        fi

    done < <(
        awk '
            /^LXC Containers$/ {
                in_lxc = 1
                next
            }

            in_lxc && $1 ~ /^[0-9]+$/ {
                print $1, $2
            }
        ' "${inventory_file}"
    )

    if (( container_count == 0 )); then
        log_info "No LXC containers were present in the inventory."
    fi

    log_success "LXC network collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_vm_summary
#
# Purpose:
#   Generate a human-readable summary of QEMU virtual machines and LXC
#   containers using only previously collected artifacts.
#
# Parameters:
#   $1 - Virtual machine staging directory.
#   $2 - Container staging directory.
#
# Returns:
#   0 - Summary generated successfully.
#   1 - Summary generation failed.
###############################################################################

_polaris_proxmox_collect_vm_summary() {

    local vm_dir="$1"
    local container_dir="$2"

    local inventory_file="${vm_dir}/inventory.txt"
    local output_file="${vm_dir}/summary.txt"
    local qemu_dir="${vm_dir}/qemu"

    local qemu_total=0
    local qemu_running=0
    local qemu_stopped=0
    local qemu_templates=0
    local qemu_protected=0
    local qemu_snapshot_count=0
    local qemu_memory_mb=0

    local lxc_total=0
    local lxc_running=0
    local lxc_stopped=0

    local config_file
    local status_file
    local snapshots_file
    local snapshot_count

    log_info "Generating virtual machine and container summary."

    if [[ ! -f "${inventory_file}" ]]; then
        operator_error "Virtual machine inventory artifact not found."
        return 1
    fi

    qemu_total="$(
        awk '
            /^QEMU Virtual Machines$/ {
                in_qemu = 1
                next
            }

            /^LXC Containers$/ {
                in_qemu = 0
            }

            in_qemu && $1 ~ /^[0-9]+$/ {
                count += 1
            }

            END {
                print count + 0
            }
        ' "${inventory_file}"
    )"

    qemu_running="$(
        awk '
            /^QEMU Virtual Machines$/ {
                in_qemu = 1
                next
            }

            /^LXC Containers$/ {
                in_qemu = 0
            }

            in_qemu && $1 ~ /^[0-9]+$/ && $3 == "running" {
                count += 1
            }

            END {
                print count + 0
            }
        ' "${inventory_file}"
    )"

    qemu_stopped="$(
        awk '
            /^QEMU Virtual Machines$/ {
                in_qemu = 1
                next
            }

            /^LXC Containers$/ {
                in_qemu = 0
            }

            in_qemu && $1 ~ /^[0-9]+$/ && $3 == "stopped" {
                count += 1
            }

            END {
                print count + 0
            }
        ' "${inventory_file}"
    )"

    qemu_memory_mb="$(
        awk '
            /^QEMU Virtual Machines$/ {
                in_qemu = 1
                next
            }

            /^LXC Containers$/ {
                in_qemu = 0
            }

            in_qemu && $1 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ {
                total += $4
            }

            END {
                print total + 0
            }
        ' "${inventory_file}"
    )"

    lxc_total="$(
        awk '
            /^LXC Containers$/ {
                in_lxc = 1
                next
            }

            in_lxc && $1 ~ /^[0-9]+$/ {
                count += 1
            }

            END {
                print count + 0
            }
        ' "${inventory_file}"
    )"

    lxc_running="$(
        awk '
            /^LXC Containers$/ {
                in_lxc = 1
                next
            }

            in_lxc && $1 ~ /^[0-9]+$/ && $3 == "running" {
                count += 1
            }

            END {
                print count + 0
            }
        ' "${inventory_file}"
    )"

    lxc_stopped="$(
        awk '
            /^LXC Containers$/ {
                in_lxc = 1
                next
            }

            in_lxc && $1 ~ /^[0-9]+$/ && $3 == "stopped" {
                count += 1
            }

            END {
                print count + 0
            }
        ' "${inventory_file}"
    )"

    if [[ -d "${qemu_dir}" ]]; then

        while IFS= read -r -d '' config_file; do

            if grep -qE '^template:[[:space:]]*1$' "${config_file}"; then
                ((qemu_templates += 1))
            fi

            if grep -qE '^protection:[[:space:]]*1$' "${config_file}"; then
                ((qemu_protected += 1))
            fi

        done < <(
            find "${qemu_dir}" \
                -mindepth 2 \
                -maxdepth 2 \
                -type f \
                -name "config.conf" \
                -print0
        )

        while IFS= read -r -d '' snapshots_file; do

            snapshot_count="$(
                awk '
                    /->/ && $0 !~ /current/ {
                        count += 1
                    }

                    END {
                        print count + 0
                    }
                ' "${snapshots_file}"
            )"

            ((qemu_snapshot_count += snapshot_count))

        done < <(
            find "${qemu_dir}" \
                -mindepth 2 \
                -maxdepth 2 \
                -type f \
                -name "snapshots.txt" \
                -print0
        )

    fi

    {
        echo "Project Polaris Virtual Machine and Container Summary"
        echo "====================================================="
        echo

        echo "QEMU Virtual Machines"
        echo "---------------------"
        printf "%-32s %s\n" "Total Virtual Machines" "${qemu_total}"
        printf "%-32s %s\n" "Running" "${qemu_running}"
        printf "%-32s %s\n" "Stopped" "${qemu_stopped}"
        printf "%-32s %s\n" "Templates" "${qemu_templates}"
        printf "%-32s %s\n" "Protected" "${qemu_protected}"
        printf "%-32s %s\n" "Snapshots" "${qemu_snapshot_count}"
        printf "%-32s %s MB\n" "Configured Memory" "${qemu_memory_mb}"
        echo

        echo "LXC Containers"
        echo "--------------"
        printf "%-32s %s\n" "Total Containers" "${lxc_total}"
        printf "%-32s %s\n" "Running" "${lxc_running}"
        printf "%-32s %s\n" "Stopped" "${lxc_stopped}"
        echo

        echo "Artifact Status"
        echo "---------------"

        if [[ -d "${qemu_dir}" ]]; then
            echo "QEMU artifacts ............... Present"
        else
            echo "QEMU artifacts ............... Missing"
        fi

        if [[ -d "${container_dir}" ]]; then
            echo "LXC artifact directory ....... Present"
        else
            echo "LXC artifact directory ....... Missing"
        fi

        echo
        echo "Observations"
        echo "------------"

        if (( qemu_total > 0 )); then
            echo "• QEMU virtual machine inventory was collected successfully."
        else
            echo "• No QEMU virtual machines were present."
        fi

        if (( qemu_running > 0 )); then
            echo "• ${qemu_running} QEMU virtual machine(s) were running at collection time."
        fi

        if (( qemu_stopped > 0 )); then
            echo "• ${qemu_stopped} QEMU virtual machine(s) were stopped at collection time."
        fi

        if (( qemu_templates > 0 )); then
            echo "• ${qemu_templates} QEMU template(s) were detected."
        fi

        if (( qemu_snapshot_count > 0 )); then
            echo "• ${qemu_snapshot_count} QEMU snapshot(s) were detected."
        else
            echo "• No QEMU snapshots were detected."
        fi

        if (( lxc_total == 0 )); then
            echo "• No LXC containers were present."
        fi

    } > "${output_file}" || {
        operator_error "Unable to generate virtual machine summary."
        return 1
    }

    log_success "Virtual machine and container summary generated."

    return 0
}

###############################################################################
# Cluster Collectors
###############################################################################

###############################################################################
# Function: _polaris_proxmox_collect_cluster
#
# Purpose:
#   Coordinate Proxmox cluster information collection.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_cluster() {

    local cluster_dir="${POLARIS_PROXMOX_STAGING_ROOT}/cluster"

    log_info "Collecting Proxmox cluster information."

    create_directory "${cluster_dir}" || {
        operator_error "Unable to create cluster staging directory."
        return 1
    }

    _polaris_proxmox_collect_cluster_status "${cluster_dir}" || return 1
    _polaris_proxmox_collect_cluster_configuration "${cluster_dir}" || return 1
    _polaris_proxmox_collect_cluster_nodes "${cluster_dir}" || return 1
    _polaris_proxmox_collect_cluster_resources "${cluster_dir}" || return 1
    _polaris_proxmox_collect_cluster_storage "${cluster_dir}" || return 1

    _polaris_proxmox_collect_cluster_summary "${cluster_dir}" || return 1

    log_success "Proxmox cluster collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_cluster_status
#
# Purpose:
#   Collect the current Proxmox cluster status. If the host is not configured
#   as a cluster member, preserve that condition as an informational artifact
#   rather than treating it as a collection failure.
#
# Parameters:
#   $1 - Cluster staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_cluster_status() {

    local cluster_dir="$1"
    local output_file="${cluster_dir}/status.txt"
    local temporary_file="${cluster_dir}/.status.tmp"

    log_info "Collecting Proxmox cluster status."

    create_directory "${cluster_dir}" || {
        operator_error "Unable to create cluster staging directory."
        return 1
    }

    if ! command_exists pvecm; then

        {
            echo "Project Polaris Proxmox Cluster Status"
            echo "======================================"
            echo
            echo "Status: Unavailable"
            echo "Reason: pvecm command is not available."
        } > "${output_file}" || {
            operator_error "Unable to write cluster status artifact."
            return 1
        }

        operator_warning "pvecm command not available."
        return 0
    fi

    if pvecm status > "${temporary_file}" 2>&1; then

        {
            echo "Project Polaris Proxmox Cluster Status"
            echo "======================================"
            echo
            echo "Status: Cluster configured"
            echo
            echo "pvecm status"
            echo "------------"
            cat "${temporary_file}"
        } > "${output_file}" || {
            rm -f "${temporary_file}"
            operator_error "Unable to write cluster status artifact."
            return 1
        }

        rm -f "${temporary_file}"

        log_success "Proxmox cluster status collected."
        return 0
    fi

    {
        echo "Project Polaris Proxmox Cluster Status"
        echo "======================================"
        echo
        echo "Status: Cluster not configured or unavailable"
        echo
        echo "pvecm response"
        echo "--------------"
        cat "${temporary_file}"
    } > "${output_file}" || {
        rm -f "${temporary_file}"
        operator_error "Unable to write cluster status artifact."
        return 1
    }

    rm -f "${temporary_file}"

    log_info "Proxmox cluster is not configured or its status is unavailable."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_cluster_configuration
#
# Purpose:
#   Preserve the active Corosync cluster configuration used by Proxmox.
#
# Parameters:
#   $1 - Cluster staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_cluster_configuration() {

    local cluster_dir="$1"

    local source_file="/etc/pve/corosync.conf"
    local output_file="${cluster_dir}/corosync.conf"

    log_info "Collecting Proxmox cluster configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris Proxmox Cluster Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write cluster configuration placeholder."
            return 1
        }

        log_info "Cluster configuration file was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect cluster configuration."
        return 1
    }

    log_success "Cluster configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_cluster_nodes
#
# Purpose:
#   Collect the current Proxmox cluster node membership inventory.
#
# Parameters:
#   $1 - Cluster staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_cluster_nodes() {

    local cluster_dir="$1"
    local output_file="${cluster_dir}/nodes.txt"
    local temporary_file="${cluster_dir}/.nodes.tmp"

    log_info "Collecting Proxmox cluster node inventory."

    create_directory "${cluster_dir}" || {
        operator_error "Unable to create cluster staging directory."
        return 1
    }

    if ! command_exists pvecm; then

        {
            echo "Project Polaris Proxmox Cluster Node Inventory"
            echo "================================================"
            echo
            echo "Status: Unavailable"
            echo "Reason: pvecm command is not available."
        } > "${output_file}" || {
            operator_error "Unable to write cluster node inventory artifact."
            return 1
        }

        operator_warning "pvecm command not available."
        return 0
    fi

    if pvecm nodes > "${temporary_file}" 2>&1; then

        {
            echo "Project Polaris Proxmox Cluster Node Inventory"
            echo "================================================"
            echo
            echo "pvecm nodes"
            echo "-----------"
            cat "${temporary_file}"
        } > "${output_file}" || {
            rm -f "${temporary_file}"
            operator_error "Unable to write cluster node inventory artifact."
            return 1
        }

        rm -f "${temporary_file}"

        log_success "Proxmox cluster node inventory collected."
        return 0
    fi

    {
        echo "Project Polaris Proxmox Cluster Node Inventory"
        echo "================================================"
        echo
        echo "Status: Cluster node inventory unavailable"
        echo
        echo "pvecm response"
        echo "--------------"
        cat "${temporary_file}"
    } > "${output_file}" || {
        rm -f "${temporary_file}"
        operator_error "Unable to write cluster node inventory artifact."
        return 1
    }

    rm -f "${temporary_file}"

    log_info "Proxmox cluster node inventory was unavailable."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_cluster_resources
#
# Purpose:
#   Collect the Proxmox cluster resource inventory using the cluster API.
#
# Parameters:
#   $1 - Cluster staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_cluster_resources() {

    local cluster_dir="$1"
    local output_file="${cluster_dir}/resources.txt"

    log_info "Collecting Proxmox cluster resources."

    create_directory "${cluster_dir}" || {
        operator_error "Unable to create cluster staging directory."
        return 1
    }

    if ! command_exists pvesh; then

        {
            echo "Project Polaris Proxmox Cluster Resources"
            echo "========================================="
            echo
            echo "Status: Unavailable"
            echo "Reason: pvesh command is not available."
        } > "${output_file}" || {
            operator_error "Unable to write cluster resource artifact."
            return 1
        }

        operator_warning "pvesh command not available."

        return 0
    fi

    if pvesh get /cluster/resources > "${output_file}" 2>/dev/null; then

        log_success "Proxmox cluster resources collected."

        return 0

    fi

    operator_error "Unable to collect cluster resources."

    return 1
}

###############################################################################
# Function: _polaris_proxmox_collect_cluster_storage
#
# Purpose:
#   Collect the cluster-wide Proxmox storage inventory, including storage
#   availability and node ownership information.
#
# Parameters:
#   $1 - Cluster staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_cluster_storage() {

    local cluster_dir="$1"
    local output_file="${cluster_dir}/storage.txt"

    log_info "Collecting Proxmox cluster storage relationships."

    create_directory "${cluster_dir}" || {
        operator_error "Unable to create cluster staging directory."
        return 1
    }

    if ! command_exists pvesh; then

        {
            echo "Project Polaris Proxmox Cluster Storage"
            echo "======================================="
            echo
            echo "Status: Unavailable"
            echo "Reason: pvesh command is not available."
        } > "${output_file}" || {
            operator_error "Unable to write cluster storage artifact."
            return 1
        }

        operator_warning "pvesh command not available."
        return 0
    fi

    if pvesh get /cluster/resources \
        --type storage \
        > "${output_file}" 2>/dev/null; then

        log_success "Proxmox cluster storage relationships collected."
        return 0
    fi

    operator_error "Unable to collect Proxmox cluster storage relationships."
    return 1
}

###############################################################################
# Function: _polaris_proxmox_collect_cluster_summary
#
# Purpose:
#   Generate a human-readable operational summary of the Proxmox cluster
#   using previously collected artifacts. This function does not query the
#   operating system directly.
#
# Parameters:
#   $1 - Cluster staging directory.
#
# Returns:
#   0 - Summary generated successfully.
#   1 - Summary generation failed.
###############################################################################

_polaris_proxmox_collect_cluster_summary() {

    local cluster_dir="$1"

    local status_file="${cluster_dir}/status.txt"
    local nodes_file="${cluster_dir}/nodes.txt"
    local resources_file="${cluster_dir}/resources.txt"
    local storage_file="${cluster_dir}/storage.txt"
    local corosync_file="${cluster_dir}/corosync.conf"

    local output_file="${cluster_dir}/summary.txt"

    log_info "Generating Proxmox cluster summary."

    for file in \
        "${status_file}" \
        "${nodes_file}" \
        "${resources_file}" \
        "${storage_file}" \
        "${corosync_file}"
    do
        if [[ ! -f "${file}" ]]; then
            operator_error "Required artifact missing: ${file}"
            return 1
        fi
    done

    local cluster_name
    local transport
    local quorate
    local expected_votes
    local quorum

    local node_count
    local qdevice_present

    local vm_count
    local lxc_count
    local storage_count

    cluster_name="$(
        awk -F':' '
            /Name:/ {
                gsub(/^[ \t]+/, "", $2)
                print $2
                exit
            }
        ' "${status_file}"
    )"

    transport="$(
        awk -F':' '
            /Transport:/ {
                gsub(/^[ \t]+/, "", $2)
                print $2
                exit
            }
        ' "${status_file}"
    )"

    quorate="$(
        awk -F':' '
            /Quorate:/ {
                gsub(/^[ \t]+/, "", $2)
                print $2
                exit
            }
        ' "${status_file}"
    )"

    expected_votes="$(
        awk -F':' '
            /Expected votes:/ {
                gsub(/^[ \t]+/, "", $2)
                print $2
                exit
            }
        ' "${status_file}"
    )"

    quorum="$(
        awk -F':' '
            /^Quorum:/ {
                gsub(/^[ \t]+/, "", $2)
                print $2
                exit
            }
        ' "${status_file}"
    )"

    node_count="$(
        awk '
            /^[[:space:]]*[0-9]+/ {
                if ($NF != "Qdevice")
                    count++
            }
            END {
                print count+0
            }
        ' "${nodes_file}"
    )"

    if grep -qi "Qdevice" "${nodes_file}"; then
        qdevice_present="Yes"
    else
        qdevice_present="No"
    fi

    vm_count="$(
        grep -c "qemu/" "${resources_file}" 2>/dev/null || true
    )"

    lxc_count="$(
        grep -c "lxc/" "${resources_file}" 2>/dev/null || true
    )"

    storage_count="$(
        grep -c "storage/" "${resources_file}" 2>/dev/null || true
    )"

    {
        echo "Project Polaris Proxmox Cluster Summary"
        echo "======================================="
        echo

        echo "Cluster"
        echo "-------"
        printf "%-24s %s\n" "Cluster Name" "${cluster_name}"
        printf "%-24s %s\n" "Transport" "${transport}"
        printf "%-24s %s\n" "Quorate" "${quorate}"
        printf "%-24s %s\n" "Expected Votes" "${expected_votes}"
        printf "%-24s %s\n" "Quorum Requirement" "${quorum}"
        echo

        echo "Nodes"
        echo "-----"
        printf "%-24s %s\n" "Cluster Nodes" "${node_count}"
        printf "%-24s %s\n" "QDevice Present" "${qdevice_present}"
        echo

        echo "Resources"
        echo "---------"
        printf "%-24s %s\n" "QEMU Guests" "${vm_count}"
        printf "%-24s %s\n" "LXC Containers" "${lxc_count}"
        printf "%-24s %s\n" "Storage Resources" "${storage_count}"
        echo

        echo "Observations"
        echo "------------"

        if [[ "${quorate}" == "Yes" ]]; then
            echo "• Cluster quorum is healthy."
        else
            echo "• Cluster quorum is NOT healthy."
        fi

        if [[ "${qdevice_present}" == "Yes" ]]; then
            echo "• QDevice is configured."
        fi

        echo "• Cluster configuration artifact collected."
        echo "• Cluster resource inventory collected."
        echo "• Cluster storage relationships collected."

    } > "${output_file}" || {
        operator_error "Unable to generate cluster summary."
        return 1
    }

    log_success "Proxmox cluster summary generated."

    return 0
}

###############################################################################
# Certificate Collectors
###############################################################################

###############################################################################
# Function: _polaris_proxmox_collect_certificates
#
# Purpose:
#   Coordinate Proxmox certificate collection.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_certificates() {

    local certificate_dir="${POLARIS_PROXMOX_STAGING_ROOT}/certificates"

    log_info "Collecting Proxmox certificates."

    create_directory "${certificate_dir}" || {
        operator_error "Unable to create certificate staging directory."
        return 1
    }

    _polaris_proxmox_collect_root_ca "${certificate_dir}" || return 1
    _polaris_proxmox_collect_pve_ssl_certificate "${certificate_dir}" || return 1
    _polaris_proxmox_collect_certificate_metadata "${certificate_dir}" || return 1
    _polaris_proxmox_collect_certificate_summary "${certificate_dir}" || return 1

    log_success "Certificate collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_root_ca
#
# Purpose:
#   Preserve the Proxmox cluster root certificate authority.
#
# Parameters:
#   $1 - Certificate staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_root_ca() {

    local certificate_dir="$1"

    local source_file="/etc/pve/pve-root-ca.pem"
    local output_file="${certificate_dir}/pve-root-ca.pem"

    log_info "Collecting Proxmox root certificate authority."

    create_directory "${certificate_dir}" || {
        operator_error "Unable to create certificate staging directory."
        return 1
    }

    if [[ ! -f "${source_file}" ]]; then
        operator_warning "Proxmox root CA not found."
        return 0
    fi

    if cp "${source_file}" "${output_file}"; then
        log_success "Proxmox root certificate authority collected."
        return 0
    fi

    operator_error "Unable to collect Proxmox root certificate authority."

    return 1
}

###############################################################################
# Function: _polaris_proxmox_collect_pve_ssl_certificate
#
# Purpose:
#   Preserve the active Proxmox node TLS certificate used by the web interface
#   and API service.
#
# Parameters:
#   $1 - Certificate staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_pve_ssl_certificate() {

    local certificate_dir="$1"

    local node_name
    local source_file
    local output_file="${certificate_dir}/pve-ssl.pem"

    log_info "Collecting Proxmox node TLS certificate."

    create_directory "${certificate_dir}" || {
        operator_error "Unable to create certificate staging directory."
        return 1
    }

    node_name="$(hostname -s)"

    if [[ -z "${node_name}" ]]; then
        operator_error "Unable to determine the local Proxmox node name."
        return 1
    fi

    source_file="/etc/pve/nodes/${node_name}/pve-ssl.pem"

    if [[ ! -f "${source_file}" ]]; then
        operator_warning \
            "Proxmox node TLS certificate not found for node ${node_name}."
        return 0
    fi

    if cp "${source_file}" "${output_file}"; then
        log_success \
            "Proxmox node TLS certificate collected for node ${node_name}."
        return 0
    fi

    operator_error \
        "Unable to collect Proxmox node TLS certificate for node ${node_name}."

    return 1
}

###############################################################################
# Function: _polaris_proxmox_collect_certificate_metadata
#
# Purpose:
#   Generate certificate metadata and SHA-256 fingerprints using previously
#   collected Proxmox certificate artifacts.
#
# Parameters:
#   $1 - Certificate staging directory.
#
# Returns:
#   0 - Metadata generated successfully.
#   1 - Metadata generation failed.
###############################################################################

_polaris_proxmox_collect_certificate_metadata() {

    local certificate_dir="$1"

    local root_ca_file="${certificate_dir}/pve-root-ca.pem"
    local node_certificate_file="${certificate_dir}/pve-ssl.pem"
    local output_file="${certificate_dir}/metadata.txt"

    log_info "Generating Proxmox certificate metadata."

    if ! command_exists openssl; then
        operator_error "openssl command is not available."
        return 1
    fi

    if [[ ! -f "${root_ca_file}" ]]; then
        operator_error "Collected Proxmox root CA artifact not found."
        return 1
    fi

    if [[ ! -f "${node_certificate_file}" ]]; then
        operator_error "Collected Proxmox node TLS certificate artifact not found."
        return 1
    fi

    {
        echo "Project Polaris Proxmox Certificate Metadata"
        echo "============================================"
        echo

        echo "Cluster Root Certificate Authority"
        echo "----------------------------------"

        openssl x509 \
            -in "${root_ca_file}" \
            -noout \
            -subject \
            -issuer \
            -serial \
            -dates \
            -fingerprint \
            -sha256

        echo
        echo "Node TLS Certificate"
        echo "--------------------"

        openssl x509 \
            -in "${node_certificate_file}" \
            -noout \
            -subject \
            -issuer \
            -serial \
            -dates \
            -fingerprint \
            -sha256 \
            -ext subjectAltName

    } > "${output_file}" 2>&1 || {
        rm -f "${output_file}"
        operator_error "Unable to generate Proxmox certificate metadata."
        return 1
    }

    log_success "Proxmox certificate metadata generated."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_certificate_summary
#
# Purpose:
#   Generate a human-readable summary of the Proxmox certificate subsystem
#   using previously collected artifacts.
#
# Parameters:
#   $1 - Certificate staging directory.
#
# Returns:
#   0 - Summary generated successfully.
#   1 - Summary generation failed.
###############################################################################

_polaris_proxmox_collect_certificate_summary() {

    local certificate_dir="$1"

    local metadata_file="${certificate_dir}/metadata.txt"
    local output_file="${certificate_dir}/summary.txt"

    log_info "Generating Proxmox certificate summary."

    if [[ ! -f "${metadata_file}" ]]; then
        operator_error "Certificate metadata artifact not found."
        return 1
    fi

    local root_subject
    local root_expiration

    local node_subject
    local node_expiration

    root_subject="$(
        awk '
            /Cluster Root Certificate Authority/ {section=1; next}
            /Node TLS Certificate/ {section=0}
            section && /^subject=/ {
                sub(/^subject=/,"")
                print
                exit
            }
        ' "${metadata_file}"
    )"

    root_expiration="$(
        awk '
            /Cluster Root Certificate Authority/ {section=1; next}
            /Node TLS Certificate/ {section=0}
            section && /^notAfter=/ {
                sub(/^notAfter=/,"")
                print
                exit
            }
        ' "${metadata_file}"
    )"

    node_subject="$(
        awk '
            /Node TLS Certificate/ {section=1; next}
            section && /^subject=/ {
                sub(/^subject=/,"")
                print
                exit
            }
        ' "${metadata_file}"
    )"

    node_expiration="$(
        awk '
            /Node TLS Certificate/ {section=1; next}
            section && /^notAfter=/ {
                sub(/^notAfter=/,"")
                print
                exit
            }
        ' "${metadata_file}"
    )"

    {
        echo "Project Polaris Proxmox Certificate Summary"
        echo "==========================================="
        echo

        echo "Cluster Root Certificate Authority"
        echo "----------------------------------"
        printf "%-18s %s\n" "Subject" "${root_subject}"
        printf "%-18s %s\n" "Expires" "${root_expiration}"
        echo

        echo "Node TLS Certificate"
        echo "--------------------"
        printf "%-18s %s\n" "Subject" "${node_subject}"
        printf "%-18s %s\n" "Expires" "${node_expiration}"
        echo

        echo "Artifacts"
        echo "---------"

        [[ -f "${certificate_dir}/pve-root-ca.pem" ]] \
            && echo "Root CA............... Present"

        [[ -f "${certificate_dir}/pve-ssl.pem" ]] \
            && echo "Node Certificate...... Present"

        [[ -f "${certificate_dir}/metadata.txt" ]] \
            && echo "Metadata.............. Present"

        echo
        echo "Observations"
        echo "------------"

        echo "• Cluster certificate authority preserved."
        echo "• Node TLS certificate preserved."
        echo "• Certificate metadata generated."
        echo "• SHA-256 fingerprints recorded."

    } > "${output_file}" || {

        operator_error "Unable to generate certificate summary."

        return 1
    }

    log_success "Proxmox certificate summary generated."

    return 0
}

###############################################################################
# Scheduling Collectors
###############################################################################

###############################################################################
# Function: _polaris_proxmox_collect_cron
#
# Purpose:
#   Coordinate collection of scheduled cron jobs and related automation
#   configuration.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_cron() {

    local cron_dir="${POLARIS_PROXMOX_STAGING_ROOT}/cron"

    log_info "Collecting scheduled task information."

    create_directory "${cron_dir}" || {
        operator_error "Unable to create cron staging directory."
        return 1
    }

    _polaris_proxmox_collect_root_crontab "${cron_dir}" || return 1
    _polaris_proxmox_collect_system_crontab "${cron_dir}" || return 1
    _polaris_proxmox_collect_cron_directories "${cron_dir}" || return 1
    _polaris_proxmox_collect_systemd_timers "${cron_dir}" || return 1
    _polaris_proxmox_collect_systemd_timer_definitions "${cron_dir}" || return 1
    _polaris_proxmox_collect_cron_summary "${cron_dir}" || return 1

    log_success "Scheduled task collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_root_crontab
#
# Purpose:
#   Collect the root user's scheduled cron jobs. If no root crontab exists,
#   preserve that condition in the artifact rather than treating it as a
#   collection failure.
#
# Parameters:
#   $1 - Cron staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_root_crontab() {

    local cron_dir="$1"
    local output_file="${cron_dir}/root-crontab.txt"
    local temporary_file="${cron_dir}/.root-crontab.tmp"

    log_info "Collecting root user crontab."

    create_directory "${cron_dir}" || {
        operator_error "Unable to create cron staging directory."
        return 1
    }

    if ! command_exists crontab; then

        {
            echo "Project Polaris Root Crontab"
            echo "============================"
            echo
            echo "Status: Unavailable"
            echo "Reason: crontab command is not available."
        } > "${output_file}" || {
            operator_error "Unable to write root crontab artifact."
            return 1
        }

        operator_warning "crontab command not available."
        return 0
    fi

    if crontab -l -u root > "${temporary_file}" 2>&1; then

        {
            echo "Project Polaris Root Crontab"
            echo "============================"
            echo
            echo "Status: Configured"
            echo
            echo "Root Scheduled Jobs"
            echo "-------------------"
            cat "${temporary_file}"
        } > "${output_file}" || {
            rm -f "${temporary_file}"
            operator_error "Unable to write root crontab artifact."
            return 1
        }

        rm -f "${temporary_file}"

        log_success "Root user crontab collected."
        return 0
    fi

    {
        echo "Project Polaris Root Crontab"
        echo "============================"
        echo
        echo "Status: Not configured"
        echo
        echo "crontab response"
        echo "----------------"
        cat "${temporary_file}"
    } > "${output_file}" || {
        rm -f "${temporary_file}"
        operator_error "Unable to write root crontab artifact."
        return 1
    }

    rm -f "${temporary_file}"

    log_info "No root user crontab was configured."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_system_crontab
#
# Purpose:
#   Preserve the system-wide cron configuration from /etc/crontab.
#
# Parameters:
#   $1 - Cron staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_system_crontab() {

    local cron_dir="$1"

    local source_file="/etc/crontab"
    local output_file="${cron_dir}/system-crontab.txt"

    log_info "Collecting system-wide crontab."

    create_directory "${cron_dir}" || {
        operator_error "Unable to create cron staging directory."
        return 1
    }

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "Project Polaris System Crontab"
            echo "=============================="
            echo
            echo "Status: Not present"
            echo "Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write system crontab artifact."
            return 1
        }

        log_info "System-wide crontab was not present."
        return 0
    fi

    {
        echo "Project Polaris System Crontab"
        echo "=============================="
        echo
        echo "Status: Present"
        echo "Source: ${source_file}"
        echo
        echo "Configuration"
        echo "-------------"
        cat "${source_file}"
    } > "${output_file}" || {
        operator_error "Unable to collect system-wide crontab."
        return 1
    }

    log_success "System-wide crontab collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_cron_directories
#
# Purpose:
#   Preserve the contents of the system cron directories.
#
# Parameters:
#   $1 - Cron staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_cron_directories() {

    local cron_dir="$1"

    local source_directory
    local destination_directory

    log_info "Collecting system cron directories."

    for source_directory in \
        /etc/cron.d \
        /etc/cron.hourly \
        /etc/cron.daily \
        /etc/cron.weekly \
        /etc/cron.monthly
    do

        destination_directory="${cron_dir}/$(basename "${source_directory}")"

        create_directory "${destination_directory}" || {
            operator_error "Unable to create ${destination_directory}."
            return 1
        }

        if [[ ! -d "${source_directory}" ]]; then
            log_info "${source_directory} not present."
            continue
        fi

        if ! cp -a "${source_directory}/." "${destination_directory}/"; then
            operator_error "Unable to collect ${source_directory}."
            return 1
        fi

    done

    log_success "System cron directories collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_systemd_timers
#
# Purpose:
#   Collect the complete systemd timer inventory, including active, inactive,
#   loaded, and unloaded timer units.
#
# Parameters:
#   $1 - Cron and scheduled-task staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_systemd_timers() {

    local cron_dir="$1"
    local output_file="${cron_dir}/systemd-timers.txt"

    log_info "Collecting systemd timer inventory."

    create_directory "${cron_dir}" || {
        operator_error "Unable to create scheduled-task staging directory."
        return 1
    }

    if ! command_exists systemctl; then

        {
            echo "Project Polaris systemd Timer Inventory"
            echo "======================================="
            echo
            echo "Status: Unavailable"
            echo "Reason: systemctl command is not available."
        } > "${output_file}" || {
            operator_error "Unable to write systemd timer inventory artifact."
            return 1
        }

        operator_warning "systemctl command not available."
        return 0
    fi

    {
        echo "Project Polaris systemd Timer Inventory"
        echo "======================================="
        echo
        echo "Collection Time"
        echo "---------------"
        date -u '+%Y-%m-%d %H:%M:%S UTC'
        echo

        echo "All Timer Units"
        echo "---------------"

        systemctl list-timers \
            --all \
            --no-pager \
            --full

        echo
        echo "Installed Timer Unit Files"
        echo "--------------------------"

        systemctl list-unit-files \
            --type=timer \
            --no-pager \
            --full

    } > "${output_file}" 2>&1 || {
        rm -f "${output_file}"
        operator_error "Unable to collect systemd timer inventory."
        return 1
    }

    log_success "systemd timer inventory collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_systemd_timer_definitions
#
# Purpose:
#   Preserve the effective definitions of all installed systemd timer units.
#
# Parameters:
#   $1 - Cron and scheduled-task staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_systemd_timer_definitions() {

    local cron_dir="$1"
    local output_file="${cron_dir}/systemd-timer-definitions.txt"

    local timer_unit
    local timer_count=0

    log_info "Collecting systemd timer unit definitions."

    create_directory "${cron_dir}" || {
        operator_error "Unable to create scheduled-task staging directory."
        return 1
    }

    if ! command_exists systemctl; then

        {
            echo "Project Polaris systemd Timer Definitions"
            echo "========================================="
            echo
            echo "Status: Unavailable"
            echo "Reason: systemctl command is not available."
        } > "${output_file}" || {
            operator_error "Unable to write systemd timer definition artifact."
            return 1
        }

        operator_warning "systemctl command not available."
        return 0
    fi

    {
        echo "Project Polaris systemd Timer Definitions"
        echo "========================================="
        echo
        echo "Collection Time"
        echo "---------------"
        date -u '+%Y-%m-%d %H:%M:%S UTC'
        echo

        while IFS= read -r timer_unit; do

            [[ -z "${timer_unit}" ]] && continue

            ((timer_count += 1))

            echo "Timer Unit: ${timer_unit}"
            printf '%*s\n' "$((12 + ${#timer_unit}))" '' | tr ' ' '-'

            if ! systemctl cat "${timer_unit}" --no-pager 2>&1; then
                echo "Unable to retrieve timer unit definition."
            fi

            echo

        done < <(
            systemctl list-unit-files \
                --type=timer \
                --no-legend \
                --no-pager \
                --full 2>/dev/null \
                | awk '{print $1}' \
                | sort -u
        )

        echo "Timer Units Collected"
        echo "---------------------"
        echo "${timer_count}"

    } > "${output_file}" || {
        rm -f "${output_file}"
        operator_error "Unable to collect systemd timer unit definitions."
        return 1
    }

    log_success "systemd timer unit definitions collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_cron_summary
#
# Purpose:
#   Generate a human-readable summary of scheduled task configuration using
#   previously collected artifacts.
#
# Parameters:
#   $1 - Scheduled task staging directory.
#
# Returns:
#   0 - Summary generated successfully.
#   1 - Summary generation failed.
###############################################################################

_polaris_proxmox_collect_cron_summary() {

    local cron_dir="$1"

    local output_file="${cron_dir}/summary.txt"

    local root_status
    local system_status

    local timer_count
    local cron_directory_count

    log_info "Generating scheduled task summary."

    root_status="$(awk -F': ' '/^Status:/ {print $2; exit}' \
        "${cron_dir}/root-crontab.txt")"

    system_status="$(awk -F': ' '/^Status:/ {print $2; exit}' \
        "${cron_dir}/system-crontab.txt")"

    timer_count="$(awk '
        /^Timer Units Collected$/ {
            getline
            getline
            print
            exit
        }
    ' "${cron_dir}/systemd-timer-definitions.txt")"

    cron_directory_count=0

    for directory in \
        cron.d \
        cron.hourly \
        cron.daily \
        cron.weekly \
        cron.monthly
    do

        if [[ -d "${cron_dir}/${directory}" ]]; then
            ((cron_directory_count++))
        fi

    done

    {
        echo "Project Polaris Scheduled Task Summary"
        echo "======================================"
        echo

        echo "Cron"
        echo "----"

        printf "%-24s %s\n" \
            "Root Crontab" \
            "${root_status}"

        printf "%-24s %s\n" \
            "System Crontab" \
            "${system_status}"

        printf "%-24s %s\n" \
            "Cron Directories" \
            "${cron_directory_count}"

        echo

        echo "systemd Timers"
        echo "--------------"

        printf "%-24s %s\n" \
            "Installed Timers" \
            "${timer_count}"

        echo

        echo "Artifacts"
        echo "---------"

        [[ -f "${cron_dir}/root-crontab.txt" ]] \
            && echo "Root Crontab............. Present"

        [[ -f "${cron_dir}/system-crontab.txt" ]] \
            && echo "System Crontab........... Present"

        [[ -f "${cron_dir}/systemd-timers.txt" ]] \
            && echo "Timer Inventory.......... Present"

        [[ -f "${cron_dir}/systemd-timer-definitions.txt" ]] \
            && echo "Timer Definitions........ Present"

        echo

        echo "Observations"
        echo "------------"

        echo "• Scheduled task inventory collected."
        echo "• Cron configuration preserved."
        echo "• systemd timer inventory preserved."
        echo "• Timer definitions preserved."

    } > "${output_file}" || {

        operator_error "Unable to generate scheduled task summary."

        return 1
    }

    log_success "Scheduled task summary generated."

    return 0
}

###############################################################################
# Proxmox  Summary
###############################################################################

###############################################################################
# Function: _polaris_proxmox_collect_proxmox_summary
#
# Purpose:
#   Generate a top-level operational summary of the complete Proxmox
#   collection using only previously collected artifacts.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Summary generated successfully.
#   1 - Summary generation failed.
###############################################################################

_polaris_proxmox_collect_proxmox_summary() {

    local proxmox_root="${POLARIS_PROXMOX_STAGING_ROOT}"
    local output_file="${proxmox_root}/summary.txt"

    local host_dir="${proxmox_root}/host"
    local storage_dir="${proxmox_root}/storage"
    local network_dir="${proxmox_root}/network"
    local firewall_dir="${network_dir}/firewall"
    local vm_dir="${proxmox_root}/virtual-machines"
    local container_dir="${proxmox_root}/containers"
    local cluster_dir="${proxmox_root}/cluster"
    local certificate_dir="${proxmox_root}/certificates"
    local cron_dir="${proxmox_root}/cron"

    local hostname_value="Unavailable"
    local proxmox_version="Unavailable"
    local kernel_version="Unavailable"

    local local_vm_count="Unavailable"
    local cluster_vm_count="Unavailable"
    local local_lxc_count="Unavailable"
    local cluster_lxc_count="Unavailable"

    local cluster_name="Unavailable"
    local cluster_quorate="Unavailable"
    local cluster_nodes="Unavailable"
    local qdevice_present="Unavailable"

    local firewall_status="Unavailable"
    local certificate_status="Incomplete"
    local scheduled_task_status="Incomplete"

    local host_artifact_count=0
    local storage_artifact_count=0
    local network_artifact_count=0
    local vm_artifact_count=0
    local cluster_artifact_count=0
    local certificate_artifact_count=0
    local cron_artifact_count=0

    log_info "Generating top-level Proxmox summary."

    create_directory "${proxmox_root}" || {
        operator_error "Unable to create Proxmox staging directory."
        return 1
    }

    if [[ -s "${host_dir}/hostname.txt" ]]; then
        hostname_value="$(head -n 1 "${host_dir}/hostname.txt")"
    fi

    if [[ -s "${host_dir}/version.txt" ]]; then
        proxmox_version="$(head -n 1 "${host_dir}/version.txt")"
    fi

    if [[ -s "${host_dir}/kernel.txt" ]]; then
        kernel_version="$(head -n 1 "${host_dir}/kernel.txt")"
    fi

    if [[ -f "${vm_dir}/summary.txt" ]]; then

        local_vm_count="$(
            awk '
                /^Total Virtual Machines/ {
                    print $NF
                    exit
                }
            ' "${vm_dir}/summary.txt"
        )"

        local_lxc_count="$(
            awk '
                /^Total Containers/ {
                    print $NF
                    exit
                }
            ' "${vm_dir}/summary.txt"
        )"

    fi

    if [[ -f "${cluster_dir}/summary.txt" ]]; then

        cluster_name="$(
            awk '
                /^Cluster Name/ {
                    print $NF
                    exit
                }
            ' "${cluster_dir}/summary.txt"
        )"

        cluster_quorate="$(
            awk '
                /^Quorate/ {
                    print $NF
                    exit
                }
            ' "${cluster_dir}/summary.txt"
        )"

        cluster_nodes="$(
            awk '
                /^Cluster Nodes/ {
                    print $NF
                    exit
                }
            ' "${cluster_dir}/summary.txt"
        )"

        qdevice_present="$(
            awk '
                /^QDevice Present/ {
                    print $NF
                    exit
                }
            ' "${cluster_dir}/summary.txt"
        )"

        cluster_vm_count="$(
            awk '
                /^QEMU Guests/ {
                    print $NF
                    exit
                }
            ' "${cluster_dir}/summary.txt"
        )"

        cluster_lxc_count="$(
            awk '
                /^LXC Containers/ {
                    print $NF
                    exit
                }
            ' "${cluster_dir}/summary.txt"
        )"

    fi

    if [[ -f "${firewall_dir}/firewall_summary.txt" ]]; then

        firewall_status="$(
            awk '
                /^Firewall Status/ {
                    print $NF
                    exit
                }
            ' "${firewall_dir}/firewall_summary.txt"
        )"

    fi

    if [[ -f "${certificate_dir}/summary.txt" ]] &&
       [[ -f "${certificate_dir}/metadata.txt" ]] &&
       [[ -f "${certificate_dir}/pve-root-ca.pem" ]] &&
       [[ -f "${certificate_dir}/pve-ssl.pem" ]]; then

        certificate_status="Complete"

    fi

    if [[ -f "${cron_dir}/summary.txt" ]] &&
       [[ -f "${cron_dir}/root-crontab.txt" ]] &&
       [[ -f "${cron_dir}/system-crontab.txt" ]] &&
       [[ -f "${cron_dir}/systemd-timers.txt" ]] &&
       [[ -f "${cron_dir}/systemd-timer-definitions.txt" ]]; then

        scheduled_task_status="Complete"

    fi

    if [[ -d "${host_dir}" ]]; then
        host_artifact_count="$(
            find "${host_dir}" -type f 2>/dev/null | wc -l
        )"
    fi

    if [[ -d "${storage_dir}" ]]; then
        storage_artifact_count="$(
            find "${storage_dir}" -type f 2>/dev/null | wc -l
        )"
    fi

    if [[ -d "${network_dir}" ]]; then
        network_artifact_count="$(
            find "${network_dir}" -type f 2>/dev/null | wc -l
        )"
    fi

    if [[ -d "${vm_dir}" ]]; then
        vm_artifact_count="$(
            find "${vm_dir}" -type f 2>/dev/null | wc -l
        )"
    fi

    if [[ -d "${container_dir}" ]]; then
        vm_artifact_count="$(
            printf '%s\n' "$(
                find "${vm_dir}" "${container_dir}" \
                    -type f 2>/dev/null \
                    | wc -l
            )"
        )"
    fi

    if [[ -d "${cluster_dir}" ]]; then
        cluster_artifact_count="$(
            find "${cluster_dir}" -type f 2>/dev/null | wc -l
        )"
    fi

    if [[ -d "${certificate_dir}" ]]; then
        certificate_artifact_count="$(
            find "${certificate_dir}" -type f 2>/dev/null | wc -l
        )"
    fi

    if [[ -d "${cron_dir}" ]]; then
        cron_artifact_count="$(
            find "${cron_dir}" -type f 2>/dev/null | wc -l
        )"
    fi

    {
        echo "Project Polaris Proxmox Collection Summary"
        echo "=========================================="
        echo

        echo "Host"
        echo "----"
        printf "%-30s %s\n" "Hostname" "${hostname_value}"
        printf "%-30s %s\n" "Proxmox VE" "${proxmox_version}"
        printf "%-30s %s\n" "Kernel" "${kernel_version}"
        echo

        echo "Cluster"
        echo "-------"
        printf "%-30s %s\n" "Cluster Name" "${cluster_name}"
        printf "%-30s %s\n" "Cluster Nodes" "${cluster_nodes}"
        printf "%-30s %s\n" "Quorate" "${cluster_quorate}"
        printf "%-30s %s\n" "QDevice Present" "${qdevice_present}"
        echo

        echo "Guest Inventory"
        echo "---------------"
        printf "%-30s %s\n" "Local QEMU Guests" "${local_vm_count}"
        printf "%-30s %s\n" "Cluster QEMU Guests" "${cluster_vm_count}"
        printf "%-30s %s\n" "Local LXC Containers" "${local_lxc_count}"
        printf "%-30s %s\n" "Cluster LXC Containers" "${cluster_lxc_count}"
        echo

        echo "Operational Status"
        echo "------------------"
        printf "%-30s %s\n" "Firewall" "${firewall_status}"
        printf "%-30s %s\n" "Certificates" "${certificate_status}"
        printf "%-30s %s\n" "Scheduled Tasks" "${scheduled_task_status}"
        echo

        echo "Artifact Inventory"
        echo "------------------"
        printf "%-30s %s\n" "Host Artifacts" "${host_artifact_count}"
        printf "%-30s %s\n" "Storage Artifacts" "${storage_artifact_count}"
        printf "%-30s %s\n" "Network Artifacts" "${network_artifact_count}"
        printf "%-30s %s\n" "VM and Container Artifacts" "${vm_artifact_count}"
        printf "%-30s %s\n" "Cluster Artifacts" "${cluster_artifact_count}"
        printf "%-30s %s\n" "Certificate Artifacts" "${certificate_artifact_count}"
        printf "%-30s %s\n" "Scheduled Task Artifacts" "${cron_artifact_count}"
        echo

        echo "Subsystem Status"
        echo "----------------"

        [[ "${host_artifact_count}" -gt 0 ]] \
            && echo "Host........................ Complete" \
            || echo "Host........................ Incomplete"

        [[ "${storage_artifact_count}" -gt 0 ]] \
            && echo "Storage..................... Complete" \
            || echo "Storage..................... Incomplete"

        [[ "${network_artifact_count}" -gt 0 ]] \
            && echo "Network..................... Complete" \
            || echo "Network..................... Incomplete"

        [[ "${vm_artifact_count}" -gt 0 ]] \
            && echo "Virtual Machines............ Complete" \
            || echo "Virtual Machines............ Incomplete"

        [[ "${cluster_artifact_count}" -gt 0 ]] \
            && echo "Cluster..................... Complete" \
            || echo "Cluster..................... Incomplete"

        [[ "${certificate_status}" == "Complete" ]] \
            && echo "Certificates................ Complete" \
            || echo "Certificates................ Incomplete"

        [[ "${scheduled_task_status}" == "Complete" ]] \
            && echo "Scheduled Tasks............. Complete" \
            || echo "Scheduled Tasks............. Incomplete"

        echo
        echo "Observations"
        echo "------------"

        echo "• Proxmox host configuration artifacts were collected."
        echo "• Cluster configuration and quorum evidence were preserved."
        echo "• Runtime firewall evidence and Proxmox firewall configuration were preserved."
        echo "• Certificate trust artifacts and fingerprints were preserved."
        echo "• Cron and systemd scheduling configuration were preserved."

        if [[ "${local_vm_count}" != "Unavailable" ]] &&
           [[ "${cluster_vm_count}" != "Unavailable" ]] &&
           [[ "${local_vm_count}" != "${cluster_vm_count}" ]]; then

            echo "• Detailed VM artifacts are local-node only by design."
            echo "• Cluster-wide guest ownership is recorded in cluster-inventory.txt."

        fi

    } > "${output_file}" || {
        operator_error "Unable to generate top-level Proxmox summary."
        return 1
    }

    log_success "Top-level Proxmox summary generated."

    return 0
}

###############################################################################
# Metadata Collectors
###############################################################################

###############################################################################
# Function: _polaris_proxmox_collect_metadata
#
# Purpose:
#   Coordinate collection of Project Polaris metadata artifacts for the
#   Proxmox collector.
#
# Parameters:
#   None
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_metadata() {

    local metadata_dir="${POLARIS_PROXMOX_STAGING_ROOT}/metadata"

    log_info "Collecting metadata."

    create_directory "${metadata_dir}" || {
        operator_error "Unable to create metadata staging directory."
        return 1
    }

    _polaris_proxmox_collect_collector_info "${metadata_dir}" || return 1
    _polaris_proxmox_collect_execution_info "${metadata_dir}" || return 1
    _polaris_proxmox_collect_version_inventory "${metadata_dir}" || return 1
    _polaris_proxmox_collect_manifest "${metadata_dir}" || return 1

    log_success "Metadata collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_collector_info
#
# Purpose:
#   Record static information describing the Project Polaris Proxmox collector.
#
# Parameters:
#   $1 - Metadata staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_collector_info() {

    local metadata_dir="$1"

    local output_file="${metadata_dir}/collector-info.txt"

    log_info "Collecting collector information."

    {
        echo "Project Polaris Collector Information"
        echo "====================================="
        echo
        printf "%-24s %s\n" "Collector Name"      "${MODULE_DISPLAY_NAME}"
        printf "%-24s %s\n" "Module"              "${MODULE_NAME}"
        printf "%-24s %s\n" "Project"             "Project Polaris"
        printf "%-24s %s\n" "Collector Version"   "${MODULE_VERSION}"
        printf "%-24s %s\n" "Generated"           "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    } > "${output_file}" || {

        operator_error "Unable to write collector information."

        return 1
    }

    log_success "Collector information collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_execution_info
#
# Purpose:
#   Record execution context for the current Project Polaris Proxmox collector
#   run.
#
# Parameters:
#   $1 - Metadata staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_execution_info() {

    local metadata_dir="$1"
    local output_file="${metadata_dir}/execution.txt"

    local execution_user
    local effective_user
    local hostname_short
    local hostname_fqdn
    local current_directory

    log_info "Collecting execution information."

    execution_user="${SUDO_USER:-$(id -un)}"
    effective_user="$(id -un)"
    hostname_short="$(hostname -s)"
    hostname_fqdn="$(hostname -f 2>/dev/null || hostname)"
    current_directory="$(pwd -P)"

    {
        echo "Project Polaris Collector Execution Information"
        echo "==============================================="
        echo
        printf "%-28s %s\n" "Collection Timestamp" \
            "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        printf "%-28s %s\n" "Execution User" "${execution_user}"
        printf "%-28s %s\n" "Effective User" "${effective_user}"
        printf "%-28s %s\n" "Hostname" "${hostname_short}"
        printf "%-28s %s\n" "Fully Qualified Hostname" "${hostname_fqdn}"
        printf "%-28s %s\n" "Working Directory" "${current_directory}"
        printf "%-28s %s\n" "Collector Directory" "${POLARIS_PROXMOX_COLLECTOR_DIR}"
        printf "%-28s %s\n" "Framework Root" "${POLARIS_PROXMOX_FRAMEWORK_ROOT}"
        printf "%-28s %s\n" "Staging Root" \
            "${POLARIS_PROXMOX_STAGING_ROOT}"
        printf "%-28s %s\n" "Shell" "${BASH_VERSION}"
        printf "%-28s %s\n" "Process ID" "$$"
    } > "${output_file}" || {
        operator_error "Unable to write execution information."
        return 1
    }

    log_success "Execution information collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_version_inventory
#
# Purpose:
#   Record important Project Polaris, Proxmox, operating system, kernel, and
#   shell version information relevant to the current collector run.
#
# Parameters:
#   $1 - Metadata staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_version_inventory() {

    local metadata_dir="$1"
    local output_file="${metadata_dir}/versions.txt"

    local host_dir="${POLARIS_PROXMOX_STAGING_ROOT}/host"
    local proxmox_version_file="${host_dir}/version.txt"
    local kernel_version_file="${host_dir}/kernel.txt"

    local proxmox_version="Unavailable"
    local kernel_version="Unavailable"
    local debian_version="Unavailable"
    local bash_version="${BASH_VERSION}"
    local openssl_version="Unavailable"
    local systemd_version="Unavailable"

    log_info "Collecting version inventory."

    if [[ -s "${proxmox_version_file}" ]]; then
        proxmox_version="$(head -n 1 "${proxmox_version_file}")"
    fi

    if [[ -s "${kernel_version_file}" ]]; then
        kernel_version="$(head -n 1 "${kernel_version_file}")"
    fi

    if [[ -r /etc/debian_version ]]; then
        debian_version="$(cat /etc/debian_version)"
    fi

    if command_exists openssl; then
        openssl_version="$(openssl version 2>/dev/null || printf 'Unavailable')"
    fi

    if command_exists systemctl; then
        systemd_version="$(
            systemctl --version 2>/dev/null \
                | head -n 1 \
                || printf 'Unavailable'
        )"
    fi

    {
        echo "Project Polaris Version Inventory"
        echo "================================="
        echo

        printf "%-28s %s\n" "Project" "Project Polaris"
        printf "%-28s %s\n" "Collector" "${MODULE_DISPLAY_NAME}"
        printf "%-28s %s\n" "Collector Version" "${MODULE_VERSION}"
        printf "%-28s %s\n" "Collector Author" "${MODULE_AUTHOR}"
        echo

        printf "%-28s %s\n" "Proxmox VE" "${proxmox_version}"
        printf "%-28s %s\n" "Kernel" "${kernel_version}"
        printf "%-28s %s\n" "Debian" "${debian_version}"
        printf "%-28s %s\n" "Bash" "${bash_version}"
        printf "%-28s %s\n" "OpenSSL" "${openssl_version}"
        printf "%-28s %s\n" "systemd" "${systemd_version}"

    } > "${output_file}" || {
        operator_error "Unable to write version inventory."
        return 1
    }

    log_success "Version inventory collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_manifest
#
# Purpose:
#   Generate an enterprise backup manifest containing every artifact produced
#   by the Proxmox collector along with file size and SHA-256 checksum.
#
# Parameters:
#   $1 - Metadata staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_manifest() {

    local metadata_dir="$1"

    local proxmox_root="${POLARIS_PROXMOX_STAGING_ROOT}"
    local output_file="${metadata_dir}/manifest.txt"

    local artifact_count=0
    local file
    local relative_path
    local file_size
    local file_hash

    log_info "Generating backup manifest."

    {
        echo "# Project Polaris Enterprise Backup Manifest"
        echo "# ==========================================="
        echo "#"
        echo "# Collection Time"
        echo "# ---------------"
        printf '# %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo "#"
        echo "# Format"
        echo "# ------"
        echo "# Relative Path<TAB>Size(Bytes)<TAB>SHA-256"
        echo "#"

        while IFS= read -r -d '' file; do

            [[ "${file}" == "${output_file}" ]] && continue

            relative_path="${file#"${proxmox_root}/"}"
            file_size="$(stat -c '%s' -- "${file}")" || {
                operator_error \
                    "Unable to determine artifact size: ${file}"
                return 1
            }

            file_hash="$(sha256sum -- "${file}")" || {
                operator_error \
                    "Unable to calculate artifact hash: ${file}"
                return 1
            }

            file_hash="${file_hash%% *}"

            printf '%s\t%s\t%s\n' \
                "${relative_path}" \
                "${file_size}" \
                "${file_hash}"

            ((artifact_count += 1))

        done < <(
            find "${proxmox_root}" \
                -type f \
                ! -path "${output_file}" \
                -print0 |
                sort -z
        )

        echo "#"
        printf '# Artifact Count: %s\n' "${artifact_count}"

    } > "${output_file}" || {
        operator_error "Unable to generate backup manifest."
        return 1
    }

    log_success "Enterprise backup manifest generated."

    return 0
}

###############################################################################
# Configuration Collector
###############################################################################

###############################################################################
# Function: _polaris_proxmox_collect_configuration
#
# Purpose:
#   Coordinate collection of remaining Proxmox platform configuration that
#   does not belong to an existing subsystem.
#
# Parameters:
#   None.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_configuration() {

    local configuration_dir="${POLARIS_PROXMOX_STAGING_ROOT}/configuration"

    log_info "Collecting Proxmox platform configuration."

    create_directory "${configuration_dir}" || {
        operator_error "Unable to create platform configuration staging directory."
        return 1
    }

    _polaris_proxmox_collect_datacenter_config "${configuration_dir}" || return 1
    _polaris_proxmox_collect_user_config "${configuration_dir}" || return 1
    _polaris_proxmox_collect_domains_config "${configuration_dir}" || return 1
    _polaris_proxmox_collect_notifications_config "${configuration_dir}" || return 1
    _polaris_proxmox_collect_storage_config "${configuration_dir}" || return 1
    _polaris_proxmox_collect_jobs_config "${configuration_dir}" || return 1
    _polaris_proxmox_collect_cluster_firewall_config "${configuration_dir}" || return 1
    _polaris_proxmox_collect_replication_config "${configuration_dir}" || return 1
    _polaris_proxmox_collect_ha_resources_config "${configuration_dir}" || return 1
    _polaris_proxmox_collect_ha_groups_config "${configuration_dir}" || return 1
    _polaris_proxmox_collect_sdn_config "${configuration_dir}" || return 1

    log_success "Proxmox platform configuration collection complete."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_datacenter_config
#
# Purpose:
#   Preserve the cluster-wide Proxmox datacenter configuration.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_datacenter_config() {

    local configuration_dir="$1"

    local source_file="/etc/pve/datacenter.cfg"
    local output_file="${configuration_dir}/datacenter.cfg"

    log_info "Collecting Proxmox datacenter configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris Proxmox Datacenter Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write datacenter configuration artifact."
            return 1
        }

        log_info "Proxmox datacenter configuration was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect Proxmox datacenter configuration."
        return 1
    }

    log_success "Proxmox datacenter configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_user_config
#
# Purpose:
#   Preserve the Proxmox access-control configuration, including configured
#   users, groups, roles, ACL assignments, and API-token identifiers.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_user_config() {

    local configuration_dir="$1"

    local source_file="/etc/pve/user.cfg"
    local output_file="${configuration_dir}/user.cfg"

    log_info "Collecting Proxmox access-control configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris Proxmox Access-Control Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write access-control configuration artifact."
            return 1
        }

        log_info "Proxmox access-control configuration was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect Proxmox access-control configuration."
        return 1
    }

    chmod 0600 "${output_file}" || {
        operator_error "Unable to secure Proxmox access-control artifact permissions."
        return 1
    }

    log_success "Proxmox access-control configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_domains_config
#
# Purpose:
#   Preserve the Proxmox authentication realm configuration, including PAM,
#   PVE, LDAP, Active Directory, and OpenID Connect realm definitions.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_domains_config() {

    local configuration_dir="$1"

    local source_file="/etc/pve/domains.cfg"
    local output_file="${configuration_dir}/domains.cfg"

    log_info "Collecting Proxmox authentication realm configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris Proxmox Authentication Realm Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write authentication realm artifact."
            return 1
        }

        log_info "Proxmox authentication realm configuration was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect authentication realm configuration."
        return 1
    }

    chmod 0600 "${output_file}" || {
        operator_error "Unable to secure authentication realm artifact permissions."
        return 1
    }

    log_success "Proxmox authentication realm configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_notifications_config
#
# Purpose:
#   Preserve the Proxmox notification configuration.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_notifications_config() {

    local configuration_dir="$1"

    local source_file="/etc/pve/notifications.cfg"
    local output_file="${configuration_dir}/notifications.cfg"

    log_info "Collecting Proxmox notification configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris Notification Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write notification configuration artifact."
            return 1
        }

        log_info "Notification configuration was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect notification configuration."
        return 1
    }

    log_success "Notification configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_storage_config
#
# Purpose:
#   Preserve the Proxmox storage configuration.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_storage_config() {

    local configuration_dir="$1"

    local source_file="/etc/pve/storage.cfg"
    local output_file="${configuration_dir}/storage.cfg"

    log_info "Collecting Proxmox storage configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris Storage Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write storage configuration artifact."
            return 1
        }

        log_info "Storage configuration was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect storage configuration."
        return 1
    }

    log_success "Storage configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_jobs_config
#
# Purpose:
#   Preserve Proxmox scheduled job configuration, including backup jobs,
#   replication jobs, and future scheduler definitions.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_jobs_config() {

    local configuration_dir="$1"

    local source_file="/etc/pve/jobs.cfg"
    local output_file="${configuration_dir}/jobs.cfg"

    log_info "Collecting Proxmox scheduled job configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris Scheduled Job Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write scheduled job artifact."
            return 1
        }

        log_info "Scheduled job configuration was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect scheduled job configuration."
        return 1
    }

    log_success "Scheduled job configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_cluster_firewall_config
#
# Purpose:
#   Preserve the Proxmox datacenter firewall configuration.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_cluster_firewall_config() {

    local configuration_dir="$1"

    local source_file="/etc/pve/firewall/cluster.fw"
    local output_file="${configuration_dir}/cluster.fw"

    log_info "Collecting Proxmox datacenter firewall configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris Datacenter Firewall Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write datacenter firewall artifact."
            return 1
        }

        log_info "Datacenter firewall configuration was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect datacenter firewall configuration."
        return 1
    }

    log_success "Datacenter firewall configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_replication_config
#
# Purpose:
#   Preserve Proxmox replication job configuration.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_replication_config() {

    local configuration_dir="$1"

    local source_file="/etc/pve/replication.cfg"
    local output_file="${configuration_dir}/replication.cfg"

    log_info "Collecting Proxmox replication configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris Replication Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write replication configuration artifact."
            return 1
        }

        log_info "Replication configuration was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect replication configuration."
        return 1
    }

    log_success "Replication configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_ha_resources_config
#
# Purpose:
#   Preserve Proxmox High Availability resource configuration.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_ha_resources_config() {

    local configuration_dir="$1"

    local source_file="/etc/pve/ha/resources.cfg"
    local output_file="${configuration_dir}/ha-resources.cfg"

    log_info "Collecting Proxmox HA resource configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris HA Resource Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write HA resource configuration artifact."
            return 1
        }

        log_info "HA resource configuration was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect HA resource configuration."
        return 1
    }

    log_success "HA resource configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_ha_groups_config
#
# Purpose:
#   Preserve Proxmox High Availability group configuration.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_ha_groups_config() {

    local configuration_dir="$1"

    local source_file="/etc/pve/ha/groups.cfg"
    local output_file="${configuration_dir}/ha-groups.cfg"

    log_info "Collecting Proxmox HA group configuration."

    if [[ ! -f "${source_file}" ]]; then

        {
            echo "# Project Polaris HA Group Configuration"
            echo "# Status: Not present"
            echo "# Source: ${source_file}"
        } > "${output_file}" || {
            operator_error "Unable to write HA group configuration artifact."
            return 1
        }

        log_info "HA group configuration was not present."
        return 0
    fi

    safe_copy "${source_file}" "${output_file}" || {
        operator_error "Unable to collect HA group configuration."
        return 1
    }

    log_success "HA group configuration collected."

    return 0
}

###############################################################################
# Function: _polaris_proxmox_collect_sdn_config
#
# Purpose:
#   Preserve Proxmox Software Defined Networking (SDN) configuration.
#
# Parameters:
#   $1 - Platform configuration staging directory.
#
# Returns:
#   0 - Collection successful.
#   1 - Collection failed.
###############################################################################

_polaris_proxmox_collect_sdn_config() {

    local configuration_dir="$1"

    log_info "Collecting Proxmox SDN configuration."

    collect_optional_directory \
        "/etc/pve/sdn" \
        "${configuration_dir}/sdn" \
        "Project Polaris SDN Configuration" || {
            operator_error "Unable to collect SDN configuration."
            return 1
        }

    log_success "Proxmox SDN configuration collected."

    return 0
}

###############################################################################
# Public Interface
###############################################################################

###############################################################################
# Function: collect_proxmox_ai
#
# Purpose:
#   Execute the complete Project Polaris AI Node Proxmox collection workflow
#   using the destination directory supplied by the calling component.
#
#   Named distinctly from Homelab's collect_proxmox() (not just relocated)
#   so there is zero namespace collision risk if both collector scripts
#   were ever sourced in the same shell session.
#
# Parameters:
#   $1 - Absolute or relative destination directory for collector output.
#
# Returns:
#   0 - Proxmox collection completed successfully.
#   1 - Input validation or one or more collection stages failed.
###############################################################################

collect_proxmox_ai() {

    local destination_directory="${1:-}"

    if [[ -z "${destination_directory}" ]]; then
        operator_error "No Proxmox collection destination was provided."
        return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    fi

    POLARIS_PROXMOX_STAGING_ROOT="${destination_directory}"

    log_info "Starting ${MODULE_DISPLAY_NAME} v${MODULE_VERSION}."
    log_info "Collector destination: ${POLARIS_PROXMOX_STAGING_ROOT}"

    _polaris_proxmox_validate_environment || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_create_staging || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_collect_host || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_collect_storage || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_collect_network || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_collect_vms || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_collect_cluster || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_collect_certificates || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_collect_cron || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_collect_configuration || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_collect_proxmox_summary || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"
    _polaris_proxmox_collect_metadata || return "${POLARIS_PROXMOX_COLLECTOR_RESULT_ERROR}"

    log_success "Proxmox collection complete."

    return "${POLARIS_PROXMOX_COLLECTOR_RESULT_SUCCESS}"
}
