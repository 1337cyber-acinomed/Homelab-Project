<!-- Converted from text file: Claude Files/cyberrange summary.txt -->

# Gate 8G1 Step 7 — Consolidated Update Summary
**Purpose:** everything confirmed in RUN-003 (through v1.24, 22 Sep 2026) that needs to flow into RUN-002, REG-001, RM-001, and MB-001 to bring them current. Organized by target document. This is a planning/review document, not itself a formal register — RUN-003 remains the authoritative source for full evidence and chronology on every item below.

---

## 1. Into RUN-002 (Cyberrange Segmentation Runbook, currently v1.31)

**Policy correction:**
- PROTECTED_NETWORKS alias previously contained two typos — `127.16.0.0/12` (should be `172.16.0.0/12`) and `100.64.0.0/16` (should be `100.64.0.0/10`). Corrected in OPNsense, re-verified against the runtime table: now exactly `10.0.0.0/8`, `100.64.0.0/10`, `169.254.0.0/16`, `172.16.0.0/12`, `192.168.0.0/16`.
- Procedural lesson from the alias-activation incident: for any boundary alias, the required sequence is Save → **Apply on Aliases** → verify the runtime table → edit/activate dependent rules → Apply firewall rules → validate both positive and negative outcomes. (An alias object can exist and look correct in the GUI while its runtime table is still empty — this caused a real, if brief, policy gap during the original PROTECTED_NETWORKS rollout.)
- Quarantine (VLAN 99) second rule destination confirmed as `RFC1918_NETWORKS`.
- All six active-purpose zone rule orders confirmed PASS via direct GUI verification; WAN/LAN reviewed and match spec.

**Validation evidence to fold in as the current as-built record:**
- VM310 (BlackArch, CYBER_ATTACK/VLAN 10) and VM360 (analysis-probe01, VLAN 60) full validated-state tables — both Pass on identity, IPv4, gateway/DNS, public DNS/HTTPS, OPNsense control-plane block, Proxmox block, CGNAT/Tailscale block, and link-local block.
- Testing-methodology correction: a raw TCP connection test to `1.1.1.1:443` is not a sufficient public-HTTPS test — use `curl -4` to a normal HTTPS endpoint and treat any non-`000` HTTP status as proof of reachability. (An earlier false failure traced to a script using `NRR==1` instead of `NR==1`.)
- VM300 (cyber-fw01) NIC MACs: WAN (vtnet0) `BC:24:11:XX:XX:XX`, LAN (vtnet1) `BC:24:11:XX:XX:XX`.
- Post-correction OPNsense XML export is the current baseline: `config-OPNsense01.polaris.home.arpa-20260922114944.xml`, 131,400 bytes, SHA-256 `5301e992610d386dae2df0759f2a46f7d5c6b77f0aa648f06fb05ab593adaf98`.

**New section: AI system architecture (finalized 22 Sep 2026):**
- Cyberrange AI system runs entirely on the cyberrange Proxmox node — never on the separate homelab AI node — to preserve the isolation boundary. A cross-host pooled-GPU configuration is an explicit non-goal, not a deferred gate.
- Planned guests: VM311 `attack-ai` (VLAN 10, LXC) and VM351 `defense-ai` (VLAN 50, LXC) — not yet built.
- Dual-GPU allocation plan: a 12 GB card shared between both AI guests via cgroup device passthrough (concurrent VRAM budget ≈12 GB); an 8 GB card exclusively PCI-passthrough'd to whichever non-AI GPU workload (password cracking, analysis tooling) currently needs it, reassigned at guest power-on/off boundaries.
- Hardware identity confirmed: current card is an AMD RX 580 8GB (Vulkan backend, no ROCm on gfx803); planned upgrade path is a Ryzen 7 5800X3D + X570 Taichi AM4 + RX 7700 XT 12GB + 850W PSU. **Not yet confirmed with the operator:** exact mapping of these two cards onto the "12 GB" / "8 GB" roles above.
- Accepted risk, recorded: VM311/VM351 as LXC containers share the host kernel rather than getting hardware-virtualized isolation — a deliberate trade for GPU-sharing concurrency. A container escape terminates at the same destination (the cyberrange Proxmox host) that a full-VM hypervisor escape from any other guest would reach; LXC doesn't create a new blast-radius class, just a somewhat higher escape probability.

**New section: Gate 8G1 host management-plane audit (§3.4 of RUN-003) — full findings, now closed:**
- **Cluster membership** (homelab/AI/cyberrange under Datacenter "polaris", NAS01 as QDevice): operator-confirmed accepted risk. Corosync rides only the trusted vmbr0 bridge — no cyberrange guest has any path to it.
- **Proxmox account audit:** `polaris-cyberrange-collector@pve` confirmed least-privilege (scoped to cyberrange's own node/storage/VMs). `proxcenter@pve` identified as the homelab-wide backup-automation token; its cluster-root scope is broader than the tightly-scoped collector account and is accepted as residual risk (not actioned).
- **NAS mount reconciliation:** legitimate, must-stay mounts are `NAS-AI` and `NAS-Configurations` (cyberrange's own backup landing point, via the `storage-admin` credential) and `NAS-ISO-Repo-CyberRange` (read-only `polaris-cyberrange-iso-ro` credential, cyberrange-scoped ISO content). Six other stale-mounted shares (`NAS-ISO-Repo` plain, `NAS-Windows`, `NAS-Infrastructure`, `NAS-Templates`, `NAS-Backups`, `NAS-CyberRange`) were identified and unmounted.
- **Tailscale peer isolation** — the largest single finding of this audit. What was believed to be an isolating ACL turned out to be Tailscale's unmodified stock default (fully open). Root-caused and fixed through two separate real issues: (1) a genuine, currently-open Tailscale platform bug where the `src` selector in `acls`/`grants` ignores `hosts`/IP-based selectors (only identity selectors work), which required pivoting the design to a tag-based approach (`tag:cyberrange-admin` → `tag:cyberrange`); (2) Shields Up being enabled locally on the cyberrange node itself — found via `journalctl -u tailscaled` log evidence (`shields=true`, explicit `Drop:` entries for every protocol/port attempted), independent of the ACL entirely, and confirmed as the actual cause of a parallel TCP-timeout symptom that survived an otherwise-correct ACL. Final state, applied and verified with live traffic (not just `tailscale ping`): only the tagged admin device can reach the cyberrange node over Tailscale; all other tailnet devices, including `homelab`, are correctly denied.
- **SSH trust:** the `ai` hostname had no `/etc/hosts` entry (unlike `homelab`) — fixed and verified. The higher-risk item — Proxmox's own cluster-wide passwordless SSH trust between nodes (via the pmxcfs-shared `/etc/pve/priv/authorized_keys`) — was researched against Proxmox's own documentation and developer guidance (a Proxmox staff member states cluster nodes "will always need to trust each other," and that manually edited entries in this file get silently regenerated) and accepted as a documented risk by explicit operator decision, given the real exposure requires hypervisor-level compromise of the cyberrange host itself (guests have no path to it) and there is no durable, supported way to close it without risking cluster breakage.
- **External, homelab-side risk tracked (not a cyberrange-side fix):** a `root@pam` "ansible" Proxmox API token on the homelab's CT402 — full-root, not privilege-separated, not yet excluded from the cyberrange node/pool per the homelab team's own tracked status.
- **Design principle recorded:** the cyberrange, homelab, and AI nodes are each treated as independent builds except for explicitly intentional ties — Proxmox cluster + NAS01 QDevice membership, the host-level NAS01 backup mount, and Tailscale break-glass access (scoped to the operator's own admin device only). Anything else is treated as unwanted reach, not an accepted extension.

---

## 2. Into REG-001 (Asset and Network Register, currently v6.2)

**VM310 (BlackArch Linux, attack host):**
VMID 310 · CYBER_ATTACK / VLAN 10 · IP `10.10.10.177/24` · 1 socket / 4 cores · 4.00 GiB RAM · 80 GiB disk on `Cyber_VM` · SeaBIOS/i440fx · single NIC (`net0`, virtio, MAC `BC:24:11:XX:XX:XX`, bridge `vmbr1`, tag 10, firewall=1) · Start at boot = No · QEMU Guest Agent disabled · Protection = No · baseline snapshot created (local only). **Open reconciliation item:** Proxmox display name `Blackarchlinux01` vs. guest-observed identity `lab-admin-blackarch` — carry both until reconciled at Gate 8G2.

**VM360 (analysis-probe01):**
Ubuntu Server 26.04 · VLAN 60 · IP `10.10.60.103/24`.

**VM300 (cyber-fw01, OPNsense):**
NIC MACs — WAN (vtnet0) `BC:24:11:XX:XX:XX`, LAN (vtnet1) `BC:24:11:XX:XX:XX`.

**Planned, not yet built:**
VMID 311 `attack-ai` (LXC, VLAN 10) · VMID 351 `defense-ai` (LXC, VLAN 50).

**PROTECTED_NETWORKS alias — current correct values:**
`10.0.0.0/8`, `100.64.0.0/10`, `169.254.0.0/16`, `172.16.0.0/12`, `192.168.0.0/16`.

**Cyberrange Proxmox host:**
`192.168.10.119` · cluster "polaris" member alongside `homelab` and `AI`, with NAS01 as QDevice · 31.23 GiB usable RAM (~32 GB installed) · `/etc/hosts` now has correct entries for both `homelab` (`192.168.10.2`) and `ai` (`192.168.10.124`).

**Storage inventory (current, active on cyberrange node):**
`Cyber_VM`, `NAS-ISO-Repo-CyberRange` (read-only `polaris-cyberrange-iso-ro` credential), `local`, `local-lvm` — PVE-managed. OS-level CIFS mounts: `NAS-AI` and `NAS-Configurations` (both `//192.168.10.4/Backups[...]`, `storage-admin` credential) — the legitimate cyberrange-host backup target. All other previously-mounted shares (`NAS-ISO-Repo` plain, `NAS-Windows`, `NAS-Infrastructure`, `NAS-Templates`, `NAS-Backups`, `NAS-CyberRange`) are now unmounted and should be removed from the register.

**Proxmox account register:**
`root@pam` (cluster default) · `polaris-cyberrange-collector@pve` (scoped: `/nodes/cyberrange`, `/storage/Cyber_VM`, `/storage/NAS-ISO-Repo-CyberRange`, `/storage/local`, `/storage/local-lvm`, `/vms/300`, `/vms/301` — cyberrange backup automation) · `proxcenter@pve` (cluster-root `/`, near-Administrator — homelab-wide backup automation token; broad scope flagged, not narrowed).

**Tailscale device/tag register:**
`cyberrange` (`100.64.0.17`, `tag:cyberrange`) · `lab-admin-windows-laptop` (`100.64.0.14`, `tag:cyberrange-admin`) · `homelab` (`100.64.0.18`, untagged/`autogroup:member`). `tagOwners`: both `tag:cyberrange` and `tag:cyberrange-admin` owned by `autogroup:admin`.

**AI system hardware (planned):**
Current: AMD RX 580 8GB. Planned upgrade: Ryzen 7 5800X3D + X570 Taichi AM4 + RX 7700 XT 12GB + 850W PSU. Exact dual-GPU role mapping not yet confirmed with operator.

---

## 3. Into RM-001 (Roadmap, currently v6.2)

- **Gate 8G1** (current-state recovery, host-hardening validation, documentation freeze): steps 1–6 all CLOSED 22 Sep 2026. Step 7 — this document-update work — is the only remaining step.
- **M8 milestone position:** advance to "post-VM310 build, Gate 8G1 complete."
- **AI system architecture** finalized as of this gate cycle (§3.3 of RUN-003) — worth recording as a completed roadmap decision, not just a backlog note.
- **Next gates, unchanged in sequence, now that 8G1 is closing:**
  - Gate 8G2 — complete VM310 as the final attack workstation (includes the Proxmox-display-name-vs-guest-identity reconciliation).
  - Gate 8G3 — build remaining final workload systems (VM311/VM351 AI guests, SIEM host(s), defensive Linux/Windows AD sides, purposefully vulnerable hosts).
  - Gate 8G4 — one-zone-at-a-time behavioral validation.
  - Gate 8H — quarantine and scenario policy.
  - Gate 9 — fail-closed exercise and closeout.

---

## 4. Into MB-001 (Maintenance Backlog, currently v5.1)

**Accepted risks (documented, not actioned — carry forward, do not re-raise unless operator revisits):**
- `proxcenter@pve`'s cluster-root scope, broader than the tightly-scoped `polaris-cyberrange-collector@pve` pattern used elsewhere.
- `storage-admin` shared CIFS credential — broad blast radius across most NAS-backed storages.
- Proxmox's cluster-wide passwordless root SSH trust between cyberrange and `homelab` — researched and accepted; Proxmox's own developer guidance says this isn't safely restrictable without risking cluster breakage, and the real exposure requires hypervisor-level compromise (guests have no path to it).
- `root@pam` "ansible" full-root API token on homelab's CT402 — external, homelab-side, tracked only; watch for the homelab team's own resolution.

**Open, non-blocking future items:**
- Cyberrange host firewall/SSH hardening: `pve-firewall` currently disabled at the Datacenter level (8006/22/API reachable from the entire trusted `/24`, not scoped to Admin01/Kali01); `PasswordAuthentication` left at the OpenSSH compiled default rather than explicitly hardened; `rpcbind` listening on all interfaces (vestigial — no NFS in use). Identified as a lower-risk alternative to the SSH-trust hardening that was declined; not yet actioned.
- Tailscale internet egress (exit-node / `autogroup:internet` routing) for `tag:cyberrange` not yet restricted — separate from the peer-isolation work just closed; real, acknowledged future improvement.
- VM310 Proxmox display name (`Blackarchlinux01`) vs. guest-observed identity (`lab-admin-blackarch`) — reconciliation item, carried to Gate 8G2.

**Unchanged holds:**
- Home-edge cutover (Gateway01, PiHole01, NanoStation, household cabling) remains on HOLD — do not combine with cyberrange work.
- Documentation format: RUN-003 maintained as markdown going forward per operator preference; v1.0/v1.1 `.docx` retained as historical snapshots only.

---

## Before I can build these four documents out

I don't currently have RUN-002, REG-001, RM-001, or MB-001 in this project — only the two RUN-003 files are attached. Editing them in place means working from their actual current content (structure, sections, existing items I haven't touched above), not guessing at it. Two ways to proceed:

1. **You share their current versions** (upload, or paste content) — I produce precise, additive updates against what's actually there, the same way every edit in this project has been done.
2. **They don't exist as separately maintained documents yet**, or you're fine with me drafting fresh, standalone v-next versions of each, using this summary and RUN-003 as the sole source of truth — meaning anything in their *prior* versions that this summary doesn't cover would not carry forward unless you tell me it should.

Which is it?