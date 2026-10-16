#!/usr/bin/env bash

[[ -n "${POLARIS_OPNSENSE_SH_LOADED:-}" ]] && return 0
readonly POLARIS_OPNSENSE_SH_LOADED=1

###############################################################################
# Project Polaris
# OPNsense Configuration Collector
###############################################################################

POLARIS_OPNSENSE_COLLECTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly POLARIS_OPNSENSE_COLLECTOR_DIR
POLARIS_OPNSENSE_FRAMEWORK_ROOT="$(cd -- "${POLARIS_OPNSENSE_COLLECTOR_DIR}/../.." && pwd -P)"
readonly POLARIS_OPNSENSE_FRAMEWORK_ROOT
readonly POLARIS_OPNSENSE_LIB_DIR="${POLARIS_OPNSENSE_FRAMEWORK_ROOT}/lib"

# shellcheck source=/dev/null
source "${POLARIS_OPNSENSE_LIB_DIR}/polaris-common.sh"
# shellcheck source=/dev/null
source "${POLARIS_OPNSENSE_LIB_DIR}/polaris-firewall-collector.sh"

readonly POLARIS_OPNSENSE_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_OPNSENSE_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_OPNSENSE_COLLECTOR_RESULT_NO_CHANGE=2
readonly POLARIS_OPNSENSE_MODULE_NAME="opnsense"
readonly POLARIS_OPNSENSE_MODULE_DISPLAY_NAME="OPNsense Collector"
readonly POLARIS_OPNSENSE_MODULE_VERSION="1.0.0"
readonly POLARIS_OPNSENSE_MODULE_AUTHOR="Project Polaris"

polaris_register_firewall_collector \
    "opnsense" \
    "OPNsense" \
    "OPNsense Collector" \
    "1.0.0" \
    "192.168.10.120" \
    "root" \
    "/root/.ssh/polaris-opnsense-backup" \
    "10" \
    "/conf/config.xml"

# Purpose: Invoke the shared firewall engine with the OPNsense registry entry.
# This comment documents intent; implementation behavior is unchanged.
collect_opnsense() {
    polaris_collect_firewall_configuration \
        "opnsense" \
        "${1:-}" \
        "${2:-}" \
        "${3:-}"
}
