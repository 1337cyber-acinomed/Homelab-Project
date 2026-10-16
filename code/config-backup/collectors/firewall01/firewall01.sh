#!/usr/bin/env bash

[[ -n "${POLARIS_PFSENSE_SH_LOADED:-}" ]] && return 0
readonly POLARIS_PFSENSE_SH_LOADED=1

###############################################################################
# Project Polaris
# pfSense Configuration Collector
###############################################################################

POLARIS_PFSENSE_COLLECTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly POLARIS_PFSENSE_COLLECTOR_DIR
POLARIS_PFSENSE_FRAMEWORK_ROOT="$(cd -- "${POLARIS_PFSENSE_COLLECTOR_DIR}/../.." && pwd -P)"
readonly POLARIS_PFSENSE_FRAMEWORK_ROOT
readonly POLARIS_PFSENSE_LIB_DIR="${POLARIS_PFSENSE_FRAMEWORK_ROOT}/lib"

# shellcheck source=/dev/null
source "${POLARIS_PFSENSE_LIB_DIR}/polaris-common.sh"
# shellcheck source=/dev/null
source "${POLARIS_PFSENSE_LIB_DIR}/polaris-firewall-collector.sh"

readonly POLARIS_PFSENSE_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_PFSENSE_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_PFSENSE_COLLECTOR_RESULT_NO_CHANGE=2
readonly POLARIS_PFSENSE_MODULE_NAME="pfsense"
readonly POLARIS_PFSENSE_MODULE_DISPLAY_NAME="pfSense Collector"
readonly POLARIS_PFSENSE_MODULE_VERSION="1.0.0"
readonly POLARIS_PFSENSE_MODULE_AUTHOR="Project Polaris"

polaris_register_firewall_collector \
    "pfsense" \
    "pfSense" \
    "pfSense Collector" \
    "1.0.0" \
    "192.168.10.1" \
    "admin" \
    "/root/.ssh/polaris-pfsense-backup" \
    "10" \
    "/cf/conf/config.xml"

# Purpose: Invoke the shared firewall engine with the pfSense registry entry.
# This comment documents intent; implementation behavior is unchanged.
collect_pfsense() {
    polaris_collect_firewall_configuration \
        "pfsense" \
        "${1:-}" \
        "${2:-}" \
        "${3:-}"
}
