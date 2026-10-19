# GATE 10 — OSCP PRACTICE LAB (VLAN 80)

**Project Polaris | Build-gate and operations doc for the OSCP-exam-style practice lab**
**Version 1.0 | 19 October 2026 | Status: ✅ GATE 10 COMPLETE — 6-box exam core built & sealed (100 pts). A6-81 + A7 closed. Technique annex (Phase E) is the only remaining optional scope.**

> Companion to `RUN-003`. RUN-003 remains the master runbook; this doc owns the VLAN 80 lab's design, roster, flag model, build-access SOP, and phased build. Nothing in here is built until the operator approves each bounded phase. No IP/VLAN/VMID/firewall change is made ahead of approval.

---

## 1. Gate definition and scope

Build a self-contained, flag-based **OSCP-exam-style practice lab** on a brand-new, isolated **VLAN 80**, with a pivot-only internal sub-segment on **VLAN 81**. The lab mimics a real OSCP exam network as closely as publicly known: a points-weighted mix of an Active Directory set and standalone machines, each yielding `local.txt` + `proof.txt` flags, solved with the full PEN-200 technique range.

**In scope (this gate):**
- New VLAN 80 (`CYBER_OSCP`) + VLAN 81 (`CYBER_OSCP_INT`, pivot-only) infrastructure.
- A **6-box exam core** (~100 pts) — Phases B–D.
- A **technique annex** of extra single-skill boxes — **Phase E, explicitly a separate later step** (operator wants these for certain, built after the core is usable).
- A flag + scoring model and a manual scorecard.
- A temporary build-access SOP (kali01 → boxes) and its mandatory revert-before-snapshot discipline.

**Explicitly OUT of scope / deliberate exclusions:**
- **No SIEM monitoring.** No Wazuh agents, no `auditd`/Sysmon telemetry baked in, no `CYBER_OSCP → SIEM` rule. This is the one zone built as pure offense practice — nothing is watching, by operator decision.
- **No 96-hour auto-revert.** These boxes are manually reset only (see §9), so a half-finished exam box is never wiped out from under the operator.
- No standing path to/from kali01 in the finished lab (build access is temporary only — §6).

---

## 2. Security model and deviations

The lab reuses the project's standard zone pattern, with three intentional deviations recorded up front:

1. **No monitoring (deviation from the 8H pattern).** Every other target zone carries a Wazuh agent + `monitored-baseline`. VLAN 80/81 deliberately do not. This keeps OSCP practice "quiet" — the point is offense, not detection.
2. **Pivot-only internal segment (reuses the VLAN 71 precedent).** VLAN 81 gets **no `CYBER_ATTACK` pass and no `VLAN 80 → VLAN 81` pass**. The *only* route into 81 is through a compromised, dual-homed foothold host (VM381) that straddles 80 and 81 — exactly the "you must tunnel to reach the internal hosts" exam mechanic. Default inter-cyber-VLAN deny (the §7.4.1 finding) is what enforces this; we simply add no exception.
3. **Temporary build-access from kali01 (documented, time-boxed).** To script/paste accurately during the build, kali01 gets a scoped, single-box, single-port opening (SSH for Linux, RDP for Windows), removed before each box's `oscp-baseline` snapshot. This is *kali01 → box* (outbound from kali01), so the standing rule "nothing opens inbound **to** kali01" is preserved. Precedent: the VM370 build used the same temporary-then-reverted pattern.

**Standing access model of the finished lab:** the only standing cross-zone path is **`CYBER_ATTACK` (VLAN 10, kali-attack/kali02) → `CYBER_OSCP` (VLAN 80)**, full ports (an exam attacker has unrestricted L4 access to targets). VLAN 81 is reachable only by pivoting through VM381. Internet is egress-only and fail-closed, same as every zone.

---

## 3. Addressing and naming plan

| Item | Value |
|---|---|
| External segment | **VLAN 80 / `CYBER_OSCP`** — `10.10.80.0/24`, gateway/DNS `10.10.80.1` (OPNsense) |
| Internal segment | **VLAN 81 / `CYBER_OSCP_INT`** — `10.10.81.0/24`, gateway `10.10.81.1` (OPNsense), **pivot-only** |
| DHCP (VLAN 80) | Dnsmasq range `10.10.80.100–199`; static reservations for the lab boxes below |
| VLAN 81 addressing | **Static** (AD segment) — no DHCP range needed |
| Local domain (non-AD) | `oscp.range.home.arpa` (Unbound Host Overrides for any static names, per project DNS convention) |
| AD domain (the set) | **`oscp.lab`** (NetBIOS `OSCP`) — a **separate forest** from production `corp.cyberrange.local`; DC is DNS for this domain, forwarding up to `10.10.81.1` for internet names |
| Proxmox VMID block | **380–389 core**, **390–399 annex** (reserved) |
| Host naming | `cyber-oscp-*` (console/Proxmox names), lab-facing hostnames per box |
| Snapshots | `oscp-baseline` per box (post-vuln, post-build-access-removal) |
| Attack host (play) | kali-attack / **VM310 (kali02)** on VLAN 10 |

---

## 4. Box roster — the 6-box exam core, mapped to OSCP coverage

Points mirror a modern OSCP exam: **AD set 40 pts + 3 standalones × 20 = 100; pass ≥ 70.**

| VMID | Host | Seg | Role / points | Primary techniques exercised |
|---|---|---|---|---|
| **381** | `oscp-ext01` | **80 + 81** (dual-homed) | AD **external foothold** + **pivot** into 81 (10 pts) | Web exploit (upload / known-CVE / injection) → initial access → domain creds harvested → chisel/ssh pivot set up into 81 |
| **382** | `oscp-ws01` | **81** | AD **internal workstation** (10 pts) | Reached only via pivot; Windows privesc + AD lateral movement (cred harvest, Kerberoast / AS-REP / PtH) |
| **383** | `oscp-dc01` | **81** | AD **Domain Controller** — final objective (20 pts) | Domain compromise: DCSync / PtH-to-DA / Kerberos; `proof.txt` as Domain Admin |
| **384** | `oscp-linux01` | **80** | Standalone **Linux**, web → root (10 user / 10 root) | Web entry (SQLi / LFI-RFI / command-injection / file-upload, incl. a vulnerable CMS) → Linux privesc (SUID / sudo / cron / capabilities / PATH / kernel) |
| **385** | `oscp-win01` | **80** | Standalone **Windows**, service → SYSTEM (10 / 10) | Service exploit or weak creds → Windows privesc (unquoted service path / AlwaysInstallElevated / token-impersonation "Potato" / DLL hijack) |
| **386** | `oscp-mix01` | **80** | Standalone **exploit-fix** + **Metasploit-permitted** box (10 / 10) | `searchsploit` → locate, **modify/compile** a public exploit → foothold → privesc. The single box where MSF use is "allowed," per exam rule |

**Coverage check — every PEN-200 class has a home:**

| Technique class | Covered by |
|---|---|
| Enumeration (nmap / service / web) | every box |
| Web: SQLi / LFI-RFI / upload / command-injection | 381, 384 |
| Web: CMS known-vuln (WordPress/Drupal/Joomla) | 384 (one CMS target) |
| Find / fix / compile a public exploit | 386 |
| Password attacks (hydra / hashcat / john, spraying) | 381→382 creds, service brute on 384/385 |
| Linux privesc (SUID/sudo/cron/caps/PATH/kernel) | 384 (+ annex sampler) |
| Windows privesc (service/unquoted/AlwaysInstallElevated/token/DLL) | 385, 382 (+ annex sampler) |
| Pivoting / tunneling (chisel / ssh / socat / proxychains) | into VLAN 81 via 381 |
| AD enumeration (BloodHound / ldap) | the AD set |
| AD attacks (Kerberoast / AS-REP / PtH / PtT / DCSync) | 382 → 383 |
| Lateral movement (evil-winrm / psexec / wmiexec) | AD set |
| Credential dumping (mimikatz / secretsdump) | 382, 383 |
| Metasploit (one box only) | 386 |
| Buffer overflow (de-emphasized on modern exam) | **annex** (Phase E), e.g. `oscp-bof01` |

**Technique annex (Phase E — reserved 390–399, scoped when reached):** `oscp-bof01` (classic Windows stack BOF), `oscp-cms01` (CMS chain), `oscp-linpriv01` / `oscp-winpriv01` (privesc samplers), and any additional single-skill drill boxes. Detailed specs are deferred to Phase E so the exam core lands first.

---

## 5. Flag and scoring model

- **Flags:** `local.txt` (low-priv user home/desktop) and `proof.txt` (root/SYSTEM) on each box — a unique **32-char random hex** string per flag.
- **Points:** AD set 40 (10 + 10 + 20), standalones 20 each (10 user / 10 root). Total 100, **pass ≥ 70** — matched to the real exam.
- **Submission:** a **manual scorecard** (markdown table in this doc) listing each box, its two flag values, and points — the operator matches the captured hash. No submission portal: the real exam is manual proof, and a portal would be standing infrastructure to maintain for little gain. (Revisit if desired later.)
- **Flag placement discipline:** flag files are placed as the *last* build step on each box, before the `oscp-baseline` snapshot, so a reset restores the intended flags intact.

A `Scorecard` section will be appended here as boxes are built (kept out of chat; it's the answer key).

---

## 6. Build-access SOP (temporary kali01 → box, removed before snapshot)

Run this **per box**, only during that box's build window. The revert steps are a gating requirement — a box is not "scenario-ready" until build access is gone and verified.

**Open (build start):**
1. **OPNsense:** add a single scoped pass rule — source **kali01's address only**, destination **this box's IP only**, port **22 (Linux)** or **3389 (Windows)** — on the relevant interface, labeled `TEMP-BUILD-<host>`. (Outbound from kali01; nothing is opened inbound to kali01.)
2. **On the box:** enable the matching service (`sshd` / RDP) and a host-firewall allow **from kali01 only**.
3. Build with copy/paste fidelity: `ssh`/`scp` (Linux) or **`xfreerdp /clipboard`** (Windows). (RustDesk direct-IP mode is an accepted alternative on Windows; if used, it's one more agent to remove at cleanup.)

**Revert (build complete — all must pass before snapshot):**
4. Remove the box's build service exposure — disable `sshd`/RDP, or the host-firewall allow — **except** where that service is an intended scenario vector.
5. Delete the `TEMP-BUILD-<host>` OPNsense rule.
6. **Verify from kali01:** the box is **no longer reachable** on the build port.
7. **Verify from the VLAN 10 attack host:** the box is reachable **only** as the scenario intends (and VLAN 81 boxes are *not* reachable except via the pivot).
8. **Then** take the `oscp-baseline` snapshot — it must capture the clean, build-access-free state.

A per-box revert checklist is logged in the Scorecard/build-log section as each box completes.

---

## 7. Phased build plan

| Phase | Scope | Gate |
|---|---|---|
| **A** | **Infra** — VLAN 80 + 81 interfaces, DHCP/DNS, firewall policy, the one `CYBER_ATTACK → CYBER_OSCP` pass, pivot-only 81, no SIEM. Validate with a throwaway guest. | **This approval** |
| **B** | **Standalones** 384 → 385 → 386, one at a time (build → vuln → flags → build-access revert → snapshot). | after A passes |
| **C** | **AD set** 381 → 382 → 383 (`oscp.lab` forest, dual-home 381, pivot path, flags). | after B |
| **D** | **Pivot validation + scorecard** — confirm 81 is reachable *only* through compromised 381; finalize the point map. | after C |
| **E** | **Technique annex** (BOF, CMS, privesc samplers, …) — separate later step. | after D |

---

## 8. Phase A — infrastructure build SOP (detailed, awaiting approval)

Mirrors the VLAN 70/71 infra build. **Each step is operator-executed; nothing here runs until approved.** cyber-fw01 = VM300.

**A1 — Proxmox trunk.** Add VLAN tags **80 and 81** to VM300's cyber-facing NIC. Quote the `qm set --netX` value (the unquoted-semicolon bash split bit us on VM332/VM370). Expect the trunk change to take effect live — no cyber-fw01 reboot needed (confirmed behavior on prior zones).

**A2 — OPNsense VLAN interfaces.** Create `vlan80` and `vlan81` on the cyber parent interface; assign as **`CYBER_OSCP`** and **`CYBER_OSCP_INT`**; set static **`10.10.80.1/24`** and **`10.10.81.1/24`**; enable both.

**A3 — DHCP (Dnsmasq).** VLAN 80 range **`10.10.80.100–199`**, per-range Domain `oscp.range.home.arpa`. Add **both** VLAN 80 and 81 to the Dnsmasq listening interfaces (an "internal" zone still needs the listener for DNS to function). VLAN 81 gets **no range** (static AD hosts).

**A4 — DNS (Unbound).** Add VLAN 80/81 to Unbound's listening/allowed set; create Host Overrides for any static VLAN 80 names (static records live in **Unbound**, not Dnsmasq, per the §11.3.1f convention). AD hosts on 81 will point at the DC (383) for `oscp.lab`, with the DC forwarding to `10.10.81.1` — wired during Phase C.

**A5 — Firewall: `CYBER_OSCP` standard active-purpose policy** (the 4-rule template): (1) block to OPNsense control plane / anti-lockout; (2) allow DNS/DHCP to `.1`; (3) block to **`PROTECTED_NETWORKS`**; (4) allow Internet egress.

**A6 — Firewall: the attack-path exception** (new §7.4.x in RUN-003 once built): on `CYBER_OSCP`, **pass source `CYBER_ATTACK` net → `CYBER_OSCP` net, full ports**, placed **above** the `PROTECTED_NETWORKS` block. This is the lab's only standing cross-zone pass.

**A7 — Firewall: `CYBER_OSCP_INT` (VLAN 81)** — standard 4-rule policy, but **add NO `CYBER_ATTACK` pass and NO `VLAN 80 → VLAN 81` pass**. Confirm default inter-VLAN deny so the only path to 81 is through VM381. (This is the deliberate break from the exception-template pattern, like VLAN 71.)

**A8 — Validation** (spin a disposable throwaway Linux guest on VLAN 80 — the same "validation probe" pattern used before VM360 — then remove it):
- §12.1 block on the guest: DHCP lease, gateway `.1`, DNS, **public HTTPS 200**, and `PASS` on Proxmox / CGNAT-Tailscale / link-local / no-IPv6.
- From the VLAN 10 attack host: **can** reach the VLAN 80 guest; **cannot** reach VLAN 81.
- Confirm (by omission) there is **no** `CYBER_OSCP → SIEM` rule.

**A9 — Record.** Export the OPNsense config XML (filename/size/SHA-256) after the ruleset is in; log the new §7.4.x exception and the Phase A closure back into RUN-003.

---

## 9. Reset and disposability model

- Each box carries an **`oscp-baseline`** snapshot taken after vulnerabilities + flags are in place and build access is removed.
- Reset is **manual** (`qm rollback <vmid> oscp-baseline && qm start <vmid>`) — deliberately **excluded from the 96h auto-revert map** so an in-progress exam box is never auto-wiped.
- All VLAN 80/81 boxes are disposable/rebuildable per the project principle; cyber-fw01 and the lab's own addressing plan are the only fixed parts.
- Powered off by default (reboot-on-demand) — consistent with "only what's needed is up at once."

---

## 10. Decisions log

| Date | Decision |
|---|---|
| 14 Oct 2026 | Placement/isolation, exam-shape composition, and coverage matrix agreed. |
| 14 Oct 2026 | **Scope:** 6-box core first; technique annex as a separate later phase (annex confirmed in-scope). |
| 14 Oct 2026 | **Pivot sub-segment:** yes (VLAN 81, pivot-only) — real-exam mechanic. |
| 14 Oct 2026 | **Reset:** manual only; `oscp-baseline` snapshots; excluded from auto-revert. |
| 14 Oct 2026 | **Difficulty:** tuned to real-exam realism as closely as publicly known. |
| 14 Oct 2026 | **Build access:** temporary kali01→box (SSH / `xfreerdp /clipboard`), removed and verified before each `oscp-baseline` snapshot. |
| 15 Oct 2026 | **Phase A complete.** VLAN 80 + 81 interfaces, DHCP/DNS, firewall policy, the two-way attack path (forward `CYBER_ATTACK→CYBER_OSCP` on the CYBER_ATTACK iface + reverse `CYBER_OSCP→CYBER_ATTACK` on the OSCP iface), and pivot-only 81 all built. VLAN 80 validated on the real box 1 (A6-80). **A6 (VLAN 81 isolation proof) + A7 (XML export + closure) deferred to the first box on 81 (VM381, Phase C).** |
| 15 Oct 2026 | **Box 1 (oscp-linux01, VM384) CLOSED** — see Build Log §11. |
| 17 Oct 2026 | **Box 2 (oscp-win01, VM385) CLOSED** — Windows SMB→WinRM foothold + unquoted-service-path privesc. See Build Log §11 (+ build gotchas). |
| 17 Oct 2026 | **Box 3 (oscp-mix01, VM386) CLOSED** — Debian 11 (EOL/archived), Drupalgeddon2 (MSF-permitted) → PwnKit (snapshot polkit). **Phase B complete: all 3 standalones = 60 pts.** See Build Log §11 (+ build gotchas). |
| 15 Oct 2026 | **Operator request:** add a legitimate, publicly-available **OSCP exam-rules write-up** to the final/closeout runbook. Tracked as a closeout deliverable. |
| 18 Oct 2026 | **A6-81 CLOSED** — with the DC live on VLAN 81, pings/ports from VLAN 10 and VLAN 80 to `10.10.81.10` all fail: pivot-only isolation proven on a real host. |
| 19 Oct 2026 | **Phase C (AD set) CLOSED** — `oscp.lab` forest; SQLi→WinRM foothold (381) → Kerberoast→lateral (382) → LSA-dump→DCSync→Domain Admin (383). 40 pts. See Build Log §11. |
| 19 Oct 2026 | **A7 CLOSED** — post-build OPNsense config XML exported (`config-OPNsense01.polaris.home.arpa-20261019*.xml`). Phase A fully recorded. |
| 19 Oct 2026 | **🏁 GATE 10 COMPLETE** — 6-box exam core built, sealed, snapshotted (100 pts, pass ≥70). Only the optional technique annex (Phase E) remains. |

---

## 11. Build log & scorecard

**Scorecard — answer key. Kept in this doc, never in chat.**

| Box | VMID | Address | Points | `local.txt` | `proof.txt` | Status |
|---|---|---|---|---|---|---|
| oscp-linux01 | 384 | 10.10.80.11 | 20 (10/10) | `23aac5315a183baff083d8c1a48e5aa9` | `8f81fbbe38d0ade4eaf953437fa6e113` | **CLOSED 15 Oct 2026** |
| oscp-win01 | 385 | 10.10.80.12 | 20 (10/10) | `a87a37839e9131850e5fc7cf27b54053` | `a1eefc5c25cc8b4100d76311f859872c` | **CLOSED 17 Oct 2026** |
| oscp-mix01 | 386 | 10.10.80.13 | 20 (10/10) | `76961c04c4cb941279f497b558ccd3c3` | `8531437153db8b82b887ecef92788301` | **CLOSED 17 Oct 2026** |
| **AD set `oscp.lab` (40 pts, chained)** | | | | | | |
| oscp-ext01 | 381 | 10.10.80.14 (+81: .11) | 10 (foothold) | `e66ab3bea8e1efb48be04629306c381f` | — | **CLOSED 19 Oct 2026** |
| oscp-ws01 | 382 | 10.10.81.12 | 10 (lateral) | — | `9cb57975fc1a75e036a7af2a26fcd69d` | **CLOSED 19 Oct 2026** |
| oscp-dc01 | 383 | 10.10.81.10 | 20 (Domain Admin) | — | `b438d1e7ce4dc6f10bfcb0c143d0b41b` | **CLOSED 19 Oct 2026** |

**Box 1 — `oscp-linux01` (VM384, 10.10.80.11)** — Debian 12; console name `cyber-oscp-linux01`, lab hostname `webdev01`.
- **Foothold (A):** Apache/PHP "Meridian NetOps" site; unlinked `tools.php` diagnostics page runs `shell_exec("ping -c 1 " . $_GET['host'])` with no sanitization → command injection → `www-data`.
- **Lateral:** `/var/www/html/includes/config.php` holds DB creds `jmorgan` / `N3tOps_adm1n2024`, reused for the local account → switch to `jmorgan` → `local.txt`.
- **Privesc (i):** `jmorgan` has `NOPASSWD: /usr/bin/find` (`/etc/sudoers.d/jmorgan`) → GTFOBins → root → `proof.txt`.
- **Final exposure:** 22 + 80 open to VLAN 10 (10.10.10.0/24) only; no kali01 path.
- **Reset:** `oscp-baseline` snapshot (2026-10-15 23:19); manual rollback only, excluded from the 96h auto-revert.
- **Build access (removed):** kali01→384:22 via the recycled LAN→CYBER_OSCP temp-ssh rule (now disabled) + a temp `builder` sudo user (deleted). Seal verified — kali01 cannot reach it; kali02 gets HTTP 200.
- **Covers:** web enum, command injection, credential reuse/hunting, lateral-to-user, sudo-GTFOBins privesc.

**Box 2 — `oscp-win01` (VM385, 10.10.80.12)** — Windows Server 2019 Std (Desktop Experience); console name `cyber-oscp-win01`, host `WIN-BGNT6RFC7PQ`.
- **Foothold (A):** guest-readable SMB share `IT` (`C:\Shares\IT\Handover.txt`) leaks low-priv creds `jbrown` / `Br0wn!Helpdesk25`; `jbrown` is in Remote Management Users → WinRM shell → `local.txt` (on jbrown's profile Desktop, `C:\Users\jbrown.WIN-BGNT6RFC7PQ\Desktop`).
- **Privesc (i):** service `MeridianBackup` runs as LocalSystem with an **unquoted `ImagePath`** (`C:\Program Files\Meridian Backup\service agent\backup.exe`); `Authenticated Users` have **Modify** on `C:\Program Files\Meridian Backup\`, and `jbrown` has start/stop rights on the service → plant `service.exe` in that segment → SYSTEM → `proof.txt` (`C:\Users\Administrator\Desktop`).
- **Final exposure:** SMB 445 + WinRM 5985 open to VLAN 10 only; RDP off; no kali01 path.
- **Reset:** `oscp-baseline` snapshot (2026-10-17 11:23); manual rollback only, excluded from the 96h auto-revert.
- **Build access (removed):** kali01→385:3389 (RDP, `xfreerdp /clipboard`) via the recycled LAN→CYBER_OSCP temp rule (now disabled); RDP turned back off. Seal verified — kali01 cannot reach it; kali02 lists the `IT` share.
- **Covers:** SMB enum, credential discovery, WinRM auth, unquoted-service-path privesc.

**Box 3 — `oscp-mix01` (VM386, 10.10.80.13)** — Debian 11 (bullseye, EOL/archived — deliberately behind on patches); console name `cyber-oscp-mix01`, lab hostname `intranet01`. The **Metasploit-permitted** box.
- **Foothold (A / public exploit, MSF-permitted):** **Drupal 7.57** at `/var/www/html` (Drupalgeddon2, CVE-2018-7600, < 7.58) → `www-data`. DB `drupal`/`drupal`/`DrupalDB2024` (MariaDB). `local.txt` in `/var/www`.
- **Privesc (i / compile-a-public-PoC):** **PwnKit** — `policykit-1` pinned to the vulnerable **`0.105-31`** (from `snapshot.debian.org`, `apt-mark hold`), SUID `pkexec`; compile the public PoC on-box (`build-essential` present) → root → `proof.txt` in `/root`.
- **Final exposure:** 80 open to VLAN 10 only; `gcc`/`build-essential` intact (needed for the on-box PoC compile); no kali01 path.
- **Reset:** `oscp-baseline` snapshot (2026-10-17 21:43); manual rollback only, excluded from the 96h auto-revert.
- **Build access (removed):** kali01→386:22 (SSH) + a temp :80 allow for the Drupal web-install, via the recycled LAN→CYBER_OSCP rule (now disabled) + a temp `builder` sudo user (deleted). Seal verified — kali01 cannot reach it; kali02 gets HTTP 200.
- **Covers:** web enum, find/use a public exploit (+MSF), compile-a-public-PoC Linux privesc.

**AD set — `oscp.lab` (VM381/382/383, 40-pt chain)** — forest `oscp.lab` / NetBIOS `OSCP`, DC `OSCP-DC01` on Server 2022, `OSCP-WS01` Win10, `OSCP-EXT01` Server 2019 dual-homed (VLAN 80 `.14` + VLAN 81 `.11`). Separate forest from production `corp.cyberrange.local`. DC DNS forwarder → `10.10.81.1`.
- **Foothold — 381 (10 pts):** PHP + SQLite "Meridian Employee Directory" (`C:\web`, served by `php -S 0.0.0.0:80` via the `PortalWeb` scheduled task; Chocolatey-installed PHP 8.5 — XAMPP abandoned, see notes). UNION-SQLi on `?q=` dumps a `credentials` table leaking `OSCP\jtorres` / `Autumn2024Torres`; jtorres is in Remote Management Users on 381 → **WinRM** → `local.txt`.
- **Lateral — 382 (10 pts):** as jtorres, **Kerberoast** `svc_sql` (SPN `MSSQLSvc/oscp-ext01.oscp.lab:1433`, pw `Welcome123`) → crack → `svc_sql` is **local admin on 382** → pivot through dual-homed 381 → evil-winrm/psexec to 382 → `proof.txt`; **dump LSA secrets** (the disabled `BackupAgent` service runs as `svc_backup`, storing its plaintext) → recover `svc_backup`.
- **Domain Admin — 383 (20 pts):** `svc_backup` holds **DCSync** rights (Replicating Directory Changes [All], granted via `dsacls`) → replicate the `Administrator` hash → PtH → **383** → `proof.txt`. Bonus: **AS-REP-roastable** `mrossi` (`Spring2022`).
- **Pivot-only enforced:** attacker reaches only 381 (VLAN 80: web 80 + WinRM 5985 from VLAN 10). 382/383 on VLAN 81 are reachable only by tunneling through compromised 381 (A6-81 proven). 382 opens WinRM/SMB from `10.10.81.0/24`.
- **Final exposure:** 381 → 80 + 5985 to VLAN 10; 382/383 → VLAN 81 only; RDP off on all three; no kali01 path.
- **Reset:** `oscp-baseline` snapshots (2026-10-19, all three; crash-consistent — guest-agent VSS timeout, fine for revert); manual rollback only, excluded from auto-revert.
- **Build access (removed):** kali01→VLAN 80/81 : 3389 (RDP) via the recycled LAN→CYBER_OSCP + LAN→CYBER_OSCP_INT temp rules (now disabled); RDP off on all three.
- **Covers:** web SQLi, WinRM auth, BloodHound/AD enum, Kerberoast, AS-REP, lateral movement, LSA-secret credential dumping, DCSync → Domain Admin.

### Build gotchas (apply to the AD Windows boxes 381/382, and future Linux boxes)
- **Do NOT pre-create a user's profile folder** (`C:\Users\<user>\...`) before that user's first logon. Doing so makes Windows spin up a differently-named profile (`<user>.<HOST>`) on first logon, and anything placed in the pre-created folder is orphaned. Create the user, let them log on once (WinRM/interactive) to materialize the profile, **then** place flags/files — or detect the real profile path via `Get-CimInstance Win32_UserProfile -Filter "SID='<sid>'"`.
- Unquoted-service-path vuln: `sc create` with a quoted `binPath` stores it quoted (safe). Force the vuln by writing `ImagePath` directly as an **unquoted `ExpandString`** in the registry.
- **Debian 11 is EOL/archived (2026):** the netinst installer's "select software" step fails if a desktop task is chosen (pick only SSH server + standard utils), and apt must point at **`archive.debian.org`** (`deb.debian.org`/`security.debian.org` 404 the pool) with `Acquire::Check-Valid-Until "false"`.
- **PwnKit needs the pre-fix polkit:** the archive's `main` only carries the patched `0.105-31+deb11u1`; pull the vulnerable `0.105-31` (+ `libpolkit-agent-1-0`, `libpolkit-gobject-1-0`) from `snapshot.debian.org` (dated before 2022-01-25), `dpkg -i`, and `apt-mark hold`. A minimal install lacks `libglib2.0-0` (install it, then `dpkg --configure -a`).
- **On-target exploit compiles need `build-essential`**, not just `gcc` — a bare `gcc` without `libc6-dev` makes a self-compiling PoC (e.g. PwnKit's gconv module) fail silently ("could not convert … to EVIL", no root).
- **Shell gotcha:** a `!` in a password passed inside double quotes triggers bash history expansion ("event not found"); use `!`-free values for anything that goes through the shell, or single-quote / `set +H`.
- **Windows web-stack on an offline/no-browser box:** Server 2019 ships IE only, and sourceforge direct links return an HTML interstitial (saved `.exe` is "corrupted and unreadable"). Skip XAMPP/sourceforge — use **Chocolatey** (`iex (New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')`, then `choco install -y php`, `refreshenv`). Serve a SQLi app with `php -S` + SQLite via a startup Scheduled Task; enable `pdo_sqlite`/`sqlite3` in `C:\tools\php85\php.ini` (append `extension_dir`, `extension=pdo_sqlite`, `extension=sqlite3`).
- **Dual-homed AD member (381):** default gateway on the **attacker-facing** NIC (VLAN 80) so it can answer VLAN 10; **no** gateway on the internal NIC (VLAN 81, L2 to the DC); DNS = the DC on **both** NICs; add a `Add-DnsServerForwarder` on the DC for internet resolution. Combined join+rename can race ("directory service is busy") — join first, then `Rename-Computer -DomainCredential`.
- **DCSync seed:** grant a non-DA account Replicating Directory Changes [All] via `dsacls <domainDN> /G "DOM\user:CA;Replicating Directory Changes[ All]"`; stage its creds for recovery by setting a disabled service's logon account to it (`sc config <svc> obj= ... password= ...` stores it as an LSA secret, dumpable by a local admin — no need for the service to run).
- Guest/anonymous SMB share listing needs `RestrictNullSessAccess=0`, the share in `NullSessionShares`, and `everyoneincludesanonymous=1`, plus `Restart-Service LanmanServer`.

---

*Status: **GATE 10 COMPLETE.** The 6-box exam core (3 standalones @ 20 + a 40-pt AD chain = 100 pts, pass ≥70) is built, sealed, and snapshotted on VLAN 80/81, no SIEM, manual reset. A6-81 and A7 are closed. Remaining optional scope: **Phase E — the technique annex** (BOF, CMS, privesc samplers) and the operator-requested **OSCP exam-rules write-up** for the closeout runbook — both deferred until requested.*
