# Sanitization Notes

This public copy is generated from a private working set. Before publication:

| Item | Treatment |
|---|---|
| Private RFC1918 addresses (192.168.x.x, 10.10.x.x) | **Kept.** They are not routable and are needed to follow the design |
| Tailscale tailnet name | Replaced with `example-tailnet.ts.net` |
| Tailscale device addresses | Replaced with consistent placeholders in `100.64.0.10`–`100.64.0.18`. Well-known Tailscale service addresses (`100.100.100.100`) and network ranges are unchanged |
| MAC addresses | `BC:24:11:XX:XX:XX` (Proxmox OUI kept) or `XX:XX:XX:XX:XX:XX` |
| Disk, memory and device serial numbers | `SERIAL-REDACTED` |
| UUIDs (VM SMBIOS, tokens, etc.) | `00000000-0000-0000-0000-00000000000N` (Microsoft's well-known default GPO GUIDs kept) |
| Administrative account names | `domain-admin` (AD admin), `lab-admin` (Linux/Forgejo admin) |
| Personal email addresses, household members' names | Placeholders |
| OSCP lab flags (answer key) | `FLAG-REDACTED` |
| Secrets (passwords, API token values, private keys) | None present in the published material; credentials live in Vaultwarden |
| Raw chat logs, screenshots, databases, logs, superseded versions | Not published |

Hostnames, VMIDs, VLAN numbers and service account names (for example `polaris-admws-backup`) are kept on purpose, because they show the least-privilege design.
