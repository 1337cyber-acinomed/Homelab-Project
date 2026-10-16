# AI-Assisted Engineering

Polaris was built with AI assistants as pair engineers: ChatGPT from the first pfSense design on 28 June 2026, then Claude for the cyber range, the backup framework and the agent platform. This section explains **how** I used them, and what kept the work correct and safe, because doing that well is itself a skill.

## Division of labour

| AI did | I did |
|---|---|
| Researched options and vendor documentation; drafted designs, runbooks and code; proposed diagnostic steps; reviewed my evidence | Set the goals and the architecture; made every decision; **ran every command myself** on real hardware; captured the evidence (screenshots, command output, hashes); accepted or rejected each step |
| Wrote first drafts of documents | Reviewed, corrected and versioned them in Forgejo |

## Working method

1. **Operating rules up front.** Every session started from the same rules: GUI-first for Proxmox, pfSense, OPNsense and Windows; one bounded gate at a time; exact commands only; read-only discovery or a stop when something is unknown; back up before any risky change; never fix a finding in the same step that found it.
2. **Living runbooks as the source of truth.** Each phase has a runbook that records decisions, findings and current state (for example RUN-003, which is at v1.77). AI memory was never trusted across sessions.
3. **Session handoff prompts.** When a session grew long, it was closed with a "resume prompt" that indexes the current state and points to the runbook, so the next session starts from documented facts. See the [example](session-handoff-example/resume-prompt-phase4-example.md).
4. **Evidence beats confidence.** Claims about live state were verified against the live system, and several important bugs were found this way (the firewall alias typo, Tailscale's allow-all policy, the agent that applied a change while saying it would not).
5. **Rejecting suggestions is part of the job.** Examples: rebuilding instead of repairing, keeping the cyber-range AI off the shared AI node to avoid any leakage path, and replacing prompt-based approval rules with an architectural gate.

## Building AI into the lab itself

The same lessons shaped the in-lab agents (see [AI-000](../08-ai-platform/AI-000-ai-platform-overview.md) and [chapter 7](../00-build-story/07-ai-agent-platform.md)):

- [Foreman agent system prompt](agent-prompts/foreman-agent-system-prompt.md): routing, honesty and live-state rules
- [Coding agent system prompt](agent-prompts/coding-agent-system-prompt.md): engineering standards inside a sandbox

### Prompt-design patterns that worked

| Pattern | Why |
|---|---|
| "Answer live-state questions only from a tool call made this turn, one call per device" | Stops the model from repeating stale memory as fact |
| "Never present tool output as more complete or certain than it was; say plainly when data could not be obtained" | Stops the model filling gaps with plausible-sounding guesses |
| Concrete patterns with negative examples instead of open-ended judgement calls | Smaller local models follow patterns far more reliably |
| Telling the agent which tools exist and when to use them | A tool that is wired in but not described in the prompt is effectively invisible |
| **Not** relying on prompts for safety-critical actions | Testing showed narration and tool calls can diverge; approval is enforced structurally |

### Testing AI behaviour

- Test with varied phrasings, including vague ones ("go ahead and finish that").
- Read the **execution trace**, not just the chat reply.
- Accept a test as proof of a rule only if that rule was the deciding factor in the outcome.
- Re-test after the conversational memory window has lapsed.
