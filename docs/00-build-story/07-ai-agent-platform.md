# Chapter 7 — The AI Agent Platform (September – October 2026)

## Goal

A **local-LLM** operations assistant I can talk to from my phone. It should answer questions about the lab, propose firewall changes, write and test code, and keep the documentation current. **Under no circumstances may it change live infrastructure without my explicit approval.**

## Phases

| Phase | Date | Result |
|---|---|---|
| 1 | 7 Sep | Third Proxmox node (Ryzen 9 7900X, RX 9060 XT 16 GB). Ollama in a privileged LXC with ROCm. LXC instead of a VM avoids the AMD GPU reset bug. Fixed GPU permissions where the device group ID mapped to the wrong group name inside the container |
| 2 | 8 Sep | n8n + Ansible: chat → AI agent → tool call → Ansible → Proxmox API → real data |
| 3 | 9–17 Sep | Config-backup automation with AI-reviewed results and the merge-broker (chapter 6) |
| 4 | 17–27 Sep | **Documentation agent** (Forgejo docs and an auto-rebuilding MkDocs site) and **coding agent** in a sandbox container: clone → write → **run and test** as an unprivileged user with resource limits → open a PR. Runs that hit the iteration cap still open a PR, clearly labelled `[INCOMPLETE]` |
| 5 | 27 Sep → | **Foreman** agent on self-hosted **Matrix + Element** with phone push (ntfy). Read access to all three firewalls with drift tracking. **Networking Manager** subagent for firewall writes |

Models: `gpt-oss:20b` (primary), `qwen3:14b` (backup and coding), `qwen3-vl:8b` (vision), all local.

## The key finding: prompts are not a safety control

On 7 Oct 2026, with two firewall changes pending, I told the Foreman "go ahead". Its reply correctly refused to guess which change I meant. **The n8n execution log showed it had already called the approval tool and applied one of them.** The narrated answer and the actual tool calls diverged within a single turn.

That ended the "better prompt rules" approach. The fix was **architectural**:

- The ability to approve was removed from every AI-controlled path. The review tool's AI-facing entry point hard-rejects `approve`.
- Approval now happens only through a **deterministic `/approve <id>` Matrix command**, parsed by a non-AI branch of the workflow. That branch calls a separate apply workflow that is never exposed as an AI tool.
- A separate **Network Change Executor** is the only component that holds a firewall write credential. Every proposal, approval and apply result is **ledgered**.
- This mirrors the earlier merge-broker pattern: **AI proposes, a human commits.**

Since then, aliases, firewall rules, VLANs and interface assignments on firewall01 have all been proven end-to-end. One bug found along the way: pfSense's VLAN `id` is a **live array index**, not a stable key, so the apply step now re-resolves its target by a stable attribute immediately before writing.

## Skills demonstrated

Local LLM deployment (ROCm, Ollama), agent orchestration (n8n), tool and prompt design, AI safety engineering (credential isolation, structural approval gates, audit ledgers), REST API integration (pfSense API v2), Matrix/Element, sandboxing (SSH forced commands, unprivileged execution, egress control), testing methodology (checking execution traces, not just replies).

## Records

[AI-000 overview](../08-ai-platform/AI-000-ai-platform-overview.md) · [Phase 1](../08-ai-platform/runbooks/AI-PH1-gpu-ollama-ai-host.md) · [Phase 2](../08-ai-platform/runbooks/AI-PH2-n8n-ansible-orchestration.md) · [Phase 4](../08-ai-platform/runbooks/AI-PH4-documentation-and-coding-agents.md) · [Phase 5 Foreman](../08-ai-platform/runbooks/AI-PH5-foreman-agent.md) · [Coding-agent sandbox scripts](../../code/coding-agent-workspace/) · [Agent prompts](../15-ai-assisted-engineering/README.md)
