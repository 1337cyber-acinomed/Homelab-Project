# Polaris config-backup framework

Daily collection, validation and archiving of every lab device's configuration.

```
bin/            orchestrators: polaris-backup (homelab devices), polaris-ai-backup (AI node)
collectors/     one per device: proxmox, proxmox-ai, firewall01, gateway01, opnsense, switch, docker, admin01, admin-ws, pihole
lib/            polaris-common.sh (shared library), polaris-firewall-collector.sh, polaris-single-export-collector.sh
framework/      verify-manifest.sh
orchestration/  ansible/ (inventory + playbook), n8n/ (exported schedule and run workflows)
```

## Flow

1. n8n fires at 07:00 and runs the Ansible playbook, which runs `bin/polaris-backup` on the homelab node.
2. The orchestrator takes a lock (exit code 5 = already running, which Ansible treats as skipped), then runs each registered collector.
3. Each collector returns `NEW_OR_CHANGED`, `NO_CHANGE` or `FAILED`.
4. New output is validated against its manifest (SHA-256). Valid output is copied to nas01, validated again and promoted. Invalid output is quarantined.
5. Retention runs separately for validated and quarantined backups and never removes a device's last good copy.

## Conventions

- Public functions are verbs (`collect_proxmox`, `verify_manifest`); private functions start with `_`; shared helpers live in `polaris-common.sh`.
- Collectors never modify the device and never package or verify their own output.
- Each device is accessed by its own least-privilege identity.

Full design and history: [docs/09-automation](../../docs/09-automation/README.md).
