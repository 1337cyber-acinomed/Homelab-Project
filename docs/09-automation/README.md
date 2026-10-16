# 09 — Automation: Configuration Backup Framework

The **Polaris config-backup framework** is a Bash framework that collects the configuration of every device in the lab daily. It validates each collection against a manifest and copies it to nas01. Unchanged configurations are detected and skipped, failed or invalid output is quarantined, and retention never deletes a device's last good copy.

## Layout

| Path | Contents |
|---|---|
| `../../code/config-backup/bin/polaris-backup` | Main orchestrator (v0.2.0) for homelab devices. Collectors: proxmox, gateway01, firewall01 (`pfsense` id), opnsense, docker, admin01, admin-ws, switch, pihole |
| `../../code/config-backup/bin/polaris-ai-backup` | Single-purpose orchestrator for the AI node's Proxmox host |
| `../../code/cyberrange-backup/` | Single-purpose orchestrator + collector for the cyberrange node. API-only by design, because that node runs hostile software |
| `../../code/config-backup/collectors/` | One collector per device. Collectors only read the device and produce artifacts |
| `../../code/config-backup/lib/polaris-common.sh` | Shared library: logging, locking, manifests, SHA-256, result-code contract |
| `../../code/config-backup/lib/polaris-firewall-collector.sh` | Shared engine for pfSense/OPNsense XML collection |
| `../../code/config-backup/lib/polaris-single-export-collector.sh` | Shared engine for "generate one export, then fetch it" devices (Pi-hole) |
| `../../code/config-backup/collectors/switch/switch-export.py` | Playwright script that drives the GS324TP web UI (no CLI on this switch) |
| `../../code/config-backup/framework/verify-manifest.sh` | Manifest verifier |
| `../../code/config-backup/orchestration/ansible/` | Inventory + playbook n8n uses to run the orchestrator on the homelab node (`/opt/project-polaris/config-backup`) |
| `../../code/config-backup/orchestration/n8n/` | Exported n8n workflows: daily schedule (`0 7 * * *`) and run/notify |
| `../../code/scripts/` | Windows organizer for exported configs; quarantine-recovery helper |
| `design/` | Three-tier architecture, change-waves plan, Phase 3.5 implementation matrix, refinement review, logging plan |
| `AI-PH3-*.md` | Full Phase 3 build runbook (Ansible + n8n + AI review, merge-broker) and the step 3n addendum |

## Design rules

1. **Three tiers.** Collectors gather. Framework utilities verify, package and catalogue. The orchestrator coordinates. No collector knows the orchestrator exists.
2. **Result-code contract.** Every collector returns NEW_OR_CHANGED, NO_CHANGE or FAILED, and the orchestrator branches on that alone.
3. **Validate twice.** Output is validated locally, then validated again after the copy to nas01. Only then is it promoted.
4. **Quarantine, never delete, bad output.**
5. **Least-privilege identities per device.** Examples: `polaris-ansible-backup` on the homelab node, `polaris-admws-backup` (a non-admin local account) on Admin-WS, and a least-privilege Proxmox API token for the cyberrange collector.
6. **Changes to the framework's own code always need human approval** through the Forgejo merge-broker.

## History

Development waves 2–14 (Sep 2026), superseded scripts and orchestrator run logs are kept in the private working set and are not published here.
