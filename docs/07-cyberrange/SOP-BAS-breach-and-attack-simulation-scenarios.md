# Project Polaris — BAS Scenario SOPs (Gate 8H.3)

**Purpose.** On-demand, scoped procedures for running breach-and-attack-simulation tools across zones. Per the Gate 8H design (§11.5.2), **no BAS cross-zone path is ever left active** — but the rules are *pre-built and disabled*, so a scenario is just "enable the rule, run, disable the rule, revert the target." Treat every step literally and in order.

---

## 0. Foundations & conventions (build these once, before running any SOP)

### 0.1 Monitoring baseline (per monitored box)
Detection is only as good as the telemetry source. Each monitored box must carry, **inside its revert snapshot**, the full endpoint telemetry — otherwise a Phase-G revert strips it.
- **Wazuh agent** (done in 8H.2).
- **Linux targets:** `auditd` + `execve` audit rules + a Wazuh `audit` localfile (read-only recon like `whoami`/`ps` is otherwise invisible — proven on VM332, 9 Oct 2026). Setup:
  ```bash
  sudo apt install -y auditd audispd-plugins
  printf -- '-a exit,always -F arch=b64 -S execve -k exec\n-a exit,always -F arch=b32 -S execve -k exec\n' | sudo tee /etc/audit/rules.d/wazuh-exec.rules
  sudo augenrules --load && sudo systemctl enable --now auditd
  # add to /var/ossec/etc/ossec.conf inside <ossec_config>:
  #   <localfile><log_format>audit</log_format><location>/var/log/audit/audit.log</location></localfile>
  sudo systemctl restart wazuh-agent
  ```
- **Windows targets:** Sysmon + a maintained config + the Wazuh `Microsoft-Windows-Sysmon/Operational` localfile (§10 deferred item).
- **Then snapshot** `qm snapshot <vmid> monitored-baseline` (on top of any deliberately-vulnerable state the box attacks from). **`monitored-baseline` is the revert target for every SOP — never the old pre-agent `hardened_baseline`.**

**All monitored boxes carry a `monitored-baseline` as of 10 Oct 2026** (Linux: Wazuh agent + auditd; Windows: Wazuh agent + Sysmon). The §0.3 OPNsense rules (10, disabled) and standing UFW allows are also built (10 Oct 2026). Foundations complete — SOPs are now just enable/run/disable/revert.

| Box | VMID | monitored-baseline |
|---|---|---|
| VM332 cyber-ubuntu01 (Linux) | 332 | ✅ |
| VM333 cyber-ubuntu02 | 333 | ✅ |
| VM334 cyber-debian01 | 334 | ✅ |
| VM335 cyber-alma01 | 335 | ✅ |
| VM320 cyber-DC01 (Win+Sysmon) | 320 | ✅ |
| VM321 cyber-ws01 (Win+Sysmon) | 321 | ✅ |
| VM322 cyber-ws02 (Win+Sysmon) | 322 | ✅ |
| VM340 cyber-apps01 | 340 | ✅ |
| VM370 cyber-dmz01 | 370 | ✅ |
| VM371 cyber-corpsrv01 (Win+Sysmon) | 371 | ✅ |

### 0.2 Firewall model — pre-built & disabled
- **OPNsense:** every BAS path is a rule **built once and left DISABLED**, above the PROTECTED_NETWORKS block on the relevant interface. A scenario = enable the one rule → Apply → run → disable → Apply. Clear naming (`BAS-CALDERA-LINUX`, …).
- **VM350 UFW:** the matching allows are **standing** (built once, left in place). Safe because OPNsense is the only L3 hop between zones — while the OPNsense rule is disabled, cross-zone traffic cannot reach VM350 regardless of UFW, so the standing allow is inert until the OPNsense rule is enabled. (UFW has no per-rule disable, which is why the toggle lives in OPNsense.)

### 0.3 BAS firewall rule catalog (pre-build all OPNsense rules DISABLED; build the matching standing VM350 UFW allows now)

**Create two port aliases once:** `BAS_CALDERA_PORT` = `8888`, `BAS_MONKEY_PORT` = `5000`.
**Every OPNsense rule:** Action **Pass** · Interface = the source zone's · Direction **in** · Protocol **TCP** · Source = zone net · Destination **`SIEM_MANAGER`** · Dest port = the tool alias · placed **above the PROTECTED_NETWORKS block** · **Disabled** (uncheck Enabled). The matching VM350 UFW allow is **standing** (built now, left in place — inert until the OPNsense rule is enabled).

#### Caldera — sandcat beacons back to the server (target → VM350:8888). Lowest risk (inbound to SIEM).
| OPNsense rule (disabled) | Interface | Source | Dest:port | Standing VM350 UFW allow |
|---|---|---|---|---|
| `BAS-CALDERA-LINUX` | CYBER_LINUX | `10.10.30.0/24` | SIEM_MANAGER:8888 | `ufw allow from 10.10.30.0/24 to any port 8888 proto tcp comment 'BAS Caldera LINUX'` |
| `BAS-CALDERA-WINDOWS` | CYBER_WINDOWS | `10.10.20.0/24` | SIEM_MANAGER:8888 | `ufw allow from 10.10.20.0/24 to any port 8888 proto tcp comment 'BAS Caldera WINDOWS'` |
| `BAS-CALDERA-APPS` | CYBER_APPS | `10.10.40.0/24` | SIEM_MANAGER:8888 | `ufw allow from 10.10.40.0/24 to any port 8888 proto tcp comment 'BAS Caldera APPS'` |
| `BAS-CALDERA-HYBRID` | CYBER_HYBRID | `10.10.70.0/24` | SIEM_MANAGER:8888 | `ufw allow from 10.10.70.0/24 to any port 8888 proto tcp comment 'BAS Caldera HYBRID'` |
| `BAS-CALDERA-HYBRID-INT` | CYBER_HYBRID_INTERNAL | `10.10.71.0/24` | SIEM_MANAGER:8888 | `ufw allow from 10.10.71.0/24 to any port 8888 proto tcp comment 'BAS Caldera HYBRID-INT'` |

#### Infection Monkey — agents report to the Island (target → VM350:5000). **The Island does NOT attack targets; the agents (on targets) do — so there is NO "VM350→targets" rule.**
**Tier 1 — agent↔Island (per zone you run Monkey agents in):** same inbound-to-SIEM pattern as Caldera, just port 5000.
| OPNsense rule (disabled) | Interface | Source | Dest:port | Standing VM350 UFW allow |
|---|---|---|---|---|
| `BAS-MONKEY-LINUX` | CYBER_LINUX | `10.10.30.0/24` | SIEM_MANAGER:5000 | `ufw allow from 10.10.30.0/24 to any port 5000 proto tcp comment 'BAS Monkey LINUX'` |
| `BAS-MONKEY-WINDOWS` | CYBER_WINDOWS | `10.10.20.0/24` | SIEM_MANAGER:5000 | `ufw allow from 10.10.20.0/24 to any port 5000 proto tcp comment 'BAS Monkey WINDOWS'` |
| `BAS-MONKEY-APPS` | CYBER_APPS | `10.10.40.0/24` | SIEM_MANAGER:5000 | `ufw allow from 10.10.40.0/24 to any port 5000 proto tcp comment 'BAS Monkey APPS'` |
| `BAS-MONKEY-HYBRID` | CYBER_HYBRID | `10.10.70.0/24` | SIEM_MANAGER:5000 | `ufw allow from 10.10.70.0/24 to any port 5000 proto tcp comment 'BAS Monkey HYBRID'` |
| `BAS-MONKEY-HYBRID-INT` | CYBER_HYBRID_INTERNAL | `10.10.71.0/24` | SIEM_MANAGER:5000 | `ufw allow from 10.10.71.0/24 to any port 5000 proto tcp comment 'BAS Monkey HYBRID-INT'` |

- **Intra-zone propagation** (an agent spreading to zone-mates) needs **no firewall rule** — it's L2 within the VLAN (proven by the VM335→VM332 pivot, §11.3.4).
- **Tier 2 — cross-zone propagation (OPTIONAL, ADVANCED, highest blast radius):** to let an agent in zone A spread into zone B, build a pass on **zone A's interface**: Source = A net, Destination = B net, broad ports (Monkey's exploit set, or `any` for a full test). This is zone↔zone and does not involve VM350. **Build only for a specific A→B scenario, scoped to that pair, disabled by default — do not pre-build all combinations.** Treat each as a deliberate decision to breach one-way isolation between two target zones.

#### ART (built later, when ART remoting is set up) — opposite direction: **VM350 → target** WinRM (`5985/5986`) or SSH (`22`), rules on the **CYBER_SIEM** interface (Source VM350 → Dest target net). **No VM350 UFW rule** (outbound is allowed by default); the *target* must have its WinRM/SSH port open. Higher blast radius (SIEM into targets) — catalog provided when you're ready to use ART.

**Build order:** create the two port aliases → build the 10 OPNsense rules (5 Caldera + 5 Monkey Tier-1) all **disabled** → add the 10 standing VM350 UFW allows. Then a scenario is just "enable the one rule."

### 0.4 Standing facts
- VM350 `cyber-siem01` = `10.10.50.149` (Wazuh :443, Monkey Island :5000 HTTPS, Caldera :8888 HTTP). Aliases: `SIEM_MANAGER`, `WAZUH_AGENT_PORTS`=`1514,1515`.
- **Golden rule:** tool cleanup is a convenience; the `monitored-baseline` revert is the guarantee. Always finish with Phase G.

---

## SOP-1 — Caldera operation against the Linux zone (VLAN 30)

**Prereq:** §0 done — `BAS-CALDERA-LINUX` rule exists (disabled), standing UFW allow in place, target carries a `monitored-baseline` (agent + auditd). Caldera running on VM350. Target example: VM332 `cyber-ubuntu01` (`10.10.30.105`).

1. **Open the path:** OPNsense → CYBER_LINUX → **enable** `BAS-CALDERA-LINUX` → **Apply**. Verify from target: `nc -zv -w3 10.10.50.149 8888` connects.
2. **Deploy sandcat on the target:** Caldera UI → Agents → Deploy → sandcat → Linux, server `http://10.10.50.149:8888`, group `red`; run the generated one-liner on VM332. Confirm the agent appears.
3. **Run the operation:** Operations → new → pick an adversary profile, group `red`, planner `atomic` → Start. Watch abilities execute.
4. **Observe (Wazuh, from VM360):** Threat Hunting → Last 24h → filter the agent. With auditd in the baseline, Discovery TTPs (`whoami`/`who`/`ps`) now surface as `execve` audit events (~rule 80792). Note what did/didn't alert.
5. **Cleanup (best-effort):** terminate/clean the operation in Caldera; on the target `pkill -f sandcat ; rm -f /tmp/sandcat`.
6. **Close the path:** OPNsense → **disable** `BAS-CALDERA-LINUX` → **Apply**. Verify `nc … 8888` now times out.
7. **Reset (the guarantee):** on the Proxmox host `qm rollback 332 monitored-baseline && qm start 332`; confirm the agent re-connects before the next run.

**Done.** No active BAS path remains, and the target is pristine *with monitoring intact*.

---

## SOP-2 — Caldera operation against the Windows AD zone (VLAN 20)

**Identical shape to SOP-1.** Deltas: rule `BAS-CALDERA-WINDOWS` on interface **CYBER_WINDOWS**; targets are Windows, so the sandcat one-liner is the **PowerShell** variant and telemetry is **Sysmon** (not auditd). Target examples: VM321 `cyber-ws01`, VM322 `cyber-ws02`, or VM320 `cyber-DC01` (`10.10.20.10`).

1. **Open the path:** OPNsense → CYBER_WINDOWS → **enable** `BAS-CALDERA-WINDOWS` → **Apply**. Verify from target: `Test-NetConnection 10.10.50.149 -Port 8888` succeeds.
2. **Deploy sandcat:** Caldera UI → Agents → Deploy → sandcat → **Windows**, server `http://10.10.50.149:8888`, group `red`; run the generated **PowerShell** one-liner on the target. Confirm the agent appears.
3. **Run the operation:** Operations → new → adversary profile, group `red`, planner `atomic` → Start.
4. **Observe (Wazuh, from VM360):** Threat Hunting → Last 24h → filter the agent. Discovery/execution TTPs now surface as **Sysmon** events (process-create EID 1, etc.) rather than auditd execve. Note what did/didn't alert.
5. **Cleanup (best-effort):** terminate/clean the operation in Caldera; on the target `Stop-Process -Name splunkd,sandcat -Force 2>$null` (or whatever the implant was named) and delete the dropped binary from its temp path.
6. **Close the path:** OPNsense → **disable** `BAS-CALDERA-WINDOWS` → **Apply**. Verify `Test-NetConnection … 8888` now fails.
7. **Reset (the guarantee):** Proxmox host `qm rollback <vmid> monitored-baseline && qm start <vmid>` (321 / 322 / 320); confirm the agent re-connects before the next run.

---

## SOP-3 — Caldera operation against the Apps zone (VLAN 40)

**Identical shape to SOP-1** (Apps hosts are Linux → auditd telemetry, bash sandcat one-liner). Deltas: rule `BAS-CALDERA-APPS` on interface **CYBER_APPS**. Target: VM340 `cyber-apps01` (VLAN 40, DHCP-assigned `10.10.40.x`).

1. **Open the path:** OPNsense → CYBER_APPS → **enable** `BAS-CALDERA-APPS` → **Apply**. Verify from VM340: `nc -zv -w3 10.10.50.149 8888`.
2. **Deploy sandcat (Linux one-liner)** on VM340, server `http://10.10.50.149:8888`, group `red`.
3. **Run the operation** (adversary profile, group `red`, planner `atomic`).
4. **Observe (Wazuh, from VM360):** Threat Hunting → filter the agent; auditd `execve` events (~rule 80792) for discovery TTPs. VM340 also hosts the deliberately-vulnerable web apps, so FIM/web-log noise is expected alongside.
5. **Cleanup (best-effort):** `pkill -f sandcat ; rm -f /tmp/sandcat`.
6. **Close the path:** OPNsense → **disable** `BAS-CALDERA-APPS` → **Apply**; verify `nc … 8888` times out.
7. **Reset:** `qm rollback 340 monitored-baseline && qm start 340`.

---

## SOP-4 — Caldera operation against the Hybrid zone (VLAN 70) and Hybrid-Internal (VLAN 71)

Two distinct paths because the hybrid scenario has an internet-facing leg (VLAN 70) and an internal-only leg (VLAN 71). **Run them as separate scenarios — enable only the rule for the leg you're exercising.**

### 4a — Hybrid DMZ (VLAN 70): rule `BAS-CALDERA-HYBRID`, interface **CYBER_HYBRID**, target VM370 `cyber-dmz01` (`10.10.70.10`, Linux → auditd).
1. OPNsense → CYBER_HYBRID → **enable** `BAS-CALDERA-HYBRID` → Apply. Verify `nc -zv -w3 10.10.50.149 8888` from VM370.
2. Deploy sandcat (Linux one-liner) on VM370, group `red`.
3. Run the operation.
4. Observe in Wazuh (auditd execve). VM370 also carries the SQLi web layer — expect web-tier events in parallel.
5. Cleanup: `pkill -f sandcat ; rm -f /tmp/sandcat`.
6. OPNsense → **disable** `BAS-CALDERA-HYBRID` → Apply; verify timeout.
7. Reset: `qm rollback 370 monitored-baseline && qm start 370`.

### 4b — Hybrid-Internal (VLAN 71): rule `BAS-CALDERA-HYBRID-INT`, interface **CYBER_HYBRID_INTERNAL**, target VM371 `cyber-corpsrv01` (`10.10.71.11`, Windows → Sysmon, PowerShell one-liner).
> **Isolation note.** VLAN 71 is internal-only by design — it has no CYBER_ATTACK path and normally no outbound. Enabling `BAS-CALDERA-HYBRID-INT` is the **first and only sanctioned outbound exception** from this zone (target→SIEM:8888), and it is still inbound-to-SIEM only — it never opens VLAN 71 to anything inbound. Enable it only for the duration of the run.
1. OPNsense → CYBER_HYBRID_INTERNAL → **enable** `BAS-CALDERA-HYBRID-INT` → Apply. Verify `Test-NetConnection 10.10.50.149 -Port 8888` from VM371.
2. Deploy sandcat (**PowerShell** one-liner) on VM371, group `red`.
3. Run the operation.
4. Observe in Wazuh (Sysmon events).
5. Cleanup (Windows): stop the implant process, delete the dropped binary.
6. OPNsense → **disable** `BAS-CALDERA-HYBRID-INT` → Apply; verify failure — **confirm VLAN 71 is back to fully internal-only before closing out.**
7. Reset: `qm rollback 371 monitored-baseline && qm start 371`.

---

## SOP-5 — Infection Monkey operation (template — applies to any zone)

**Different model from Caldera — read this before running.** The Monkey **Island** (on VM350:5000) is a C2/reporting server, **not an attacker**: the **agent runs ON the target** and does the scanning/exploitation itself, then reports back to the Island. So:
- The only firewall rule a Monkey run needs is the **Tier-1 agent→Island:5000** pass for the zone you're seeding (`BAS-MONKEY-<zone>`). There is **no** "Island→targets" rule.
- An agent spreading to **zone-mates** (same VLAN) needs **no rule** — it's L2 within the VLAN (proven VM335→VM332, §11.3.4).
- An agent spreading to **another zone** needs a **Tier-2 cross-zone** rule, which is **optional/advanced** and built per-scenario, scoped to the exact A→B pair, disabled by default (see §0.3). **Do not enable Tier-2 unless the scenario is explicitly a cross-zone propagation test.**

**Per-zone map** (pick your zone's row): `BAS-MONKEY-LINUX` / CYBER_LINUX / patient-zero VM332 · `BAS-MONKEY-WINDOWS` / CYBER_WINDOWS / VM321 · `BAS-MONKEY-APPS` / CYBER_APPS / VM340 · `BAS-MONKEY-HYBRID` / CYBER_HYBRID / VM370 · `BAS-MONKEY-HYBRID-INT` / CYBER_HYBRID_INTERNAL / VM371 (VLAN-71 isolation note from SOP-4b applies here too).

1. **Open the Tier-1 path:** OPNsense → `<zone interface>` → **enable** `BAS-MONKEY-<zone>` → **Apply**. Verify from patient-zero: `nc -zv -w3 10.10.50.149 5000` (Linux) / `Test-NetConnection 10.10.50.149 -Port 5000` (Windows).
2. **Get the agent onto patient-zero:** Island UI (`https://10.10.50.149:5000`, from VM360) → **Run Monkey** → copy the agent command for the target OS → run it on the chosen patient-zero host. The agent registers with the Island.
3. **Scope the run in the Island** *before* it spreads: Configuration → set the **scan target list / network range to the single VLAN** you're exercising (e.g. `10.10.30.0/24`) and **leave every other range out** — this is the real containment for intra-zone-only runs, since L2 propagation isn't firewalled. Confirm no other subnet is listed. (For a deliberate Tier-2 test, and only then, add the second zone's range here *and* enable the matching Tier-2 OPNsense rule.)
4. **Run** from the Island; watch the propagation/exploitation map build.
5. **Observe (Wazuh, from VM360):** Threat Hunting → Last 24h → the lateral-movement / exploit attempts across the zone's agents (auditd execve on Linux, Sysmon on Windows). This is the lateral-movement detection drill.
6. **Cleanup (best-effort):** Island → **Cleanup / kill all agents** (the Island can self-remove its agents); confirm the map shows agents stopped.
7. **Close the path:** OPNsense → **disable** `BAS-MONKEY-<zone>` → **Apply**. For VLAN 71, re-confirm internal-only. (If a Tier-2 rule was enabled, disable it too and re-verify.)
8. **Reset (the guarantee):** `qm rollback <vmid> monitored-baseline && qm start <vmid>` for **every** host the agent touched — Monkey spreads, so revert the whole zone's touched hosts, not just patient-zero.

**Done.** No active BAS path remains; the Island holds its run report for review while the targets are reverted clean with monitoring intact.

---

## SOP-6 — Atomic Red Team (placeholder — build when ART remoting is stood up)

ART runs the **opposite direction** (VM350 → target, WinRM 5985/5986 or SSH 22, rules on **CYBER_SIEM**, no VM350 UFW rule, target port must be open). Higher blast radius (SIEM reaching into targets). The rule catalog and step-by-step come when you're ready to use ART — not built yet (§0.3, §10).

---

*All on-demand BAS SOPs (Caldera + Infection Monkey) are now written. ART follows when its remoting is set up.*
