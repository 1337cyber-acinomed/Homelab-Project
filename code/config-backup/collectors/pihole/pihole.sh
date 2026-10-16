#!/usr/bin/env bash

[[ -n "${POLARIS_PIHOLE_SH_LOADED:-}" ]] && return 0
readonly POLARIS_PIHOLE_SH_LOADED=1

###############################################################################
# Project Polaris
# Pi-hole (pihole01) Configuration Collector
#
# Registers pihole01 into the shared single-export collector engine
# (polaris-single-export-collector.sh). pihole01 is CT 108, an LXC on
# Homelab, not a physical device.
#
# Comparison design (verified empirically, not assumed):
#   Teleporter's own zip is NOT byte-stable across two real no-change
#   exports (confirmed 2026-09-12), but etc/pihole/pihole.toml inside it
#   IS byte-identical across those same two exports. gravity.db,
#   pihole-FTL.db, dhcp.leases, and hosts were NOT tested and are
#   deliberately excluded from the comparison for now - see the runbook's
#   3p notes before including any of them.
#
# Export access requires a scoped sudo rule on pihole01 itself
# (/etc/sudoers.d/polaris-pihole-backup):
#   polaris-pihole-backup ALL=(pihole) NOPASSWD: /usr/bin/pihole-FTL --teleporter
# pihole.toml and its rotated backups are pihole:pihole owned and not
# readable by polaris-pihole-backup directly - this is Pi-hole's own
# documented access model, not a misconfiguration on our end.
###############################################################################

POLARIS_PIHOLE_COLLECTOR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly POLARIS_PIHOLE_COLLECTOR_DIR

POLARIS_PIHOLE_FRAMEWORK_ROOT="$(cd -- "${POLARIS_PIHOLE_COLLECTOR_DIR}/../.." && pwd -P)"
readonly POLARIS_PIHOLE_FRAMEWORK_ROOT

readonly POLARIS_PIHOLE_LIB_DIR="${POLARIS_PIHOLE_FRAMEWORK_ROOT}/lib"

# shellcheck source=/dev/null
source "${POLARIS_PIHOLE_LIB_DIR}/polaris-common.sh"
# shellcheck source=/dev/null
source "${POLARIS_PIHOLE_LIB_DIR}/polaris-single-export-collector.sh"

###############################################################################
# Registration
#
# Parameters, in order: collector_id, product_name, module_display_name,
# module_version, host, user, ssh_key, connect_timeout, remote_work_dir,
# remote_export_command, staged_artifact_name, comparison_inner_path.
###############################################################################

polaris_register_single_export_collector \
    "pihole" \
    "Pi-hole" \
    "Pihole Collector" \
    "1.0.0" \
    "192.168.30.2" \
    "polaris-pihole-backup" \
    "/root/.ssh/polaris-pihole-backup" \
    "10" \
    "/tmp" \
    "cd /tmp && sudo -u pihole pihole-FTL --teleporter" \
    "pihole-teleporter.zip" \
    "etc/pihole/pihole.toml"

###############################################################################
# Function: collect_pihole
#
# Purpose:
#   Thin entry point matching the collector interface polaris-backup
#   expects (declare -F collect_pihole), delegating to the shared engine.
#
# Parameters:
#   $1 - Collector staging root.
#   $2 - Previous validated artifact baseline, or an empty value.
#   $3 - Troubleshooting root.
###############################################################################

collect_pihole() {
    polaris_collect_single_export_configuration "pihole" "$@"
}
