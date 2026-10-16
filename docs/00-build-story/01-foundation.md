# Chapter 1 — Foundation: Firewall-First Proxmox (late June – July 2026)

## Starting point

On 28 June 2026 the network was a consumer setup: an ISP router doing NAT, a TP-Link Deco mesh, and one Proxmox host with an Intel 4-port PCIe NIC feeding a TP-Link TL-SG608E switch. The first goal was to put **all lab traffic behind a virtualized pfSense firewall**. The long-term goal was bigger: put the whole house behind pfSense, and put a virtualized cyber range behind OPNsense, so I would learn both platforms.

## What I built

| Area | Result |
|---|---|
| Firewall | pfSense VM on Proxmox with separate WAN/LAN bridges. The first install's package database corrupted. Rather than fight it, I rebuilt cleanly as **firewall01 (VM 101)**, restored the config and kept the broken VM until the new one was proven. That became the **PFSENSE-GOLD** template. |
| Services | `docker01` running Nginx Proxy Manager, **Vaultwarden** (temporary internal TLS on 4 Jul), Homepage, Uptime Kuma, **Forgejo** (self-hosted git), Portainer |
| Admin | `admin01` Linux admin host; naming, IP-allocation, backup and change-management standards (HES-001…012) |
| Docs | `homelab-infrastructure` repo created 3 Jul; ADRs, SOPs, governance, a Disaster Recovery Kit and recovery runbooks RB-001…008 |
| Storage | NAS (Asustor AS1202T) for VM backups, ISO repository and config archive |
| Cluster | Second node added; **QDevice on the NAS** (20 Jul) via a custom arm64 `corosync-qnetd` container, so a 2-node cluster keeps quorum |

## Problems I hit and how I solved them

| Date | Incident | Root cause → fix | Write-up |
|---|---|---|---|
| 5 Jul | Docker01 backup failed and the VM would not start | The old `VM` ZFS pool had entered a suspended I/O state after disk errors, and several VM configs and `storage.cfg` still referenced it even though production disks had been migrated. Removed the stale references and the dead storage backend; Docker01 recovered | [TS-005](../12-troubleshooting/TS-005-2026-07-05-proxmox-suspended-zfs-pool-stale-vm-references.md) |
| 10 Jul | firewall01 lost WAN; LAN clients could reach pfSense but not the Internet | No DHCP offer on WAN, so no default route. Removed the Proxmox `firewall=1` flags from all three pfSense NICs to simplify the forwarding path. A second fault appeared on restart: the VM disk referenced a storage ID (`Firewall`) that no longer existed. Fixed the reference without moving any data | [TS-006](../12-troubleshooting/TS-006-2026-07-10-pfsense-proxmox-firewall-conflict.md) |
| 25 Jul | Proxmox GUI and Tailscale unreachable after a management IP change | Linux source-address selection: the old and new addresses were both on the bridge. Ruled out driver, NIC offload, rp_filter and bridge learning first | [TS-007](../12-troubleshooting/TS-007-2026-07-25-proxmox-unreachable-after-wan-migration.md) |
| Jul | TrueNAS static IP and pool creation issues | Documented; storage later standardized on the Asustor NAS | [TS-003](../12-troubleshooting/TS-003-truenas-static-ip-configuration.md), [TS-004](../12-troubleshooting/TS-004-truenas-pool-creation.md) |

## Skills demonstrated

Proxmox VE (bridges, ZFS, clustering, corosync QDevice), pfSense deployment and rebuild, Docker Compose, reverse proxying and internal TLS, git-based documentation, building a container image for ARM (arm64), incident root-cause analysis.

## Records

[ARC-001 Architecture](../01-architecture/ARC-001-northstar-architecture.md) · [ADRs](../01-architecture/adr/) · [Proxmox installation guide](../04-virtualization/proxmox-installation-guide.md) · [Cluster and guest inventory](../04-virtualization/VIRT-001-cluster-and-guest-inventory.md) · [Recovery runbooks](../11-recovery/runbooks/) · [QDevice Dockerfile](../../code/qdevice/)
