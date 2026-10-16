# Chapter 4 — Building the Cyber Range (August – October 2026)

## Goal

A cyber range that can safely host deliberately vulnerable and deliberately malicious systems. It must never become a path into the household or the trusted lab, even when I make a mistake.

## Containment design

- The cyber range runs on its **own Proxmox node**. Guests attach only to an internal, VLAN-aware bridge (`vmbr1`) that has **no host IP**.
- **cyber-fw01 (OPNsense)** is the only guest that touches both the trusted network and the cyber fabric.
- Every active zone uses the same **4-rule template**: block the firewall's own control plane → allow DNS/DHCP to the zone gateway → block `PROTECTED_NETWORKS` (10/8, 172.16/12, 192.168/16, 100.64/10, 169.254/16) → allow Internet.
- **Inter-zone default deny.** Each attack path (attack → Windows, Linux, apps, hybrid, OSCP) is a documented, numbered exception.
- **Pivot-only segments** (VLAN 71 and 81) have no attack-zone pass at all. They can only be reached by compromising a dual-homed host and tunnelling, just as in a real engagement.
- No guest has a second NIC, a NAS mount, a VPN or a route around OPNsense. Cyber guests are protected by local snapshots only.

## Build sequence (gated)

| Gates | Date | Result |
|---|---|---|
| 1–5 | 21–28 Aug | Recovery points, host config archive, `vmbr1` made VLAN-aware without losing management |
| 6–7 | 28 Aug – 3 Sep | VLANs, per-zone DHCP and DNS (Unbound in front of Dnsmasq), isolation, quarantine |
| 8A–8F | 3–9 Sep | Analysis probe built **offline**, inspected and only then attached; policy validated |
| 8G1 | 22 Sep | Policy audit, host management-plane audit, Tailscale isolation (below) |
| 8G2 | 26 Sep | Attack side: Kali02, Parrot01, Attack-AI with GPU inference |
| 8G3 | 27 Sep – 11 Oct | Windows AD forest, six Linux targets, web apps, hybrid capstone, SIEM, defense-AI |
| 8H | Oct | Narrow, scoped cross-zone passes for SIEM agents |
| **9** | **14 Oct** | **Fail-closed exercise: PASS** |

## Problems found by auditing, not by luck

| Finding | How I found it | Fix |
|---|---|---|
| `PROTECTED_NETWORKS` contained `127.16.0.0/12` instead of `172.16.0.0/12`, and `100.64.0.0/16` instead of `/10` | Compared the alias against the firewall's **runtime table**, not the config page | Corrected as its own approved step, then re-verified against the runtime table |
| The cyberrange node, believed isolated on Tailscale, was reachable from every tailnet device | Read the actual policy JSON. The tag existed, but no rule referenced it | Wrote real tag-scoped grants. Chasing the follow-on TCP timeouts uncovered a Tailscale `src`-selector limitation and a forgotten local "Shields Up" setting. Isolation was verified with live traffic |
| A full-root Proxmox API token used by LLM-triggered Ansible | Host management-plane audit | Tracked as a top backlog risk |
| BlackArch keyring mount anomaly on the attack VM | Build validation | Rebuilt the VM as Kali (23 Sep) |
| ROCm does not support Debian 13 for the Attack-AI container | Upstream bug and AMD support matrix | Rebuilt the container on Ubuntu 24.04; installed userspace ROCm only (no DKMS inside an LXC) |

## Hardware upgrade and GPUs (26 Sep – 13 Oct)

The node was moved from an i7-7700K with 31 GiB to a **Ryzen 7 5800X3D with 64 GB, an RX 7700 XT and a GTX 970**. The RX 7700 XT is shared by the Attack-AI and defense-AI containers through cgroup device passthrough. The GTX 970 is passed through to Kali02 with **vfio** for hashcat. That needed `iommu=pt`; `amd_iommu=on` is not a valid option on this host. Result: **11.6 GH/s NTLM**.

## Fail-closed proof (Gate 9, 14 Oct 2026)

With console access to the host prepared in advance, I shut down cyber-fw01 while three guests in three zones were online. All three lost Internet access, **found no alternate gateway**, and still could not reach Proxmox, CGNAT or link-local addresses. When the firewall was restored, DHCP, DNS, NAT and logging came back, and a fresh config export was taken. **The cyber range fails closed.**

## Skills demonstrated

Network segmentation and firewall policy design (OPNsense), VLAN trunking on Linux bridges, DNS (Unbound + Dnsmasq), containment and blast-radius thinking, AD attack-lab design, Linux and Windows target hardening and deliberate vulnerability injection, GPU passthrough (vfio and LXC cgroup), Tailscale ACL/grant design, evidence-driven validation.

## Records

[RUN-003 cyber-range master record](../07-cyberrange/RUN-003-cyberrange-current-state-handoff.md) · [RUN-002 segmentation runbook](../07-cyberrange/RUN-002-cyberrange-segmentation-runbook.md) · [Guest hardening steps](../07-cyberrange/linux-guest-hardening-and-validation-steps.md) · [VM371 closure](../07-cyberrange/build-records/VM371-cyber-corpsrv01-closure-summary.md) · [OPNsense ACL privilege mapping](../02-network/firewalls/opnsense-diagnostics-acl-privilege-mapping.md)
