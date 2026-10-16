# RUN-003 Update Summary — VM371 (cyber-corpsrv01) Closure

**Prepared:** 7 October 2026
**Target revision:** RUN-003 v1.61
**Basis:** Agreed VM371 build + pivot-validation plan (prior session) and operator confirmation of successful completion. Per operator, detailed console evidence (domain-join output, `ipconfig /all`, `whoami /priv`) could not be captured/uploaded due to security restrictions on the range; this closure is therefore logged as **operator-confirmed** rather than screenshot-backed, which is a deliberate, noted exception to the project's standard evidence discipline.

This file holds the exact blocks to splice into the master runbook. Four edits: new §11.3.1h, the §1 primary-next-action pointer, the §4 inventory row, and the revision-history entry. Nothing else in RUN-003 changes.

---

## EDIT 1 — New subsection: insert §11.3.1h (after §11.3.1g, before §11.4)

### 11.3.1h Gate 8G3 item 3 (hybrid zone) — VM371 (cyber-corpsrv01) build, scenario-account wiring, and pivot validation — CLOSED 7 Oct 2026

**Operator-confirmed closure. No console evidence captured (range security restriction — see this revision's note). Logged from the agreed build plan plus operator confirmation of success.**

With VM371 built and the full relayed privilege check passing, the Windows/Linux combination zone (Gate 8G3 roadmap item 3, §11.3.1b) is now **fully closed** — both VM370 (§11.3.1f/§11.3.1g) and VM371 are complete, and the capstone scenario path is end-to-end live.

**Base build (single-homed, by design):**

- Created VM371 mirroring DC01's spec: 1 socket / 4 cores / 8192 MiB / 80 GiB, UEFI (OVMF) + q35 + vTPM 2.0, VirtIO SCSI, QEMU agent, ISOs pulled from `NAS-ISO-Repo-CyberRange`. **Single NIC only**, `virtio,bridge=vmbr1,tag=71,firewall=1` — one leg on VLAN 71 (CYBER_HYBRID_INTERNAL) and nowhere else, unlike dual-homed VM370. NIC placement on tag 71 only confirmed via `qm config 371 | grep net` before install.
- Installed **Windows Server 2022 Standard (Desktop Experience)**, VirtIO storage driver loaded from `virtio-win.iso` at the disk-selection screen (same pattern as DC01/VM321/VM322). Hostname `cyber-corpsrv01`. The `cyber-corpsrv01` hostname reflects a member **server**, not a workstation like VM321/VM322.
- **Static networking, deliberately not pointed at the gateway for DNS:** IP `10.10.71.11/24` (`.10` on VLAN 71 is already VM370's second NIC), gateway `10.10.71.1`, **DNS `10.10.20.10` (DC01, not OPNsense)** — the same per-host-DNS pattern decided for VM321/VM322 in v1.35 to avoid the DNS/registry-change approval trigger. It resolves because the §11.3.1e `CYBER_HYBRID_INTERNAL → CYBER_WINDOWS` AD-ports pass already carries TCP/UDP 53.
- **Domain-joined** to `corp.cyberrange.local` (same process as VM321/VM322), rebooted, `whoami /fqdn` confirmed per operator.
- **`hardened-baseline` snapshot** taken before any scenario/hardening config — same clean → harden → snapshot discipline as every other host.

**Scenario-content wiring (the steps sequenced after the base build, per the prior-session plan):**

- `svc_legacysync` created as a real AD account on DC01 (`corp.cyberrange.local`), with the same credential seeded into VM370's SQLi app in §11.3.1g — `svc_legacysync` / `Changeme123`, NTLM `8091fee1f3890584904bd7d5cea1240e`. The hash cracked out of the web layer now authenticates for real against this forest, closing the loop the §11.3.1g seed opened.
- WinRM access granted to `svc_legacysync` on VM371.
- **`SeImpersonatePrivilege` granted directly** to the account (operator's chosen mechanism — not wired through a real service), enabling the Potato-family escalation stage once the account is reached and logged in via evil-winrm.

**Pivot validation — full relayed path, not local-only:**

- VM370's temporary chisel-test UFW rule was replaced with the permanent, zone-scoped rule: `ufw allow from 10.10.10.0/24 to any port 8080 proto tcp` (comment `legacy monitoring agent`) — open only to sources in CYBER_ATTACK (10.10.10.0/24), filtered/closed to every other zone under UFW default-deny. This is a **source-scoped** asymmetry, not an inbound/outbound one: "discoverable only from the zone you're meant to pivot from," with no OPNsense change and no break to the one-way isolation posture.
- VM370 ran `chisel server --port 8080` (the compromised-foothold host is the server, matching "attacker drops a tool and pivots from the box they already own").
- kali-attack ran `chisel client 10.10.70.10:8080 5985:10.10.71.11:5985`, then `evil-winrm -i 127.0.0.1 -u svc_legacysync -p Changeme123`.
- Inside the relayed session, `whoami /priv` showed **`SeImpersonatePrivilege` Enabled** over the full path (kali-attack → chisel tunnel → VM370 → VM371 WinRM), confirming both the tunnel and the privilege grant end-to-end.

**Design decision folded in (deferred, not built here):** a dedicated C2/beaconing host for learning frameworks such as Sliver is confirmed as its own future box in its own zone (TBD), rather than bolted onto this web-app-compromise scenario. VM370 staying a chisel *server* (not an outbound-dialing client) kept the existing one-way CYBER_ATTACK → CYBER_HYBRID design intact; a true reverse/beaconing topology would need a deliberate new `CYBER_HYBRID → CYBER_ATTACK` rule and is explicitly out of scope until the Sliver box is designed.

**What this does and does not assert:** the closure covers the *build* and the *reachability + privilege* validation. The remaining stages of the capstone exercise — Potato-family local escalation to SYSTEM, BloodHound path discovery, and the walk to Domain Admin on the existing forest — are now **available for the operator to run as the capstone red-team exercise**; they are practice activity, not build-validation steps, and are not claimed as completed here.

---

## EDIT 2 — §1, "Primary next action" cell — replace the trailing status

**Change the final sentence of the cell** from:

> ... Active step now: VM371 (cyber-corpsrv01).**

**to:**

> **VM371 (cyber-corpsrv01) is CLOSED (7 Oct 2026, operator-confirmed — see §11.3.1h): single-homed on VLAN 71, domain-joined to `corp.cyberrange.local`, `svc_legacysync` created with WinRM + `SeImpersonatePrivilege`, and the full kali-attack → chisel → VM370 → VM371 pivot validated (`SeImpersonatePrivilege` Enabled over the relayed path). The Windows/Linux combination zone (Gate 8G3 item 3) is therefore fully closed. Active step now: Analysis zone content build-out on VM360 (Gate 8G3 item 4, §11.3.1b) — MITRE ATT&CK Navigator only; the Infection Monkey / Caldera / Atomic Red Team trio remains in the SIEM build (VM350) per the 26 Sep decision, confirmed 7 Oct 2026.**

---

## EDIT 3 — §4 asset/VM inventory — add a VM371 row

Add beneath the VM370 row:

> | 371 | cyber-corpsrv01 Windows Server 2022 Std (Desktop Exp.) | 4 cores; 8192 MiB; 80 GiB | One VirtIO NIC vmbr1 tag 71; 10.10.71.11; domain-joined corp.cyberrange.local; running; `hardened-baseline` snapshot taken | Reachable only via VM370 chisel tunnel; `svc_legacysync` has WinRM + SeImpersonatePrivilege |

(If the VM370 row still reads "not yet built" anywhere in §4, correct it to built/running per §11.3.1f/g at the same time.)

---

## EDIT 4 — Revision history — add at top

> | 1.61 | 7 October 2026 | **VM371 (cyber-corpsrv01) build, scenario-account wiring, and pivot validation CLOSED (new §11.3.1h) — operator-confirmed, no console evidence captured (range security restriction).** Windows Server 2022 Std, single-homed on VLAN 71 (`10.10.71.11`, per-host DNS to DC01), domain-joined to `corp.cyberrange.local`, `hardened-baseline` snapshot. `svc_legacysync`/`Changeme123` created as a real AD account on DC01 with WinRM + `SeImpersonatePrivilege` granted directly, closing the loop on the §11.3.1g seeded hash. Pivot validated end-to-end: VM370's permanent zone-scoped UFW rule (`10.10.10.0/24` → 8080), VM370 as chisel server, kali-attack tunneling 5985 to VM371, `evil-winrm` as `svc_legacysync`, `whoami /priv` showing `SeImpersonatePrivilege` Enabled over the full relayed path. Windows/Linux combination zone (Gate 8G3 item 3) now fully closed. Dedicated Sliver C2 box confirmed as a separate future zone, not folded into this scenario. Next: Analysis zone content on VM360 (Gate 8G3 item 4) — ATT&CK Navigator only; BAS trio stays in SIEM/VM350. Updated §1, §4, §11.3.1b, §11.3.1h (new), revision history. |
