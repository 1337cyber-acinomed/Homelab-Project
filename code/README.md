# Code

Working code from Project Polaris, published as a reference. Hostnames and private addresses match the lab. Account names, the Forgejo owner (`lab-admin`) and Tailscale details are placeholders. Credentials are never in the code: scripts read them from root-only files or token files on the host.

| Folder | What it is | Language |
|---|---|---|
| [`config-backup/`](config-backup/) | Configuration-backup framework: orchestrators, per-device collectors, shared libraries, manifest verifier, Ansible and n8n orchestration | Bash, Python, YAML, JSON |
| [`cyberrange-backup/`](cyberrange-backup/) | Separate API-only orchestrator and collector for the cyber-range node (it runs hostile software, so there is no SSH trust into it) | Bash |
| [`coding-agent-workspace/`](coding-agent-workspace/) | SSH forced-command scripts that sandbox the AI coding agent: start a workspace, list/read/write files, run checks, propose a PR, discard | Bash |
| [`recoveryrelay/`](recoveryrelay/) | PowerShell named-pipe transport for the RecoveryRelay broker (Admin-WS ↔ Docker01, `QUARANTINE` only) | PowerShell |
| [`docker-compose/`](docker-compose/) | docker01 services: Forgejo, Homepage, Nginx Proxy Manager, Portainer, Uptime Kuma, Vaultwarden | YAML |
| [`qdevice/`](qdevice/) | Dockerfile for the arm64 `corosync-qnetd` image that runs the Proxmox QDevice on the NAS | Dockerfile |
| [`pki/`](pki/) | `CAPolicy.inf` for the offline root CA | INF |
| [`scripts/`](scripts/) | Windows organizer for exported configs; quarantine recovery helper | PowerShell, Bash |

Design notes for the backup framework are in [docs/09-automation](../docs/09-automation/README.md), and the story behind it is in [chapter 6](../docs/00-build-story/06-automation-config-backup.md).
