# Phase 3 Runbook: NAS01 Config Backup Automation (Ansible + n8n + AI)

**Status:** Planning / In Progress
**Primary host:** CT 402 "orchestrator-n8n" on node `AI` (existing n8n + Ansible control layer from Phase 2)
**Last updated:** 2026-09-16 (session spanned 2026-09-15 into 2026-09-16) — 3k promoted to production, cyberrange node collector (3u) designed, built, and proven

**Maintenance note (2026-09-16):** as of this session, this document is maintained
directly rather than via separate resume-prompt addenda — new work is folded into
the relevant existing section (or a new lettered subsection under Build Plan) and
into Network Topology Reference / Open Items / Change Log in place, the same
discipline used for the first two phases' runbooks. Resume prompts going forward
should point at this file as the single current-state source rather than carry
their own summary of recent sessions.

## Overview

This runbook covers migrating the existing "Project Polaris" configuration-backup
framework (currently a bash-only system, cron-triggered from the `Homelab` Proxmox
node) into an Ansible-driven, n8n-orchestrated, approval-gated automation running
from the AI host's existing orchestration container (CT 402). It also folds in
hardware/network changes happening alongside this work (Starlink cutover, Ubiquiti
bridge removal, switch replacement).

Goal, in the user's words: Ansible controls the backup process, triggered
autonomously, evaluates the system for changes, prompts for approval only when
changes look "major" per rules defined in advance, otherwise proceeds
autonomously — consistent with the original tiered-autonomy design from the
AI-homelab project (autonomous for routine/safe tasks, approval required for
anything touching root/system-level changes, which includes changes to the
automation's own code).

## Network Topology Reference (as of 2026-09-09; credential/access notes updated 2026-09-16)

Corrects/consolidates scattered facts from chat into one place.

| Segment | Device | IP | Notes |
|---|---|---|---|
| House WiFi | Home modem → Ubiquiti bridge | — | Bridge being removed in Starlink cutover |
| House (192.168.30.0/24) | gateway01 (pfSense) | 192.168.30.1 | House-side firewall |
| House (192.168.30.0/24) | pihole01 | 192.168.30.2 | DNS |
| — | Switch g1 (vlan 30) | — | → vmbr3 on Homelab |
| — | Switch g2 (vlan 30) | — | → main Deco AP, provides house WiFi |
| Homelab/mgmt (192.168.10.0/24) | firewall01 (pfSense) | 192.168.10.1 | Separates house from homelab; `pfsense.sh` target |
| Homelab/mgmt | Switch g3 (vlan 10) | — | → vmbr2 on Homelab |
| Homelab/mgmt | cyberrange Proxmox host | 192.168.10.119 | Switch g4 (vlan 10); member of the `polaris` Proxmox cluster (see 3u — this has real credential-exposure consequences, now mitigated) |
| Homelab/mgmt | AI Proxmox host | 192.168.10.124 | Switch g5 (vlan 10) |
| Homelab/mgmt | NAS01 (ASUSTOR AS1202T) | 192.168.10.4 | Switch g6 (vlan 10); 1-bay populated of 2, 4TB, ADM 5.1.4.RL21, AArch64, 1GB RAM. No IP-based share ACL available in ADM — isolation between collectors' destinations is enforced entirely via per-account, per-subfolder ownership underneath a shared top-level share (see 3u) |
| Homelab/mgmt | New switch (Netgear GS324TP S350) | 192.168.10.126 | Replaces `switch01`; web-managed only, no SSH/CLI |
| Homelab/mgmt | cyber-fw01 (OPNsense) — homelab-side mgmt access | 192.168.10.120 | Reachable **only from Admin01** (firewall-scoped); `opnsense.sh` target |
| Cyberrange internal (10.10.1.0/24 native + 10.10.10–99.0/24 tagged) | cyber-fw01 (OPNsense) — cyberrange-side | 10.10.1.1 (LAN, native VLAN on `vmbr1`) + CYBER_ATTACK/WINDOWS/LINUX/APPS/SIEM/ANALYSIS/QUARANTINE sub-interfaces (VLANs 10/20/30/40/50/60/99 — cyber-fw01's own internal numbering, unrelated to the physical Homelab VLAN 10 despite the coincidental digit) | Isolated; never reachable from homelab side directly. `vmbr1` has no physical uplink at all (confirmed via its bridge-ports being empty), so this isolation holds at the hypervisor level independent of cyber-fw01's own firewall rules. kali01 (VM 301) sits deliberately untagged on the native LAN segment as cyber-fw01's sole permitted admin console; Blackarchlinux01 (310, CYBER_ATTACK) and analysis-probe01 (360, CYBER_ANALYSIS) are properly VLAN-tagged into their intended zones. Firewall rules (identical across all CYBER_* zones) block OPNsense's control plane and a `PROTECTED_NETWORKS` alias (Trusted Infrastructure + inter-zone) from every zone, confirmed via direct rule review, 2026-09-15 |

**Tailscale ACL (closed 2026-09-15/16):** the tailnet ran with no custom ACL policy
(default full-mesh) from 3i through this session. A minimal policy was added —
`tag:cyberrange` defined, assigned to the `cyberrange` device, with a single
`autogroup:member` ↔ `autogroup:member` accept rule covering everything else —
giving `cyberrange` zero tailnet reachability in either direction (tagged devices
match neither side of an `autogroup:member` rule) while leaving every other
device's existing access, including ntfy and remote SSH, completely unchanged.
Remote access to cyberrange is now exclusively via a LAN hop through
Homelab/AI, matching the user's stated intent. Rollout was staged (policy → tag
assignment → live verification) specifically to avoid a window where the
account had a tag defined but no rules, which briefly denies everything
tailnet-wide, not just the tagged device — no evidence this window was ever
actually hit, but the sequencing is worth repeating for any future ACL change.

Isolation intent (unchanged from original design): gateway01 firewalls the house,
firewall01 separates homelab from house, cyber-fw01 separates cyberrange from
everything else. Automation must never bridge across the cyber-fw01 boundary —
OPNsense config backup happens via the homelab-side management IP (`.120`) through
Admin01 only, never by reaching into 10.10.1.0/24.

## Existing Framework Assessment (rewritten 2026-09-09 against the real live pull)

Real structure, confirmed via a fresh pull directly from Homelab
(`/opt/project-polaris/config-backup/`):

```
config-backup/
├── bin/polaris-backup          (orchestrator, registry-driven)
├── lib/polaris-common.sh       (shared logging/utility library)
├── lib/polaris-firewall-collector.sh  (shared engine for pfsense+opnsense)
├── collectors/{proxmox,pfsense,opnsense,docker,admin01,admin-ws}/*.sh
├── logs/orchestrator/*.log     (one real log per run, 30-day retention)
└── temp/troubleshooting/
```

Six active collectors as of this rewrite: `proxmox`, `pfsense`, `opnsense`,
`docker`, `admin01`, `admin-ws`. `switch01`/`nano-ap`/`nano-station` have been
removed from the orchestrator's registry (see Decisions Log) — their script
files still physically exist on disk but are no longer invoked; safe to
delete once `config-backup/` is under git (3c).

The orchestrator (`polaris-backup`) turned out to already be far more mature
than the original stale-copy review suggested — it's registry-driven
(`POLARIS_COLLECTOR_IDS` + a set of parallel associative arrays keyed by
collector ID), so `main()` loops generically over collectors rather than
repeating per-collector logic. `pfsense.sh`/`opnsense.sh` are themselves now
thin ~49-line wrappers around a shared, table-driven `polaris-firewall-collector.sh`
engine (`polaris_register_firewall_collector()` takes host/user/ssh-key/
remote-path as parameters into a shared `POLARIS_FIREWALL_CONFIG` table) — a
good design that already solved the namespace-duplication problem found in
the stale copy without needing my earlier fix. Confirmed connection targets:
`docker.sh` → 192.168.10.20, `admin01.sh` → 192.168.10.30, `admin-ws.sh` →
192.168.10.41, all as user `lab-admin` (firewalls use their own dedicated
accounts/keys).

### Fixes implemented and deployed

1. **Logging redesign.** The `report_*` compatibility layer had already been
   removed upstream in favor of explicit `operator_*` (screen)/`log_*` (file)
   calls, but auditing real call-site counts across the whole tree showed the
   underlying problem was still present, and worse than the stale copy
   suggested: 611 of 795 `operator_error` sites and 52 of 62 `operator_warning`
   sites never reached the log file — concentrated entirely in the deep
   collector logic (`proxmox.sh`, `admin-ws.sh`, `admin01.sh`, `docker.sh`,
   `polaris-firewall-collector.sh` each had **zero** `log_error` calls).
   Rather than touch ~600 call sites across 5 large files, the fix
   centralizes in `polaris-common.sh`: `operator_warning`/`operator_error`/
   `log_warning`/`log_error` now all route through one `_emit_diagnostic()`
   that writes to both screen and file, tagged with `[collector-name]`
   (sourced from a new `POLARIS_ACTIVE_COLLECTOR` variable the orchestrator
   sets/clears around each collector's run via a single choke point,
   `_execute_registered_collector`). Zero changes needed inside the five
   large collector files. `operator_info`/`operator_success`/`log_info`/
   `log_success` left untouched — that split was already working as intended.
   This also directly sets up Build Plan 3i (major-change rules) and the
   AI-notification idea: `[ERROR] [pfsense] ...` is now a reliable, parseable
   signal, not free-text prose. **Deployed and confirmed working in
   production** via manual run and real tagged log output.
2. **Collector retirement.** `switch01`/`nano-ap`/`nano-station` removed from
   all 9 registries in `polaris-backup`; verified programmatically consistent.
   **Deployed.**
3. **Defensive PATH.** Added as the first thing `polaris-common.sh` does
   (universal choke point every script sources), rather than in the crontab —
   chosen specifically so it protects Ansible/n8n-via-SSH invocation equally,
   not just cron. **Deployed.**

Net effect on the two files touched: `polaris-backup` shrank by 481 lines,
`polaris-common.sh` grew by well under 100 — a net reduction while adding
real capability. Old versions preserved as `.bak` on Homelab pending
confidence in the new ones.

**Suggested future cleanup (not yet done, flagged per standing permission to
suggest changes):** many call sites in `polaris-backup` itself already call
`operator_error "X"; log_error "X"` back-to-back with identical message
text — now fully redundant since both do the same complete thing. Collapsing
these would shrink the orchestrator further; low urgency, cosmetic not
correctness, good candidate for a later dedicated pass.

### Production Health (current understanding, 2026-09-09)

**✅ Proxmox — very likely resolved.** Failed 32/32 days across the full
available log history (never once succeeded) prior to today. Root cause was
never captured in logs (predates the logging fix — only "failed, exit code 1"
was ever recorded, never why). Fast, consistent failures (1–22s) pointed at
an early check rather than a timeout; leading hypothesis was a PATH gap under
cron affecting the `command_exists pveversion` check. **Manual run after
deploying the PATH fix succeeded** — strong support for this theory, though
not yet 100% confirmed since it wasn't literally triggered by cron. Pending:
confirm via an actual unattended cron run.

**🟡 Admin-WS — theory corrected, still open.** User diagnostics ruled out
network path entirely: `ping` 100% loss, but `arp -n 192.168.10.41` showed a
correct exact match for Admin-WS's real MAC (`BC:24:11:XX:XX:XX` on
`vmbr2`) — rules out ARP/VLAN/physical-switch causes, consistent with the
switch having only been replaced 3 days ago while this issue is roughly a
month old. SSH itself has produced both `Connection timed out` and
`No route to host` on different runs, ruling out the `domain-admin`
username/SSH-key theory (that would show as `Permission denied (publickey)`
*after* a successful connection, not before).

Initial follow-up theory (Proxmox per-VM firewall, `firewall=1` on the NIC)
**ruled out by direct evidence**: user's screenshots show both the VM-level
and Datacenter-level "Firewall" master toggles set to "No", plus zero rules
configured on VM 201 ("No firewall rule configured here"). `firewall=1` on a
NIC only wires that interface into the framework — actual enforcement needs
the VM-level or Datacenter-level toggle enabled too, and neither is. Proxmox's
firewall is not filtering this traffic.

**✅ Admin-WS — fully resolved.** Root cause confirmed (NLA never
domain-authenticated Admin-WS; OpenSSH inbound rule scoped to Domain profile
only, so it never applied). Permanent fix applied (firewall re-enabled,
rule's profile scope widened) and verified working via a follow-up test
backup completing successfully — not just the disabled-firewall diagnostic
test. Both of the two active production failures found in this review are
now closed out.

**New, separate dependency discovered 2026-09-10 (see Decisions Log):**
Admin-WS's backup also depends on DC01 being powered on, since its SSH
account is domain-based and Windows must resolve it against Active
Directory before any credential is checked — confirmed as a distinct
mechanism from the NLA/firewall issue above, not a regression of it.

**Healthy:** pfSense, OPNsense, Docker01, Admin01 — 0 failures across all
available log history for each.

**Important caveat on all "when did this start" claims:** `polaris-backup`
retains orchestrator logs for only 30 days
(`POLARIS_ORCHESTRATOR_LOG_RETENTION_DAYS=30`), so the earliest available log
is just the oldest one retention hadn't purged yet, not necessarily when
anything actually started. An initial read placed Admin-WS's regression at
Aug 17 based on the available window — that should be understood as "the
earliest visible point," not a confirmed onset date; the real start could be
earlier and isn't recoverable from logs alone. Same logic explains the empty
NAS `validated/admin-ws` folder and `incomplete` stopping at Aug 16 — the
7-day NAS validated-retention window ages out old backups regardless of when
the real failure started.

### Resolved: proxmox-style collection extends to the AI node

Confirmed 2026-09-09: the AI Proxmox host needs its own collector (see Build
Plan 3n) — no longer just an open question, since local host-level backup
coverage was never extended past Homelab. Cyberrange node's inclusion still
undecided.

### Open architecture question — resolved as moot, 2026-09-10

`opnsense.sh` has a 100% success rate reaching `.120` from wherever cron
currently runs (Homelab). Originally flagged as worth confirming before
building a ProxyJump-via-Admin01 config for Ansible. That build item (3g)
was dropped once `polaris-backup`'s monolithic design was confirmed — Ansible
never reaches `.120` directly, so how exactly Homelab's own access works is
no longer a build-blocking question, just an unresolved intellectual
curiosity. Left here for completeness, not tracked as an open item anymore.

Did not do a full line-by-line read of `proxmox.sh`/`docker.sh`/`admin01.sh`/
`admin-ws.sh` bodies (~12,000 combined lines) — prioritized the active
production failures over further code review. Can go deeper into any of
these on request.

<details>
<summary>Original assessment (2026-09-09, based on stale copy — kept for reference only, superseded above)</summary>


Six collectors under `polaris-backup`, orchestrated with a stage → hash-validate →
copy-to-NAS01 → validate copy → promote-or-quarantine → retention lifecycle per
collector. Architecture is solid and worth preserving as-is; issues found are
targeted, not structural.

| Collector | Method | Status going forward |
|---|---|---|
| `proxmox.sh` | Local commands, no hardcoded IPs, runs on whichever node executes it | Keep. Currently only covers Homelab node — decide later whether to also deploy to AI/cyberrange nodes |
| `pfsense.sh` | Remote SSH/SCP, `192.168.10.1` | Keep. Has the unfixed generic-variable-name bug (see Fix List) |
| `opnsense.sh` | Remote SSH/SCP, `192.168.10.120` | Keep as-is. Confirmed live/intentional (cyber-fw01 via Admin01), not dead code |
| `switch01.sh` | Manual export (`/root/Downloads/config.cfg`) | **Retire** — switch being physically replaced |
| `nano-ap.sh` | Manual export (MAC-named file) | **Retire** — part of Ubiquiti bridge being removed |
| `nano-station.sh` | Manual export (MAC-named file) | **Retire** — part of Ubiquiti bridge being removed |
| *(new)* Netgear GS324TP collector | TBD — see Switch Automation Investigation | To be built |

### Fix List (carried from code review)

1. **Logging split bug** — `report_warning`/`report_error` in `polaris-common.sh`
   print to stdout only and are never written to the log file; `report_info`/
   `report_success` do the reverse. Fix so all four write to both, or at minimum
   ensure warnings/errors always land in the log file — this becomes the source
   of truth for n8n/Ansible to parse.
2. **`pfsense.sh` namespace debt** — still uses generic unprefixed constants
   (`COLLECTOR_RESULT_SUCCESS`, `CONFIG_STATUS_NEW`, etc.) that `opnsense.sh`
   already fixed (per its `.pre-namespace-fix` backup). Not currently crashing,
   but should be brought in line before adding the new switch collector.
3. **Cleanup leftovers**: empty `proxmox/.proxmox.sh.swp`, test artifact
   `proxmox/a/.placeholder`, empty unused `docker/` and `ubiquiti/` directories.
4. **Confirm real run history** — need actual logs from
   `${POLARIS_PROJECT_ROOT}/logs/config-backup/orchestrator/` and NAS01's
   `Project-Polaris/{validated,quarantine}` to know what's actually succeeded
   historically (not yet reviewed).

</details>

## Decisions Log

| Date | Decision |
|---|---|
| 2026-09-09 | Retire nano-ap.sh and nano-station.sh (Ubiquiti bridge removal) |
| 2026-09-09 | Retire switch01.sh (switch being replaced); build new Netgear GS324TP collector |
| 2026-09-09 | Confirmed `opnsense.sh` stays pointed at `192.168.10.120`, not dead code |
| 2026-09-09 | New switch IP is `192.168.10.126` (static, netmask corrected to /24) |
| 2026-09-09 | Switch automation: invest in scripting rather than stay manual |
| 2026-09-09 | Notifications: self-hosted **ntfy**, reachable only via Tailscale |
| 2026-09-09 | Ansible/n8n control plane consolidates onto CT 402 (AI host), not Homelab |
| 2026-09-09 | OPNsense collector task reaches `.120` via SSH ProxyJump through Admin01 (firewall already scopes access this way) |
| 2026-09-09 | `config-backup/` goes under git on Docker01's existing Forgejo instance |
| 2026-09-09 | TFTP landing zone for switch export lands on CT 402, not NAS01 (NAS01 is low-power ARM/1GB RAM — keep it storage-only) |
| 2026-09-09 | "Major change" detection: rules-based thresholds first; LLM summarizes/explains for the approval notification rather than being sole judge |
| 2026-09-09 | Self-modifying automation code always requires approval, regardless of how confident the agent is — matches original tiered-autonomy design |
| 2026-09-09 | Discovered local documentation zip was stale vs. the live Homelab system; re-baselined against a fresh live pull. All prior fixes based on the stale copy voided. |
| 2026-09-09 | Logging design: centralize warning/error dual-write (screen+file) in `polaris-common.sh` with `[collector-name]` tagging, rather than auditing ~600 call sites individually — chosen specifically to support future AI log review with reliable per-device attribution |
| 2026-09-09 | Retired `switch01`/`nano-ap`/`nano-station` from the orchestrator's collector registry (script files left on disk pending git setup) |
| 2026-09-09 | User granted standing permission to suggest/implement code simplifications while working toward the automation end goal, subject to the existing approval-for-system-level-changes principle |
| 2026-09-09 | Deferred Build Plan 3n (AI Proxmox host collector) until after the Ansible migration (3f+) rather than building a one-off SSH bridge from Homelab into the AI host for a single collector |
| 2026-09-09 | Confirmed via direct test that `ansible -m command`/`-m shell` work (rc=0) against Homelab's Python 3.13 — Phase 2's AnsiballZ segfault does not reproduce here, isolating that issue to the AI node's specific environment rather than a general Python 3.13 incompatibility. 3f proceeds using `command`/`shell` as planned. |
| 2026-09-09 | Created dedicated least-privilege Homelab automation account `polaris-ansible-backup` (NOPASSWD sudo scoped to exactly `/opt/project-polaris/config-backup/bin/polaris-backup`, nothing else), with its own per-purpose SSH keypair (`/root/.ssh/polaris-ansible-homelab` on CT402) — named and scoped this way specifically to leave room for future sibling accounts per agent role (network-mgmt, docs, coding, etc.) without collision or over-broad shared credentials |
| 2026-09-09 | **Autonomy classifications are expected to evolve.** User explicitly welcomes revising what counts as "major" vs. routine as real usage reveals gaps in the initial ruleset — not treated as a design failure, just normal iteration. |
| 2026-09-09 | **Confirmed:** hardware/VM inventory drift-detection folds into existing architecture rather than needing a new autonomy tier — "new VM with no collector" becomes one of 3i's major-change trigger conditions; any actual collector-code creation still routes through 3k's git-based approval flow (self-modifying automation code always requires approval, per the original tiered-autonomy design). Drift-detection itself gets its own **read-only-scoped** Proxmox API token, separate from any write-capable token, matching the least-privilege-per-role pattern used for the Homelab SSH account. |
| 2026-09-10 | **First successful Ansible-triggered production run.** All 7 collectors completed successfully via `ansible-playbook run-polaris-backup.yml`, matching filenames confirm NAS01 promotion — functionally identical output to a cron-triggered run, just launched by Ansible. `polaris-ansible-backup` account re-locked (`passwd -l`) after resolving an SSH-key-auth issue that had forced a temporary password. |
| 2026-09-10 | **Confirmed:** 3g dropped. Original intent was an SSH ProxyJump so Ansible/CT402 could reach OPNsense's homelab-side management IP (`.120`), which is firewall-scoped to Admin01 only. Since `polaris-backup` remains monolithic on Homelab and makes that connection itself (as it always has, with its own established access), Ansible never needs a path to `.120` at all. Also resolves the older "Open architecture question" about whether Homelab's IP is separately allow-listed on OPNsense — moot for build purposes either way, since Homelab's existing access (whatever it is) is untouched by this migration. |
| 2026-09-10 | **Working-practice lesson:** the SSH password-prompt issue traced back to a placeholder (`<paste contents of CT402's polaris-ansible-homelab.pub here>`) being copied into `authorized_keys` verbatim instead of being replaced with the real key — a silent failure with a confusing downstream symptom (surfaced later as a sudo error, not an SSH one). Going forward, any instruction containing a fill-in-the-blank placeholder gets an explicit verification step immediately after (e.g. `cat` the file, confirm it starts with `ssh-ed25519`/`ssh-rsa`) rather than trusting the substitution was made correctly. |
| 2026-09-10 | **Confirmed:** playbook retrieves the orchestrator's real log file via `slurp` (decoded with `b64decode`) rather than `fetch` — no need for a second archived copy of a file NAS01/local retention already maintains; the goal is to hand the content forward to n8n (3i/3j), not to duplicate storage. |
| 2026-09-10 | **New, distinct dependency discovered (not a regression of the earlier fix):** Admin-WS's automated backup fails whenever DC01 is powered off, even though the SSH key itself is valid. Root cause: `domain-admin` is authenticated by SSH as a **domain account**, and Windows must resolve that username against Active Directory (a live domain-controller lookup) before any credential — key or password — is even evaluated. Interactive console/RDP logon doesn't hit this because it can fall back to cached domain credentials (which requires an actual password to hash-check against the cache); SSH pubkey auth never presents a password, so there's nothing for that fallback to use, and the account-lookup step has no DC-outage resilience built in. Confirmed as a different failure mode than the original NLA/firewall issue — this time the error was a clean `Permission denied` (reached `sshd` fine), not `Connection timed out`/`No route to host` (never reached it), proving the original fix is still holding. Inherent dependency, not a bug to patch; optionally removable later by switching this specific automation credential to a **local** Admin-WS account instead of a domain one, consistent with the local-dedicated-account pattern already used for `polaris-ansible-backup`. |
| 2026-09-10 | **Idea captured for 3i:** before firing a notification for any collector failure, check the target's actual power state via the Proxmox API (already working since Phase 2). A target that's simply powered off is an expected, self-explanatory state, not a "major change" — suppress or downgrade the alert in that case rather than treating every failure as equally alert-worthy. |
| 2026-09-10 | **Confirmed:** switch Admin-WS's backup credential from a domain account to a dedicated local account (new Build Plan item 3q, after 3p). DC01's mandatory ~180-day rebuild cycle (unlicensed Server 2019) makes the domain-account dependency a real, recurring, foreseeable failure mode rather than a theoretical one — a local account removes it entirely, independent of DC01's lifecycle. |
| 2026-09-10 | **Confirmed:** 3i split into three tiers (silent / notify-batched / approval-required) rather than a flat major/routine scale, since "notify" and "block pending a decision" are different things. Full device-by-device escalation table finalized — see "3i Notification Tiering" for the complete rubric and table. Design complete; implementation (actual log-parsing + classification logic) still pending, planned alongside 3j. |
| 2026-09-10 | **Confirmed:** Firewall01 escalates, with a fourth escalation rubric reason added based on the user's own analysis: a device can qualify by *backstopping* another already-escalated boundary (Firewall01's inside interface shares the same segment as OPNsense's homelab-side interface, so it'd contain a cyberrange leak if OPNsense's isolation failed) — independent of the "high blast radius" reasoning already covering it. 3i's device classification is now fully finalized with no open items. |
| 2026-09-10 | **Significant security finding, pre-existing and unrelated to any work in this session:** Tailscale's tailnet already includes `ai`, `homelab`, `cyberrange`, `docker01`, plus the user's personal laptop and phone — but no custom ACL policy has ever been configured. Tailscale's documented default in that state is "allow all": every device can reach every other device on every port, completely independent of and invisible to OPNsense/VLAN-based isolation. This means cyberrange currently has full mesh network access to every other tailnet device, bypassing the isolation boundary entirely. **Mitigated 2026-09-10:** "block incoming connections" ("shields up") enabled on the cyberrange device. Full tag-based ACL policy redesign deliberately deferred — user's call, since cyberrange currently holds only cyber-fw01, kali01, and a base Ubuntu install, nothing sensitive/production yet. Real underlying issue, not urgent at current build state; revisit before cyberrange holds anything more valuable. |
| 2026-09-10 | CT402 joined the tailnet — Tailscale IP `100.64.0.12`. Docker's ntfy container will bind explicitly to this address, not `0.0.0.0`, to keep it reachable only over Tailscale as intended. |
| 2026-09-10 | **Key distinction identified:** Tailscale's network-layer encryption and a browser's HTTPS/secure-context requirement (needed for the Notifications API and PWA installability) are unrelated — Tailscale traffic is genuinely encrypted, but browsers can't see that and still refuse those APIs over plain `http://`. Chose to enable Tailscale's official HTTPS Certificates feature (MagicDNS + per-machine `tailscale cert`, real Let's Encrypt certs) rather than switch to a third-party desktop client, on the reasoning that it's reversible and adds no new software to trust. Trade-off accepted: the specific machine given a cert (CT402 only) becomes visible in a public certificate transparency ledger — judged fine since no machine names are sensitive. |
| 2026-09-10 | **New coverage gap identified:** gateway01 and pihole01 were deployed after the original backup framework was built and have zero backup coverage — pfsense.sh only ever covered Firewall01. gateway01 (also pfSense) can reuse the existing shared firewall-collector engine directly. pihole01's Teleporter export is confirmed CLI-capable in current Pi-hole releases (`pihole-FTL --teleporter`), so it can follow the SSH-based pattern like docker.sh/admin01.sh rather than needing Playwright. Logged as new Build Plan item 3p. |
| 2026-09-10 | **Confirmed:** Homelab's crontab currently runs `polaris-backup` via `0 2 * * *` (2:00 AM daily, no other cron entries). n8n's Schedule Trigger for 3h will be built to match this exactly. |
| 2026-09-10 | **Naming decision:** rename `pfsense.sh` to `firewall01.sh` once 3p work begins, to sit alongside the new `gateway01.sh` — avoids two same-named-in-spirit "pfsense" scripts (Firewall01 and gateway01 are both pfSense software) being ambiguous about which covers which device. Applies to the collector script, its registry entries in `polaris-backup`, and its registration call into `polaris-firewall-collector.sh`. |
| 2026-09-10 | **Reachability confirmed for 3p:** both gateway01 and pihole01 are reachable from Homelab (web GUI confirmed for both; SSH confirmed clean for gateway01). pihole01's SSH is currently blocked — see Open Items for the live troubleshooting thread. |
| 2026-09-09 | **Autonomy clarification:** user wants input into *what the rules/tiers actually allow* (defining approval-gate conditions in advance) but does not need to be looped into routine execution steps beyond the approval gates themselves — the ntfy/approval-flow touchpoints (3j/3k) are the intended single point of contact, not ongoing narration of agent activity in between. |
| 2026-09-09 | **Vision captured, not yet built:** cross-agent collaboration, now elaborated with a centralized "foreman" orchestrator agent — see new "Multi-Agent Architecture Vision" section below for the full design notes. |
| 2026-09-13 | NAS01 historical review (3m) found no unexplained coverage gaps beyond the two issues resolved the same day (3s, 3t); a same-day check of hash-detected collectors' "unchanged, no backup created" behavior was confirmed correct, not a failure, directly against the real orchestrator log — corrected an initial misread that treated it as a coverage gap. |
| 2026-09-13 | **Structural fix (3s):** validated-backup retention now never deletes a collector's last remaining backup regardless of age, fixed once in the shared `_apply_validated_retention()` function so it protects every current and future hash-detected collector automatically. Quarantine retention deliberately left unchanged — full aging-to-zero is correct there. |
| 2026-09-13 | **Admin-WS SSH stall (3t):** confirmed as a new, distinct issue from 3q's already-solved domain-account dependency via careful evidence-based elimination (reboot timing, multiplexing artifacts, an external timeout wrapper, reverse-DNS, GSSAPI, and Windows Defender real-time protection were each tested directly and ruled out in turn). Root mechanism narrowed to something inside SSH's own protocol exchange after the TCP handshake completes, with a domain-touch-during-local-logon theory as the leading (correlational, not proven) explanation. Mitigated via a raised `ConnectTimeout` (10s → 20s) and, since Admin-WS is the only collector making 50+ independent SSH connections per run, via SSH connection multiplexing (ControlMaster) — reducing both the exposure to the stall and overall runtime. |
| 2026-09-13 | **New standing guidance:** default every collector to independent, one-shot SSH connections; reach for connection multiplexing only when a single collector run needs many sequential calls to the same host, and scope `ControlPersist` tight with an explicit close at the end of the work when it's used. |
| 2026-09-13 | Confirmed, via direct `git status` and code inspection, an unrelated uncommitted change already sitting on Homelab from an earlier session: `collectors/pfsense/pfsense.sh` renamed to `collectors/firewall01/firewall01.sh`, plus a new `collectors/gateway01/gateway01.sh` — both functioning correctly per the same day's real orchestrator log, but not yet committed to git as of this session. Flagged separately from this session's own git push rather than bundled into it. |
| 2026-09-13 | **Branch protection option decided (3k):** Option B — protect `main` via Forgejo branch protection, but keep the existing human-driven deploy keys (`homelab-polaris-git`, `ct402-git-deploy`) and `lab-admin`'s own admin login able to bypass it entirely, so today's reviewed human workflow stays frictionless. The actual target of 3k's review requirement is a future *reasoning agent's* unsupervised push, not the user's own already-reviewed work. Rejected Option A (protection with no exceptions, PR required for everyone including the user) specifically because routing the user's own work through a PR would blur the line the user wants PRs to mean: "things that need my review," not routine self-approved traffic. |
| 2026-09-13 | **Design correction, self-merge:** discovered live (not designed in advance) that Forgejo blocks a user from approving their own pull request, and that merge rights are a separate whitelist from push rights. Combined with the branch protection above, this makes self-merge structurally impossible for every identity except the one explicitly whitelisted human account, regardless of tier — reframing classification's purpose from "decide if self-merge is safe" to "decide how much review scrutiny is warranted." |
| 2026-09-13 | **Design correction, merge authority:** user proposed the foreman agent could hold merge rights for routine (Tier 1) changes on the user's behalf. Reasoned through to a stronger design instead — per 3k's own original rule that push-to-main authority must be deterministic and non-AI, the foreman is itself a reasoning agent and should never hold merge credentials, even scoped narrowly. Resolved by introducing a third, dedicated identity (`polaris-merge-broker`) — separate from both the coding agent (proposes) and the foreman (discusses) — driven by a purely deterministic n8n workflow with no LLM involvement in the merge decision itself. |
| 2026-09-13 | **Standing rule for all future agent identities:** never grant an agent account push access via a write-scoped deploy key, since Forgejo's deploy-key push-whitelist toggle is all-or-nothing (any write-scoped deploy key on the repo bypasses push protection, with no way to whitelist specific keys only). Agent identities get plain collaborator accounts with Write permission instead, which carries no such bypass. |
| 2026-09-13 | **Decided:** build and fully prove the 3k merge-broker mechanism on a dedicated, permanent test repo (`Polaris-Pipeline-Testing`) using manually-created test PRs, before it ever touches `Project_Polaris`'s real whitelists or any output from a real coding agent — mirrors the same "prove the engine before adding the conductor" sequencing already used for the backup pipeline itself. The test repo is meant to be reused for future pipeline iterations too, not recreated per test. |

## Multi-Agent Architecture Vision (forward-looking, captured 2026-09-09 — nothing built yet)

This spans beyond backup automation into the broader AI-homelab project's
"agent hats" plan (see `phase2-n8n-ansible-runbook.md` Open Items and the
AI-homelab resume doc) — captured here since it came up in this thread, worth
folding into that project's own resume/handoff document whenever that thread
is next picked up.

**Orchestrator ("foreman") agent.** A centralized, user-facing agent — the
one the user personally chats with, directly analogous to this chat — that
learns over time and deploys/directs specialized sub-agents (docs,
networking, coding, backup, cybersecurity, etc.) rather than those sub-agents
coordinating with each other directly. This reframes the earlier "agent
hats" idea from a flat set of interchangeable personas into a hub-and-spoke
hierarchy with the foreman at the center.

**Recommended coordination pattern** (a starting recommendation, genuinely
open to revision as the user gets hands-on with n8n): hub-and-spoke via
n8n's already-proven "Call n8n Workflow Tool" mechanism (built and confirmed
working in Phase 2 for the Proxmox-VM-listing tool). Each specialized agent
is its own published sub-workflow behind an AI Agent node with its own
system prompt/toolset/credentials; the foreman's own AI Agent node holds one
"Call n8n Workflow Tool" per sub-agent, same as any other tool. Sub-agents
report structured results back to the foreman rather than calling each other
peer-to-peer — keeps one place where "what's happening across all agents" is
visible, reducing duplicated or conflicting work. Scaling trade-off to watch:
the foreman's own tool list grows with every sub-agent added, so tool
descriptions need to stay precise or tool selection gets noisy — manageable,
but worth monitoring as more agents come online.

**Single-approval touchpoint, elaborated for the drift-detection example:**
backup agent finds an uncovered VM → reports to foreman → foreman asks the
coding agent to draft a collector → foreman bundles "here's what was found"
+ "here's the proposed code" into one approval request (ntfy or chat) → user
approves once → foreman directs the coding agent to merge and the backup
agent to pick the new collector up on its next run. One human touch, not two.

**Sequencing recommendation:** don't build the foreman first. Prove out two
or more individual specialized sub-agent workflows on their own — the
Proxmox-VM-listing tool from Phase 2 is the first, the backup agent's own
n8n workflow (3h) will be the second — before wiring a coordination layer on
top of agents that don't exist yet.



## Switch Automation Investigation (in progress)

**Architecture decided 2026-09-09:** Playwright-driven browser automation using
the switch's **HTTP File Export** option (not TFTP) — Playwright captures the
resulting file download directly via its own API, eliminating the need for a
separate TFTP receiver on CT 402 entirely (drops the originally-planned
Build Plan 3e). Credentials stored in a restricted-permission file
(`/root/.polaris_switch_credentials`, `chmod 600`), matching the existing
SSH-key-file pattern used for pfsense/opnsense — read at runtime, never
hardcoded.

Netgear GS324TP (S350 series) confirmed: web-managed only, no SSH/CLI, SNMP is
read-only, no native scheduled backup. Only path is the Maintenance → Export
screen.

Findings from captured traffic (2026-09-09):
- Export form submits via a hidden iframe POST to `FileUpload.html/a1` —
  generic action handler shared across the UI, not a clean per-feature endpoint.
- Form fields use internal widget IDs (`v_2_3_1`, `v_2_4_1`, `submit_flag`,
  `clazz_information`, etc.), not human-readable names.
- **Session cookie (`RID`) rotates every 60 seconds** (`max-age=60`) — any
  raw-HTTP automation must log in fresh within the same run; captured/stored
  tokens are not reusable. (Not a concern for the Playwright path, which
  drives a real browser session — this only matters for the parallel HTTP
  side quest.)
- UI polls `ping.html` repeatedly while a transfer is "in progress" — export
  is async, not synchronous.

**Correction 2026-09-09:** Initially instructed the user to set up the Python
venv/Playwright/credentials on CT 402 — incorrect, conflated the *future*
Ansible/n8n control-layer location (CT 402, per earlier decision) with where
*this collector's* dependencies need to live *today*. `polaris-backup` still
runs natively on Homelab via cron (3f-3h, the actual Ansible/n8n migration,
haven't happened yet) — every collector is a bash function sourced into that
same process on that same host, so the switch collector's Python venv and
script must be co-located on Homelab too, matching every other collector's
SSH keys/credentials files. Corrected; venv setup redirected to Homelab.
Whether anything physically relocates to CT 402 will be a deliberate decision
made when 3f-3h are actually built, not an accidental side effect of this one
collector's setup.

**Decision made 2026-09-09:** Playwright is the primary/only path going
forward for the actual collector build. Raw HTTP replay via curl remains the
user's separate, non-blocking side quest for learning purposes — not part of
the critical path.

**Standalone script verified working end-to-end 2026-09-09.** Root cause of
the earlier timeout found and fixed: the "Apply" button click was incorrectly
scoped to the `maincontent` iframe in the production rewrite — the verified
`codegen` recording calls it on the outer `page`, not the iframe (the button
sits in a persistent header area outside the iframe that holds the
sidebar/form content). Fixed to match the recording exactly; also added a
defensive 1920x1080 viewport as a secondary safety net. Confirmed working:
both Text Configuration (4,618 chars, correct VLAN 10/30 config) and Tech
Support (108,207 chars) exports produced real, complete data in one browser
session. Per-step debug screenshots added during troubleshooting are being
left in for now as low-cost diagnostic insurance, pending a few clean
production runs. **Next: full orchestrator integration test** (`switch.sh` +
registry entries in `polaris-backup` were already built and delivered
earlier — pending confirmation of a clean end-to-end run promoting to
`validated/` and NAS01).

## Build Plan (phases)

- [x] **3a.** ~~Apply fix list (logging bug, pfsense.sh namespace fix, cleanup leftovers)~~ — **superseded**: original fix targeted the stale copy. Real fix (centralized tagged dual-write logging) implemented 2026-09-09 directly against the live `polaris-common.sh`, verified with a functional smoke test through the actual production code paths, not just a syntax check. Pending: user deploys and confirms a live run.
- [x] **3b.** Retire nano-ap, nano-station, switch01 from the orchestrator registry — done 2026-09-09, all 9 registries verified internally consistent programmatically. Physical script files left on disk (delete once 3c/git is set up, for a recoverable/reviewable deletion).
- [x] **3c.** Push `config-backup/` to Docker01 Forgejo, establish repo workflow — **complete 2026-09-09**. Repo: `ssh://git@192.168.10.20:2222/lab-admin/Project_Polaris.git` (private, owner `lab-admin`), dedicated deploy key (`~/.ssh/polaris-git-deploy`) with write access, `core.sshCommand` configured so this repo always uses that key. Initial snapshot commit (13 files) and follow-up cleanup commit (retired switch01/nano-ap/nano-station removed, 150 deletions) both pushed successfully. Stray `.bak`/`.pre-wave15` files removed from disk (were never tracked, `.gitignore` excluded them from commit one). Working tree now exactly matches the 6 live collectors.
- [x] **3d.** Resolve switch automation path (curl vs. Playwright), build new collector — **complete 2026-09-09**. Full orchestrator run succeeded end-to-end: all 7 collectors (proxmox, pfsense, opnsense, docker, admin01, admin-ws, switch) completed successfully, `Switch-2026-09-09-202224.tar.zst` confirmed promoted to `validated/switch/` on NAS01 with matching `.sha256`, identical pattern to every other collector.
- [x] **3n.** Build new collector: AI Proxmox host (proxmox.sh-style local collection, extending coverage beyond Homelab-only) — **complete 2026-09-14/15.** Built as a genuinely separate orchestrator (`bin/polaris-ai-backup`) and forked collector (`collectors/proxmox-ai/proxmox_ai_collector.sh`), not a modification of Homelab's own `bin/polaris-backup` — deliberately, for zero risk to production and room to diverge as the AI node's actual hardware differs from Homelab's. Writes to its own NAS01 share (`NAS-AI`), a second independent safety layer beyond the separate-orchestrator design. Proven twice manually on real hardware, integrated into a duplicated n8n workflow (three real integration bugs found and fixed along the way — see the closing 3n section below), and proven against a real deliberately-forced failure end-to-end through Classification/Tiering/ntfy. Now running unattended on the same 7 AM daily schedule as Homelab. See "3n n8n Workflow Built..." below for the full record, including two latent path-resolution bugs this exposed in the pre-existing shared framework.
- [x] **3o.** Build new collector: new Netgear switch — **complete 2026-09-09**, see 3d above
- [x] ~~**3e.** Stand up TFTP landing zone (or Playwright runner) on CT 402~~ — **no longer needed**, superseded by 3d's HTTP-export-with-direct-download approach. Checkbox corrected 2026-09-14 — this was resolved-as-unnecessary back on 2026-09-09, just never formally ticked.
- [x] **3f.** ~~Build Ansible roles/playbooks wrapping each existing collector script~~ — **complete 2026-09-10**: `run-polaris-backup.yml` triggers a full, real, 7-collector production run via Ansible, identical in effect to the cron-triggered version. "Wrapping each collector individually" turned out not to apply once `polaris-backup`'s monolithic (no per-collector selection) design was confirmed from source — one playbook targeting the whole orchestrator is the correct shape. Log-retrieval (`find`/`slurp`/`b64decode`) confirmed working via a real run's decoded, timestamped output — not just inferred, actually verified against real content.
- [x] ~~**3g.** Ansible inventory + SSH ProxyJump config for OPNsense-via-Admin01~~ — **confirmed not needed, 2026-09-10** (see Decisions Log). `polaris-backup` handles its own connection to `.120` from Homelab exactly as it always has; Ansible/CT402 never needs a path there.
- [x] **3h.** ~~n8n Schedule Trigger + sub-workflow replacing the Homelab crontab~~ — **complete 2026-09-10**: "Backup Schedule" (Schedule Trigger, `0 2 * * *`, matching real crontab) → "Run Polaris Backup" (Execute Workflow Trigger + SSH loopback → `ansible-playbook run-polaris-backup.yml`) built, published, activated, and manually tested end-to-end successfully — 6/7 collectors succeeded (Admin-WS's one failure traced to DC01 being powered off, a real infrastructure dependency, not a workflow bug). Homelab crontab not yet disabled — that's 3l's cutover step, deliberately still pending.
- [x] **3i.** Define notification/rule set for collector results — **complete.** See "3i Notification Tiering" below for the full model and device table. Checkbox corrected 2026-09-14 — the Classification/Power-State/Tiering/Urgent/Digest logic this describes has been running in production and live-tested against real failures since 3j closed on 2026-09-11; only the checkbox itself was stale. The underlying *principle* (tiering/classification thinking is reusable and should be reapplied case-by-case for future agents/collectors) remains a standing practice, not something this checkbox closes out — see the Decisions Log entry on drift-detection for the first named example.
- [x] ~~**3j.** Stand up self-hosted ntfy, wire to Tailscale, connect n8n approval notifications~~ — **complete 2026-09-11.** Full pipeline confirmed end-to-end in production: Classification → Power-State → Proxmox API → Tiering → NTFY, with real alerts (opnsense, admin01, switch config-changed) actually delivered to the phone. See 3j Implementation Notes below for the n8n container DNS fix that unblocked the final step, and 3r for a real escalation-tier correction discovered during this test.
  LXC containers need `/dev/net/tun` explicitly passed through before Tailscale will run (same category of gotcha as Phase 1's GPU passthrough) — added to `/etc/pve/lxc/402.conf` on the AI host:
  ```
  lxc.cgroup2.devices.allow: c 10:200 rwm
  lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
  ```
  then restart CT402, confirm `/dev/net/tun` exists inside the container, and only then install Tailscale.
  CT402 joined the tailnet at `100.64.0.12`. Ntfy container:
  ```
  docker run -d \
    --name ntfy \
    --restart unless-stopped \
    --security-opt apparmor=unconfined \
    -p 100.64.0.12:80:80 \
    -v /root/ntfy/cache:/var/cache/ntfy \
    binwiederhier/ntfy \
    serve --cache-file /var/cache/ntfy/cache.db
  ```
  **Note:** the first attempt at this command omitted `--security-opt
  apparmor=unconfined` and failed with `apparmor_parser: Access denied` —
  a repeat of the exact issue already documented in Phase 2 (LXC containers
  don't get `CAP_MAC_ADMIN` even when privileged; the host-level
  `lxc.apparmor.profile: unconfined` setting only stops Proxmox confining
  the container itself, not each Docker container launched inside it).
  **Standing rule going forward: every `docker run` on CT402, for any
  service, must include this flag** — this isn't ntfy-specific, it'll apply
  to anything containerized on this host from here on.
  Port bound explicitly to the Tailscale IP, not `0.0.0.0` — the deliberate
  fix for Docker's all-interfaces-by-default gotcha, keeping ntfy genuinely
  unreachable from the regular LAN. No reverse proxy or TLS layer needed —
  Tailscale's own encrypted tunnel between peers already covers that, unlike
  a raw-internet-facing deployment. Topic names no longer need to be
  obscure/hard-to-guess (the public ntfy.sh model's only real access
  control) since Tailscale itself is now the access boundary — plain names
  like `polaris-alerts` are fine. No additional ntfy-level auth (its
  optional `auth-file`/user database feature) configured for now, given the
  small, already-trusted set of tailnet devices; worth revisiting if the
  tailnet ever grows to include less-trusted devices.
- [x] **3k.** Git-based review/approval flow for AI-proposed automation-code changes — **complete 2026-09-14** (mechanism fully built and proven on the test repo; promotion to `Project_Polaris`'s real whitelists remains a deliberate, separate next step — see Open Items). Original architecture: agents get unrestricted push access to their own working branches, Forgejo branch protection locks down only the production branch (main); the component actually holding push-to-main credentials must be a deterministic, non-AI n8n workflow, never a reasoning agent; a two-tier change classification (routine/self-contained vs. intrusive/shared) governs review depth. See "3k Design" below for the original reasoning, "3k Implementation Progress" for the branch-protection/account/test-repo build, and **"3k n8n Merge-Broker Workflow: Built and Proven End-to-End"** for the full working n8n workflow — webhook, HMAC signature verification, Forgejo API integration, Tier 1 auto-merge and Tier 2/side-channel notifications, all proven against real Forgejo state changes.
- [x] ~~**3l.** Cutover: disable Homelab crontab, confirm n8n-triggered runs succeed end-to-end~~ — **complete 2026-09-11.** Homelab crontab entry removed, n8n Schedule Trigger moved to `0 7 * * *`. n8n is now the sole trigger for `polaris-backup`, fully confirmed via repeated real runs including successful urgent and digest alert delivery.
- [x] **3m.** Review real historical logs/NAS01 backup contents once available — **complete 2026-09-13.** See "3m Findings: NAS01 Historical Review" below. Surfaced two real, previously-invisible issues via direct evidence rather than assumption: a structural retention bug capable of silently zeroing out validated-backup coverage for any stable, low-change-frequency collector (3s), and a post-3q Admin-WS SSH reliability issue distinct from the original domain-account dependency (3t).
- [x] ~~**3p.** Add `gateway01` and `pihole01` as new collectors~~ — **complete 2026-09-12.** gateway01 completed 2026-09-11 (see below). pihole01's collector built via a new shared engine (`polaris-single-export-collector.sh`, sibling to the firewall engine — for devices needing a "generate export, then fetch" acquisition step rather than `cat`-ing an existing file), with comparison scoped to `etc/pihole/pihole.toml` specifically (empirically verified stable across two real no-change exports, unlike the surrounding Teleporter zip or `gravity.db`/`pihole-FTL.db`/`dhcp.leases`). Required a scoped sudoers grant (`polaris-pihole-backup ALL=(pihole) NOPASSWD: /usr/bin/pihole-FTL --teleporter`) and a `cd /tmp` before the export command, since sudo changes effective user but not working directory. Proven via two consecutive real runs (first: `new`, as expected with no prior baseline; second: `unchanged`, confirming the comparison logic genuinely works). The broader inventory-mode "changed" reliability question is resolved — see 3r below — and Switch was separately promoted from inventory mode to genuine hash-detected mode in the same session (see 3r). See the new "3p/3r Resolution" section below for full detail.
- [x] ~~**3q.** Switch Admin-WS's backup SSH account from the domain account (`domain-admin`) to a dedicated **local** Windows account~~ — **complete 2026-09-12.** `polaris-admws-backup` created as a dedicated, deliberately non-administrator local account (Administrator rights remain exclusive to `domain-admin`, which is retained for its actual DC01/CA01 administration purpose — only its SSH key grant on Admin-WS was removed). Required resolving four independent Windows permission surfaces to get full read-only inventory access without elevation: three separate WMI namespace ACLs (`root\CIMV2`, `root\StandardCimv2`, `root\Microsoft\Windows\Storage`, `root\Microsoft\Windows\TaskScheduler`), a Service Control Manager SDDL grant (`Win32_Service`/`Get-Service` are both gated here, not by WMI at all), and a deliberate, permanent decision to accept degraded data for DISM/AppX (`Get-WindowsCapability`, `Get-WindowsOptionalFeature`, `Get-AppxPackage -AllUsers`) rather than grant Administrator — see the new "3q Resolution" section below for the full decision record, including why top-down privilege carve-out doesn't produce a real boundary and the agent-authority reasoning behind holding the line here. Also found and fixed a real, pre-existing CRLF line-ending bug in this collector's remote-output parsing, and a real n8n Classification key mismatch (`docker01` vs. the real registry ID `docker`) that was silently swallowing genuine Docker01 failures. Established `polaris-<hostname>-backup` as the standing naming convention for all new/migrated credentials going forward, not just an Admin-WS-specific choice.
- [x] ~~**3r.** Investigate and fix collector change-detection reliability~~ — **fully resolved 2026-09-12, as a permanent architectural decision, not a pending fix.** OPNsense's case-sensitivity bug (below) was confirmed fixed via live re-verification and restored to its escalation tier. Separately, direct inspection of `polaris-backup` (not inference from behavior) found the real mechanism behind inventory-mode's always-"changed" behavior: `_run_admin01_collector`/`_run_docker_collector`/`_run_admin_ws_collector`/`_run_proxmox_collector` unconditionally log "Collector result: NEW_OR_CHANGED" on any success — there is no comparison logic in this path at all, not a broken one. **Decision: Admin01, Docker01, Admin-WS, and Proxmox remain failure-detection-only, permanently** — building genuine content-diffing for these devices is explicitly deferred, not scheduled, since their many-file, no-single-source-of-truth shape makes real diffing much harder than it was for a single config file. Their existing failure-escalation tiers are unaffected. **Switch was separately promoted out of inventory mode into genuine hash-detected mode** in the same session — unlike Admin01/Docker01, it already had exactly one clean, provably-stable file (`switch-configuration.txt`, confirmed byte-identical across two real no-change exports); `switch.sh` now has its own baseline-lookup/comparison scoped to that file alone, with `switch-tech-support.txt` (confirmed volatile every run) never influencing the result. A related, distinct future item was captured separately, not folded into this decision: access-origin/anomalous-traffic detection (did something reach a device that shouldn't have, as opposed to did its config change) — this belongs to the eventual networking/security agent, not Project Polaris's backup collectors, and applies to the whole infrastructure, not just the devices discussed here.
- [x] **3s.** Fix validated-backup retention so it never deletes a collector's last remaining backup, regardless of age — **complete 2026-09-13.** See "3s Resolution: Validated-Backup Retention Guard" below.
- [x] **3t.** Diagnose the intermittent Admin-WS SSH stall discovered during 3m/3q follow-up; implement SSH connection multiplexing for Admin-WS — **complete 2026-09-13, pending confirmation across further real scheduled runs.** See "3t Resolution: Admin-WS SSH Stall Investigation & Connection Multiplexing" below.

### 3f Implementation Notes

**Confirmed 2026-09-09, from reading the real `polaris-backup` source:** `main()`
never inspects `"$@"` — no `getopts`, no argument case statement, nothing.
It unconditionally loops over the full `POLARIS_COLLECTOR_IDS` registry every
invocation. This resolves the earlier open design fork: there is no
per-collector selection to design around, so the `polaris-ansible-backup`
sudoers rule (scoped to the bare `polaris-backup` command, no arguments) is
already correct as-is.

**Lock file discovered:** `/run/lock/polaris-backup.lock`, checked by
`_acquire_lock` before any collector runs; a held lock returns exit code `5`
(`POLARIS_BACKUP_LOCKED`) immediately, before touching anything. Useful
safety net during the cron/Ansible-coexistence period before 3l's cutover —
an overlap between a cron-triggered and an Ansible-triggered run fails
closed (one cleanly skips) rather than corrupting shared state. The 3f
playbook treats `rc=5` as "already running, skipped" rather than a real
failure.

**Confirmed-working playbook** (`~/ansible/playbooks/run-polaris-backup.yml`
on CT402) — first successful production run 2026-09-10, now extended with
log retrieval:

```yaml
---
- name: Run Project Polaris backup orchestrator
  hosts: homelab-node
  gather_facts: false
  tasks:
    - name: Execute polaris-backup
      command: /opt/project-polaris/config-backup/bin/polaris-backup
      become: true
      register: backup_result
      failed_when:
        - backup_result.rc != 0
        - backup_result.rc != 5   # 5 = already running (lock held), not a real failure

    - name: Note if a run was already in progress
      debug:
        msg: "polaris-backup was already running (lock held); this invocation was skipped, not failed."
      when: backup_result.rc == 5

    - name: Show orchestrator output
      debug:
        var: backup_result.stdout_lines
      when: backup_result.rc != 5

    - name: Find the most recent orchestrator log file
      find:
        paths: /opt/project-polaris/config-backup/logs/orchestrator
        patterns: "*.log"
      become: true
      register: orchestrator_logs
      when: backup_result.rc != 5

    - name: Read the most recent orchestrator log
      slurp:
        src: "{{ (orchestrator_logs.files | sort(attribute='mtime') | last).path }}"
      become: true
      register: orchestrator_log_raw
      when:
        - backup_result.rc != 5
        - orchestrator_logs.matched | default(0) > 0

    - name: Decode the orchestrator log
      set_fact:
        orchestrator_log_text: "{{ orchestrator_log_raw.content | b64decode }}"
      when:
        - backup_result.rc != 5
        - orchestrator_logs.matched | default(0) > 0

    - name: Display the orchestrator log content
      debug:
        var: orchestrator_log_text
      when:
        - backup_result.rc != 5
        - orchestrator_logs.matched | default(0) > 0
```

Notes on this addition:
- `become: true` moved off the play and onto only the tasks that need root — `find`/`slurp` need it too, since the orchestrator's log directory is root-written, same as the binary itself.
- Path (`/opt/project-polaris/config-backup/logs/orchestrator`) inferred from the documented framework layout above — confirm/correct against the real path if it differs.
- The "most recent file by mtime" approach is a practical heuristic, not a guarantee — safe today because the lock file prevents overlapping runs, so there's no ambiguity about which log is "ours." A more precise approach (capturing the exact log filename the orchestrator itself reports) is possible later if this ever becomes unreliable, but not needed yet.
- **Decision chosen:** `slurp` chosen over `fetch` — the goal is to hand this content forward (eventually to n8n for 3i/3j), not maintain a second archived copy of a file NAS01/local retention already manages.
- `slurp` always returns content base64-encoded regardless of file type — must be decoded with the `b64decode` filter or the output is unreadable.

### 3i Notification Tiering (design complete 2026-09-10)

**Key distinction driving this design:** "notify" and "requires approval before
proceeding" are not the same thing, and treating them as one flat "routine vs.
major" scale either causes constant pestering or blocks things that already
happened with nothing left to decide. Three tiers instead:

- **Tier 0 — Silent.** Nothing worth surfacing. A failure fully explained by
  the target being confirmed powered off (checked via the already-working
  Proxmox API), or a config that's genuinely unchanged from last run.
- **Tier 1 — Notify, nothing pending.** Something happened worth knowing,
  but no decision is waiting on the user — the run already completed one way
  or another. Delivered as a batched daily summary, not real-time.
- **Tier 2 — Approval required, blocks until answered.** An actual proposed
  *action* exists that shouldn't proceed without the user (a new VM detected
  with no collector, or any change to the automation's own code — the latter
  is an existing hard rule regardless of confidence, not a per-device call).

**Escalation rubric** (device qualifies for real-time Tier-1-but-urgent
treatment if any one applies — in practice, "escalate" below means
real-time notification rather than batching into the daily summary, since
none of these have a pending action to *approve*, just urgency to convey
quickly):
1. **Perimeter exposure** — sits directly between the network and the open internet.
2. **Deliberately hostile neighbor** — isolates something intentionally vulnerable by design.
3. **High blast radius on the other side** — protects something severe if compromised, regardless of exposure (root CA, domain controllers, credential stores, or the isolation boundary's own control points).
4. **Backstops another escalated boundary** — sits positioned to contain a failure of a different device that already qualifies for escalation, independent of what's directly behind it (defense-in-depth).

**Device classification (confirmed 2026-09-10):**

| Device | Real-time escalation? | Reasoning |
|---|---|---|
| Proxmox (Homelab) | Yes — failures | Hosts every VM in the homelab; highest blast radius in the topology |
| gateway01 *(3p)* | Yes — failures & config changes | Internet perimeter (rubric #1) |
| OPNsense (cyber-fw01) | Yes — failures & config changes | Isolates the deliberately-vulnerable cyberrange (rubric #2) |
| Admin01 | Yes — failures & config changes | Only host with access to the cyberrange isolation boundary (rubric #3) |
| Firewall01 | Yes — failures & config changes | Protects ROOTCA01/DC01/CA01 (rubric #3); also backstops OPNsense (rubric #4) — its inside interface shares the same `192.168.10.0/24` segment as OPNsense's homelab-side interface, so it'd contain a cyberrange leak if OPNsense's isolation ever failed |
| Switch (Netgear) | Config changes only, not failures | A failure is likely device flakiness; a config change could mean VLAN separation itself shifted |
| Docker01 | No — daily summary | Meaningful but doesn't meet any rubric reason |
| Admin-WS | No — daily summary | No documented path to the isolation boundary |
| pihole01 *(3p)* | No — daily summary | Degraded DNS/adblocking on failure, not exposure |

**Not yet implemented** — this is the design; the actual logic (parsing the
retrieved orchestrator log for per-collector `[ERROR]`/`[SUCCESS]` results
and config-changed/unchanged status, cross-referencing this table, and
checking Proxmox VM power state for the Tier 0 suppression case) is still to
be built, most naturally in n8n once 3j's ntfy delivery exists to actually
act on the classification.

### Stage 2: Daily Digest — designed and confirmed 2026-09-11

Originally scoped as needing genuine cross-run persistence (accumulate
results across multiple executions, flush on a timer) — simplified once
checked against reality: `polaris-backup` runs exactly once per day, so
there's no "across runs" to accumulate. Everything belonging in "today's
digest" already exists in the same single run that produces urgent alerts.

Implementation: Tiering tags each output item with `urgency: 'urgent'` or
`urgency: 'digest'` instead of only producing alerts. Two new nodes both
read directly from Tiering: **Urgent Items** (filters to `urgency ===
'urgent'`, feeds the existing NTFY node unchanged) and **Digest Items**
(filters to `urgency === 'digest'`, combines everything into one calm,
single message — `Priority: 2`, `Tags: clipboard`, distinct from the urgent
NTFY node's `rotating_light`/priority 5). "Digest Items" returns zero items
on a clean day, so "Digest NTFY" simply doesn't fire — same pattern as
Power-State/HTTP Request's optional-branch behavior.

**Honest limitation, on record:** this only works because backups run
once daily. If `polaris-backup` is ever triggered more than once per day
(e.g. once drift-detection exists), this would produce multiple separate
"daily" summaries instead of one true digest — real cross-run accumulation
(n8n's `$getWorkflowStaticData('global')`) would need revisiting at that
point. Also worth knowing for later: that feature explicitly does not
reliably persist during manual "Execute workflow" testing, only on real
triggers — would have complicated testing this evening had it been needed.

**Live-tested and confirmed 2026-09-11**, not just designed: powered off
DC01 (leaving Admin-WS itself running) to reproduce the earlier
domain-account/AD dependency failure on purpose — a real Admin-WS failure
that's neither silenced (Admin-WS itself wasn't off) nor escalated
(Admin-WS isn't failure-tier). Landed exactly in Digest Items → NTFY
"Digest" as designed: message listed `admin-ws`, priority `2`, tag
`clipboard`, urgent branch correctly empty. **Both branches of the full
Stage 1 + Stage 2 pipeline are now proven against real failures, not just
clean-run behavior.**

### 3p Notes: gateway01 and pihole01

**gateway01** is also pfSense software (per the Network Topology Reference)
— just a second, separate instance from Firewall01, added to the house
network after the original backup framework was built. Since `pfsense.sh`
and `opnsense.sh` are already thin wrappers around a shared, table-driven
`polaris-firewall-collector.sh` engine (`polaris_register_firewall_collector()`
taking host/user/ssh-key/remote-path as parameters), adding gateway01 should
be low-effort: a new registration entry plus a thin wrapper script mirroring
`pfsense.sh`, using the same shared engine — no new mechanism to design.

**pihole01** — confirmed 2026-09-11 to be **CT 108, an LXC container on
Homelab** (not a physical device, an earlier assumption). SSH access
resolved (see Decisions Log) — dedicated `polaris-pihole-backup` account
created and confirmed working, same pattern as every other collector.
Checked current (2026) Pi-hole documentation rather than
assume: recent official Pi-hole release notes (Feb/Apr/Jul 2026, FTL
v6.5–6.7 era) confirm Teleporter — Pi-hole's built-in config export — has a
genuine **command-line path**, `pihole-FTL --teleporter`, not just a web-UI
button. That means pihole01 can likely follow the same SSH-based pattern as
`docker.sh`/`admin01.sh`/`admin-ws.sh` (SSH in, run the export command,
retrieve the resulting archive) — **no Playwright/browser-automation needed**
here, unlike the Netgear switch, which genuinely had no CLI path at all.
Exact flags and output file location should be verified directly against
the real pihole01 host before building, rather than assumed from
documentation alone.

### 3p/3r Resolution (2026-09-12)

**pihole01 collector.** Built via a new shared engine,
`polaris-single-export-collector.sh` (sibling to `polaris-firewall-collector.sh`,
which was left completely untouched — this is a new file, not a modification
to proven, live code). Used for devices where a remote command must be *run*
to generate a fresh export artifact, rather than `cat`-ing an already-existing
stable file. pihole01 registration (`pihole.sh`): host `192.168.30.2`, export
command `cd /tmp && sudo -u pihole pihole-FTL --teleporter` (the `cd /tmp` is
required because sudo changes effective user but not working directory, and
Teleporter has no output-path flag of its own), staged artifact name
`pihole-teleporter.zip` (dropping Teleporter's own embedded timestamp),
comparison scoped to `etc/pihole/pihole.toml` only.

Comparison scope was decided empirically, not assumed: two real Teleporter
exports taken ~2 minutes apart with no real config change produced different
whole-zip hashes (zip containers aren't byte-deterministic), but identical
`pihole.toml` hashes when extracted and compared directly. `gravity.db`
(compiled blocklist DB, likely rebuild-volatile but untested),
`pihole-FTL.db` (query log, certain to vary every run), `dhcp.leases` (live
lease state) are all backed up as part of the full zip but deliberately
excluded from the comparison. Access required a scoped sudoers rule
(`polaris-pihole-backup ALL=(pihole) NOPASSWD: /usr/bin/pihole-FTL
--teleporter`) — Pi-hole's config files are `pihole:pihole`-owned per its own
documented access model, not a misconfiguration. NAS backup prefix: `Pihole`
(capitalized, no hyphen, matching the project-wide convention — chosen
deliberately given this project's history with prefix case-sensitivity bugs).
Proven via two consecutive real runs: first reported `new` (no prior
baseline, expected), second reported `unchanged` (real proof the
baseline-lookup and comparison both work, not just that the pipeline runs).

**Switch promoted to genuine hash-detected mode.** Unlike Admin01/Docker01,
Switch already had exactly one clean, provably-stable file
(`switch-configuration.txt`) with no comparison logic ever built around it —
confirmed via direct code reading that `switch.sh` had zero baseline/compare
functions and `_run_switch_collector` unconditionally mapped success to
`NEW_OR_CHANGED`, identical to Admin01's pattern. Added `_locate_baseline`/
`_compare_configuration` to `switch.sh`, scoped strictly to
`switch-configuration.txt` — `switch-tech-support.txt` (confirmed volatile:
different hash, different byte count across two real back-to-back exports
with zero real device change) is still collected and backed up on every
promoted run, but never influences the changed/unchanged decision. Also
found and fixed a real bug in the corresponding `_run_switch_collector`
baseline-lookup: it copied the firewall engine's `-mindepth 3 -maxdepth 3`
pattern verbatim without re-deriving it for Switch's actual (one level
deeper, `configuration/switch/...`) directory structure — `find` with a
non-matching exact depth silently returns nothing rather than erroring,
so every run was scored `new` until corrected to `-mindepth 4 -maxdepth 4`.
Verified via direct `sha256sum` comparison of the two real config files
(matched) before applying the fix, ruling out a real config change
coincidentally masking the bug. Proven via a clean third run reporting
`unchanged` after the fix.

**Docker01/Admin01/Admin-WS/Proxmox — permanent decision, not a pending
fix.** See the updated 3r entry above. `POLARIS_COLLECTOR_INVOCATION_MODES`
also has a small, harmless, purely cosmetic bug worth fixing during a future
cleanup pass — `gateway01`'s entry is set to the literal string
`"_run_gateway01_collector"` instead of `"hash-detected"`; this table is
documentary only and isn't read anywhere else in the code.

**Real n8n bug found and fixed while verifying pihole/Switch's Classification
behavior**: the `collectors` lookup table in Classification used the key
`docker01`, but `polaris-backup`'s real registry ID (and therefore its actual
log tagging) is `docker`. A genuine Docker01 failure would have matched none
of Classification's status checks, fallen through to `status: 'unknown'`,
and been silently dropped by Tiering (which only branches on `'failed'`/
`'changed'`) — **producing no notification at all.** Fixed by correcting the
key to `docker` (Tiering's own `tierTable` already used the correct key, so
this was Classification-only).

**n8n "Run Confirmation" heartbeat, added and then fixed.** Built to solve a
real gap: a fully clean day produces zero notifications today (Digest Items
returns `[]` when nothing is digest-worthy, and n8n never executes a
downstream node on zero input items), meaning there was no way to distinguish
"ran cleanly" from "never ran at all." Deliberately built as an independent
branch off Tiering rather than modifying Digest Items' existing filter logic,
per the user's explicit requirement that it stay easily removable/
interchangeable once the richer per-agent foreman summary exists later.
**First wiring was wrong** — connected downstream of Tiering, which only
outputs items needing escalation, so on a clean day this branch never
executed either, for the exact same reason Digest Items was silent in the
first place. Fixed by rewiring the trigger to Classification (which always
produces exactly one output item every real run); no code change was needed
inside the node itself, since its logic already looks up both Classification
and Tiering by name (`$('NodeName').all()`) regardless of what triggers it.
Confirmed working: real "Polaris Run Confirmation" notification received,
"Backup run completed — 9/9 collectors reported, 0 urgent."

**pihole Tiering decision**: `{ failure: true, change: false }`, deliberately
**not** added to the Power-State-checked list (unlike Proxmox/pfSense/
Admin01). Reasoning: pihole is the house's primary DNS — a failure is urgent
for operational-continuity reasons (the user may need to personally switch
the house to an alternate DNS/connectivity path), not a security-boundary
reason, making this a fifth escalation category distinct from the original
four (perimeter exposure/hostile-neighbor isolation/high blast radius/
backstops an escalated boundary). Power-State's whole purpose (suppress an
alert when "powered off" benignly explains the failure) inverts for this
specific device — if pihole01 being off *is* the emergency, silencing on
that basis would suppress the one scenario that matters most.

**NAS01-unavailable behavior, confirmed by reading
`_process_collector_lifecycle` directly**: the local archive is created and
preserved *before* NAS availability is even checked, so a NAS outage never
loses a backup. However, the lifecycle function's non-success return in that
path causes `main()`'s dispatcher to log `[ERROR] [<collector_id>]` — the
exact string Classification matches for "failed." **Practical effect: if
NAS01 is down during a run, every collector that completed its own
collection successfully still gets externally reported as "failed."**
Accepted as-is (2026-09-12 decision) — under this project's working
definition of "urgent" (go verify severity, not "drop everything now"),
several devices failing in the same run is itself a strong hint to check
NAS01 first. A new, not-yet-scheduled future item was captured: a
maintenance-mode sentinel file `polaris-backup` could check for, to route
straight to local-archive-only without ever hitting the error-tagging path,
for whenever NAS01 needs planned downtime.

**Future item, captured for the eventual networking/security agent (not
Project Polaris's scope), broad to the whole infrastructure**: access-origin/
anomalous-traffic detection — did something reach a device that shouldn't
have, as distinct from did a device's config change. Best signal source
would be the boundary devices' own logs (OPNsense/Firewall01/gateway01), not
the target devices' own auth logs. Checked directly: none of this is
currently collected anywhere (`admin01.sh` only captures `authorized_keys`
contents, nothing about actual login history/source IPs). Would slot into
the existing Classification → Tiering → ntfy pipeline as a new trigger
condition, not a parallel system. Same underlying gap as the once-daily
(not continuous) alert cadence, also captured as a future item explicitly
tied to the eventual multi-agent "foreman" architecture rather than
something to force into the daily-batch backup framework.

### 3q Resolution (2026-09-12)

Full technical detail (exact SDDL strings, exact WMI namespace paths, exact
PowerShell command changes) lives in `admin-ws.sh` itself and in this
session's chat log — captured here is the decision record and the
reasoning, since that's the part worth not having to re-derive later.

**Four independent permission surfaces**, each requiring its own distinct
fix, found by getting the real, isolated error text for each new failure
before proposing a fix rather than generalizing from the previous fix's
shape:

1. **WMI namespace ACLs** — `root\CIMV2` (legacy `Win32_*` classes),
   `root\StandardCimv2` (modern networking module — `Get-NetAdapter`,
   `Get-NetFirewallProfile`, etc.), `root\Microsoft\Windows\Storage`
   (`Get-Disk`/`Get-Partition`/`Get-Volume`), `root\Microsoft\Windows\
   TaskScheduler` (`Get-ScheduledTask`). Each granted only Execute Methods/
   Enable Account/Remote Enable — narrow, not full namespace control.
2. **DCOM Launch/Activation** — Storage Management Service's actual
   provider is DCOM-hosted, separate from the namespace grant above.
   Deliberately not pursued (would require a machine-wide COM Security
   default change) — `Get-Disk`/`Get-Partition`/`Get-Volume`/
   `Get-StoragePool` fail soft instead, falling back to `Win32_LogicalDisk`/
   `Get-PSDrive` (already present in the same collector) for basic drive
   visibility.
3. **Service Control Manager security descriptor** — `Get-CimInstance
   Win32_Service` AND `Get-Service` are both gated here (both ultimately
   open the same SCM handle). Root cause, confirmed via Microsoft's own SCM
   documentation: non-interactive network logons (SSH sessions) are
   excluded by default from the enumerate right Windows grants to
   interactive/service-logon sessions, for any non-admin account. Fixed via
   one additive SDDL entry (`(A;;CCLCRPRC;;;<SID>)`) granting this
   account's specific SID the same rights already granted by default to
   Interactive Users/Service accounts — not broadened to Administrators.
   `sc.exe`, not `sc` (aliased to `Set-Content` inside PowerShell), is
   required. The change took a short but real amount of time to propagate —
   an immediate retest can still show Access Denied even when the change is
   correct.
4. **DISM's hard elevation check** (`Get-WindowsCapability`,
   `Get-WindowsOptionalFeature`) and **`Get-AppxPackage -AllUsers`**'s
   identical, separately-documented requirement — unconditional, binary
   elevation gates with no scoped ACL equivalent, unlike 1-3 above.

**The DISM/AppX decision record** (the most substantial discussion of the
day, worth preserving in full):

- The framework's actual purpose was named explicitly: enabling a clean VM
  rebuild after catastrophic data loss, not security monitoring (already a
  separate future item for the networking/security agent).
- Real risk specific to this gap: OpenSSH Server itself is a Windows
  Capability — this account's own access method. A rebuild that forgets to
  re-enable it loses access the same way it was gained. No automated
  safeguard exists for this; tracked manually for now, since capability/
  feature changes are rare, deliberate, human-triggered actions (unlike
  constantly-drifting installed software), making a short manual note far
  more tractable here.
- Three options were considered explicitly: Administrator, graceful
  degradation, a middle tier. The middle tier does not actually exist for
  this specific gap — DISM's elevation check and `-AllUsers`'s requirement
  are both unconditional binary gates, unlike the SCM's graduated ACL model
  that made a real middle tier possible for services.
- **Network-level mitigation (IP-scoping via Windows Firewall + sshd `Match
  Address`) for the Administrator option is real and would work** — but it
  only addresses leaked-credential/external-attacker risk. It does not
  address the separately-raised concern: agent authority boundaries. An
  admin-scoped backup credential blurs "backup/inventory agent" and "agent
  with system-level authority" as separate tiers, independent of network
  exposure.
- **Top-down privilege carve-out (grant broad, restrict specific files/
  folders afterward) does not produce a real boundary, on either axis.**
  Windows (and Linux/root, identically) grants Administrator the inherent
  right to take ownership of any object and rewrite its own ACL — a Deny
  rule placed against an admin account is not a wall, since the same
  account can remove it. Bottom-up scoping (narrow rights granted to a
  non-admin account on objects it doesn't own and can't rewrite) is the
  only approach that produces a boundary enforceable independent of the
  account's own cooperation. General principle, likely to recur — worth
  referencing directly rather than re-deriving next time.
- **Agent-side tool-call boundaries are a real, distinct mitigation for the
  agent-authority concern specifically — but don't apply today.** An AI
  agent restricted to calling a small number of fixed, human-written,
  narrowly-scoped functions (as this project's n8n "Call n8n Workflow Tool"
  pattern already does) never gets the chance to misuse a credential beyond
  what that fixed function does, regardless of the credential's own
  underlying privilege level. Real and valuable, but it defends against a
  *reasoning* agent overreaching — it does nothing for credential leakage,
  and doesn't change today's decision, since `admin-ws.sh` is a fixed,
  human-written, non-agentic script; there is no reasoning agent in this
  loop yet.
- **Decision: graceful degradation, permanent.** Explicitly scheduled for
  re-review at two future trigger points: when the multi-agent "foreman" is
  built and any dynamic agent gains a role in Admin-WS's own automation
  (the tool-boundary mitigation becomes relevant), and more generally when
  agentic deployment begins in earnest.

**Real, pre-existing CRLF line-ending bug found and fixed** (not introduced
this session, but propagated into new code before being caught). PowerShell's
native output uses CRLF; nothing in the shared `polaris_ssh_execute_to_file`
(used by every collector) normalizes this, since Admin-WS is the only
Windows target. Silently broke every `grep -qx` exact-match marker check and
every `awk` last-field comparison (`$NF == "Installed"`, etc.) throughout
this collector — e.g. `WinGet Availability` had been reporting `Available`
with 0 packages on every real run this collector has ever made, when the
correct answer was `Unavailable`. Caught because the user directly verified
the summary's claim against an identically-constructed manual test rather
than accepting it at face value. Fixed once, centrally, in `admin-ws.sh`'s
own `_admin_ws_remote_execute_to_file` wrapper — deliberately not in the
shared `polaris_ssh_execute_to_file`, which is proven for every other,
non-Windows collector and doesn't need this correction.

**Credential cleanup**: `domain-admin`'s SSH key grant removed from
Admin-WS's `administrators_authorized_keys` (the account itself retained —
it remains the primary DC01/CA01 administration identity, used for other
purposes). Confirmed via direct key-content comparison, before removal, that
the single key present was in fact `polaris-admin01-backup`'s public key and
nothing else.

### 3k Design (2026-09-12)

Full reasoning captured in the chat log for this session; summarized here as
the decision record. **Nothing described in this section has been built —
see the updated 3k checklist entry above.**

**Git flow**: agents get unrestricted push access to their own working
branches (e.g. `agent/fix-123`); only the production branch (main) is
Forgejo-branch-protected. Pushing to a scratch branch is fundamentally
lower-risk than pushing to main — nothing goes live — so no per-push
approval is needed there, and Forgejo's own commit/compare view serves as
the review surface for free (a separate PR-with-review-comments system was
considered and rejected as unnecessary overhead). The component actually
holding push-to-main credentials must be a deterministic, non-AI n8n
workflow, never a reasoning agent — an LLM-driven agent can in principle be
talked into overreaching via a bad prompt; a fixed, scripted workflow cannot
be talked into anything. The foreman stays the single conversational thread
the user talks to, bundling findings and proposed changes into coherent
updates, but never itself holds git-write credentials — same "Call n8n
Workflow Tool wraps SSH" pattern already used for the AI Agent's existing
tool access.

**Review cadence**: daily/batch digest (generalizing the Run Confirmation
heartbeat pattern to this second domain), not per-commit ceremony — a plain
link into Forgejo's own diff view for whenever the user wants to look, not a
notification per individual change.

**Two-tier change classification**, grounded in what actually happened
during this session's real work rather than invented abstractly: Tier 1
(routine, self-contained — a genuinely new, isolated file, e.g. today's
`pihole.sh`) can run its own checks and push freely, plausibly eligible for
self-merge with an FYI-only notification once proven out. Tier 2 (intrusive,
shared, or security-relevant — anything touching an already-deployed shared
file like `polaris-backup`/`polaris-common.sh`/`polaris-firewall-collector.sh`,
or anything changing credentials/permissions/security posture) requires
mandatory human push-to-main regardless of automated checks passing, no
self-merge ever.

**Credentialing model — two patterns, not mutually exclusive**: a dedicated
narrow account per job/system (the existing `polaris-<hostname>-backup`
pattern) for recurring, well-understood needs tied to one system; a
specialized credentialing broker — a deterministic component holding one or
more credentials behind a small, fixed menu of pre-approved actions — for
new/occasional needs where standing up a full dedicated identity per one-off
ask would be disproportionate. The git push-mechanism above is a specific
instance of this general broker pattern, independently re-derived from the
git-flow discussion before being recognized as the same shape. Trade-off
named explicitly: many narrow credentials are individually lower-stakes but
more work to stand up one at a time; a centralized broker is easier to
manage but becomes a bigger prize if it's ever the thing that fails. Decided
to use both, matched to the situation, provided the broker's own action menu
stays narrow and specific — never a general "do anything with what I'm
holding" capability.

**Notification/approval architecture: ntfy primary and self-hosted;
Telegram is a deliberate, narrow exception, not a 50/50 split.** ntfy's
action-button mechanism (`view`/`http`/`broadcast`, tappable directly from
lock screen/notification tray with no app-opening required, uniform across
phone/desktop/web) is confirmed real, validated against a working
real-world precedent (a Home Assistant community pattern using this exact
"quick decision via tappable buttons that fire a webhook an automation is
waiting on" shape). Its real limit: buttons are a small, fixed menu decided
when the notification is composed — no free-text reply. Telegram's Bot API
is a strict superset of what's needed (genuine free-text replies, richer
inline menus, confirmed real simultaneous multi-device delivery), so
capability was not the deciding factor — the deciding factor was that ntfy
stays entirely self-hosted and inside Tailscale end to end, matching this
project's consistent self-hosting-first posture, while Telegram is
third-party and cloud-routed. Decision: default to ntfy for anything that
fits a short menu or a status report; reach for Telegram only for
interactions that genuinely require free text. The same tap-to-act webhook
mechanism doubles as the actual git push-approval surface itself ("Approve &
Push to Main" / "View Diff in Forgejo" buttons on the daily digest) — the
review-surface design and the git-mechanism design converge into the same
wiring. **Not yet done, flagged as a prerequisite before finalizing reliance
on ntfy as primary**: a live, on-device test of ntfy action buttons,
specifically confirming the phone has Tailscale actively connected (not just
installed) at the moment a button is tapped away from home. Specific
notification menu wording for actual future scenarios (VM discovery, code-
push approval, etc.) was deliberately not designed yet — agreed this depends
too heavily on the specific scenario and on real-world testing of the ntfy/
Telegram split to be worth designing in the abstract now.

### 3m Findings: NAS01 Historical Review (2026-09-13)

**Methodology.** Rather than a general "look around," this review compared,
per collector, the most recent `validated/` timestamp against the most
recent real scheduled-run date, using a full NAS01 directory tree pull plus
the real orchestrator logs for the days in question — matching this
project's established practice of verifying against real evidence rather
than inferring from summaries or dashboards alone.

**Initial false alarm, corrected via direct log evidence.** OPNsense,
Firewall01/pfSense, gateway01, and Pihole all showed no new `validated/`
entries for several days, which was initially read as a real coverage gap
(four Tier-2-relevant collectors going silent with nothing flagging it).
Direct inspection of the real 09-13-070001 orchestrator log disproved this:
all four collectors ran successfully every day; they correctly detected
their configuration as unchanged and correctly produced no new backup
artifact — exactly the intended behavior for hash-detected collectors, not
a failure. The daily ntfy heartbeat ("9/9 collectors reported, 0 urgent")
the user had already been receiving was accurate the whole time. Logged
here as a documented near-miss: a healthy hash-detected collector and a
silently broken one look identical from `validated/` timestamps alone,
without also checking the orchestrator log directly.

**Real finding, surfaced by the same review: retention-by-age has no
floor.** Reading the actual retention log lines for that same run revealed
that `_apply_validated_retention` deletes any validated-backup directory
older than its configured window, purely by age, with no awareness of how
many backups a collector currently has. For an actively-changing collector
this is harmless (a new backup always exists before the old one ages out),
but for a stable, hash-detected collector — exactly the profile of a
well-secured firewall — it means the single backup on hand keeps aging
toward deletion with nothing ever replacing it, and nothing in
Classification/Tiering positioned to notice before the last copy is gone.
OPNsense's 7-day NAS01 window made this concrete and immediate: its only
backup was already partway through that window at the time of this review.
See **3s Resolution** below.

**Adjacent, unrelated finding surfaced in the same working session: a real
Admin-WS regression.** While confirming the retention fix, a same-day
Admin-WS failure (reported via the existing Tier-1 daily-summary heartbeat,
working exactly as designed) turned out not to be the already-solved
domain-account/DC01 dependency from 3q, but a new, distinct, intermittent
SSH-level stall. Investigated and mitigated; see **3t Resolution** below.

**Clean bill, everything else.** No other coverage gaps were found across
Admin01, Docker01, Proxmox, or Switch for the reviewed window. `incomplete/`
directories were confirmed empty across the board — no orphaned,
partially-collected artifacts anywhere on NAS01 needing cleanup or recovery.

### 3s Resolution: Validated-Backup Retention Guard (2026-09-13)

**Root cause, confirmed by reading the real code, not inferred from
behavior:** `_apply_validated_retention()` in `bin/polaris-backup` enumerates
every subdirectory of a collector's local and NAS01 `validated/` directory
older than its configured retention window (`POLARIS_LOCAL_VALIDATED_RETENTION_DAYS`
= 30, `POLARIS_NAS_VALIDATED_RETENTION_DAYS` = 7) via `find ... -mtime "+N"`,
and unconditionally `rm -rf`s every match. There is no check anywhere in
this path for how many validated backups currently exist. For any collector
whose configuration goes stable for longer than its retention window — the
intended, desired state for a well-secured device, not an edge case — this
means the single remaining backup ages out with nothing behind it, and
nothing downstream (Classification, Tiering, the daily heartbeat) is
positioned to notice, since from the pipeline's point of view nothing
"failed" that day.

**Scope decision.** The fix applies to `_apply_validated_retention()` only,
not `_apply_quarantine_retention()`. Quarantine holds failed/rejected copies
pending review, not last-known-good state — letting it age fully to zero is
correct, intentional behavior and was left untouched.

**Fix implemented and deployed 2026-09-13.** Before deleting anything in
either the local or NAS01 leg, the function now identifies the single most
recent validated-backup directory (by name — the `Device-YYYY-MM-DD-HHMMSS`
naming convention sorts correctly as plain text) and unconditionally skips
it in the deletion loop, regardless of age. This is generalized, not
device-specific: because it lives in the one shared function every
collector's retention pass calls, it protects OPNsense, Firewall01/pfSense,
gateway01, Pihole, and Switch automatically, with no per-collector code
needed, and will protect any future hash-detected collector the same way
without further changes.

**Verified with real evidence, not just code review.** A live test forced
the exact failure condition: `touch -d "60 days ago"` on gateway01's only
NAS01 validated backup (the lowest-blast-radius real target available,
since it already had exactly one backup), followed by a real n8n-triggered
production run. The orchestrator log for that run shows the new guard
firing exactly as designed:
```
[093320] [INFO] Skipping removal of Gateway01's most recent NAS01 validated backup (last remaining copy is protected regardless of age): .../Gateway01-2026-09-11-131105
```
The backdated directory was left in place afterward; no further action
needed — it will be replaced naturally whenever gateway01's configuration
next actually changes.

**Files changed:** `bin/polaris-backup` only (`_apply_validated_retention`
function). Backed up pre-change as `bin/polaris-backup.pre-retention-fix.bak`
on Homelab before editing (not tracked in git, matches established `.bak`
convention).

### 3t Resolution: Admin-WS SSH Stall Investigation & Connection Multiplexing (2026-09-13)

**Trigger.** A same-day Admin-WS failure surfaced via the existing Tier-1
daily-summary ntfy notification during the 3m review — the heartbeat/digest
pipeline itself worked exactly as designed in catching and reporting it.
Initial assumption was a recurrence of 3q's already-solved domain-account/
DC01 dependency; this was investigated and ruled out early, since Admin-WS
was confirmed powered on and had been for a meaningful period at the time
of failure.

**Ruled out, in order, each via direct evidence rather than inference:**
1. **Reboot-timing / cold-start delay** — falsified by the user directly:
   identical failures reproduced with the VM already up ~30 minutes, both
   logged in and logged out.
2. **SSH connection multiplexing already masking/causing inconsistent
   manual-test results** — checked directly; `ssh -O check` confirmed no
   ControlPath was configured anywhere prior to this fix, so manual tests
   were always genuine fresh connections.
3. **An external `timeout` wrapper around the SSH call causing a
   mid-command cutoff** — checked directly in `polaris_ssh_execute()`; no
   such wrapper exists. The only time-bound present was `-o ConnectTimeout`,
   which (in the client's OpenSSH 10.0p2) also covers waiting on the
   server's initial protocol banner, not just the raw TCP handshake — this
   became the actual explanation for the observed failures once combined
   with finding #6 below.
4. **Reverse-DNS lookup delay at connect time (`UseDNS`)** — checked
   directly on Admin-WS; `UseDNS` was unset, meaning OpenSSH's compiled-in
   default (`no`, since v6.8) was already in effect. Ruled out.
5. **GSSAPI authentication triggering a domain-controller round-trip during
   protocol negotiation** — checked directly; `GSSAPIAuthentication no`
   confirmed in `sshd_config`. Ruled out.
6. **Windows Defender real-time/network inspection** — tested directly by
   temporarily disabling `Set-MpPreference -DisableRealtimeMonitoring
   $true`, then re-running the same SSH loop that had already shown stalls.
   The stall recurred (two occurrences in 90 attempts across three runs,
   both ~12.5 seconds) with real-time protection fully off. Ruled out;
   protection was re-enabled immediately after the test.
7. **Network/transport-layer instability (virtio NIC driver, host-side
   contention)** — tested directly with a raw TCP-only connection loop to
   port 22 (bypassing the SSH protocol entirely via `/dev/tcp`), 60
   attempts across two runs, every single one landing in the 3-4ms range
   with zero outliers. Ruled out — the stall is confirmed to live inside
   SSH's own protocol exchange, after the TCP handshake completes.

**Direct evidence obtained, not just elimination.** The Windows OpenSSH
operational log for the failure windows showed `sshd: banner exchange:
... Connection aborted` entries at times matching the client-side stalls —
the earliest possible point in the SSH protocol, before authentication or
any command execution. Windows Security-log logon events (4624/4625) for
`polaris-admws-backup` correlated, at one-second display resolution, with
an observed 12.47-12.58 second stall recurring three separate times across
the investigation.

**Leading theory (correlational, not proven at the OS-mechanism level):**
Admin-WS is domain-joined; LSA's handling of a local account's logon on a
domain-joined host can involve a background domain-controller-reachability
check independent of the SSH-level authentication method. An occasional
slow answer to that check would produce exactly this signature — mostly-
instant logons, with a rare, consistently-timed stall. This is a plausible,
evidence-consistent explanation, not a confirmed root cause; it does not
need to be resolved further for the mitigations below to be effective,
since both work regardless of the underlying mechanism.

**Mitigation 1 — raised connect timeout.**
`POLARIS_ADMIN_WS_SSH_CONNECT_TIMEOUT` in `collectors/admin-ws/admin-ws.sh`
raised from 10 to 20 seconds — comfortable headroom over the worst observed
stall (12.58s), without being excessive. This is symptom mitigation,
explicitly named as such: it makes an individual stall survivable, it does
not reduce how often one occurs.

**Mitigation 2 — SSH connection multiplexing (ControlMaster), addressing
exposure rather than the stall itself.** Admin-WS is structurally unlike
every other collector: it opens a fresh, independent SSH connection for
every one of its 50+ individual remote commands per run (confirmed via the
sheer number of `_admin_ws_remote_execute_to_file` call sites), rather than
the handful of connections other collectors make. That means Admin-WS's
odds of encountering the stall at least once in a given run are far higher
than the underlying per-connection odds alone, purely from having so many
chances to hit it. Multiplexing collapses this exposure from 50+ connections
down to effectively one shared session per run.

**Design, implemented additively across three files, deployed 2026-09-13:**
- `lib/polaris-common.sh`: `polaris_ssh_execute()` and
  `polaris_ssh_execute_to_file()` each gained one new, optional, trailing
  parameter — a control-socket path, defaulting to empty. Every other
  collector's existing call sites (Admin01, Docker01, gateway01,
  pfSense/Firewall01, OPNsense) are provably unaffected, since they simply
  never populate it. Two new functions were added:
  `polaris_ssh_open_control_master()` and `polaris_ssh_close_control_master()`.
  `ControlMaster=auto` (not `=yes`) was used deliberately so the feature
  fails open: if a master session isn't available for any reason, an
  individual call simply falls back to an ordinary independent connection
  rather than erroring the collector.
- `collectors/admin-ws/admin-ws.sh`: `_admin_ws_remote_execute()` and
  `_admin_ws_remote_execute_to_file()` now read one script-scoped variable,
  `POLARIS_ADMIN_WS_SSH_CONTROL_PATH` (empty by default), rather than
  needing the new parameter threaded through all 50+ individual call sites.
- `bin/polaris-backup`: `_run_admin_ws_collector()` builds a unique per-run,
  per-process control-socket path under `POLARIS_TEMP_DIR` (keyed by run
  timestamp and PID), opens the master session, sets the variable, calls
  `collect_admin_ws()` exactly as before, captures its result, then
  unconditionally closes the master session and unsets the variable — all
  before the existing success/no-change/error branching, which was left
  completely untouched. `ControlPersist=30` provides an automatic-expiry
  safety net independent of whether the explicit close succeeds.

**Verified with real evidence.** A live test run's OpenSSH operational log
on Admin-WS showed the connection pattern collapse from dozens of
rapid-fire accept/disconnect pairs (pre-fix) to two connections total for
the entire run: one long-lived session (~79 seconds, covering the great
majority of the run) and one very brief early connection, consistent with
`ControlMaster=auto`'s fail-open behavior catching one call issued just
before the background master finished establishing — not a defect, and not
one requiring same-day action. Cross-referencing the orchestrator's own log
confirmed both connections belonged to a single, uninterrupted collector
run (91 seconds total elapsed, most of it inside the one long-lived SSH
session), and the n8n workflow's own execution record confirmed the run
was triggered exactly once, ruling out an overlapping second invocation as
an alternate explanation.

**Honest status: mitigated and verified mechanically working, not yet
proven against a real recurrence of the original stall.** Neither of the
two live test runs happened to hit the stall condition. The real proof will
come from ordinary operation over the following several scheduled runs —
either the stall doesn't recur, or it does and is fully absorbed by the
combination of far fewer connection attempts and a much wider timeout
margin.

**New general guidance captured for future collectors/agents**, worth
keeping independent of this specific fix: default to independent, one-shot
SSH connections per command — this remains correct and simplest for the
majority of collectors, which only ever make a handful of calls per run.
Reach for connection multiplexing specifically when a single unit of work
needs many sequential calls to the same host in one run. When it's used,
scope `ControlPersist` tight (30 seconds used here) and close the session
explicitly at the natural end of the work, rather than relying on the timer
alone — but always keep the timer as the real safety net underneath, since
it guarantees cleanup even from an error path an explicit close doesn't
cover.

**Security note, considered and accepted deliberately.** Multiplexing's
control socket is a local Unix socket file on Homelab, never exposed over
the network; anything with local access to that socket for the short window
it exists could act as the already-authenticated `polaris-admws-backup`
session without needing the private key again. Given the account is already
deliberately non-administrative and narrowly scoped (per 3q), and the
socket is scoped to Homelab's own already-root-trusted filesystem (the same
trust boundary every credential file and cron/Ansible/SSH-key in this
project already lives inside), this was judged an acceptable, bounded
widening rather than a new class of exposure.

**Files changed:** `lib/polaris-common.sh`, `collectors/admin-ws/admin-ws.sh`,
`bin/polaris-backup`. Each backed up pre-change (`.pre-controlmaster.bak`
suffix) before editing.

### 3k Implementation Progress (2026-09-13/14)

Work began turning the 3k Design above into real, tested infrastructure.
**Two design decisions changed during this work**, both improvements over
the original design, captured here rather than silently edited into the
original "3k Design" section above (which is left as the historical
record of the reasoning that led here).

**Design change 1 — self-merge eligibility is now structurally moot, not
a per-tier judgment call.** The original design had Tier 1 (routine)
"plausibly eligible for self-merge." Once real branch protection was
built and proven (below), it turned out Forgejo enforces something
stronger by default: **no account can approve its own pull request**,
full stop, and merge rights are a separate whitelist from push rights.
Combined, this means self-merge is impossible for every identity except
the one explicitly whitelisted human account (`lab-admin`), regardless of
tier. Classification's job is therefore no longer "decide if self-merge
is safe" — it's now "decide how much scrutiny a human review needs before
acting," the same shape as the backup pipeline's own urgent/digest
tiering, just applied to code review instead of backup alerts.

**Design change 2 — merge authority belongs to a dedicated deterministic
broker identity, not the foreman.** The user asked directly whether the
foreman agent could hold merge rights on the reasoning that "items okay
for the coding agent to push itself" could become "okay for the foreman
to push on its behalf." Correctly reasoned through to a better answer:
per 3k's own original rule ("the component holding push-to-main
credentials must be a deterministic, non-AI n8n workflow, never a
reasoning agent"), the foreman — the conversational AI the user talks to
— is itself a reasoning agent, and giving it merge authority even for a
narrow tier would reintroduce exactly the risk that rule exists to
prevent. Resolved by introducing a **third identity**, separate from both
the coding agent (proposes changes) and the foreman (talks about them):
a dedicated `polaris-merge-broker` account, added to the reviewer and
merge whitelists, driven by a purely deterministic n8n workflow with zero
LLM involvement in the decision itself. The foreman's role stays
conversational only — it can summarize a PR or tell the user it exists,
but it never performs the merge action, only the broker does, based on a
fixed pattern-match against changed files.

**Resulting design for the actual mechanism (not yet built as an n8n
workflow — see "Not yet built" below):** on a PR-opened/updated Forgejo
webhook, a workflow driven by the broker's credentials pulls the PR's
changed-file list via the Forgejo API and classifies it against a fixed
rule — touches an already-deployed shared file (`bin/polaris-backup`,
`lib/polaris-common.sh`, `lib/polaris-firewall-collector.sh`,
`lib/polaris-single-export-collector.sh`) or a credentials/permissions
path (sudoers entries, SSH key files, n8n workflow exports) → **Tier 2**,
notify-only, directional link into the real PR for manual review and
merge in Forgejo (never a tap-to-merge action — deliberately, since the
user named "keeps it in front of me for real review" as the entire point
of choosing branch-protection Option B earlier this session, and a
one-tap merge button would undercut that). Otherwise (a genuinely new,
isolated file) → **Tier 1**, the broker auto-approves and merges via its
own API token, then sends an FYI-only ntfy notification — no action
needed, matching what the original design already called "plausibly
eligible for self-merge... once proven out," just executed by the broker
identity instead of the proposing agent itself.

**Branch protection built and proven on the real `Project_Polaris` repo,
2026-09-13.** Rule applied to `main`: push restricted to whitelisted
deploy keys (`homelab-polaris-git`, `ct402-git-deploy` — preserves the
existing direct-push workflow for human-driven work exactly as-is), 1
required approval restricted to whitelisted reviewers (`lab-admin`),
"Dismiss stale approvals" and "Block merge on rejected reviews" both
enabled, merge restricted to a whitelist (`lab-admin` only — the specific
setting that stops any future write-access bot from merging its own
otherwise-approved work), and "Enforce this rule for repository admins"
left **unchecked** by deliberate choice — `lab-admin`'s own logins bypass
the rule entirely, keeping the user's own reviewed work frictionless
while still gating everyone/everything else. Proven with a real test
branch and PR: the rule correctly blocked the merge button at "0 of 1
approvals granted" while separately confirming the admin bypass ("as an
administrator, you may still merge"), and separately proved **Forgejo
natively blocks a user from approving their own PR** — a real protection
that wasn't configured, just discovered, and worth remembering as a
built-in property of the platform rather than something 3k itself needs
to enforce.

**Real Forgejo/Gitea platform quirks discovered and worth remembering,
none of them assumed from generic documentation — each confirmed against
the actual instance:**
- **The deploy-key push-whitelist toggle is all-or-nothing, not
  per-key.** "Whitelist deploy keys with write access to push" lets *any*
  write-scoped deploy key on the repo bypass push protection — there is
  no way to whitelist specific keys only. Direct consequence: a future
  coding-agent identity must **never** be granted access via a deploy key
  with write scope, only via a plain collaborator account with Write
  permission (no whitelist involvement at all) — otherwise it would
  silently inherit the same direct-push bypass as `homelab-polaris-git`/
  `ct402-git-deploy`.
- **Repository admins bypass branch protection by default**, as a
  separate toggle from the deploy-key whitelist ("Enforce this rule for
  repository admins") — two genuinely independent bypass mechanisms, not
  one.
- **Merge rights are a separate whitelist from push rights.** The default
  ("Enable merge: anyone with write access") would let any account with
  PR/write access merge its own approved work — this has to be
  deliberately restricted via "Enable merge whitelist" or the whole
  approval-gate design is cosmetic.
- **An admin-added SSH key on another user's account shows as
  unverified** ("This is unexpected, please log in with password...")
  until the key's actual owner proves control of it via an
  `ssh-keygen -Y sign` challenge from Forgejo's own SSH-key settings page
  — this is expected first-use behavior for admin-provisioned keys, not a
  misconfiguration, and was resolved correctly the first time it came up.
- **Access-token scopes are simple per-category dropdowns** (No access /
  Read / Read and Write) — `repository: Read and Write` is sufficient for
  PR approve/merge API actions; every other category should stay No
  access for a single-purpose credential like the merge broker's.

**New dedicated identity: `polaris-coding-agent`** (Forgejo user account,
repo permission Write, no deploy key, no whitelist entries anywhere) —
created specifically to prove the full agent-authored-PR flow against a
real, separate identity rather than testing solely against `lab-admin`'s
own admin bypass. SSH key `polaris-coding-agent-git` generated on CT402,
added to the account and verified via the sign-challenge above. **Fully
proven, both directions:** a direct push to `main` from this identity was
correctly rejected server-side (`Forgejo: Not allowed to push to
protected branch main`, `pre-receive hook declined`) even though the
account has write access to the repo; a full push-branch → open-PR →
review-as-a-genuinely-separate-identity (`lab-admin`) → approve → merge
flow completed cleanly. This is the first real proof, against a live
non-privileged identity, that 3k's actual security model behaves as
designed rather than merely as configured.

**Dedicated test playground: `Polaris-Pipeline-Testing` repo**, created
specifically so every future pipeline iteration (this one, and anything
else 3k grows into) has a standing place to prove itself without ever
touching `Project_Polaris` or needing a fresh throwaway repo each time.
`.gitignore` deliberately mirrors `Project_Polaris`'s real one
(`logs/`, `temp/`, `*.bak`, `*.pre-*`) plus one addition, `scratch/`, for
this repo's own testing artifacts. Dedicated deploy key
(`polaris-test-repo-deploy`, Homelab) generated rather than reusing
`polaris-git-deploy` — a deliberate choice to preserve the one-key-per-
purpose convention rather than let a key scoped for Homelab's real-repo
access also carry write access into the test repo. Branch protection
mirrors `Project_Polaris`'s rule, with `polaris-merge-broker` added
alongside `lab-admin` on the reviewer and merge whitelists from the start.

**New dedicated identity: `polaris-merge-broker`** (Forgejo user account,
repo permission **Write, not Administrator** — it only ever needs to call
PR approve/merge API actions, and Admin would additionally grant it the
ability to change branch-protection rules and collaborator lists
themselves, which it should never be able to do). Added to
`Polaris-Pipeline-Testing`'s reviewer and merge whitelists. Standard
bot-account hygiene applied from creation: "Can create organizations"
turned off, a generic non-personal email address used. API token
generated (`merge-broker-api`, scope `repository: Read and Write`,
everything else No access) and stored on CT402 at
`/root/.polaris_merge_broker_token`, `chmod 600` — matching the existing
pattern for every other credential file in this project (Proxmox API
token, SSH keys).

**Explicit safeguard, worth restating plainly:** `polaris-merge-broker` is
**only** on `Polaris-Pipeline-Testing`'s whitelists right now. It will
**not** be added to `Project_Polaris`'s real reviewer/merge whitelists
until the n8n workflow driving it has been built and proven end-to-end —
both the Tier 1 auto-merge path and the Tier 2 notify-only path — against
manually-created test PRs on the test repo, with no real coding agent
involved yet. `Project_Polaris` remains exactly as configured earlier
this session (only `lab-admin` can approve/merge) until that proof exists.

**Not yet built:** the actual n8n workflow — a Forgejo webhook listener
for pull-request events, a call into Forgejo's API for the changed-file
list, the classification logic itself, and the two action paths
(broker auto-merge via its token for Tier 1; ntfy notification with a
direct PR link for Tier 2). This is the next concrete step.


### 3k n8n Merge-Broker Workflow: Built and Proven End-to-End (2026-09-14)

The n8n workflow flagged as "not yet built" at the end of the previous
addendum is now fully built and proven against real Forgejo state changes —
not simulated, not just clean HTTP responses. Full build order and every
real bug hit along the way, captured below since several are genuinely
non-obvious platform/tooling quirks worth remembering rather than
re-discovering later.

**Webhook setup and a real, confirmed Forgejo bug.** Configured on
`Polaris-Pipeline-Testing`: Pull Request events scoped to **Modification**
(opened/closed/reopened/edited) and **Synchronized** (new commits on an
already-open PR) only — deliberately excluding Push and Reviews (the
latter to avoid the broker's own future approval action re-triggering
itself). Forgejo's built-in "Test Delivery" button appeared to silently do
nothing — extensive diagnosis (server logs at Debug level, host allow-list
checks, page-refresh staleness checks) all came up empty before finding the
real cause via Forgejo's own issue tracker: **confirmed upstream bug**
(Forgejo #7934) — Test Delivery only works when Push is one of the
webhook's enabled events, silently no-ops otherwise, regardless of what the
webhook is actually configured to listen for. Not fixable from this side;
worked around by testing exclusively with real manually-created PRs instead
of the Test Delivery button.

**Real infrastructure fix required before any delivery could succeed:**
Forgejo's webhook subsystem defaults `ALLOWED_HOST_LIST` to `external`
(confirmed via Forgejo's own source/docs) when the `[webhook]` section is
absent from `app.ini` — meaning webhook targets on private IP ranges are
silently rejected before a delivery record is even created, an SSRF
hardening default that happens to also block legitimate LAN-to-LAN
webhooks. Fixed by adding to Forgejo's `app.ini` (on Docker01, backed up
first):
```ini
[webhook]
ALLOWED_HOST_LIST = private, loopback
```
Container restarted to apply — this is not hot-reloaded.

**Signature verification (HMAC-SHA256).** Confirmed directly from Forgejo's
docs: `X-Forgejo-Signature` is HMAC-SHA256 over the **raw** request bytes,
hex-encoded, no prefix (distinct from the also-present `X-Hub-Signature-256`,
which uses GitHub's `sha256=`-prefixed convention). Implementation required
enabling **Raw Body** mode on the Webhook node (n8n parses JSON bodies by
default, which reorders/reformats bytes and would break any hash
comparison against the original payload). Secret generated via
`openssl rand -hex 32`, set on the Forgejo webhook config, and passed to
n8n via a `FORGEJO_WEBHOOK_SECRET` environment variable on the container
(also saved to a new `/root/.forgejo_webhook_secret` file on CT402,
`chmod 600`, matching this project's established credential-file
convention — plus a copy in the user's local password manager/Vaultwarden
for redundancy, the user's own standing practice for this project's
secrets).

**Two separate n8n Code-node security sandboxes hit and resolved, both
requiring container-level environment variables** (n8n 2.38.1, self-hosted,
using n8n's bundled/internal task runner, not a separate runner
container):
- `NODE_FUNCTION_ALLOW_BUILTIN=crypto` — Code nodes block all Node.js
  built-in module imports by default; scoped narrowly to `crypto` alone
  rather than `*`, since nothing else is needed.
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` — required for the Code node to
  read `$env.FORGEJO_WEBHOOK_SECRET` at all; docs list the default as
  `false` (allowed), but this instance enforced it as blocked regardless,
  so set explicitly.

**Honest trade-off discussed and accepted for this environment:** both
settings apply instance-wide — any Code node in any future workflow on this
n8n instance can now read every environment variable and use the `crypto`
module. Judged acceptable for a single-user, single-operator homelab
instance with no shared/templated/multi-tenant workflows. In a company or
shared-template setting, the correct pattern instead would be n8n's
**External Secrets** feature (Enterprise-only, confirmed via n8n's own
edition-comparison docs — not available on the free Community edition this
instance runs) referencing a real secrets manager via `$secrets.*`
expressions inside credentials, or moving signature verification out of
n8n entirely into an ingress-layer reverse proxy/verification service so
the secret and crypto logic never enter the workflow engine at all.

**Changed-files retrieval, confirmed against real Gitea/Forgejo API
documentation and then verified directly via curl before trusting it in
n8n:** `GET /api/v1/repos/{owner}/{repo}/pulls/{index}/files`, returning
`filename`/`status`/`additions`/`deletions`/`changes` per file — this
endpoint exists and behaves identically to Gitea's own docs. Authenticated
via a new n8n Header Auth credential (`Forgejo - polaris-merge-broker`),
holding `polaris-merge-broker`'s existing token from
`/root/.polaris_merge_broker_token`. **Real credential-format gotcha**:
Forgejo requires the full literal string `token <value>` as the header
value — the word "token" is a required scheme keyword, not something the
API or n8n adds automatically. Missing it produces a 404 rather than a
401/403, since Forgejo doesn't reveal whether a private repo exists to a
request it can't authenticate — took real diagnostic work (a manual
header test bypassing the credential, isolating exactly this) to find.

**Classification logic**, matching the fixed rule from the 3k Design/
Implementation Progress sections above: exact match against the four known
shared files (`bin/polaris-backup`, `lib/polaris-common.sh`,
`lib/polaris-firewall-collector.sh`, `lib/polaris-single-export-collector.sh`)
→ Tier 2; credential/permissions-path regex patterns → Tier 2; otherwise
Tier 1. **The credential-path regex patterns are explicitly a first draft,
not confirmed against `Project_Polaris`'s real file layout** — the original
decision record named categories (sudoers entries, SSH key files, n8n
workflow exports) but not literal paths. Must be reviewed and corrected
against the real repo structure before `polaris-merge-broker` is ever
whitelisted on `Project_Polaris` — flagged again below under Open Items,
since a wrong pattern here is the one mistake in this whole system that
actually matters (a real credentials-touching PR silently auto-merging
under Tier 1).

**Routing rebuilt from a single IF node into a Switch node** once real
4-way routing was needed (verified signature + relevant action → classify;
closed-without-merge; invalid signature; fallback/silent for everything
else — closed-and-merged, reopened, edited). **Discovered n8n's Switch
node (Rules mode) supports only one comparison condition per rule** —
same as the IF node's earlier AND/OR ceiling, confirmed directly against
n8n's own documentation rather than assumed to be a UI oversight. Worked
around identically: composite boolean flags (`routeClassify`,
`routeClosedNoMerge`, `routeInvalidSignature`) precomputed in the Code
node, so each Switch rule only ever needs a single "is true" check.
Fallback Output set to "Extra Output" (a distinct fourth branch) rather
than the default silent-drop, so nothing is ever lost without a visible
place to see it landed there. Live-tested: a real `reopened` event
correctly routed to Fallback with no downstream action and no error.

**New alert category identified during testing, not in the original
design:** `action: closed` with `pull_request.merged: false` — a PR closed
without ever being merged by the broker. Distinct from both tiers (nothing
pending, but also not a routine FYI) — reasoned as a system-health signal
worth more attention than Tier 1 but less than Tier 2, its own dedicated
branch and topic.

**Four dedicated ntfy topics** (replacing the single-topic-per-domain
pattern used by the backup pipeline, deliberately more granular here since
future per-agent topics were already anticipated back in 3j): all
lowercase, no `polaris-` prefix (user's deliberate simplification for a
single-homelab context, backup pipeline's existing topic left unchanged) —
`git-merge-alerts` (Tier 1 FYI), `git-prrequest-alerts` (Tier 2, needs
review), `git-prclosed-alerts` (closed without merge), and
`git-invalidsignature-alerts`.

**Tier 1 action chain, built and proven against real Forgejo state, not
just HTTP 200s:**
1. `POST /pulls/{index}/reviews`, `{"body": "...", "event": "APPROVED"}` —
   confirmed via the real PR UI showing the approval, not just a
   successful response.
2. `POST /pulls/{index}/merge`, `{"Do": "merge"}` (matching the repo's own
   `default_merge_style`) — confirmed via the PR showing "Merged."
3. ntfy → `git-merge-alerts`.

Real n8n data-flow gotcha hit twice in this chain: an HTTP Request node's
output **replaces** the item entirely with the API's response — it does
not carry forward upstream fields like `repo_owner`/`pr_number`. Fixed by
referencing the upstream node explicitly by name
(`$('NodeName').item.json...`) rather than `$json` wherever a node follows
an HTTP Request node in the same branch. A related, separate gotcha:
renaming a node breaks any `$('OldName')` reference elsewhere in the
workflow silently (only surfaces as a runtime error) — hit once when a
generically-named "If" node was renamed after being referenced by name
elsewhere. Standing practice adopted going forward: name nodes
specifically at creation time, and check for `$('NodeName')` references
before renaming anything.

Also discovered along the way: n8n's HTTP Request node has a **Specify
Body** setting (Using Fields Below vs. Using JSON) that silently accepts a
pasted JSON object into a single field's *value*, producing an
empty-keyed, meaningless body rather than an error — cost one full
debugging cycle before catching it. Always confirm "Using JSON" mode is
selected before pasting a raw JSON body.

**Tier 2: proven simply** — `git-prrequest-alerts`, no action taken,
confirmed via real message delivery including a genuine off-network test
(see Open Items below for exactly what this does and doesn't prove).

**Both side-channel alerts (`git-prclosed-alerts`,
`git-invalidsignature-alerts`) built and proven** the same way, each
connected directly off the Switch node's respective output — no
classification or file-fetch happens on these branches, so field names
match the original webhook payload shape (`pull_request.title`, etc.), not
the renamed `pr_title`/`pr_html_url` fields used further down the Tier 1/2
path.

**Known limitation, deliberately deferred, not fixed today:** every ntfy
notification's link points at Forgejo's raw LAN address
(`192.168.10.20:3001`), unreachable off-network — unlike CT402/ntfy,
Docker01/Forgejo has no Tailscale presence. Likely fix when revisited:
join Docker01 to the tailnet (same pattern already proven for ntfy in
Phase 1) and reference it by Tailscale IP/MagicDNS instead of the raw LAN
IP in these links.

**Every branch of the workflow is now built and proven against real
traffic**: webhook → HMAC verification → action filtering → 4-way Switch
routing → (Tier branch) changed-files fetch → classification → Tier 1
approve/merge/notify or Tier 2 notify-only, plus both side-channel alerts
and the silent fallback. `polaris-merge-broker` remains whitelisted only
on `Polaris-Pipeline-Testing` — promotion to `Project_Polaris`'s real
whitelists is a deliberate future step, not yet done (see Open Items).

### 3k: Promoted to Production (2026-09-16)

`polaris-merge-broker` added to `Project_Polaris`'s real reviewer/merge
whitelists, closing the last open item from the test-repo phase. First real
use came sooner than expected: the cyberrange collector's PR (see 3u) became
the actual first production exercise of this mechanism, opened as
`polaris-coding-agent` against `Project_Polaris` itself rather than the test
repo.

**Real bug found on first production use, distinct from anything the test
repo's rule ever exercised.** `lab-admin`'s approval showed `APPROVED` but the
PR still reported "0 of 1 approvals granted." Root cause, confirmed via
Forgejo/Gitea's own review-record API (`official: false` on both submitted
reviews) and cross-checked against the upstream project's source behavior:
the `official` flag — the thing branch protection actually counts — is
computed once, at submission time, purely by checking whether the reviewer
is in the target branch's **approval whitelist** at that instant; it has
nothing to do with admin status or approve/reject state. `Project_Polaris`'s
rule had "Restrict approvals to whitelisted users or teams" checked with an
**empty** whitelist field — meaning mathematically no one's approval could
ever be official, a gap that predated this session and had simply never been
exercised, since every prior real test either had `lab-admin` trying to
approve his own PR (blocked by Forgejo's separate self-approval rule before
this logic ever ran) or happened on the test repo, whose rule was configured
correctly from the start.

**Fixed by adding both `lab-admin` and `polaris-merge-broker` to
`Project_Polaris`'s "Whitelisted reviewers" field** — the latter added
proactively, before any real automated Tier 1 approval flow exists for this
repo, specifically so the eventual automation doesn't rediscover this same
gap later inside a fully unattended run, where it would be far more
confusing to debug. Confirmed fixed by having `lab-admin` submit a fresh
approval (existing reviews do not retroactively become official — the flag
is fixed at submission time) and verifying `"official": true` directly via
the API before merging. **The cyberrange PR was merged via the real,
now-working approval gate, not the admin bypass** — the first genuine
end-to-end proof of 3k's intended flow on the actual production repository.

**3k is now fully complete**, no open items remaining beyond the pre-existing,
non-blocking hygiene note on `polaris-coding-agent`'s account settings (see
Open Items).

### 3n: AI Node Proxmox Collector — Agreed Build Sequence (2026-09-14)

Before writing `bin/polaris-ai-backup`, the following end-to-end sequence
was agreed, reasoned from dependency order (each step requires the one
before it) and matching this project's established discipline of proving
each mechanism manually before automating it:

1. **Read-only deploy key** for `Project_Polaris`, created and authorized
   in Forgejo — scoped read-only deliberately, since the AI node should
   only ever pull the framework, never push to it.
2. **Build and test `bin/polaris-ai-backup`** (a new, separate,
   single-purpose orchestrator — not a modification of `bin/polaris-backup`)
   **plus a forked `collectors/proxmox-ai/proxmox_ai_collector.sh`**
   (deliberately forked from `proxmox.sh`, not sourced/shared — the AI
   node's actual Proxmox setup differs enough, e.g. no cluster relevance
   the same way, that trimming sections that don't apply is a legitimate,
   deliberate design choice here, not an oversight; this fork will not
   automatically inherit future `proxmox.sh` fixes, a known and accepted
   trade-off).
3. **Commit to `Project_Polaris` via normal git**, pushed directly to
   `main` as a human-authored change — this is Claude-assisted direct
   work, matching how 3s/3t's fixes were done, not routed through
   `polaris-merge-broker`'s PR flow (which exists specifically for
   autonomous-agent-authored changes).
4. **First real `git clone`** of `Project_Polaris` onto the AI node's
   Proxmox host, using the new deploy key.
5. **Manually run `bin/polaris-ai-backup` directly via SSH** on the AI
   node — full lifecycle proven by hand (stage → archive → NAS-AI write →
   retention) before n8n touches it at all.
6. **Verify the real NAS-AI output directly** — confirm
   `validated/proxmox-ai/` has the expected structure/content, and the
   exit code matches the shared `POLARIS_BACKUP_*` contract (now living in
   `polaris-common.sh`, see the shared-lib refactor below).
7. **Build the new n8n workflow** — triggers via `ansible -m raw`
   (`git pull -q && bin/polaris-ai-backup`, executed via raw mode
   specifically because AnsiballZ-based modules are confirmed to segfault
   on this host's Python 3.13, see below), reads the result back, and
   feeds the *existing* Classification/Tiering/ntfy pipeline — no new
   notification logic needed, since that pipeline is already
   collector-agnostic.
8. **Prove the full workflow via a manual n8n trigger first**, not yet
   scheduled — confirm parsing/classification/notification all work
   correctly driven through n8n specifically, not just by hand.
9. **Add the real Schedule Trigger and activate** — cadence relative to
   Homelab's existing 7am run is an open decision, not yet made.
10. **Update the Build Plan checklist and this runbook** with the final,
    proven state.

**Prerequisite work already completed this session, informing the above:**

- **NAS01 structure audit and cleanup**, confirmed via direct source-code
  read of `bin/polaris-backup` (not assumed from directory listings alone):
  the framework's one real, authoritative destination is hardcoded as
  `POLARIS_NAS_MOUNT="/mnt/pve/NAS-Backups"`. Removed: the redundant
  `NAS-Configurations` Proxmox storage definition (confirmed via
  `storage.cfg` to mount the identical physical folder as `NAS-Backups`);
  the unbacked stray `NAS-Infra` directory; the three retired collectors'
  leftover folders (`nano-ap`, `nano-station`, `switch01` — confirmed
  retired 2026-09-09 per 3b, and confirmed by the user as disconnected
  hardware no longer in the environment); the legacy pre-framework
  `NAS-Backups/Proxmox/` flat-tarball folder; and the entire stale,
  code-unreferenced `NAS-Infrastructure` copy of the `Project-Polaris` tree
  (last written July 28, never touched since). Kept deliberately:
  `NAS-CyberRange` (reserved for a future real cyberrange collector) and
  its one manual `Cyberrange-Host/polaris-cyberrange-pre-vlan-*.tar.gz`
  archive (a deliberate pre-VLAN-buildout snapshot, kept as reference).
- **New `NAS-AI` CIFS share created** on NAS01 (`/VM-Backups/AI`,
  mirroring the existing `NAS-CyberRange`/`NAS-Infrastructure` naming
  convention) and mounted as a Proxmox storage definition — the AI node's
  collector writes here, structurally isolated from Homelab's own
  `NAS-Backups` tree as a second, independent safety layer beyond the
  separate-orchestrator design itself.
- **Real pfsense→firewall01 naming question, resolved as already-correct,
  not left half-done.** Direct code read found a deliberate, documented
  decision already in `_run_pfsense_collector()`'s own comment: the
  internal registry ID/NAS folder name intentionally remain "pfsense" for
  backward compatibility with existing backup history, while human-facing
  log/notification text says "Firewall01" specifically to stay
  distinguishable from the separate Gateway01 collector (also pfSense
  software). Confirmed this fully satisfies the original intent (telling
  Firewall01 and Gateway01 apart) — closed as complete, no code change
  needed.
- **Shared-lib refactor, applied and verified against a real production
  run.** The six orchestrator result codes (`POLARIS_BACKUP_SUCCESS=0`
  through `POLARIS_BACKUP_LOCKED=5`) moved from `bin/polaris-backup` into
  `lib/polaris-common.sh`, so `bin/polaris-ai-backup` (and any future
  single-purpose engine) shares the exact same contract n8n's
  Classification/Tiering logic depends on, rather than duplicating it.
  One subtlety caught before applying: `bin/polaris-backup`'s own
  library-failed-to-load error path (line 97) used to reference
  `POLARIS_BACKUP_PREREQUISITE_FAILED` *before* the library that now
  defines it would have loaded — fixed by hardcoding that one specific
  early-bootstrap exit as a literal `2` with an explanatory comment,
  leaving every other (post-library-load) reference in the file
  unchanged. Verified via a real, complete 9/9-collector production run
  after applying — confirmed correct exit codes still appearing in the
  log (e.g. Gateway01's `NO_CHANGE` correctly returning exit code `2`).
- **AI node raw-execution path confirmed safe**, resolving the Phase 2
  AnsiballZ segfault concern for this specific host: `ansible -m command`
  reproduces the segfault today (`rc: 139`, confirmed via direct live
  test), while both `-m raw` and `-m script` return clean (`rc: 0`)
  against the same host. `-m script` additionally confirmed to correctly
  transfer and execute a real file, not just an inline command — the
  transport `bin/polaris-ai-backup` invocation will rely on.
- **New dedicated SSH key** (`polaris_ai_proxmox_key`) created on CT402
  and authorized as root on the AI node's Proxmox host (192.168.10.124) —
  the first SSH access ever established to this host from CT402 (only the
  read/write Proxmox API token existed previously).

### 3n: First Real `bin/polaris-ai-backup` Run — Two Latent Path Bugs Found and Fixed (2026-09-14)

Building and testing the new engine on real hardware — the first time
this repository was ever cloned onto a second host — surfaced two
genuine, previously-invisible defects in the existing framework, both
sharing the same root cause: path calculations that only ever produced
the right answer because Homelab's checkout happened to be wrapped in a
folder literally named `config-backup`, a coincidence of one operator's
naming choice at the original 3c setup, never actually enforced by git or
the framework itself.

**Git tooling gap on the AI node.** `git` was not installed on the AI
node's Proxmox host at all (Proxmox VE hosts are minimal Debian installs;
Homelab's `git` was a leftover of the original 3c work, never present
here). Installation itself hit an unrelated, genuinely broken system
package: `apt-listchanges` segfaults on every invocation on this specific
host (`rc 139`), aborting the whole `apt` transaction and leaving the
package in a stuck `rF` (half-configured) dpkg state. Root cause not
chased further — confirmed via `python3 --version`/a literal `print()`
that this is isolated to whatever `apt-listchanges` itself depends on,
not a general breakage of this host's Python 3.13 (distinguishing it from
the unrelated Phase 2 AnsiballZ segfault, a different Python-dependent
tool with a different failure signature on the same host). Resolved via
`dpkg --remove --force-remove-reinstreq --force-all apt-listchanges`
followed by `apt install -y --fix-broken`; `git` itself installed cleanly
throughout despite the surrounding noise. **Deliberately deferred, not
forgotten:** the underlying reason `apt-listchanges` itself is broken on
this host was not investigated — flagged as an open item to revisit
before fully closing out 3n, not a blocker for anything built since.

**Bug 1 — `POLARIS_PROJECT_ROOT` miscalculated in `lib/polaris-common.sh`.**
The file sits one directory below the real repo root (`lib/`), but its
own self-locating logic walked up **two** levels (`../..`), landing one
directory too high — then a second constant,
`POLARIS_CONFIG_BACKUP_ROOT`, silently re-descended into a folder
hardcoded as `/config-backup`, only working because that folder happened
to exist under that exact name on Homelab. Every collector script's own
independent `POLARIS_*_FRAMEWORK_ROOT` calculation was checked too and
confirmed **already correct** — they sit two directories deep
(`collectors/<name>/file.sh`), where `../..` is genuinely right. The bug
was isolated to this one file. Fixed to walk up one level, and
`POLARIS_CONFIG_BACKUP_ROOT` simplified to equal `POLARIS_PROJECT_ROOT`
directly rather than re-appending a hardcoded folder name — now correct
on any host regardless of what its checkout happens to be named.
Verified against `bash -n` and confirmed via git diff that the fix
applied identically on both hosts (an earlier independent manual edit on
the AI node, made to unblock testing before the officially committed
version existed, was discarded in favor of the reviewed/pushed commit via
`git checkout --`, so the AI node runs the actual committed code rather
than a hand-patched duplicate that only happened to match).

**A related, previously-untracked gap, exposed by the same second-host
clone:** `framework/verify-manifest.sh` had never actually been part of
the git-tracked repo at all — it sat as a genuine sibling folder next to
`config-backup/` on Homelab's disk, `.gitignore` didn't even mention it,
it simply predated whatever the original 3c commit captured. Brought
properly under version control as a true sibling of `bin/`/`lib/`/
`collectors/`, inside the tracked tree.

**Bug 2 — the exact same bug class, hiding in the file just recovered.**
Once `bin/polaris-ai-backup` could find `verify-manifest.sh` for the
first time, it failed with a doubled, malformed path:
`framework/../config-backup/lib/polaris-common.sh`. `verify-manifest.sh`
had its own hardcoded relative path,
`POLARIS_VERIFY_COMMON_LIBRARY_RELATIVE_PATH="../config-backup/lib/polaris-common.sh"`
— written under the same assumption Bug 1 had (that `framework/` sits
*outside* the repo, needing to walk back down into a folder named
`config-backup`). Once `framework/` became a genuine sibling of `lib/`
*inside* the repo, that same relative path doubled the segment instead.
Missed in the original audit specifically because `framework/` had never
been searched — it wasn't part of `bin/`/`lib/`/`collectors/`, the three
directories checked at the time. Fixed to `../lib/polaris-common.sh`,
matching `framework/`'s real, current position as `lib/`'s sibling. A
repo-wide `grep -rn "config-backup"` was run afterward specifically to
confirm no third instance of this same assumption was still hiding
anywhere — came back clean.

**A separate, unrelated git hygiene gap found and closed along the way:**
the original shared-lib refactor (moving the six `POLARIS_BACKUP_*`
result codes into `polaris-common.sh`, described in the previous
addendum) had been applied to Homelab's disk and verified against a real
production run — but never actually committed or pushed. This was a
process miss, not a user error: verifying a fix locally isn't the same as
closing the loop on it. The AI node's `git clone` correctly received
exactly what had been pushed, which didn't include this. Committed
properly once found. A second, older, fully unrelated gap was found in
the same `git status` check: `collectors/pfsense/pfsense.sh`'s deletion
(from the original pfsense→firewall01 rename, done as a plain file move
predating this session entirely) had also never been formally committed
— closed out as its own separate, clearly-labeled commit.

**`config-backup/` wrapper folder: kept deliberately, not removed.**
Once the `POLARIS_PROJECT_ROOT` fix landed, nothing in the framework
actually requires this specific wrapper name anymore — a fresh
`git clone` naturally produces a flat layout instead (confirmed: this is
exactly what the AI node's first clone produced, before being manually
re-wrapped). Two options were weighed: normalize Homelab to the newer
flat convention (larger blast radius — likely hardcoded absolute paths
in the Ansible playbook, inventory, and n8n's SSH invocation would all
need auditing and updating), or keep `config-backup/` as Homelab's
established convention and manually re-wrap the AI node to match
(smaller blast radius, nothing yet depends on the AI node's layout).
**Chose the latter, explicitly for lower blast radius given the AI node's
first-ever run hadn't happened yet** — accepting a known, minor future
cost: cyberrange, the one remaining host in the multi-agent vision, will
need this same manual re-wrap step when it's eventually built, since nnew
clones don't produce this layout automatically. Considered acceptable
since no further hosts beyond these three are currently anticipated.

**First real end-to-end run, proven and independently verified:**
```
[INFO] Orchestrator initialized
[INFO] Running AI Node Proxmox collector.
no pools available
no datasets available
[SUCCESS] AI Node Proxmox collector completed successfully.
Proxmox-AI-2026-09-14-221627.tar.zst: OK
```
The `no pools available`/`no datasets available` lines are accurate ZFS
reporting for this specific host (the AI node doesn't use ZFS storage the
way Homelab does) — not an error, and a real, concrete example of exactly
the kind of host-specific difference that motivated forking
`proxmox_ai_collector.sh` from `proxmox.sh` rather than sharing it
directly; a candidate section to trim in the later customization pass.
Output independently confirmed to have landed correctly on NAS01 at
`VM-Backups/AI/Project-Polaris/validated/proxmox-ai/`, checked directly
on the NAS rather than trusted from the script's own report.

**Next per the agreed sequence:** step 7, building the actual n8n
workflow — triggering `bin/polaris-ai-backup` via `ansible -m raw`,
reading the result back, and feeding it into the existing Classification/
Tiering/ntfy pipeline unchanged.

### 3n: n8n Workflow Built, Integration Bugs Found and Fixed, Proven Against a Real Failure (2026-09-14/15)

With `bin/polaris-ai-backup` proven twice on real hardware (see above), the
final piece was wiring it into n8n — which surfaced that "duplicate the
existing workflow" is a good starting shape, but not a pure copy: several
pieces downstream of the SSH/Ansible boundary were quietly written
assuming only Homelab would ever exist.

**Execution mechanism, adapted rather than reused as-is.** Homelab's real
`run-polaris-backup.yml` playbook uses a plain `command:` task — safe
there, but this host segfaults on AnsiballZ-based modules (confirmed
earlier this session). New playbook (`run-polaris-ai-backup.yml`) uses
Ansible's `raw` module instead, the one path already proven safe here.
Since the new inventory entry connects directly as root via
`polaris_ai_proxmox_key`, no `become` escalation is needed at all, unlike
Homelab's playbook. n8n side: confirmed directly against n8n's own
documentation that "Duplicate" (three-dot menu on a workflow) is a real,
supported feature, then duplicated both the top-level scheduler
("Backup Schedule" → "AI Backup Schedule") and the actual execution
sub-workflow ("Run Polaris Backup" → "Run AI Node Proxmox Backup"),
repointing the scheduler's call and the SSH node's command
(`ansible-playbook run-polaris-ai-backup.yml`) to match.

**First integration bug — Classification, three separate Homelab-specific
assumptions in one node, found by reading the actual code rather than
guessing from the error message:**
1. `t.hosts['homelab-node']` — hardcoded to Homelab's inventory alias;
   the AI node's inventory entry has no alias, so its key in Ansible's
   JSON output is the literal IP, `192.168.10.124`.
2. `hostResult.action === 'command'` — only matches the `command` module;
   the new playbook's task is `raw`.
3. The `collectors` lookup table — all nine entries were Homelab
   collector IDs; `proxmox-ai` wasn't in it at all.

Fixed by adjusting all three in the duplicated Classification node only
(Homelab's original untouched): host key → `192.168.10.124`, action
match → `'raw'`, table → a single `proxmox-ai` entry with the exact
success-message string confirmed against the real first-run output.

**Second, more serious gap — Tiering's collector table, silently
swallowing potential real failures.** `proxmox-ai` wasn't in Tiering's
`tierTable` either, and the fallback for any unlisted collector is
`{ failure: false, change: false }` — meaning a genuine `proxmox-ai`
failure would have produced **zero alert of any kind**, not even a
digest mention, simply vanishing into the fallback. This is a different
class of gap than Power-State's situation (see below): a config
mistake that would have silently defeated the entire point of building
this, not a correct "not applicable" case. Fixed by adding
`'proxmox-ai': { failure: true, change: false }`, mirroring Homelab's own
`proxmox` entry exactly — a bare-metal hypervisor collector's routine
`changed` status (which fires on every successful run, since `proxmox`
runs in inventory mode) is deliberately not escalated, but a genuine
failure is always urgent.

**Power-State correctly does not apply to `proxmox-ai`, confirmed by
reading the code rather than assumed.** `vmidMap` only contains
collectors whose target is a VM/container with a power state to check
(things running *on* Homelab's cluster) — `proxmox` itself (Homelab's own
bare-metal hypervisor) was never in this table either. `proxmox-ai`
correctly falls into the same "not applicable" category, not a gap.

**Root tagging fix, traced through the actual shared-library source
before trusting it.** `bin/polaris-ai-backup` never set
`POLARIS_ACTIVE_COLLECTOR` around its collector call — a gap from
trimming out `_execute_registered_collector()`, the function that
normally does this tagging, when reducing the orchestrator to a single
hardcoded collector. Traced the full chain in `polaris-common.sh`
(`operator_error`/`log_error` → `_emit_diagnostic` →
`_diagnostic_tag()`, which does `printf '[%s] ' "${POLARIS_ACTIVE_COLLECTOR:-orchestrator}"`)
to confirm precisely what string this produces before writing the fix,
rather than assuming. Fixed by setting
`POLARIS_ACTIVE_COLLECTOR="${POLARIS_AI_COLLECTOR_ID}"` immediately
before the collector call and clearing it immediately after, matching
Homelab's convention.

**Proven against a real, deliberately-forced failure — not just a clean
run.** `pveversion` temporarily renamed on the AI node (simulating a
missing dependency, the first real check `collect_proxmox_ai()` performs)
immediately followed by a real trigger through the full published n8n
workflow, then immediately restored and confirmed functioning again
afterward. Every layer confirmed independently:
- Real Ansible `raw` output showed `[ERROR] [proxmox-ai] Proxmox VE does
  not appear to be installed.` — confirming the tagging fix produces
  exactly the predicted string.
- Classification correctly parsed `{ collector: 'proxmox-ai', status:
  'failed' }`.
- Tiering correctly escalated to `urgent`, proving the tier-table fix
  actually works, not just that it reads correctly.
- A real urgent ntfy notification was delivered to the phone.

**Final activation:** Schedule Trigger's cron confirmed matching
Homelab's 7 AM exactly, "AI Backup Schedule" published. **3n is complete
— built, proven manually (twice), integration-tested against real
Ansible/n8n output, and proven against a real forced failure, now running
unattended on the same daily schedule as Homelab.**

**Standing checklist for the next new host** (cyberrange, per the
multi-agent vision), since this session found bugs at nearly every one of
these seams — worth deliberately checking each rather than assuming a
duplicate "just works":
1. New Ansible inventory entry — confirm which SSH key, and whether
   `raw` or `command`/`shell` is safe (test with a trivial `whoami`
   first, don't assume).
2. New playbook, module choice matching step 1's finding.
3. Duplicated n8n sub-workflow + scheduler, SSH node's command updated.
4. Classification's host-key match (literal IP vs. inventory alias) and
   action-type match (`raw` vs `command`).
5. Classification's own per-collector table (success/unchanged message
   strings, matched against real output, not assumed).
6. Tiering's per-collector table — easy to silently miss, and doing so
   means real failures produce zero alert rather than an error.
7. Power-State — only relevant if the new collector's target is an
   actual VM/container with a vmid, not a bare-metal host.

**Checklist validated, and extended, by cyberrange (3u):** items 1–7 above
assume the new host is reachable via SSH/Ansible the same way Homelab and the
AI node are. cyberrange broke that assumption entirely (see 3u) — worth
adding as an explicit item 0 for any future host: **confirm the target's
actual isolation/trust requirements and Proxmox cluster membership before
assuming the AI-node pattern applies at all.** A host with stricter isolation
needs may call for a fundamentally different access model (read-only API
token, no SSH, no local credential on the target), which changes nearly
everything else on this list.

### 3u: CyberRange Node Proxmox Collector — Isolation Design, Credential Exposure Found & Fixed, Built and Proven (2026-09-15/16)

**Design, agreed before any code was written.** Unlike the AI node,
cyberrange is the one host in this environment designed to run intentionally
hostile software — the design goal was explicitly reframed from "don't
bypass OPNsense" (the literal firewall boundary, which turned out to already
be solid on inspection — see below) to "don't create a new standing trust
path from a boundary that's designed to be broken through." Three decisions
followed directly from that reframing, all confirmed against the user's
stated priorities rather than defaulted to the AI node's pattern:

- **Read-only Proxmox API token** (`polaris-cyberrange-collector@pve`,
  `PVEAuditor`-scoped), not a root SSH key — cyberrange holds no Project
  Polaris credential of any kind, standing SSH or otherwise. Proven via
  direct `curl` testing that the tightest-sounding single grant
  (`/nodes/cyberrange`) does **not** cover VM configs or storage details —
  Proxmox's ACL model puts `/vms/{vmid}` and `/storage/{id}` in entirely
  separate permission trees from the node itself. Final grant set, each
  proven individually: `/nodes/cyberrange`, `/vms/300`, `/vms/301`, and the
  four storage IDs actually attached to the host
  (`NAS-ISO-Repo-CyberRange`, `local`, `local-lvm`, `Cyber_VM`).
- **CT402 pulls and writes; cyberrange never touches NAS01.** The
  orchestrator (`bin/polaris-cyberrange-backup`) and collector
  (`collectors/proxmox-cyberrange/proxmox_cyberrange_collector.sh`) both run
  entirely on CT402 — cyberrange is the passive target of read-only HTTPS
  calls, nothing more.
- **Host-level configuration only, and only the two persistent VMs.**
  cyber-fw01 (300) and kali01 (301) are the only VMs that aren't expected to
  be destroyed and rebuilt repeatedly; Blackarchlinux01 (310) and
  analysis-probe01 (360) are deliberately excluded, matching the project's
  existing precedent of not tracking things expected to constantly churn
  (Admin01/Docker01's inventory-mode collectors, for the same reason) — and
  matching a real constraint, not just a style choice: Proxmox's per-VM ACL
  grants are per-VMID with no "all VMs on this node" shortcut, so tracking
  disposable VMs would mean re-granting the token on every rebuild.

**Real, previously-invisible credential exposure found while verifying the
design, unrelated to anything being newly built.** Screenshots of the
cyberrange Proxmox host's own storage tree showed every NAS share in the
environment — including `NAS-Backups` and `NAS-AI` — listed as available
storage there. Root cause: `/etc/pve/storage.cfg` lives in `pmxcfs`, a
cluster-wide filesystem replicated identically to every member of the
`polaris` Proxmox cluster (confirmed via `pvecm status` — cyberrange, AI, and
Homelab are a genuine 3-node cluster, not three standalone installs), and no
storage definition had ever been node-restricted. A first mitigation
(restricting each storage's "Nodes" field) turned out to be necessary but
not sufficient — confirmed directly that **the Nodes restriction only
controls Proxmox's own auto-mount/UI behavior; the underlying CIFS password
file (`/etc/pve/priv/storage/<id>.pw`) still replicates to every cluster
node regardless**, meaning cyberrange's root retained the credential
regardless of the restriction.

**Full fix, once the actual NAS account structure was understood.**
Discovered that a single shared account (`storage-admin`) with Read & Write
had been used for every Proxmox storage definition across the whole
environment — meaning the exposure wasn't scoped to "cyberrange can see
NAS-AI," it was "any cluster member holds a credential valid for
everything." ADM has no IP-based share ACL to fall back on (confirmed via
direct inspection of ADM Defender, which only offers login-failure
blocklisting, not general access control) — the NAS's real isolation
mechanism turned out to be per-account, per-subfolder **ownership**
underneath a single shared top-level share (`Backups`), the same pattern
already used for every other collector's destination, just not previously
understood as the actual security boundary it is. Fix: created narrowly
scoped, single-purpose NAS accounts (`polaris-cyberrange-iso-ro`, read-only
on `ISO-Repo`; `polaris-cyberrange-collector-nas`, read-write on
`Backups/VM-Backups/CyberRange` only, ownership-locked at that subfolder),
rotated `storage-admin`'s password, and repointed cyberrange's remaining
storage definitions (a new split-off `NAS-ISO-Repo-CyberRange`, since the
original `NAS-ISO-Repo` is genuinely shared with Homelab/AI) at the new
accounts. `NAS-Templates` and `NAS-CyberRange` were also restricted away
from cyberrange during this pass — cyberrange ends up needing exactly one
NAS credential, read-only, to one share.

**SMB mount failure, isolated methodically rather than patched around.**
The dedicated `polaris-cyberrange-collector-nas` account could not mount via
the kernel's `cifs.ko` client — every variant (subpath vs. share root, three
SMB dialects, `nodfs`, explicit `sec=`, `seal`, even temporary
`administrators`-group membership) failed identically
(`rc=-13`/`NT_STATUS_OBJECT_PATH_NOT_FOUND`, "no tcon available for a dfs
referral request"), while Samba's own userspace `smbclient` succeeded
against the same path with the same restricted credential every time,
including a control test against `storage-admin` (full rights) succeeding
via `mount.cifs` where both restricted accounts failed — ruling out the
share, the path depth, and (via the admin-group test) group membership as
the variable, and narrowing it to something in how this specific kernel
version's CIFS client negotiates with this NAS's Samba build for
non-administrator accounts. **Root cause not fully confirmed at the
protocol level** — flagged here so it isn't mistaken for a fully understood
mechanism later, same category as 3t's Admin-WS stall. Given a repeatable,
proven working alternative existed, the design was changed rather than the
investigation extended further: `bin/polaris-cyberrange-backup`'s NAS
interaction was rewritten around `smbclient` directly (five functions:
`_nas_is_available`, `_copy_to_nas_temporary`, `_validate_nas_copy`,
`_promote_nas_copy`, `_quarantine_nas_copy`, plus new
`_polaris_nas_smb_run`/`_polaris_nas_smb_mkdir_p` helpers), with two
behaviors confirmed by direct testing before being relied on: `smbclient`'s
own process exit code is reliable only for connection-level failures (bad
credentials, unreachable host both produced real non-zero exits) and is
**not** reliable for command-level failures within an established session
(a deliberately triggered `mkdir` collision still exited 0) — every
operation therefore inspects captured output for `NT_STATUS` text rather
than trusting `$?`, and the archive copy is verified by downloading it back
and re-hashing locally rather than trusting `put`'s own success line.
**NAS-side retention (validated and quarantine) initially shipped stubbed**,
logging a clear `operator_warning` and skipping rather than erroring or
guessing, pending a real SMB-native implementation — local retention was
unaffected throughout. Built for real on 2026-09-16/17 as
`_polaris_nas_smb_list_backup_directories`/`_polaris_nas_smb_apply_retention`,
shared by both callers with a `protect_newest` flag so validated retention
keeps 3s's "never delete the last remaining copy" guard while quarantine
retention keeps its existing full-aging-to-zero behavior. Both the
date-parsing and the cd-failure-detection logic were verified against real
output already captured earlier in this same design session before being
relied on, not assumed. Proven in two stages: two real production runs
against a genuinely messy accumulated test set (11 backups) correctly
resolved every date, correctly protected only the true newest, and
correctly found nothing old enough to delete (everything was inside the
7-day window) — confirming the decision logic but not `deltree` itself,
which had only ever run once before against an empty test folder. Closed
that gap with a direct manual `deltree` against a real, populated backup
directory (five JSON files, a manifest, a verification report) — confirmed
removed cleanly via an independent `ls`, with every other backup in the
listing untouched. **3u is now fully complete, including NAS-side retention
— no known gaps remain in the cyberrange collector pipeline itself.**

**OPNsense/cyber-fw01's own firewall design reviewed directly and found
already solid**, not requiring changes: WAN interface tightly scoped to
Admin01 (management) and the Homelab Proxmox host (existing OPNsense
config-backup access, predating this session); LAN (kali01's segment)
allows only kali01 to manage OPNsense and blocks all RFC1918 destinations
including the other CYBER_* zones; every CYBER_* zone blocks the OPNsense
control plane and a `PROTECTED_NETWORKS` alias (Trusted Infrastructure plus
inter-zone). See Network Topology Reference for the corrected understanding
of `vmbr1`'s VLAN numbering — an initial concern about VLAN 10 appearing on
cyber-fw01's internal trunk was resolved as a coincidental digit collision
with cyber-fw01's own internal zone numbering, not a link to the physical
Homelab VLAN 10, and `vmbr1` has no physical uplink at all regardless.

**Real bug found in existing production code, unrelated to cyberrange
itself, surfaced by coincidental timing with the Tailscale ACL rollout.**
Homelab's Power-State code node threw `Cannot read properties of undefined
(reading 'filter')` on a run that happened to fire while the orchestrator's
own lock was already held elsewhere. Root cause confirmed directly from the
execution log: Classification's output for a lock-held run is
`{skipped: true, reason: "lock_held"}`, a shape Power-State's code never
accounted for, calling `.filter()` on it unconditionally. Confirmed
unrelated to Tailscale (the API call in question targets a plain LAN IP,
never routed through Tailscale) and confirmed non-recurring on retry. Left
as a known, minor, non-blocking gap — not fixed this session, since it only
matters when two runs genuinely overlap.

**Architectural discovery about n8n's own execution environment, relevant
to every future workflow, not just this one.** n8n's Docker container
(`n8nio/n8n`, Docker Hardened Images/Alpine) has almost nothing installed —
confirmed directly via `docker exec`: no `curl`, `jq`, `smbclient`,
`ansible-playbook`, or `zstd`, only `tar`. This means Homelab's and AI's
existing "Execute a command" nodes were never running inside n8n's own
container at all — confirmed they are actually n8n's **SSH** node type
(displayed under a renamed label), connecting out to CT402's own LXC shell
at its LAN address (`192.168.10.201`) using a credential
(`n8n_loopback_key`, present since before this session but previously
unexplained) that is almost certainly built for exactly this purpose. For
cyberrange, this meant no Ansible layer was needed at all — unlike
Homelab/AI, whose real target is a separate physical host reached across
that SSH hop, cyberrange's own target has always been CT402 itself, where
every tool and credential this collector needs already lives. The n8n
workflow's SSH node runs `bin/polaris-cyberrange-backup` directly, no
playbook or inventory entry involved.

**Built and proven end-to-end.** `collectors/proxmox-cyberrange/proxmox_cyberrange_collector.sh`
collects five things via the API (`/version`, node network, storage list,
and the two persistent VMs' configs), each canonicalized through `jq -S`
before writing (so field-reordering alone can never register as a spurious
change if real diffing is added later — the same class of bug fixed in
3p/3r, designed out from the start here instead), manifested via the shared
`polaris_manifest_required_files()` helper. `bin/polaris-cyberrange-backup`
is a close structural adaptation of `bin/polaris-ai-backup` (same
lock/validate/archive/retention lifecycle) with the NAS layer rebuilt around
`smbclient` as described above. First real run failed on a genuinely missing
`zstd` binary on CT402 (never previously needed there) — fixed by
installing it; the immediate retry succeeded completely: collector, local
archive/checksum, NAS upload, round-trip verification, and promotion all
passed, independently confirmed via a direct `smbclient ls` against the NAS.
The n8n workflow (SSH node → Classification → Tiering → Run Confirmation)
deliberately classifies purely on the orchestrator's real exit code, never
by scanning `stdout` for `WARNING`/`ERROR` text — the NAS-retention stub
above prints a `WARNING` on every single successful run, so any
design keying off text content would have escalated every routine success.
Tier mapping: exit 0 (success) and 5 (`LOCKED`) silent; 3 (`NAS_FAILED`)
digest, since a valid local copy still exists; 1/2/4 (all other failure
modes) urgent; anything unrecognized defaults to urgent rather than silent,
the same fail-safe reasoning as 3n's own Tiering table. Confirmed via a real
7 AM production run producing the expected silent outcome and a correctly
worded run-confirmation notification. This PR was also 3k's first real
production merge — see the 3k update above for the branch-protection
whitelist bug found and fixed along the way.

## Open Items

- Future option, not yet needed: extending `polaris-backup` to accept a collector-id filter (e.g. `--collector=proxmox`) for granular re-runs — would matter most for the drift-detection agent wanting to validate a newly-added collector without re-running all seven. Not being built now.

- NAS01 confirmed as storage-only; no services to add there
- **Resolved 2026-09-15/16:** the cyberrange node collector is now complete — see 3u. No further host-level Proxmox collector work is outstanding for any of the three nodes.
- Real production values for the new switch's TFTP export fields (server address, file path) once automation path is chosen
- Admin01's secondary IP (192.168.1.10/24) confirmed: pre-cutover staging address used to reach gateway01/pihole01 while building the new 192.168.30.0/24 house network. Once that cutover is fully complete, this is a candidate for removal from Admin01 as cleanup — confirm cutover status before removing.
- **Resolved 2026-09-09:** direct test of `ansible -m command` / `-m shell` against Homelab (`echo hello`, both returned `rc=0`) confirmed the AnsiballZ segfault documented in Phase 2 does **not** reproduce on Homelab, despite Homelab also running Python 3.13 (interpreter auto-discovered at `/usr/bin/python3.13`). This means the Phase 2 segfault is specific to something in the **AI node's** environment, not a general Python-3.13-on-Proxmox incompatibility — worth keeping in mind if the AI node's own Proxmox instance ever needs Ansible module access directly (stick with `community.proxmox` API modules there, per Phase 2). For Homelab-targeted work (all of 3f), `command`/`shell` are confirmed safe to build on.
- **Resolved 2026-09-11:** pihole01 (confirmed to be **CT 108, an LXC container on Homelab**, not a physical device — corrected an earlier assumption) is running Debian's real default: `PermitRootLogin prohibit-password`, in effect implicitly even though commented out in `sshd_config`. This specifically means root can only authenticate via SSH key, never password — password auth had been the only thing ever tried, so every attempt was guaranteed to fail regardless of whether the password itself was correct. `passwd -S root` confirmed root's Linux password was valid the whole time (`P`, not locked) — the account was never actually broken. Rather than fix root SSH at all, created a dedicated local account (`polaris-pihole-backup`, matching the `polaris-ansible-backup`/least-privilege pattern) via CT 108's Proxmox LXC console (which drops directly into a root shell, bypassing the SSH restriction entirely for setup purposes). Generated a fresh keypair on Homelab (`/root/.ssh/polaris-pihole-backup`), authorized it for the new account, and confirmed a clean SSH connection. Sudo scoping for the actual Teleporter export command deferred until the real collector is built in 3p — not yet known exactly what access it needs.
- **Confirmed 2026-09-09** — see Decisions Log: hardware/VM inventory drift-detection folds into 3i (trigger)/3k (approval-gated creation) with its own read-only Proxmox API token; no new autonomy tier needed.
- **Minor, low-priority polish for 3t:** `_run_admin_ws_collector()` opens the SSH multiplexing master in the background (`-M -N -f`) without confirming it has actually finished establishing before `collect_admin_ws()` begins — live testing showed exactly one call landing just before the master was ready and correctly falling back to its own connection (the intended fail-open behavior), rather than a defect. Could be tightened later with an `ssh -O check` confirmation step before the first command, closing this narrow startup window entirely. Not blocking.
- **Admin-WS SSH stall root cause remains correlational, not confirmed at the OS-internals level** (leading theory: a domain-controller-reachability check during a local account's logon on a domain-joined host). The two mitigations in place (raised timeout, connection multiplexing) work regardless of whether this theory is ever fully confirmed, so further root-causing is optional, not required for closure — flagged here only so it isn't mistaken for a definitively solved mechanism later.
- **Uncommitted pfsense→firewall01 rename + new gateway01 collector**, discovered sitting on Homelab from a prior session, confirmed working via real log evidence but not yet committed to git. Needs a deliberate decision (commit now, or investigate further first) independent of tonight's own git push.
- **3k: bot-account hygiene follow-up, not urgent.** `polaris-coding-agent` still has "Can create organizations" enabled and a personal-style placeholder email from before the two cleanup settings were established with `polaris-merge-broker` — worth aligning it to the same hygiene (org creation off, generic non-personal email) whenever convenient, for consistency across agent accounts rather than a functional problem today.
- **3k: ntfy notification links use Forgejo's raw LAN address, unreachable off-network.** Deferred fix: join Docker01 to the tailnet, same pattern as ntfy itself in Phase 1.
- **Resolved 2026-09-16:** `polaris-merge-broker` promoted to `Project_Polaris`'s real reviewer/merge whitelists, and the approval-whitelist gap found on first production use is fixed — see the 3k update above. 3k is fully complete.
- **3k: ntfy action-button tap-and-fire reliability remains genuinely untested**, distinct from plain notification delivery (confirmed working off-network via a real cellular-data test). No notification built so far uses ntfy's `Actions` feature, since 3k deliberately never uses a tap-to-decide button for the merge decision itself. Whether this is still worth testing for 3k specifically, versus deferred until a future workflow that genuinely needs a decision button (e.g. the multi-agent vision's VM-discovery-approval scenario), is unresolved.
- **3n: `apt-listchanges` is broken on the AI node** (segfaults on every invocation, `rc 139`), purged rather than root-caused. Deliberately deferred — cosmetic package, not required for anything functional, but worth understanding before fully closing out 3n.
- **3n: `config-backup/` wrapper folder retained on both Homelab and the AI node by deliberate choice (2026-09-14/15)**, not because the framework requires it (the `POLARIS_PROJECT_ROOT` fix made the path resolve correctly regardless of wrapper naming) — kept purely for visual consistency with Homelab's original layout. cyberrange's checkout (`~/project-polaris-cyberrange` on CT402) deliberately did **not** follow this convention — a fresh, plainly-named clone, since CT402 is a distinct execution context from a target host's own checkout and there was nothing to stay visually consistent with there.
- **Resolved 2026-09-16/17:** NAS-side retention for the cyberrange collector is built and proven — see the 3u closeout note above. Both the age/protect-newest decision logic and `deltree` itself against real populated backup directories are confirmed working.
- **3u: the `cifs.ko` mount failure for restricted NAS accounts against this specific NAS is empirically isolated (account-type, not path/dialect/share) but not root-caused at the protocol level.** Not blocking — `smbclient` is a proven, working alternative and the orchestrator is built around it — but worth understanding fully if it ever needs to be revisited (e.g. if a future collector wants a genuinely mounted path rather than SMB-call-by-call).
- **3u: the `NAS-CyberRange` Proxmox storage definition (restricted to the AI node) is now unused.** Superseded by CT402's direct `smbclient`-based transport, which never goes through Proxmox's storage layer at all. Candidate for removal, not yet acted on.
- **3u: CT402's `/etc/fstab` still contains the abandoned kernel-CIFS mount entry for cyberrange** (superseded by the `smbclient` pivot, and confirmed never to mount successfully). Harmless but will produce a parse/mount warning on every boot; candidate for cleanup.
- **3u: the stale `ct402-git-deploy` deploy key**, discovered on `Project_Polaris` during this session (last used 2026-09-11, tied to the abandoned `coding-agent-test` clone from earlier 3k testing), still holds real Read/Write access with nothing currently using it. Candidate for removal.
- **General, surfaced by 3u, applies to all future work:** n8n's own container has almost no tools installed (see 3u) — any new workflow needing more than what a plain SSH-to-CT402 hop provides will need either that same loopback pattern or a genuine change to the n8n image/container, not an assumption that a tool is available inside n8n itself.

## Admin01 Reference (captured 2026-09-09)

| Field | Value |
|---|---|
| Hostname | admin01 |
| Primary IP (use for Ansible ProxyJump) | 192.168.10.30/24 (ens18) |
| Secondary IP (pre-cutover staging, candidate for removal post-cutover) | 192.168.1.10/24 (ens18, same NIC) — used to reach gateway01/pihole01 while building the new 192.168.30.0/24 house network |
| Default gateway | 192.168.10.1 (firewall01) |
| Second NIC | ens19, present but unconfigured (link-local only) |

## HTTP Reverse-Engineering Side Quest (parallel track, user-driven)

Primary switch-automation path is Playwright (see Build Plan 3d). The raw-HTTP
approach is being pursued in parallel by the user as a learning exercise, not
blocking the main build. Guide provided 2026-09-09 covering: clean-session login
capture, Set-Cookie/max-age capture, viewing raw form HTML for true field names,
capturing a complete (untruncated) export-trigger POST with real values, and
capturing in-progress vs. completed `ping.html` poll responses. Updates land here
as they come in.

## Change Log

- 2026-09-09: Initial planning doc created, consolidating architecture review, network topology corrections, and decisions through this point.
- 2026-09-09: 3a fixes applied (logging split bug, pfsense.sh namespace rename) and delivered; cleanup commands provided. Admin01 IP resolved (192.168.10.30). HTTP reverse-engineering guide provided as parallel side-quest track.
- 2026-09-09: Admin01's secondary IP (192.168.1.10) confirmed as pre-cutover staging address for gateway01/pihole01; flagged as post-cutover cleanup candidate.
- 2026-09-09: Deployed corrected polaris-backup/polaris-common.sh; manual run confirmed full pipeline health for 5/6 collectors. Applied defensive PATH fix (optimized for Ansible/n8n-via-SSH, not just cron) after Proxmox's 32/32-day failure streak broke on the first manual run post-deploy. Admin-WS diagnosis corrected from network/switch theory to a Proxmox per-VM-firewall hypothesis after ARP evidence ruled out the switch entirely. Consolidated this doc's sprawling incremental updates into a single current-state narrative.
- 2026-09-09: Proxmox per-VM-firewall theory for Admin-WS ruled out by direct screenshot evidence (both VM-level and Datacenter-level firewall master toggles are "No", zero rules configured). Pivoted to a Windows Firewall/NLA network-profile-misclassification theory instead; isolation test and diagnostic commands provided, pending results. PATH fix redeployed via corrected polaris-common.sh.
- 2026-09-09: Admin-WS root cause fully confirmed (NLA never domain-authenticated; OpenSSH rule scoped to Domain profile only) and fixed via isolation test, verified in NAS01. Permanent fix (re-enable firewall + widen rule scope) recommended, not yet applied. Added AI Proxmox host and new switch as required future collectors.
- 2026-09-09: Admin-WS permanent fix confirmed via successful test backup — both production issues found in this session now fully closed. Started 3c: Forgejo/git setup guide provided (deploy key, .gitignore, initial + cleanup commits), pending user execution and Forgejo URL confirmation.
- 2026-09-09: 3c completed end-to-end. `config-backup/` now version-controlled on Docker01 Forgejo (`Project_Polaris`, private repo, SSH deploy key). Initial snapshot and retired-collector cleanup both committed and pushed. Manual `.bak`-file deployment practice can now be retired in favor of `git commit`/`push`.
- 2026-09-09: Started 3d. Architecture decided: Playwright + HTTP File Export (direct download capture), dropping the need for a TFTP landing zone (3e removed from plan). User running `playwright codegen` on Windows laptop to record verified automation code against the real switch UI.
- 2026-09-09: Homelab default-route/DNS issue diagnosed and fixed (stale route to a pre-cutover network) — unrelated to the backup framework but resolved mid-session since it blocked switch collector testing. Switch export script fixed (Apply-click iframe-scoping bug) and verified fully working end-to-end: both Text Configuration and Tech Support exports producing real data.
- 2026-09-09: **3d/3o complete.** Full orchestrator run with all 7 collectors (including switch) succeeded end-to-end; confirmed promoted to validated/ and copied to NAS01 correctly. Debug screenshot instrumentation kept in place intentionally pending a few more clean runs.
- 2026-09-09: Switch collector committed and pushed to Forgejo. Session transitioning to a new chat (image-count limit reached) — next up: 3n (AI Proxmox host collector), then the Ansible/n8n build (3f onward).
- 2026-09-09: Resumed in new chat. Corrected a handoff mislabel — the completed work was 3d/3o (switch collector), not "3l" as referenced in the handoff message; 3l is still-open cutover step. Decided to defer 3n until after the Ansible migration (3f+) rather than build a one-off SSH bridge from Homelab into the AI host for a single collector — that bridge is effectively what 3f/3g build anyway. Flagged an internal inconsistency in the Phase 2 runbook (build-steps text vs. Known Gotchas summary disagree on whether `-m command` segfaults against Proxmox-host Python 3.13) as something to verify directly against Homelab before leaning on it for 3f. Starting 3f next.
- 2026-09-09: Created `polaris-ansible-backup` service account on Homelab (least-privilege, sudo scoped to exactly the `polaris-backup` binary) and a matching dedicated SSH keypair on CT402. First attempt generated the keypair on the wrong host (Homelab instead of CT402) and pointed `-i` at a relative path from inside `~/.ssh/`; both corrected. Direct test against Homelab confirmed `ansible -m command`/`-m shell` both return `rc=0` — Phase 2's AnsiballZ segfault does not reproduce on Homelab, isolating it to the AI node's environment. 3f cleared to proceed with `command`/`shell`. User raised a new idea (hardware/VM inventory drift-detection feeding into automated collector proposals) with no prior recorded decision found; proposed mapping onto existing 3i (trigger)/3k (approval-gated code creation) architecture pending confirmation, plus a recommendation for a separate read-only Proxmox API token for that role.
- 2026-09-09: User confirmed the drift-detection mapping as proposed. Clarified desired autonomy model: input into the rules themselves, not into routine execution — approval-gate touchpoints (ntfy/3j/3k) are the intended single point of contact. User shared a broader vision of cross-agent collaboration (backup agent → approval → hands off to a separate coding-agent persona to draft the actual collector code against Docker01's Forgejo), tying back to Phase 2's "agent hats" idea; logged as a future design item, not being built yet. Clarified the `homelab`/`homelab-node` inventory naming collision is purely an Ansible-side alias with zero effect on the real host — safe to fix anytime; user deferred it for now.
- 2026-09-09: User confirmed inventory.ini updated to `homelab-node` alias directly. Confirmed comfort with autonomy-tier rules evolving over time as real usage reveals gaps. Elaborated the multi-agent vision with a centralized "foreman" orchestrator agent — the user's personal chat/learning agent that deploys and directs specialized sub-agents rather than sub-agents coordinating peer-to-peer; recommended hub-and-spoke coordination via n8n's existing "Call n8n Workflow Tool" pattern, and confirmed the single-approval-touchpoint design (foreman bundles finding + proposed code into one approval ask). Full design captured in new "Multi-Agent Architecture Vision" section. Resuming 3f.
- 2026-09-09: User shared the real `polaris-backup` source. Confirmed `main()` has no argument parsing at all — always runs the full 7-collector registry, resolving the earlier per-collector-selection design fork with no changes needed to the already-configured sudoers scope. Discovered the existing lock file (`/run/lock/polaris-backup.lock`, exit 5 = already running) as a built-in safety net for cron/Ansible coexistence pre-3l. First draft 3f playbook written (lock-aware, using `command` over `shell`), pending a live test run.
- 2026-09-10: Playbook execution troubleshooting: `.yml` file initially contained the runbook markdown instead of playbook YAML (copy-paste mismatch), corrected via heredoc. Play-level `become: true` caused the implicit Gathering Facts step to also attempt sudo and fail ("Missing sudo password") — fixed by disabling `gather_facts` and scoping `become` to only the one task needing it. Narrow sudoers rule (scoped to the bare `polaris-backup` path) then failed against real `become` traffic because Ansible wraps commands in a randomized shell string for privilege-escalation detection, which can never match a fixed-path sudoers rule — resolved by widening to `NOPASSWD: ALL` for this account, whose security boundary is enforced entirely by SSH-key-only access (a temporary password had been set to unblock SSH troubleshooting; corrected and the account re-locked once key auth was confirmed working). **First successful Ansible-triggered production run**, all 7 collectors succeeded, matching NAS01 promotion. Proposed dropping 3g as no longer needed given `polaris-backup`'s confirmed monolithic design — Ansible never needs to reach collector targets directly. Pending user confirmation.
- 2026-09-10: Root cause of the earlier SSH password fallback confirmed: the `<paste ... here>` placeholder in an earlier instruction had been copied into `authorized_keys` verbatim instead of being replaced with the real public key. Logged as a working-practice lesson — placeholder-containing instructions now get an explicit verification step immediately after. 3g confirmed dropped by user (matches original intent: ProxyJump was for Ansible-to-OPNsense access that turned out to be unnecessary). Related older "open architecture question" about Homelab's OPNsense reachability marked resolved-as-moot, not a blocking item.
- 2026-09-10: Extended `run-polaris-backup.yml` with log retrieval — `find` to locate the run's log file, `slurp` (not `fetch`) to read its content, `b64decode` to make it readable, gated behind the same `rc != 5` guard as the rest of the playbook. Not yet test-run; pending confirmation the inferred log path and mtime-based file selection work as expected against the real filesystem.
- 2026-09-10: User confirmed a full run via `tmux` (surviving a console disconnect) with the decoded log content actually visible — proof the log-retrieval addition genuinely works, not just inferred. **3f fully closed.** User identified a real coverage gap: gateway01 and pihole01 (added to the network after the original framework was built) have zero backup coverage. Researched current Pi-hole capabilities rather than assume — confirmed Teleporter has a real CLI path (`pihole-FTL --teleporter`) as of 2026 releases, so pihole01 doesn't need Playwright. gateway01 can reuse the existing shared firewall-collector engine directly. Logged as new Build Plan item 3p. User opted to complete 3h–3m first, treating 3p as independent, non-blocking work.
- 2026-09-10: User confirmed gateway01/pihole01 reachable from Homelab (web GUI both; SSH clean for gateway01). pihole01 SSH currently blocked (`Permission denied`) despite a password reset — logged as an open troubleshooting item with a leading hypothesis (Pi-hole's web admin password vs. the Linux root account password are separate credentials, easily conflated). Naming decision made: rename `pfsense.sh` to `firewall01.sh` alongside the new `gateway01.sh`, to remove ambiguity between the two pfSense-based devices, once 3p work begins. Retrieved the real Homelab crontab: `0 2 * * *` — starting 3h to match this exactly via n8n's Schedule Trigger, reusing the SSH-loopback bridge pattern already proven in Phase 2.
- 2026-09-10: Built 3h — "Backup Schedule" (Schedule Trigger) → "Run Polaris Backup" (Execute Workflow Trigger + SSH loopback) in n8n, confirmed instance timezone (`America/Los_Angeles`, set in Phase 2) matches expectations. Ruled out the web-admin-vs-Linux-password theory for pihole01 (user used `passwd root` directly, confirming it's the real system password) — leaves Debian's default `PermitRootLogin` policy as the leading suspect, still parked for 3p. Manually executed the full chain end-to-end: 6/7 collectors succeeded; Admin-WS failed. Root-caused as a new, distinct issue from the earlier NLA/firewall fix — Admin-WS's SSH account is domain-based, and Windows must resolve it against Active Directory before any credential check, which fails outright if DC01 is down; confirmed as a real dependency, not a bug, and distinguished from the earlier fix by the different error signature (`Permission denied` vs. `Connection timed out`). **3h complete.** Captured a new idea for 3i: suppress/downgrade notifications for failures explainable by the target simply being powered off, checked via the already-working Proxmox API.
- 2026-09-10: User decided to switch Admin-WS's backup account from domain to local (new item 3q, after 3p) — DC01's mandatory ~180-day rebuild cycle makes the current domain-account dependency a real, recurring risk rather than theoretical. Moving into 3i (major-change rule set) next.
- 2026-09-10: Designed 3i in full. Split into three tiers (silent / notify-batched / approval-required) rather than a flat major/routine scale. Built a three-reason escalation rubric (perimeter exposure, deliberately hostile neighbor, high blast radius) directly from the user's own stated reasoning for gateway01/OPNsense, then applied it across every device — user confirmed Proxmox, Admin01 escalate; switch config-changes (not failures) escalate; agreed with the Firewall01 recommendation (protects ROOTCA01/DC01/CA01) without objection. Full table and rubric captured as a permanent reference. Implementation (actual log-parsing and classification logic) intentionally deferred to sit alongside 3j, since there's nothing to act on a classification without notification delivery existing yet.
- 2026-09-10: User confirmed Firewall01's escalation with additional independent reasoning — it backstops OPNsense's isolation boundary on the same network segment, containing a potential cyberrange leak even beyond its already-established role protecting ROOTCA01/DC01/CA01. Added as a fourth, generalizable escalation rubric reason ("backstops another escalated boundary") rather than a one-off note specific to Firewall01. **3i's design is now fully closed**, no open items remaining.
- 2026-09-10: Started 3j. User confirmed Tailscale is not yet on CT402; existing tailnet includes ai, homelab, cyberrange, docker01, and personal devices. Surfaced and flagged a significant pre-existing security gap unrelated to this session's work: no custom Tailscale ACL exists, so cyberrange has default full-mesh access to every tailnet device, invisible to OPNsense isolation — recommended immediate "shields up" on cyberrange plus a proper tag-based ACL redesign later. Also flagged Docker's default all-interfaces port binding as a risk for the "Tailscale-only" intent of ntfy, and confirmed no Firewall01/OPNsense/gateway01 changes are needed for Tailscale connectivity itself. Identified the LXC `/dev/net/tun` passthrough requirement for CT402, same category of issue as Phase 1's GPU passthrough — documented the exact `.conf` lines needed before Tailscale can be installed.
- 2026-09-10: User activated shields-up on cyberrange (deferred full ACL redesign — reasonable given cyberrange's current minimal build state). CT402 confirmed joined the tailnet at `100.64.0.12`. Provided the ntfy Docker setup (official `binwiederhier/ntfy` image, port bound explicitly to the Tailscale IP, no TLS/reverse-proxy layer needed since Tailscale already encrypts peer traffic, topic names no longer need obscurity since Tailscale itself is the access boundary) — pending user's live test run and confirmation of end-to-end delivery to their phone.
- 2026-09-10: First `docker run` attempt for ntfy failed on `apparmor_parser: Access denied` — a repeat of Phase 2's already-documented AppArmor-in-LXC issue; the provided command omitted `--security-opt apparmor=unconfined`, an oversight on Claude's part given it was already known and applicable to any Docker container on CT402. Corrected in the runbook and flagged as a standing rule for all future CT402 Docker services, not just ntfy.
- 2026-09-10: Retried with the corrected command — container started cleanly. Full end-to-end test confirmed: both `curl` calls from CT402 returned valid JSON with real message IDs, and the second (`polaris-alerts` topic) delivered as an actual push notification to the user's phone over Tailscale. **Core ntfy setup for 3j is complete and verified.** Remaining for 3j: wiring actual notifications into the n8n workflow, implementing 3i's tiering logic as real behavior rather than just a design table.
- 2026-09-10: User requested adding the Windows laptop as a second notification target before continuing 3j. Web App route (over plain HTTP) showed messages in-page but never produced real OS-level notifications — root cause: browsers require a secure context (HTTPS) for the Notifications API and PWA installability, which Tailscale's network-layer encryption doesn't satisfy since it's invisible to the browser. Important distinction to remember going forward: Tailscale encryption and browser HTTPS/secure-context requirements are unrelated concepts that happen to usually overlap, but don't here. Confirmed Tailscale has an official fix (MagicDNS + "HTTPS Certificates" in the admin console, then `tailscale cert` per-machine, using real Let's Encrypt certs) — discloses the specific machine's name to a public certificate transparency ledger, judged acceptable since no machine names are sensitive. User chose to try this official route first over a third-party Electron desktop client, since it's reversible and doesn't foreclose switching later. Plan: enable Tailscale HTTPS, get CT402's MagicDNS name, run `tailscale cert`, recreate the ntfy container with `NTFY_LISTEN_HTTPS`/`NTFY_CERT_FILE`/`NTFY_KEY_FILE`/`NTFY_BASE_URL` pointing at the new cert, keeping port 80 available alongside 443. Pending user execution and test results.
- 2026-09-10: Cert generation succeeded cleanly — CT402's real MagicDNS name confirmed as `orchestrator-n8n.example-tailnet.ts.net`, cert/key written to `/root/ntfy/certs/`. Container recreate step failed: Claude had written "docker rm -f ntfy, then: docker run -d ..." as one descriptive sentence, but formatted ambiguously enough that it read as a single pasteable command — user reasonably pasted it as one line, and `docker rm` choked on `run -d` appearing in its own argument list ("unknown shorthand flag: 'd'"). Corrected by presenting the two commands as fully separate blocks, and the real FQDN filled in directly rather than left as a placeholder, to avoid repeating the earlier placeholder-substitution mistake. **Formatting lesson:** never blend prose connectors like "then:" into something that visually resembles one runnable command — always separate genuinely distinct commands into distinct blocks.
- 2026-09-10: HTTPS confirmed working (browser showed "Notifications are disabled" rather than "not supported" — proof the secure-context requirement was met). Browser's own permission prompt never appeared on click; diagnosed via Edge's site-permission settings and Windows' notification settings, neither of which showed a block — direct fix (manually adding the site under "Allowed to send notifications" in Edge settings) worked immediately. User decided the "browser must stay open" requirement wasn't good enough long-term and switched to the third-party `ntfy-desktop` (Aetherinox) Electron tray client. Installed and configured (server field is under Settings > Instance) — works, but shows only a tray bell/badge indicator rather than a real OS toast popup, and no in-app "launch at startup" setting was found (also didn't appear in Task Manager's startup list, a minor unexplained oddity not investigated further). User chose to defer solving that gap (can pin to taskbar manually as a workaround) rather than keep debugging, given phone + browser already cover the "real popup" need well. **Multi-device ntfy delivery judged good enough to close this sub-task and move on.**
- 2026-09-11: Built the rest of Stage 1 — renamed the topic to `polaris-backup-alerts` (user's own idea, anticipating per-agent topics like `polaris-network-alerts` once the foreman/agent architecture exists; noted ntfy supports comma-joined multi-topic subscriptions, so this scales without per-device resubscription later). Switched the SSH command to `ANSIBLE_STDOUT_CALLBACK=json` for reliable machine parsing instead of scraping decorated console text. Built Classification (parses per-collector success/failure/changed/unchanged from the JSON output — fixed a real bug where "unchanged" checks required both messages present, when unchanged collectors only ever print one), Power-State (filters to failures mappable to a real Homelab VM: pfsense, docker, admin01, admin-ws only — opnsense/switch can't be checked this way, confirmed and accepted), an HTTP Request node hitting Proxmox's API directly (bypassing Ansible entirely for this single stateless lookup — moved the Proxmox token into an n8n Header Auth credential as a result), and Tiering (merges everything into final escalate/silent decisions). Fixed an n8n Code-node gotcha (`$input.item` vs `$input.all()[0]`), an "Always Output Data" false start that was corrected by rewiring Classification to feed Tiering directly instead of routing through the optional Power-State/HTTP-Request branch (making Tiering resilient via `$('NodeName')` lookups regardless of whether that branch ran), and a final DNS resolution gap — the n8n Docker container couldn't resolve Tailscale's MagicDNS hostname for the ntfy server, since it runs in its own network namespace separate from CT402's own Tailscale-aware DNS. Fixed by explicitly setting `--dns 100.100.100.100` (Tailscale) plus fallbacks (confirmed CT402 can reach pihole01 at `192.168.30.2`, added as second-tier fallback ahead of `1.1.1.1`) on the n8n container, recreated without touching the `n8n_data` volume. **First real end-to-end alert delivered**: opnsense/admin01/switch config-change notifications actually reached the phone through the full pipeline.
- 2026-09-11: User's own review of the real results surfaced a genuine design gap: OPNsense (hash-detected mode, like pfSense) incorrectly reported `changed` despite no real change — leading hypothesis is a volatile timestamp/revision field in its config export corrupting the hash comparison, unconfirmed pending a direct diff of two exports. Admin01 (inventory mode, actively used by the user) also reported `changed` from ordinary session/log churn, not a real config change — revealing that `inventory`-mode collectors (Proxmox, Docker01, Admin01, Admin-WS, Switch) likely don't do genuine content comparison at all, unlike `hash-detected` ones (pfSense, OPNsense). **Interim mitigation applied immediately**: pulled OPNsense, Admin01, and Switch off the "escalate on config change" trigger (their failure-escalation behavior is unaffected) — pfSense/Firewall01 is the only device currently trusted for change-based escalation. Logged as new Build Plan item 3r for a proper fix later; also relevant to the future drift-detection agent design, which will need reliable change signals too.
- 2026-09-11: User merged 3r into 3p (both touch collector code directly, worth bundling). User decided to move the backup schedule from 2 AM to 7 AM, reasoning that a 2 AM alert would just be missed until morning anyway. Flagged that this isn't a simple number change — the Homelab crontab is still separately active at 2 AM, so moving only n8n's schedule would create two real daily runs instead of moving one. Reframed as the natural moment to finally do 3l's cutover (crontab disable), since n8n-triggered runs have now been repeatedly confirmed end-to-end with real alert delivery — the other half of 3l's own definition. Designed Stage 2 (daily digest): initially scoped as needing cross-execution persistence, simplified once checked against the real schedule (one run per day means no real "accumulation" is needed — just a second, calmer message sent alongside the urgent one from the same run). Tiering updated to tag `urgency: 'urgent'`/`'digest'`; two new nodes (Urgent Items, Digest Items) split the branches; a new Digest NTFY node delivers the low-priority summary. Full design and honest limitations captured in a new "Stage 2 Design" section.
- 2026-09-11: **3l complete** — Homelab crontab removed, n8n Schedule Trigger moved to 7 AM, n8n confirmed as sole trigger. Stage 2 nodes built and wired exactly as designed. A clean run correctly produced zero notifications (Tiering: 0 items, verified directly rather than assumed) — confirmed correct behavior, not a gap. User then deliberately powered off DC01 (leaving Admin-WS running) to force a real Tier-1 failure and prove the digest branch, rather than trusting the code untested — good instinct. Digest delivered correctly: `admin-ws` listed, priority 2, tag `clipboard`, urgent branch empty. **Both Stage 1 and Stage 2 are now fully proven end-to-end against real failures**, not just clean-run behavior.
- 2026-09-11: Pushed the Ansible/n8n orchestration layer into Project_Polaris git under a new `orchestration/` subfolder — dedicated deploy key generated on CT402 (`polaris-git-deploy-ct402`), matching the per-host key pattern used throughout. Hit two real snags: `git config core.sshCommand` doesn't work before a repo exists (fixed with `GIT_SSH_COMMAND` as an env var for the initial clone), and CT402 couldn't SSH into Admin01 to pull files (same "identity not trusted" category as pihole01/polaris-ansible-backup earlier) — worked around by pasting file contents directly via the console using the same heredoc pattern from earlier. Both `run-polaris-backup.yml`/`inventory.ini` and both n8n workflow JSON exports (credentials confirmed reference-only per n8n's documented export behavior, never raw secrets) are now version-controlled.
- 2026-09-11: Started 3p. Investigated the OPNsense change-detection bug from 3r by reading the real code instead of continuing to guess — disproved the original volatile-timestamp hypothesis via a direct `diff` (two real exports were byte-identical), then found the actual cause in `polaris-backup`'s `_run_opnsense_collector`: a case-sensitive filename mismatch (`OPNSense-*.tar.zst` vs. the real `OPNsense-*.tar.zst`) meaning the "does a validated backup already exist" check has never once matched, so every run was silently treated as the very first backup ever taken. Confirmed isolated to this one collector, not a systemic pattern, by cross-checking every other collector's lookup pattern against the naming table. **Fix applied on Homelab.** Pending live confirmation before restoring OPNsense to the escalation tier.
- 2026-09-11: Resolved pihole01 SSH access. Corrected an earlier assumption — pihole01 is CT 108, an LXC container on Homelab, not a physical device, which changed the console-access approach. Root cause confirmed precisely: Debian's real default (`PermitRootLogin prohibit-password`, in effect even though commented out) blocks root from password auth specifically while allowing key auth — every attempt had tried the one method root was blocked from, and root's actual Linux password was valid the whole time (`passwd -S root` showed `P`, never locked). Used the LXC console (drops straight to a root shell, bypassing the SSH restriction for setup) to create `polaris-pihole-backup`, matching the established least-privilege pattern rather than fixing root SSH just for consistency. Fresh keypair generated on Homelab, authorized, and connection confirmed clean.
- 2026-09-11: Built gateway01's full collector — new `_run_gateway01_collector`, `gateway01.sh` wrapper, all registry table entries, n8n Classification/Tiering/Power-State updates. Initial account-creation attempt via raw shell commands on gateway01 failed (`chown: illegal group name`) — diagnosed as pfSense/FreeBSD not recognizing shell-created accounts the way its own WebGUI User Manager does; recreated correctly through the WebGUI instead, which also let the SSH public key be pasted directly into the same form (no manual `authorized_keys` setup needed, unlike every other collector so far). SSH connection confirmed clean. Found and fixed a real Tiering bug from earlier: the "can't verify power state, default to urgent" fallback was unintentionally overriding switch's explicit `tier.failure: false` setting (the fallback was redundant for OPNsense, which already escalates via its own tier flag, but wrongly decisive for switch) — removed the fallback, `tier.failure` alone now governs urgency. **First real 7 AM scheduled run** (unattended, first live proof the cutover works on its own): gateway01 correctly reported `unchanged` on its very first backup, confirming the baseline-lookup mechanism works correctly with no repeat of OPNsense's case-sensitivity bug; switch's failure correctly routed to digest per the Tiering fix. Proxmox failed again — third consecutive failure across recent runs, cause still unknown; moving to investigate next.
- 2026-09-11: Diagnosed the Proxmox/Switch failures precisely from the raw orchestrator output rather than the condensed Classification status: `[ERROR] [proxmox] Proxmox collector runner is not available: _run_proxmox_collector`, same pattern for switch — not a real device or infrastructure problem at all. Confirmed via direct search that both function *definitions* had been accidentally deleted from `polaris-backup` entirely (still referenced in `POLARIS_COLLECTOR_RUNNERS`, but no longer present in the file) — almost certainly an over-wide text selection during one of tonight's paste operations, since Proxmox and Switch are exactly the first and last functions in the file's original order. **Recovered using git** — pulled the last known-good commit (`f039ed3`, predating tonight's changes) via `git show`, precisely extracted both function bodies by verified line-boundary check, and pasted them back into their original positions. Re-ran the full pipeline: zero items across every branch (Digest, Urgent, Proxmox API check) — confirmed clean, proving Proxmox was never actually broken as a device, only its own collector function was momentarily missing. Fix committed and pushed to git immediately afterward, closing the loop on the exact system that made this recoverable in the first place.
- 2026-09-12: Resumed in a new chat (previous session hit its attachment limit). Reviewed `polaris-common.sh`, `docker.sh`, `admin01.sh` against the "inventory mode is unreliable" theory — found real embedded live timestamps in every inventory report file, initially theorized as the cause of the always-"changed" behavior. User ran the actual empirical test this called for (two real Teleporter exports ~2 minutes apart): raw zip hashes differed, but `pihole.toml` extracted from both was identical — became the evidence base for pihole01's collector design.
- 2026-09-12: Read `polaris-backup` directly for the first time this session. Found the real mechanism behind inventory mode's always-"changed" behavior: `_run_admin01_collector`/`_run_switch_collector`/etc. unconditionally map any success to `NEW_OR_CHANGED` — no comparison logic exists in this path at all. Corrected the earlier timestamp-poisoning theory given to the user; the timestamps are real but were not the actual cause. User independently tested Switch's two export files across two real runs (config hash identical, tech-support hash/size both differed) and, combined with reading `switch.sh` (confirmed: same "no comparison exists" pattern as Admin01), established Switch could get real hash-detection cheaply, unlike Admin01/Docker01's sprawling multi-file reports.
- 2026-09-12: Diagnosed and fixed the pihole01 Teleporter permission chain live: read-denied on `pihole.toml` (Pi-hole's own documented `pihole:pihole` ownership model, fixed via a scoped sudoers rule), then write-denied on the output zip (sudo changes effective user but not working directory, fixed via explicit `cd /tmp`). Verified the resulting zip lands world-readable, confirming only the *generation* step needs elevated privilege. Built `polaris-single-export-collector.sh`, `pihole.sh`, and `switch.sh`'s new comparison logic; all syntax-validated before delivery. First full pipeline run with all changes live: zero errors, pihole/switch both correctly `changed` (first run, no baseline yet — expected, not yet proof the comparison logic works).
- 2026-09-12: Second run: pihole correctly reported `unchanged` (real proof). Switch still reported `changed` — diagnosed against the real on-disk path and found a `find -mindepth 3 -maxdepth 3` copied verbatim from the firewall engine without re-deriving it for Switch's actual one-level-deeper structure; verified the two real config files were genuinely byte-identical before applying the `-mindepth 4 -maxdepth 4` fix, ruling out a real change coincidentally masking the bug. Third run: switch correctly reported `unchanged`. Reviewed `polaris-backup` and the three n8n JavaScript nodes (Classification/Tiering) directly at the user's request; found and fixed the `docker01`/`docker` key mismatch bug (a real Docker01 failure would have produced zero notification), added the `pihole` entry to Classification, and confirmed Switch needed no Classification changes since its existing `NO_CHANGE` handling had simply been unreachable until now.
- 2026-09-12: Discussed and closed out the NAS01-unavailable "all collectors report failed" finding as accepted-as-is, given the project's working definition of "urgent." Designed and built the "Run Confirmation" heartbeat (solving the "did this even run" gap for fully clean days), deliberately as an independently-removable branch per the user's explicit requirement, anticipating a richer future per-agent daily summary. Moved into 3q (Admin-WS): read `admin-ws.sh` in full, confirmed 100% read-only via exhaustive verb search, found Admin-WS was reusing Admin01's SSH key (folded into 3q's scope). Created `polaris-admws-backup` as a dedicated non-administrator local account — 20-character Windows account name limit required shortening to `admws`. First SSH connection test succeeded cleanly on the first try.
- 2026-09-12: Diagnosed and fixed, one at a time via real isolated error text for each, four independent Windows permission gaps blocking `polaris-admws-backup`'s read-only access: three WMI namespaces (`CIMV2`, `StandardCimv2`, `Microsoft\Windows\Storage`, then `Microsoft\Windows\TaskScheduler`), DCOM for Storage (declined, graceful degradation instead), the Service Control Manager's own security descriptor for services (fixed via a scoped additive SDDL entry, Microsoft's own documented answer for exactly this problem), and DISM/AppX's hard elevation checks (declined after an extended, explicitly-requested brainstorm on admin-vs-scoped authority — see the new "3q Resolution" section for the full decision record). Found and fixed a real, pre-existing CRLF line-ending bug affecting every exact-match and last-field comparison in this collector, caught because the user directly verified a summary claim (`WinGet Availability: Available` with 0 packages) against a manual test rather than accepting it at face value. Removed `domain-admin`'s SSH key grant from Admin-WS after confirming via direct key comparison it was the only thing in that file. **3q complete** — full standalone and real-orchestrator runs both succeeded cleanly.
- 2026-09-12: Started scoping 3k. Worked through the git-review flow (agents push freely to their own branches, only main is protected; the actual push-to-main mechanism must be a deterministic, non-AI workflow, never a reasoning agent), which the user then independently connected to a broader credentialing-broker pattern via two of his own follow-up questions. Checked ntfy's action-button capability against real precedent (confirmed real, found a working Home Assistant analog) and Telegram's capability (confirmed superset, including genuine multi-device delivery) before settling the notification architecture on self-hosting grounds (ntfy primary/Tailscale-contained, Telegram only for the free-text exception) rather than capability grounds. **3k design fully settled and captured in the new "3k Design" section; explicitly not implemented — deployment and specific menu design deferred to a future session.** Closing this session here; next up per the original priority order: 3m (review historical logs/NAS01 backup contents).
- 2026-09-13: Resumed 3m. Reviewed a full NAS01 directory tree pull; initially misread OPNsense/Firewall01/gateway01/Pihole having no recent `validated/` entries as a real coverage gap, corrected directly against the real 09-13-070001 orchestrator log — all four had run successfully and correctly produced no new backup for unchanged configuration, exactly as designed. Reading that same log's retention lines surfaced a real, previously-invisible structural bug: `_apply_validated_retention` ages out backups purely by count of days with no floor, meaning a stable hash-detected collector's last remaining backup will eventually be deleted with nothing replacing it and nothing downstream positioned to notice. Traced OPNsense's 7-day NAS01 window as already partway toward triggering this for real.
- 2026-09-13: Fixed the retention bug in `bin/polaris-backup`'s shared `_apply_validated_retention()` function — the fix is generalized (protects every hash-detected collector automatically, not device-specific), deliberately scoped to leave quarantine retention's full-aging-to-zero behavior untouched (correct there). Used a Python exact-match-and-assert patch script (backup file first, then a text-replace gated on finding precisely one match, aborting with no changes written otherwise) rather than manual editing, given the file's size and the cost of a mistake in shared, already-deployed code. Verified with a live forced-failure test: backdated gateway01's only NAS01 validated backup to 60 days old, triggered a real n8n run, and confirmed the orchestrator log showed the new guard skipping its removal exactly as designed. **3s complete.**
- 2026-09-13: A same-day Admin-WS failure, caught correctly by the existing daily-summary heartbeat, was initially assumed to be a recurrence of 3q's domain-account dependency — ruled out directly, since Admin-WS was confirmed powered on well before the failure and the user reproduced it identically both logged in and logged out. Extended, evidence-based elimination process followed: connection multiplexing artifacts, an external timeout wrapper, reverse-DNS (`UseDNS`), GSSAPI, and Windows Defender real-time protection were each tested directly (not assumed) and ruled out in turn, narrowing the stall to somewhere inside SSH's own protocol exchange after the TCP handshake completes (confirmed via a raw-TCP-only test showing zero transport-layer issues). Windows' own OpenSSH and Security event logs provided direct, correlating evidence of the stall (`banner exchange: Connection aborted`, timed logon events) rather than leaving the diagnosis purely inferential.
- 2026-09-13: Discussed the tradeoffs of SSH connection multiplexing in depth before building anything, given it was new territory for the user — covered `ControlPersist`'s actual behavior (short-lived, not "always open"), the real (and bounded) security widening of a shared local control socket, and a general case-by-case rule for when future collectors/agents should reach for it versus stick with independent connections. Agreed: raise Admin-WS's connect timeout as an immediate mitigation (10s → 20s), and build multiplexing for Admin-WS specifically, since it's the one collector making 50+ independent connections per run and therefore the one most exposed to the underlying stall's odds. Implemented additively across `lib/polaris-common.sh`, `collectors/admin-ws/admin-ws.sh`, and `bin/polaris-backup`, using the same exact-match, assert-before-write Python patch discipline established earlier in this session, including one real transcription mistake (a wrongly-added trailing backslash) caught by the patch script's own safety check before it could reach the file. Verified via a live run: the OpenSSH operational log showed the connection pattern collapse from dozens of rapid connections to two (one long-lived session covering the bulk of the run, one early fallback consistent with `ControlMaster=auto`'s intended fail-open behavior), cross-referenced against the orchestrator's own log and n8n's execution record to rule out a double-invocation as an alternate explanation. **3t complete, pending real-world confirmation across further scheduled runs.**
- 2026-09-13: Captured new standing guidance for future collectors/agents on when to use SSH connection multiplexing versus independent connections, and logged an unrelated, previously-undiscussed uncommitted change (pfsense→firewall01 rename, new gateway01 collector) sitting on Homelab, confirmed working but flagged separately for a deliberate commit decision. Runbook consolidated and updated to reflect the full session; code changes pending git commit/push.
- 2026-09-13: Retention and Admin-WS fixes (3s, 3t) committed and pushed to `Project_Polaris`. User raised an open question about the older, unrelated uncommitted pfsense→firewall01 rename discovered earlier; deliberately left uncommitted and separate from this session's push rather than bundled in, pending the user's own decision on it later.
- 2026-09-13: Started 3k implementation. Laid out a bottom-up build sequence (branch protection → classification logic → deterministic merge workflow → live ntfy action-button reliability test → wire buttons to the real workflow), explicitly agreed as flexible rather than strictly sequential — pausing one piece to build another when useful is expected, not a deviation. Before touching Forgejo, surfaced a real design fork the original 3k notes hadn't resolved: should branch protection apply uniformly (Option A) or exempt the user's own already-reviewed human workflow (Option B)? User chose Option B specifically because routing their own work through a PR would blur the line they want PRs to represent — "things that need my review."
- 2026-09-13: Reviewed Forgejo's real branch-protection UI directly rather than assuming generic Gitea defaults, and found two real, non-obvious mechanisms worth remembering: the deploy-key push-whitelist is all-or-nothing (no per-key control), and merge rights are a separate whitelist from push rights (the default lets any write-access account merge its own work, which would defeat the whole approval-gate design if left as-is). Built the actual rule: `main` protected, push whitelisted to the two existing human-driven deploy keys, 1 required approval restricted to `lab-admin`, stale-approval dismissal and rejected-review blocking both enabled, merge restricted to `lab-admin` only, admin bypass left enabled for `lab-admin`'s own logins per the Option B decision.
- 2026-09-13: Tested the new rule with a real branch/PR — confirmed the merge button correctly blocked at "0 of 1 approvals" while `lab-admin`'s admin bypass was separately available, and discovered (not configured) that Forgejo natively refuses to let a user approve their own pull request. User correctly identified this as further validation of the Option B decision. Since testing solo as `lab-admin` couldn't exercise the "genuinely separate reviewer" case, agreed to stand up a real second identity rather than accept a partial test.
- 2026-09-13: User proposed the foreman could hold merge rights for routine changes on their behalf, prompting a real design question about whether that would need impersonating the user's own account. Clarified the whitelists are freely editable, not locked to any one account — but reasoned through to a stronger design than "add the foreman to the whitelist" by revisiting 3k's own original rule that push-to-main authority must be deterministic and non-AI. Introduced a third identity, `polaris-merge-broker`, as the actual holder of merge rights — separate from both the coding agent (proposes changes) and the foreman (discusses them, never merges). User agreed this "encompasses everything discussed while leaving all possibilities on the table."
- 2026-09-13: Chose to prove the coding-agent flow against a real second identity before moving on, rather than defer it — user suggested standing up an identity that will need to exist anyway (the coding agent) rather than a throwaway test account, two birds with one stone. Created `polaris-coding-agent` (Forgejo user, Write collaborator, no deploy key, no whitelist entries), generated its SSH key on CT402, and hit a real first-use quirk: an admin-added SSH key shows as unverified until the key's owner proves control via Forgejo's own `ssh-keygen -Y sign` challenge flow. User diagnosed and resolved this correctly without it being a real problem, confirmed via the key showing "Verified" afterward.
- 2026-09-13/14: Ran the full agent-PR test against the real `polaris-coding-agent` identity. Negative test passed cleanly: a direct push to `main` from this write-access account was rejected server-side (`pre-receive hook declined`), proving write access and push-to-main authority are genuinely separate now. Positive test passed cleanly: `polaris-coding-agent` pushed a branch and opened a PR, `lab-admin` reviewed and approved it as a real, separate identity this time (not the admin-bypass path), and the merge completed normally — the first full, real proof of 3k's intended flow working end to end.
- 2026-09-14: Reframed classification's actual purpose now that self-merge is structurally impossible for everyone but `lab-admin` regardless of tier — no longer "is self-merge safe," now "how much review scrutiny does this need." Decided to build and fully prove the merge-broker mechanism on a dedicated, permanent test repo (`Polaris-Pipeline-Testing`) rather than test directly against `Project_Polaris` or build throwaway repos each time — user's own suggestion, explicitly reasoned as mirroring the "prove the engine before adding the conductor" approach already used for the backup pipeline itself.
- 2026-09-14: Built out the test repo: created `Polaris-Pipeline-Testing`, mirrored `Project_Polaris`'s real `.gitignore` (confirmed via direct `cat` rather than assumed) plus one addition (`scratch/`) for pipeline-testing artifacts, generated a dedicated deploy key (`polaris-test-repo-deploy`) rather than reusing `polaris-git-deploy` — deliberately preserving the one-key-per-purpose convention rather than letting a Homelab-scoped key also carry access into the test repo. User caught their own mistaken attempt to clone over the web-UI port (3001) instead of the SSH port (2222) before running it.
- 2026-09-14: Created `polaris-merge-broker` (Forgejo user, Write collaborator — deliberately not Administrator, since it only ever needs to call PR approve/merge API actions, not manage branch-protection rules or collaborators itself), applied the same bot-account hygiene decided for this account from the start (organizations off, generic non-personal email). Applied `Polaris-Pipeline-Testing`'s branch protection mirroring `Project_Polaris`'s rule, with `polaris-merge-broker` added alongside `lab-admin` on both the reviewer and merge whitelists. Generated its API token (`merge-broker-api`, scope `repository: Read and Write` only, every other category left at No access), stored at `/root/.polaris_merge_broker_token` on CT402 matching the project's established credential-file pattern. Explicitly confirmed and restated as a safeguard: `polaris-merge-broker` is only whitelisted on the test repo — it will not be added to `Project_Polaris`'s real whitelists until the actual n8n workflow is built and proven against both the Tier 1 and Tier 2 paths using manual test PRs. Session paused here due to attachment limits; next step is building that n8n workflow itself.
- 2026-09-15: New session resumed against this runbook plus the 3k/3n resume prompt. Corrected 3k's status to fully complete (whitelist promotion already done in a prior, undocumented moment) before starting. Began cyberrange collector design: reframed the isolation goal from "don't bypass OPNsense" to "don't create a new standing trust path from a boundary designed to be broken through," and settled the core design (read-only Proxmox API token, CT402 pull-and-write, host-level scope, persistent-VMs-only) collaboratively rather than defaulting to the AI node's SSH/local-collection pattern.
- 2026-09-15: Proved the read-only API token's exact ACL grants via direct `curl` testing rather than assuming Proxmox's permission model — found and worked around the real `/nodes/{node}` vs `/vms/{vmid}` vs `/storage/{id}` separation. Discovered and closed the Tailscale full-mesh gap for `cyberrange` (deferred since 3i), staged as policy → tag → verification specifically to avoid a transient deny-all window. A same-session Homelab Power-State failure, initially suspected as Tailscale-related, was root-caused instead to a pre-existing, unrelated bug (`.filter()` on an unhandled `lock_held` shape) and confirmed non-recurring.
- 2026-09-15: While verifying isolation, discovered cyberrange (a full member of the `polaris` Proxmox cluster) had cluster-wide visibility into every NAS storage definition, including Homelab's and AI's own backup shares — a real, previously-invisible exposure predating this session entirely. Restricted each storage's Nodes field, then confirmed directly that this alone doesn't remove the underlying CIFS credential from cyberrange's `pmxcfs`-replicated filesystem. Found the deeper cause: a single shared `storage-admin` account with broad rights used across every Proxmox storage definition in the environment.
- 2026-09-15: Closed the credential exposure for real: created narrowly-scoped, single-purpose NAS accounts (`polaris-cyberrange-iso-ro`, `polaris-cyberrange-collector-nas`), rotated `storage-admin`'s password, split `NAS-ISO-Repo-CyberRange` off from the shared `NAS-ISO-Repo`, and confirmed ADM's NAS-side isolation model is per-account/per-subfolder ownership underneath a shared top-level share, not IP-based (which ADM doesn't support at all).
- 2026-09-15/16: Hit a genuine `cifs.ko` mount failure for the new restricted NAS account, isolated methodically across dialect/path/share-root/group-membership variants to rule out everything except "restricted account against this specific kernel/NAS combination," with a proven working alternative (`smbclient`) rather than a fully confirmed root cause. Rewrote `bin/polaris-cyberrange-backup`'s five NAS-interaction functions around `smbclient`, confirming by direct test that its exit code is unreliable for command-level failures (only connection-level) and building every check around captured output text and a download-and-rehash verification instead. NAS-side retention deliberately stubbed pending a follow-up SMB-native implementation.
- 2026-09-16: Built and proved `collectors/proxmox-cyberrange/proxmox_cyberrange_collector.sh` and `bin/polaris-cyberrange-backup` end-to-end against real hardware — one incidental failure (`zstd` missing on CT402, first time anything there needed to compress an archive), immediate clean run after installing it: collector, local archive, NAS upload, round-trip verification, and promotion all passed.
- 2026-09-16: Discovered n8n's own container has almost no tools installed and that Homelab's/AI's existing "Execute a command" nodes are actually SSH nodes looping back to CT402's own LXC shell — a previously-unexplained key (`n8n_loopback_key`) now understood. Built the cyberrange n8n workflow (SSH node running the orchestrator directly, no Ansible layer needed since CT402 is both orchestrator and target) with Classification/Tiering keyed purely on the orchestrator's real exit code — deliberately never scanning `stdout` text, since the retention stub above prints a `WARNING` on every clean run. Added a Run Confirmation node adapted to this workflow's real field names, matching Homelab's/AI's existing message wording.
- 2026-09-16: Opened the cyberrange collector's PR as `polaris-coding-agent` against `Project_Polaris` directly — the first real production use of 3k's pipeline, not the test repo. Found and fixed a genuine gap this exposed for the first time: `Project_Polaris`'s branch protection had "Restrict approvals to whitelisted users or teams" enabled with an empty whitelist, meaning no approval from anyone could ever be counted official regardless of review state. Added `lab-admin` and (proactively) `polaris-merge-broker` to the whitelist, confirmed via Forgejo's review API that a fresh approval showed `official: true`, and merged via the real approval gate rather than the admin bypass. **3k is now fully complete; cyberrange's collector (3u) is built, proven, and in production**, confirmed by a real 7 AM run. Runbook converted from resume-prompt addenda to a directly maintained living document per the user's request, and updated in place to reflect this entire session.
- 2026-09-16/17: Built and proved NAS-native retention for the cyberrange collector, closing the last known gap in 3u. Verified the two riskiest assumptions (date parsing, cd-failure detection) against real output already captured earlier in the session before relying on them. Two production runs against a genuinely messy 11-backup accumulation confirmed the decision logic (dates resolved correctly, only the true newest protected, nothing old enough to delete yet); a direct manual `deltree` against a real, populated backup directory (not the earlier empty test folder) confirmed deletion itself works cleanly, verified via an independent listing. **3u is now fully complete.** Cleared stray leftovers (`bin/writetest`, `bin/polaris-cyberrange-backup.bak`) from the CT402 checkout before considering this closed.
