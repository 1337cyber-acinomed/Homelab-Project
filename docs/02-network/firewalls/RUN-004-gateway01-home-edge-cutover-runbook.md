# Project Polaris — Gateway01 Home-Edge Cutover Runbook (v2)

Status: **Cutover complete. All phases executed and validated.**
Prepared: 2026-09-04 (updated after Phases 1–4 execution) — closed out 2026-09-06.
Scope: Move home-edge routing/DHCP/DNS from Deco-router-mode to Gateway01 (pfSense) + Pihole, with Firewall01 properly isolated from the home network, and Decos converted to AP mode.

---

## 1. What changed since v1 of this runbook

Direct evidence from Proxmox + pfSense consoles revealed:

1. **Firewall01's real protected LAN (`192.168.10.1/24`) and Gateway01's home LAN currently share the same virtual bridge (vmbr2).** This means, as wired today, Firewall01 provides no actual Layer-2 isolation between "home" and "homelab" — both sides sit on one wire regardless of pfSense's own routing rules. This must be fixed as part of the cutover, not after it.
2. Pihole is an LXC container, currently on vmbr2 at `192.168.1.2/24` (pre-staging address), with no DHCP or DNS clients pointed at it yet.
3. Firewall01's WAN interface currently gets a DHCP lease directly from the raw uplink (vmbr0) — the same bridge Gateway01's WAN uses. This was fine for pre-staging (both boxes get real internet independently) but is wrong for production: Firewall01's WAN needs to sit *behind* Gateway01.
4. Home network subnet is confirmed as **`192.168.30.0/24`** (Decision A — final, matches the original IP Address Plan).
5. vmbr1 is confirmed as the CYBERMGMT emergency-access bridge (`192.168.20.0/24`) linking homelab to cyberrange if OPNsense fails — unrelated to this cutover. Gateway01 has an unused, unconfigured NIC on vmbr1 (net2) that appears to be a leftover from cloning the PFSENSE-GOLD template; it can be left alone or removed, it's not part of the production design.
6. Decision B: rather than a physical cable between Gateway01 and Firewall01, build a **new dedicated internal bridge (vmbr3)** for this — less wiring, same result, since both VMs live on the same Proxmox host.
7. Decision C confirmed the intended flow: **Router → Gateway01 → Pihole → Decos (home wifi) → Firewall01 → homelab**, with the documented emergency bypass (cable ISP router straight to the kitchen Deco, revert it to router mode) remaining the fallback if Gateway01 itself ever fails.
8. **Physical port correction:** the 4-port NIC's `nic2` port turned out to be dead/bad (`NO-CARRIER` on both ends regardless of cable). The working test link was actually on `nic1`. **vmbr3 is bound to `nic1`, not `nic2`, going forward.**
9. **Unrelated but necessary fix found along the way:** the homelab Proxmox host's own management address on vmbr0 (`192.168.68.70/24`) didn't match the live `192.168.0.0/24` network actually present on that wire, which was silently breaking the host's own outbound connectivity (Tailscale coordination-server checks specifically, since VMs on the same bridge did their own independent DHCP and were unaffected). Corrected to a static `192.168.0.90/24` with gateway `192.168.0.1`. Confirmed fixed.
10. **Critical lesson from the GS324TP switch build (cost significant debugging time — read this before touching its VLAN config again):** on this switch, **VLAN Membership and Port PVID Configuration are two fully independent settings that do not sync with each other.** VLAN Membership controls which VLAN a port's *outgoing* untagged traffic belongs to. PVID controls which VLAN *incoming* untagged traffic on that port gets classified into. Setting one does **not** set the other. A port can show correct, clean membership on the VLAN Membership page while silently discarding everything that arrives on it, because nothing tells the switch what VLAN to file incoming frames under. This produced the exact same symptom twice — once on the infra VLAN, once on the home VLAN: ARP requests visibly leaving both ends (confirmed via `tcpdump` on both homelab and cyberrange), zero replies, while every other switch feature (STP, loop protection, storm control, DHCP snooping, 802.1X) checked out clean. **Whenever configuring a VLAN on this switch, always explicitly set BOTH: (1) VLAN Membership → untagged for the port, AND (2) Port PVID Configuration → PVID matching that same VLAN ID.** Confirm via the PVID Configuration table that Untagged VLANs matches PVID and Tagged VLANs is None, for every port in use, before trusting any VLAN on this switch.

---

## 2. Finalized IP / bridge plan

| Bridge | Role | Members | Subnet |
|---|---|---|---|
| vmbr0 | Raw WAN uplink (from Ubiquiti bridge) | Gateway01 WAN only (Firewall01 moves off) | `192.168.0.0/24` (ISP-assigned, DHCP) |
| vmbr1 | CYBERMGMT emergency link | Firewall01 OPT1 | `192.168.20.0/24` (unchanged) |
| vmbr2 | **Firewall01's real protected LAN — must become exclusive** | Firewall01 LAN only (Gateway01 + Pihole move off) | `192.168.10.0/24` (unchanged) |
| **vmbr3 (new)** | Home network — Gateway01's LAN side | Gateway01 LAN, Pihole, Firewall01 WAN | **`192.168.30.0/24`** |

| Host | Interface | Old | New |
|---|---|---|---|
| Gateway01 | LAN (net1) | vmbr2, `192.168.1.1/24` | **vmbr3, `192.168.30.1/24`** |
| Gateway01 | net2 (unused) | vmbr1, unassigned | Leave unused or remove |
| Pihole | eth0 | vmbr2, `192.168.1.2/24`, gw `192.168.1.1` | **vmbr3, `192.168.30.2/24`, gw `192.168.30.1`** |
| Firewall01 | WAN (net0) | vmbr0, DHCP (`192.168.0.23/24`) | **vmbr3, DHCP or static reservation in `192.168.30.0/24`** |
| Firewall01 | LAN (net1) | vmbr2, `192.168.10.1/24` | Unchanged |
| Firewall01 | CYBERMGMT (net2) | vmbr1, `192.168.20.1/24` | Unchanged |

Reserved ranges on the new home network (from the original IP Address Plan):
- `192.168.30.100–199` — DHCP home clients
- `192.168.30.200–254` — future static home infrastructure
- `192.168.30.1` Gateway01, `192.168.30.2` Pihole — already spoken for

**Recommendation for Firewall01's new WAN address:** use a DHCP static mapping/reservation in Gateway01 (bind Firewall01's WAN MAC to a fixed address, e.g. `192.168.30.5`) rather than a floating dynamic lease. Keeps future firewall rules and troubleshooting predictable without hardcoding a static IP inside Firewall01 itself.

---

## 3. Confirmed physical layout

- **Modem room:** Modem/router. The **kitchen Deco** has only one wire — to the modem. This room and the office cannot be physically connected by cable, hence the Ubiquiti NanoStation bridge.
- **Office room:** One **TP-Link TL-SG608E** (8-port) switch connects the **office Deco**, all three Proxmox hosts (homelab, cyberrange, AI), and NAS01. This switch is being upgraded to a **Netgear GS324TP-S350** (24-port PoE+ smart switch) — timing is flexible.

**Implication for the cutover:** the kitchen Deco can never be wired directly into Gateway01's LAN — it only ever has the modem wire. So the **office Deco becomes the new mesh "main" unit**, wired into the new vmbr3 segment and switched to AP mode. The **kitchen Deco becomes a pure wireless mesh satellite**, syncing to the office Deco over the air — no cable is ever touched on it during normal cutover. Its modem wire stays put, unused, as the standing emergency bypass.

This also explains the original failure: the kitchen Deco was switched to AP mode as if it still had an uplink to rely on, but at that point nothing on the office side was actually wired through a working Gateway01 LAN yet — there was no valid mesh "main" anywhere for it, or anything else, to sync to.

### Switch swap — recommended to do first, independently

Since the TL-SG608E is already carrying 5 of its 8 ports (office Deco + 3 hosts + NAS) with no room to spare, and timing doesn't matter to you, do the swap to the GS324TP **before** Phase 5, as its own isolated step:

- It only affects office-room connectivity (hosts ↔ NAS ↔ office Deco) — the kitchen Deco and house wifi are untouched during the swap.
- It gives you enough ports to dedicate one per logical network instead of guessing what's sharing a wire — the same problem that caused the vmbr2 issue, just at the physical layer instead of the virtual one.
- **Caution:** NAS01 is your Proxmox cluster's quorum device. The swap will briefly drop all three hosts and the NAS off each other simultaneously — that's a clean, temporary outage (not a split-brain), but schedule it outside any active backup window and expect cluster status to look degraded for a minute or two after reconnecting until quorum re-establishes.

**Suggested port allocation on the new switch** (adjust to how many spare physical ports each host actually has):
| Port group | Carries | Connects to |
|---|---|---|
| 1 | WAN passthrough (if the NanoStation AP lands on this switch rather than direct into the homelab host) | homelab host's vmbr0 NIC |
| 2 | Home LAN (vmbr3) | homelab host's new vmbr3 NIC ↔ **office Deco** |
| 3 | Infra/cluster/backup (vmbr2-equivalent, cyberrange + AI host uplinks, NAS01) | all three hosts + NAS |
| 4 | CYBERMGMT (vmbr1), if it needs to physically reach the cyberrange node via this switch | homelab + cyberrange hosts |

If the switch supports VLANs and you want defense-in-depth on top of dedicated ports, tag these the same way — but with a 24-port switch, dedicated untagged ports per group is simple enough on its own.

---

## 4. Phase 1 — Build vmbr3 (no risk, no production impact)

On the Proxmox host `homelab`, **Datacenter → homelab → System → Network**:

1. Create a new Linux Bridge.
2. Name: `vmbr3`.
3. Bridge ports: **leave empty** for now (internal-only, matches your Part 4 plan of building it non-disruptively before attaching any physical NIC).
4. No IPv4/IPv6 address needed on the bridge itself.
5. Apply configuration (this is a host networking change — it will prompt to apply live or requires no reboot for a new unused bridge).

Verify:
```
ip link show vmbr3
brctl show vmbr3        # or: bridge link show
```

---

## 5. Phase 2 — Move Pihole onto vmbr3 (LXC, low risk, currently unused)

Since Pihole has zero active clients right now, this is safe to do immediately.

**Proxmox → 108 (pihole01) → Network → eth0 → Edit:**
- Bridge: `vmbr2` → `vmbr3`
- IPv4: `192.168.1.2/24` → `192.168.30.2/24`
- Gateway: `192.168.1.1` → `192.168.30.1`

Restart the container, then verify from its console:
```
ip a
ip route
```
Confirm the new address and default route via `192.168.30.1` (this won't have a live path yet until Phase 3 is done — that's expected).

While here, configure Pihole properly since it was never fully set up:
- **Settings → DNS**: set upstream resolvers (e.g. `1.1.1.1` / `1.0.0.1`, or point at Gateway01's own resolver if you want pfSense doing recursive DNS first).
- Confirm **Settings → DHCP** stays **disabled** on Pihole itself — DHCP will be handled by Gateway01, not Pihole. Pihole is DNS-only, downstream.

---

## 6. Phase 3 — Reconfigure Gateway01's LAN

**Proxmox → 107 (gateway01) → Hardware → net1 → Edit:**
- Bridge: `vmbr2` → `vmbr3`

Then in the pfSense console/GUI:
- **Interfaces → LAN**: change IPv4 address from `192.168.1.1/24` to `192.168.30.1/24`.
- **Services → DHCP Server → LAN**: enable if not already, set range within `192.168.30.100–199`, set DNS servers to `192.168.30.2` (Pihole).

Verify from Gateway01 shell:
```
ifconfig vtnet1
netstat -rn
```

At this point, from Pihole's console, confirm it can now reach Gateway01:
```
ping 192.168.30.1
dig @192.168.30.2 google.com    # once upstream DNS is set
```

---

## 7. Phase 4 — Move Firewall01's WAN onto vmbr3

This is the step that actually puts Firewall01 behind Gateway01 instead of on the raw uplink, and — combined with Phase 2/3 — finally separates the home network from the protected `192.168.10.0/24` side.

**Proxmox → 101 (Firewall01) → Hardware → net0 → Edit:**
- Bridge: `vmbr0` → `vmbr3`

In pfSense (Firewall01) console/GUI:
- **Interfaces → WAN**: should now pick up DHCP from Gateway01 in the `192.168.30.0/24` range (or the static reservation, if you set one up in Phase 3's DHCP server).

Verify:
```
ifconfig vtnet0
netstat -rn | grep default   # should show gateway 192.168.30.1
```

**Checkpoint — this is the most important one in the whole runbook:**
From a homelab VM (e.g. DC01), confirm:
```
ping 8.8.8.8
dig google.com
tailscale status
```
All three should work. This confirms double-NAT through Gateway01 works, and is a good moment to check whether the Tailscale anomaly from before is now resolved — it very well might have been caused by Firewall01's WAN sitting on the wrong/shared bridge the whole time.

**Nothing physical has moved yet.** The house is still running on the kitchen Deco in router mode, untouched. Everything above can be fully validated and left running in this state for as long as you want before touching a single cable.

---

## 8. Phase 5 — Switch migration (TL-SG608E → GS324TP)

Goal: move all office-room devices (office Deco, homelab/cyberrange/AI Proxmox hosts, NAS01) onto the new switch with **zero connectivity loss** at any point, and end with every connection clearly labeled against the vmbr scheme — so there's never ambiguity again about what's plugged into what.

### 8.1 Prep — configure VLANs and label before you touch anything

**Before any cable moves**, configure two VLANs on the GS324TP (confirmed via Proxmox network config: cyberrange and AI both sit on `192.168.10.0/24`, the same network as homelab's `nic3`/vmbr2 — this is also the network Proxmox's own 3-node cluster/quorum traffic needs between all nodes, not just VM traffic, so it can't share a flat VLAN with the home network without undoing the isolation this whole project is built around):

| VLAN | Carries | Ports |
|---|---|---|
| **Home** (`192.168.30.0/24`) | Gateway01 LAN, house wifi | Port 1 — homelab `nic1`/vmbr3 · Port 2 — office Deco |
| **Infra** (`192.168.10.0/24`) | Cluster/quorum + protected homelab network | Port 3 — homelab `nic3`/vmbr2 · Port 4 — cyberrange · Port 5 — AI · Port 6 — NAS01 |
| *(flexible)* | Testing | Port 7 — Kali laptop, assign to whichever VLAN is under test |

Label each physical port accordingly before connecting anything.

**Confirm via the PVID Configuration table** that every port in use shows Untagged VLANs matching its PVID and Tagged VLANs = None. Setting VLAN Membership alone is not sufficient — see item 10 in §1. This is the single check that would have caught both VLAN outages that happened building this switch, and takes thirty seconds to verify.

Before moving anything, confirm the **current** NIC↔vmbr mapping on each host so you know exactly which cable is which when you start unplugging:
```
ip link show          # run on each of homelab, cyberrange, and AI hosts
```
Confirmed so far: homelab `nic1`→vmbr3, `nic3`→vmbr2 (`192.168.10.2/24`, currently miswired to the Deco's LAN port — a leftover from before this project's earlier fixes, and needs to move to Port 3 above, not stay disconnected), `nic4`→vmbr0 (direct to the Ubiquiti bridge, never touches either switch). Cyberrange: `nic1`→vmbr0 (`192.168.10.119/24`). AI: `nic0`→vmbr0 (`192.168.10.124/24`).

**Before disconnecting `nic3` from the Deco, check current cluster health as a baseline:**
```
pvecm status
```
If quorum already looks degraded or homelab is missing from it, that confirms this path has effectively been dead — this fix can only help. If it looks healthy, something else is currently carrying that traffic and it's worth understanding what before proceeding.

### 8.2 Bridge the two switches temporarily

Connect one Ethernet cable between any free port on the TL-SG608E and any free port on the GS324TP. This merges both into one logical network for the duration of the migration — nothing currently plugged into the old switch loses connectivity to anything else, including things you've already moved to the new switch.

### 8.3 Migrate one device at a time

For each device (suggested order: NAS01 first, since it's least disruptive to confirm alone; then the three Proxmox hosts — homelab's `nic3` along with cyberrange and AI — one at a time; office Deco last, since it's not doing anything production-relevant yet):

1. Move its cable from the old switch (or, for homelab `nic3`, from the Deco) to its labeled port and VLAN on the new switch.
2. Verify immediately before moving to the next device:
   - **NAS01:** confirm it's reachable from a Proxmox host (`ping <nas-ip>`), and check Proxmox's cluster/quorum status.
   - **Each Proxmox host:** `ip link show <nicX>` shows `LOWER_UP` on the new port; `pvecm status` still shows the cluster quorate; `ping` to the other two hosts and NAS still works.
   - **Office Deco:** no functional check needed yet (not providing anything production-relevant until Phase 6) — just confirm it powers up and shows a link light on its new home-VLAN port.

If anything fails a check, you can immediately move that one cable back to the old switch without affecting anything else, since the temporary uplink means both switches are still one network throughout.

### 8.4 Retire the old switch

Once every device is confirmed working from the new switch, remove the temporary uplink cable between the two switches (§8.2) and disconnect the TL-SG608E entirely.

### 8.5 Full infra validation before proceeding to the Deco leg

- [ ] `pvecm status` on any node shows all cluster members and NAS01 quorum healthy
- [ ] All three Proxmox hosts can reach each other and NAS01
- [ ] Gateway01 and Firewall01 checks from Phase 4 still pass (WAN, LAN, `tailscale status`) — confirms the switch swap didn't disturb anything already working
- [ ] Office Deco has power and link, not yet reconfigured

Only once this passes, proceed to §9 (formerly Phase 5, now Phase 6) — connect `nic1` to its labeled Port 2 and continue exactly as written there.

---

## 9. Phase 6 — Physical cutover (Deco leg)

### 8.0 Pre-flight checklist (confirm all of these before touching any cable)

- [ ] **Gateway01 DHCP server on LAN is re-enabled** (it was intentionally disabled mid-Phase 3 to allow the IP change, per your own note — confirm it's back on) with range `192.168.30.100–199` and DNS server set to `192.168.30.2`.
- [ ] **Test from an actual downstream homelab VM** (e.g. DC01), not just from Firewall01 itself: `ping 8.8.8.8`, `dig google.com`, confirm AD/logon still works. Everything validated so far was from Firewall01's own shell or the Proxmox host — this confirms the whole chain works end-to-end for a real protected-side client.
- [ ] **Know which switch nic1 is about to land on.** If the TL-SG608E hasn't been swapped for the GS324TP yet, plugging nic1 (home network, `192.168.30.0/24`) into that same flat switch puts it on the same physical wire as the infra/cluster/NAS traffic — the exact sharing problem Phases 1–4 just fixed *virtually* inside Proxmox. The virtual isolation (which vmbr a VM's traffic actually belongs to) still holds regardless, so this isn't a blocker, but if the switch swap is easy to do first, it closes the loop properly at the physical layer too.
- [ ] Back up Firewall01 and Gateway01 configs, Proxmox-backup both VMs, export the Deco mesh config from the app.
- [ ] **Pick a low-usage time.** The mode-switch step below affects the whole house at once — see 8.2.

### 8.1 Wire it up and prove it before touching Deco mode

1. Disconnect the test laptop from `nic1`; connect `nic1` to the switch instead.
2. **Checkpoint — re-plug the same test laptop into a switch port** (not directly into `nic1` this time) and confirm it still gets a `192.168.30.x` lease, resolves via Pihole, and reaches the internet. This proves the switch itself is passing this segment correctly before trusting a Deco to it — the switch is a new variable that direct-to-`nic1` testing never exercised.

### 8.2 The mode switch — expect a whole-house blip, by design

**Important correction to plan around:** TP-Link Deco mesh systems operate in one mode for the *entire* mesh — you cannot have the office unit in AP mode while the kitchen unit stays in router mode. The moment you initiate the switch, all units (kitchen included) drop and renegotiate together. This matches your own impact assessment — it's expected, not a sign of failure, and it's why 8.0/8.1 exist: to make sure the *reconnection* has something valid to land on the instant it happens, rather than repeating the first attempt's problem.

3. In the Deco app, designate the **office Deco** as the new main unit (TP-Link's app has a "change main router" or equivalent flow — the app will guide you to plug that unit's Ethernet port into your new router before confirming). Connect its Ethernet port to the switch port validated in 8.1.
4. Initiate the Router → Access Point mode conversion. **All units will drop simultaneously** — this is the one moment of real house-wide impact in this entire cutover, and it should be brief if 8.0/8.1 checked out.
5. Watch the app's network map as units reconnect. Power-cycle any satellite — including the kitchen unit — that doesn't automatically rejoin within a few minutes.
6. Full validation pass (§10 below).

---

## 10. Post-cutover validation

- [ ] Gateway01 WAN still shows a valid IP
- [ ] Every Deco unit online, house wifi working from multiple rooms
- [ ] Firewall01 WAN shows a `192.168.30.x` address with default route to `192.168.30.1`
- [ ] Firewall01's LAN side (`192.168.10.0/24`) unaffected — DC01, AD logon, Docker01 all working
- [ ] `tailscale status` on a homelab VM shows a working connection
- [ ] Pihole query log shows LAN clients actually querying it (confirms DHCP handoff, not silently bypassing it)
- [ ] From a home-network client, confirm you **cannot** reach `192.168.10.0/24` directly — this is the actual proof that Firewall01 is isolating again

---

## 11. Rollback

- **Software-level (Phases 1–4):** every change above is reversible independently — just flip the bridge dropdown back and revert the IP in pfSense/Pihole. Nothing here touches the running kitchen Deco path at all.
- **Switch migration (Phase 5):** move any single device's cable back to the old switch at any point — the temporary uplink keeps both switches as one network until you deliberately retire the old one.
- **Physical-level (Phase 6):** documented emergency bypass — reconnect the ISP router directly to the kitchen Deco, switch it back to router mode.

---

## 12. Closed out — final state and housekeeping

Final production topology, for reference: ISP router → Ubiquiti bridge → Gateway01 (WAN: vmbr0/`192.168.0.20`, LAN: vmbr3/`192.168.30.1`) → Pihole (`192.168.30.2`) + office Deco (AP mode, house wifi) → Firewall01 (WAN: `192.168.30.x`, LAN: vmbr2/`192.168.10.1`) → homelab infrastructure. Cyberrange and AI Proxmox hosts share the `192.168.10.0/24` cluster/infra network via the GS324TP's VLAN 10; home network rides VLAN 30 on the same switch.

A few worthwhile follow-ups, none urgent:

- **Update ARC-001 to a new version.** The current authoritative doc (v3.2) still records the home-edge cutover as on hold pending certification — that's no longer true, and this runbook plus the finalized topology above is the source of truth for what to write into a v3.3/v4.0. Worth doing while the details are fresh rather than letting the docs drift out of sync with reality again, as happened with the v2.0/v3.2 divergence at the start of this project.
- **Retire the TL-SG608E** physically if it's not needed elsewhere — everything it carried now lives on the GS324TP.
- **Set Management VLAN ID on the GS324TP to 10** if that wasn't carried through from the rebuild, so the switch's own reachability doesn't depend on VLAN 1 ever again.
- **Export/back up the GS324TP's running config, and Gateway01/Firewall01's pfSense configs**, now that they're in a known-good final state — a clean baseline to restore to is worth more after the fact than before it.
