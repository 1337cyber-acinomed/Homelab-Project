# HW-000 — Hardware Inventory

| Field | Value |
|---|---|
| Document ID | HW-000 |
| Version | 3.0 |
| Status | Authoritative — current state |
| Effective | 16 October 2026 |
| Owner | Jesse Breedlove (Project Polaris) |
| Supersedes | Hardware Inventory v2 (docx), HW-001…HW-007 (Jul 2026), `homelab-specs.md`, `physiccal_disk_registry.md`, `disk-inventory.md` |
| Evidence | Proxmox node summaries and Disks page (16 Oct 2026), `dmidecode` output, AI runbook Phase 1, RUN-003 §3.3.5 |

## 1. Summary

| Asset | Role | Platform | CPU | RAM | GPU | Storage |
|---|---|---|---|---|---|---|
| **homelab** | Proxmox node 1 — firewalls, infrastructure, AD/PKI, media | Gigabyte B550 EAGLE WIFI6 (BIOS F4a) | AMD Ryzen 5 5500, 6C/12T | 48 GB DDR4-2666 Kingston (46.92 GiB usable) | None | ~10.6 TB raw across 7 HDDs + boot device |
| **cyberrange** | Proxmox node 2 — isolated cyber range | ASRock X570 Taichi | AMD Ryzen 7 5800X3D, 8C/16T | 64 GB DDR4 | RX 7700 XT 12 GB (AI + host console), GTX 970 4 GB (vfio → kali02) | 512 GB Samsung SSD (OS), 4 TB ZFS `Cyber_VM` |
| **AI** | Proxmox node 3 — AI agents and automation | Gigabyte X870 AORUS Elite WiFi7 ICE | AMD Ryzen 9 7900X, 12C/24T | 32 GB DDR5-6000 | RX 9060 XT 16 GB (gfx1200); Raphael iGPU unused | 2.05 TB SPCC NVMe (`ai-storage` LVM-thin), 1.02 TB Intel NVMe (reserve) |
| **nas01** | Backups, ISO repo, config archive, cluster QDevice | Asustor AS1202T (ARM) | — | — | — | 1 × 4 TB (single disk — accepted risk) |
| **switch01** | Core switch | Netgear GS324TP S350, 24 × 1 GbE PoE+ (190 W), 2 × SFP | — | — | — | — |
| **Starlink** | Internet uplink | Starlink Standard Kit Gen 3 (dish + router with 2 × RJ45) | — | — | — | — |
| **Deco mesh** | Household Wi-Fi (AP mode) | TP-Link Deco × 2 (model TBC) | — | — | — | — |

## 2. homelab node

| Item | Value |
|---|---|
| Hostname / IP | `homelab` / 192.168.10.2 |
| Proxmox VE | 9.2.20, kernel `7.0.14-19-pve`, EFI boot |
| Board | Gigabyte B550 EAGLE WIFI6, BIOS F4a (14 Apr 2026), TPM 2.0 (AMD fTPM) |
| CPU | Ryzen 5 5500 (1 socket, 12 threads) |
| Memory | 48 GB DDR4-2666 Kingston (HX426C16FB3 family), 128 GB max, 4 DIMM slots |
| NICs | Onboard + Intel 4-port PCIe NIC. **`nic2` is dead** (no carrier on either end); home LAN bridge `vmbr3` uses `nic1` |
| Root filesystem | 93.93 GiB (`/`), boot device model TBC |
| Proxmox storages | `local`, `local-lvm`, `VM`, `VM2`, `NAS-Backups`, `NAS-ISO-Repo`, `NAS-Infrastructure`, `NAS-Templates`, `NAS-Windows` |

### 2.1 Disks (Proxmox → Disks, 16 Oct 2026)

| Device | Model | Size | Use |
|---|---|---|---|
| /dev/sda | Toshiba MQ01ABD100 | 1.00 TB | Partitioned (pool member — mapping TBC) |
| /dev/sdb | Toshiba MQ01ABD100 | 1.00 TB | Partitioned |
| /dev/sdc | Samsung HD103UJ | 1.00 TB | Partitioned |
| /dev/sdd | Toshiba MK6465GSXN | 640 GB | Partitioned |
| /dev/sde | Toshiba MQ01ABD100V | 1.00 TB | Unpartitioned |
| /dev/sdf | Seagate ST2000DM001 | 2.00 TB | Partitioned |
| /dev/sdg | Seagate ST4000NM0033 | 4.00 TB | USB-attached jellyfin01 media disk (`/srv/media`, excluded from backups) |

The disk → storage (`VM`, `VM2`, `local-lvm`) mapping is not recorded yet (MB-001). Serial numbers are kept in the Proxmox Disks page and are not reproduced here.

## 3. cyberrange node

| Item | Value |
|---|---|
| Hostname / IP | `cyberrange` / 192.168.10.119 |
| Proxmox VE | 9.2.x, kernel `7.0.14-19-pve` pinned (`7.0.14-14` broken, still installed) |
| Board / CPU | ASRock X570 Taichi / Ryzen 7 5800X3D (no iGPU) |
| Memory | 64 GB DDR4 (upgraded 26 Sep 2026 from 31 GiB) |
| GPU slot 1 | RX 7700 XT 12 GB, PCI `0e:00.0`, `amdgpu`, ROCm gfx1101 — shared by CT 311 and CT 351 via cgroup device passthrough; also drives the host console. Undervolt service `gpu-undervolt.service` |
| GPU slot 2 | GTX 970 4 GB, PCI `0f:00.0`/`0f:00.1`, exclusive vfio passthrough to VM 310 kali02 — hashcat 11.6 GH/s NTLM (13 Oct 2026). Needs `iommu=pt` |
| Storage | 512 GB Samsung SSD (PVE), `Cyber_VM` 4 TB ZFS (guest disks + snapshots), `NAS-ISO-Repo-CyberRange` (host-level only) |
| History | Built on an Intel i7-7700K with 31 GiB RAM; rebuilt on the AM4 platform 26 Sep 2026 |

## 4. AI node

| Item | Value |
|---|---|
| Hostname / IP | `AI` / 192.168.10.124 |
| Board / CPU | Gigabyte X870 AORUS Elite WiFi7 ICE / Ryzen 9 7900X |
| Memory | 32 GB DDR5-6000 |
| GPU | RX 9060 XT 16 GB GDDR6 (gfx1200, RDNA4), PCI `03:00.0` → `renderD128`; passed into CT 401 (privileged LXC) |
| Storage | `ai-storage` LVM-thin on 2.05 TB SPCC NVMe; 1.02 TB Intel NVMe untouched (reserve); NAS mounts `NAS-AI`, `NAS-CyberRange`, `NAS-ISO-Repo`, `NAS-Infrastructure`, `NAS-Templates`, `NAS-Windows` |

## 5. nas01

| Item | Value |
|---|---|
| Model | Asustor AS1202T, ADM, ARM |
| Disk | 1 × 4 TB — single-disk, accepted risk (ARC-C02); SMART monitored |
| Shares | `NAS-Backups`, `ISO-Repo`, `Infrastructure`, `Templates`, `Windows`, `AI`, `CyberRange`, `Configurations`, `Backups/ActiveDirectory` |
| Roles | Proxmox backup target, config-backup archive, ISO repo, cluster QDevice (`corosync-qnetd` container, custom arm64 image) |
| Settings backup | ADM settings export (private archive) |

## 6. Network hardware

| Device | Details |
|---|---|
| switch01 | Netgear GS324TP S350; management 192.168.10.126 on VLAN 10 (mask shows /22 — fix pending); VLANs 1/10/30 (+4089 Auto-Video); web UI only (no CLI/SSH), so the config collector drives it with Playwright |
| Starlink | Standard Kit Gen 3. Router hands 192.168.1.x to gateway01 (router mode, not bypass — TBC). 75 ft dish cable |
| Deco mesh | Office unit = mesh main in AP mode on VLAN 30; kitchen unit = wireless satellite |

## 7. Retired hardware

| Device | Retired | Replaced by |
|---|---|---|
| TP-Link TL-SG608E 8-port switch (old switch01, 192.168.10.3) | Sep 2026 | Netgear GS324TP |
| Ubiquiti NanoStation pair (station + AP bridge) | Sep/Oct 2026 | Starlink router cabled directly to the homelab node |
| cyberrange i7-7700K platform, 31 GiB RAM | 26 Sep 2026 | Ryzen 7 5800X3D / X570 Taichi / 64 GB |
| ISP modem/router (192.168.68.x / 192.168.0.x) | Starlink cutover, Sep 2026 | Starlink Gen 3 |

## Revision history

| Version | Date | Summary |
|---|---|---|
| 1.0 | 15 Jul 2026 | Production hardware baseline (homelab only) |
| 2.0 | Aug 2026 | Regenerated for Backup Framework v1.0 |
| 3.0 | 16 Oct 2026 | Rewrite: all three nodes, NAS, GS324TP, Starlink, GPUs, disk table, retired hardware |
