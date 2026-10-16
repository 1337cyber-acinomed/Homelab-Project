#!/usr/bin/env bash

[[ -n "${POLARIS_GATEWAY01_SH_LOADED:-}" ]] && return 0
readonly POLARIS_GATEWAY01_SH_LOADED=1

###############################################################################
# Project Polaris
# Gateway01 Configuration Collector
###############################################################################

POLARIS_GATEWAY01_COLLECTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly POLARIS_GATEWAY01_COLLECTOR_DIR
POLARIS_GATEWAY01_FRAMEWORK_ROOT="$(cd -- "${POLARIS_GATEWAY01_COLLECTOR_DIR}/../.." && pwd -P)"
readonly POLARIS_GATEWAY01_FRAMEWORK_ROOT
readonly POLARIS_GATEWAY01_LIB_DIR="${POLARIS_GATEWAY01_FRAMEWORK_ROOT}/lib"

# shellcheck source=/dev/null
source "${POLARIS_GATEWAY01_LIB_DIR}/polaris-common.sh"
# shellcheck source=/dev/null
source "${POLARIS_GATEWAY01_LIB_DIR}/polaris-firewall-collector.sh"

readonly POLARIS_GATEWAY01_COLLECTOR_RESULT_SUCCESS=0
readonly POLARIS_GATEWAY01_COLLECTOR_RESULT_ERROR=1
readonly POLARIS_GATEWAY01_COLLECTOR_RESULT_NO_CHANGE=2
readonly POLARIS_GATEWAY01_MODULE_NAME="gateway01"
readonly POLARIS_GATEWAY01_MODULE_DISPLAY_NAME="Gateway01 Collector"
readonly POLARIS_GATEWAY01_MODULE_VERSION="1.0.0"
readonly POLARIS_GATEWAY01_MODULE_AUTHOR="Project Polaris"

polaris_register_firewall_collector \
    "gateway01" \
    "Gateway01" \
    "Gateway01 Collector" \
    "1.0.0" \
    "192.168.30.1" \
    "polaris-gateway-backup" \
    "/root/.ssh/polaris-gateway01-backup" \
    "10" \
    "/cf/conf/config.xml"

# Purpose: Invoke the shared firewall engine with the Gateway01 registry entry.
collect_gateway01() {
    polaris_collect_firewall_configuration \
        "gateway01" \
        "${1:-}" \
        "${2:-}" \
        "${3:-}"
}
