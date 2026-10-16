# Chapter 5 — Detection Engineering and Adversary Emulation (October 2026)

## Goal

Turn the cyber range into a place to practise **both sides**: run real adversary techniques against monitored targets, and confirm that the SIEM detects them, with AI support for triage.

## What I built

| Layer | Implementation |
|---|---|
| SIEM | **Wazuh** on `cyber-siem01` (VLAN 50). SIEM core closed 8 Oct 2026 |
| Endpoint telemetry | **Sysmon** (SwiftOnSecurity config) on every Windows target; **auditd + execve rules** on every monitored Linux target; Wazuh Docker listener plus web-log ingestion on the web-app host |
| Baselines | Every monitored target carries a `monitored-baseline` snapshot (agent and telemetry included), and disposable targets revert every 96 hours on a host-side systemd timer |
| Adversary emulation | **MITRE Caldera**, **Infection Monkey** and **Atomic Red Team**. Firewall rules for each tool are pre-built but **disabled**; they are enabled only for the duration of a scenario and then turned off again |
| ATT&CK coverage | ATT&CK Navigator, bound to loopback only |
| AI triage | **defense-AI** container: `deepseek-r1:14b` as analyst plus `llama-guard3:8b` as an I/O guardrail, on a shared GPU. A poller reads Wazuh alerts, writes structured analyses to an `ai-analysis-*` index, and analysts review them in Open-WebUI or the Wazuh dashboard |

## Findings that improved detection

- **Caldera discovery commands (`whoami`, `ps`, …) produced no Wazuh alerts on Linux.** Linux had no process-execution telemetry. Fix: auditd execve rules plus Wazuh audit log collection on every Linux target, then the baseline snapshots were re-taken. Confirmed: discovery now shows up.
- **Revert targets predated the agents.** The `hardened-baseline` snapshots were taken before Wazuh was installed, so a revert would have silently removed monitoring. All ten monitored boxes were re-baselined.
- **The Wazuh API went down after every reboot.** The cause was a cold-boot start-order race: the indexer took 68 seconds to start and starved the manager. Memory was ruled out first. The race was fixed and verified across a clean cold reboot.
- **The AI over-called false positives.** It labelled a benign Docker overlayfs rootcheck finding a "critical rootkit". Prompt tuning with known-false-positive context is tracked. AI output is advisory, and an analyst confirms.

## Skills demonstrated

SIEM deployment and tuning (Wazuh), Windows (Sysmon) and Linux (auditd) telemetry, detection validation with Caldera, Infection Monkey and Atomic Red Team, MITRE ATT&CK mapping, root-cause analysis of service failures, applying local LLMs to SOC triage with guardrails, scenario SOPs.

## Records

[SOP-BAS scenarios](../07-cyberrange/SOP-BAS-breach-and-attack-simulation-scenarios.md) · [RUN-003 §11 (SIEM, defense-AI and deferred items)](../07-cyberrange/RUN-003-cyberrange-current-state-handoff.md) · [SEC-006 Security monitoring](../13-security/SEC-006-security-monitoring-and-logging.md)
