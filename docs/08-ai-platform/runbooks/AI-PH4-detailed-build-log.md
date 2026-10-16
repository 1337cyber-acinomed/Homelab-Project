# Phase 4 Runbook: AI Agents (Documentation, Backup, Coding, Foreman)

**Status:** Documentation agent (4a-4c) built and proven; coding agent (4g): MILESTONE — first fully autonomous chat-to-real-PR run succeeded end to end 2026-09-23 (Polaris-Pipeline-Testing PR #28); false branch built and confirmed; context length raised to 80,000 and confirmed applied, but ruled out as the cause of a real, unresolved cap-out on a harder multi-cycle test — root cause still open, session paused mid-diagnosis
**Primary host:** AI node (every agent gets its own dedicated container there — see Standing Principles)
**Last updated:** 2026-09-21 (coding agent design session)
**Maintenance note:** maintained as a living document from the start, same convention adopted for Phase 3 partway through — edited in place as work happens, not through separate addenda.

## Overview and Overall Goal

This phase begins actually building the "Multi-Agent Architecture Vision" first
captured in the Phase 3 runbook (2026-09-09, forward-looking, nothing built at
the time): a centralized **foreman** — the single agent the user personally
talks to, in chat and eventually remotely — that directs specialized
sub-agents (documentation, backup, coding, networking, cybersecurity, etc.)
rather than those sub-agents coordinating with each other directly. Sub-agents
report structured results back to the foreman; the foreman is the one place
"what's happening across everything" is visible.

**Phase 3 built the first real precedent this phase depends on.** 3k's
git-review pipeline (a reasoning agent proposes via branch/PR, a separate
deterministic identity handles the actual merge decision, a human approves)
and 3u's credential-scoping discipline (every new capability gets its own
narrowly-scoped identity, proven empirically before being trusted) are not
just prior work — they are the operating rules this phase builds every agent
against, restated explicitly below so they don't get silently reinvented or
loosened.

**Explicitly out of scope for "Phase 4" as a single monolithic build**: this
is not one big-bang implementation. Per the agreed sequencing rule (below),
agents are proven individually, smallest first, with the foreman itself built
last, once there is more than one working sub-agent for it to actually
coordinate.

## Working Philosophy (read before changing anything)

**This plan is expected to change.** Phase 3 changed its own plan repeatedly
as real building revealed things a design conversation couldn't have
predicted — the SMB mount pivot, the n8n execution-environment discovery, the
approval-whitelist bug found on first production use, are all examples of the
plan adapting mid-flight rather than being followed rigidly. Phase 4 will do
the same. A change to this plan is always acceptable when it has a real
reason and a clear purpose, and still serves the goal above — a conversation,
a plan for the change, and then execution, exactly the same shape every
correction took during Phase 3. What's not acceptable is drifting from the
plan silently, without that conversation happening first.

**This project is a learning experience, carried forward as a standard from
Phases 1 through 3, restated explicitly here because Phase 4 leans harder on
it than any phase so far.** The user is new to n8n, Ansible, and most AI/LLM
agent structures. Nothing gets built or explained assuming familiarity that
hasn't been established — every step gets the reasoning behind it, not just
the action to take, jargon gets defined on first real use rather than dropped
in as if already known, and "why this approach" gets stated alongside "what
to do," the same way Phase 3's own explanations worked (e.g. why Proxmox's
`/vms/{vmid}` ACL is a separate tree from `/nodes/{node}`, not just "grant
this path"). This matters more here specifically because n8n's and LLM
agents' own concepts (nodes, triggers, credentials, tool-calling, system
prompts, context windows) are genuinely new ground, distinct from the
bash/git/Proxmox work most of Phase 3 involved.

**Related: expect gaps in what tooling actually exists, and be deterministic
about them rather than assuming a solution is available.** The AI-agent
tooling landscape (community nodes, integrations, established patterns for
this specific kind of homelab-scale multi-agent setup) is less mature and
less standardized than, say, Ansible's or Proxmox's own ecosystems — a
capability that sounds like it should obviously exist as a ready-made
integration sometimes doesn't. When that happens, the answer is the same
discipline used throughout Phase 3: verify directly rather than assume
(check n8n's actual node palette, actual docs, actual current state of a
project), and when a gap is confirmed real, have an explicit, deliberate plan
for it (build the missing piece, drop to a lower-level primitive like a raw
HTTP call, or substitute a different tool) instead of leaving it as an
unstated assumption something will "just work."

**Concrete lesson from 4b's stage 3 build, worth stating as its own standing
rule rather than a one-off correction:** once more than one account is
involved in a multi-step sequence (this build eventually had `lab-admin`,
`polaris-mkdocs-rebuild`, and `sudo` all in play across the same session),
every command block that depends on which account it runs under must say so
explicitly, every time — not left to be inferred from what happened a few
messages earlier. Two real mistakes in this exact build traced back to
exactly this gap (a `sudo` self-escalation attempt, and confusion over which
shell a step was meant to run in), and both were the explanation's fault for
not stating the required context plainly, not the user's for losing track of
it.

**Stronger version of the same lesson, adopted partway through the same
build after direct feedback:** for any step with real, multi-part stakes —
new credentials, container recreation, webhook wiring, anything where
getting the sequence wrong is costly to untangle — work **one instruction at
a time**: state the reason briefly and separately from the action, give
exactly one thing to do, wait for confirmation, then give the next. Don't
bundle explanation, multiple steps, and the next stage's setup into a single
response, even when the full picture is already known. Step 5 of 4b's stage
3 (the actual Forgejo webhook → n8n workflow, including a container
recreation, a new SSH credential, and a five-node workflow) was built
entirely this way after the feedback landed, and went cleanly — worth
defaulting to this format for comparable future work, not just applying it
reactively.

**Adjustment to the one-instruction-at-a-time default (stated 2026-09-21,
at the start of the coding agent's build):** grouping several instructions
together is acceptable, and often clearer, as long as each group is concise
and states three things up front — what it is for, which account runs it, and
which box it runs on. The actual goal is eliminating confusion and preventing
commands run under the wrong account or on the wrong host, not literal
one-command-per-message. Working rule: start a new group at every host or
account switch, and stop after any group whose result decides what comes next
(for example, a verification whose output determines the following step).
Labeling account and host on every group remains non-negotiable.

**Design for the whole homelab; prove it through Forgejo (stated 2026-09-21,
after noticing the framing recur across several sessions).** Forgejo is the
coding agent's proving ground and the documentation agent's actual subject,
not the boundary of what any agent is ultimately for. The question to ask
when designing anything is never "does this work for Forgejo/git" — it's
"does this work for the entire three-node homelab, and can it be proven via
Forgejo." When those two answers pull apart, design for the second and use
the first as the test harness. A throwaway container or VM stood up purely to
prove a concept, then torn down, is an expected and acceptable cost of
building this way, not a sign the design is wrong. Applied immediately: the
coding agent's workspace tools are described as generic task/check/propose
operations rather than git-specific ones, because git is today's proving
mechanism, not a permanent constraint on the design.

**Non-linear thinking and outside connections are explicitly welcome (stated
2026-09-21).** The user will regularly raise ideas and questions that don't
follow the current step sequence, and connections to things outside the
homelab (external services, package registries, documentation sources, other
systems) are acceptable to consider whenever they serve the goal — on the
condition that each connection's security side is thought through at the same
time as its usefulness (what it can reach, what can reach it, what happens if
what it returns is hostile or simply wrong), not afterward. Same standard as
everything else in this document: a real reason, a clear purpose, and a
conversation before execution.

## Standing Principles (inherited, non-negotiable unless explicitly revisited)

- **Ollama's context length (`num_ctx`) must be explicitly set to a real,
  generous value on every reasoning agent's Chat Model node — never left at
  whatever default the node happens to carry.** Confirmed as a recurring,
  previously-seen root cause, not a one-off: the documentation agent hit
  this exact failure numerous times before being fixed the same way. Ollama
  truncates silently on overflow — no error, no warning — which makes the
  symptom easy to misdiagnose as a reasoning failure rather than a plumbing
  one: a model that appears to repeat tool calls, forget its own system
  prompt, or never converge to a stopping condition may simply have lost
  access to its own earlier context as the window slid forward. n8n's Ollama
  Chat Model node exposes "Context Length" as an explicit manual field
  (confirmed present, not assumed), meaning it very likely sends a fixed
  value on every call rather than negotiating anything smarter with the
  server — so whatever this field is left at (or left blank) is the real,
  binding ceiling. Setting it costs real VRAM (the KV cache grows with
  context length on top of the model weights themselves), so the value
  should be confirmed as actually applied and not pushing the box into
  failure — checking `ollama ps` on the AI node after a real run shows the
  genuine, applied context size, and is the way to confirm this, not
  assumption either way.

- **No reasoning agent ever holds push-to-main, merge, or other destructive
  credentials — ever, for any tier of change.** This is 3k's original rule,
  restated for every future agent, not just the coding agent it was invented
  for. A reasoning agent proposes (branch, PR, draft); a separate,
  deterministic, non-AI mechanism (a broker identity, an explicit approval
  gate) performs the action; the user approves. This is why `polaris-merge-broker`
  exists as a third identity, distinct from both the proposer and the
  human — the same three-way split applies to every future agent that
  changes anything.
- **One credential, one purpose, proven empirically before being trusted.**
  Every agent gets its own dedicated identity (git, API, NAS, whatever it
  needs) scoped to exactly what that agent does — never a shared or reused
  broader credential, even when one is sitting there conveniently. Access
  grants get tested directly (a real `curl`, a real push attempt) rather than
  assumed correct from documentation, matching 3u's entire NAS-credential
  arc.
- **Sandbox-execution pattern.** An agent's reasoning (the LLM, via an n8n AI
  Agent node) and an agent's actual work (running commands, editing files,
  calling git) are different things running in different places. n8n's own
  container has almost nothing installed (confirmed directly in 3u) — every
  agent delegates real work to its own dedicated execution environment with
  real tools, the same way Homelab's and AI's existing SSH-node workflows
  already do, just with a container built for the purpose rather than a
  general-purpose host being borrowed.
- **One dedicated container per agent, hosted on the AI node.** The AI node
  is the hardware this was always meant to run on (GPU-accelerated Ollama in
  CT 401, orchestration in CT 402) — every future agent's execution
  environment lives there too, not shared with CT 401/402 or Docker01's
  existing services. cyberrange is never a candidate host for anything in
  this phase, for the same isolation reasons established throughout Phase 3.
- **Confirm, don't assume — especially for anything fast-moving.** Tool
  capability (e.g. exactly what n8n's Matrix node currently supports),
  ecosystem naming (self-hosted Matrix homeserver forks rename often), and
  access grants all get verified directly at build time, not trusted from
  a design conversation held earlier.

## Carried-Forward Open Items from Phase 3 (opportunistic — address as they come, not blocking)

These remain real and tracked, not forgotten — Phase 4 does not wait on them,
but they get picked up whenever convenient rather than left alone
indefinitely:

- `cifs.ko`'s root cause for restricted NAS accounts remains unconfirmed at the protocol level (working alternative in place, not urgent)
- `NAS-CyberRange` Proxmox storage definition (AI-restricted) is unused — candidate for removal
- CT402's `/etc/fstab` leftover broken cifs mount entry — candidate for removal
- Stale `ct402-git-deploy` deploy key on `Project_Polaris` — candidate for removal
- `polaris-coding-agent` bot-account hygiene (org creation, generic email)
- ntfy action-button tap-and-fire reliability — never tested
- `apt-listchanges` broken on the AI node — cosmetic, deferred
- Uncommitted pfsense→firewall01 rename sitting on Homelab — predates Phase 3 entirely
- Real TFTP export values for the new switch, Admin01's secondary-IP cleanup, the minor 3t SSH-multiplexing polish, Docker01's Tailscale join for reachable ntfy links
- The stale full-root Proxmox API token (`root@pam`, no privilege separation, no cyberrange exclusion) — deferred explicitly per this session's decision, tackled after the documentation agent is proven, **not reused for the documentation agent itself or any future agent regardless of convenience**
- **The merge-broker (3k) needs a holistic status audit, and a named point at which it actually gets tied in.** Forgejo-side and n8n-side pieces were built in Phase 3, then deliberately put on hold because the next steps depend on the other agents existing. Nothing here has verified where it actually stands end to end (Forgejo whitelists per repo, whether the n8n workflow exists and was proven on both tiers, where the token file lives and whether the workflow can read it). Tracked as its own item, not folded into any agent's build: read-only audit first, then decide. **Decision trigger: before the coding agent's first PR against `Project_Polaris`.** Until then the coding agent's PRs go to `Polaris-Pipeline-Testing` and are merged by hand, so nothing depends on the broker.
- **Phase 3's "Multi-Agent Architecture Vision" section (2026-09-09) contains text superseded by 3k's own later design corrections.** It says the foreman "directs the coding agent to merge"; 3k's 2026-09-13 corrections established that no reasoning agent (coding agent or foreman) ever merges — only the deterministic broker or the user. This runbook's 4g delivery model is authoritative. That Phase 3 paragraph should get a one-line annotation the next time that file is edited.

## Design Decisions Log (this planning session, 2026-09-16/17)

Captured in the order decided, same convention as Phase 3's own decisions log.

- **First agent to build and prove: the documentation agent**, chosen specifically as the smallest real scope, per the "prove one sub-agent before the foreman" rule. The backup agent (sits on Phase 3's now-complete collectors) and a reasoning layer over the existing `polaris-coding-agent` identity remain the next candidates, in no fixed order yet.
- **The stale full-root Proxmox API token is deferred, explicitly not inherited by any new agent.** Deferring its cleanup and handing a new agent broad access are two separate decisions — every new agent's Proxmox access (if any) is built from scratch, scoped to only what it needs, the same way `polaris-cyberrange-collector@pve` was built in 3u rather than reusing something broader that happened to already work.
- **Documentation agent's ultimate scope, stated explicitly so incremental steps stay aimed at it:** owns all documentation for the homelab — reads, writes, organizes, and eventually removes/restructures content across every repo and the dedicated wiki both. Building starts small (read-only Q&A first) and grows toward this deliberately, not all at once.
- **Documentation platform — revised twice in the same session, each time for a stated reason: Wiki.js, then MkDocs.** Wiki.js was chosen first for its git-sync backend (the only major live-wiki option storing content in real git rather than a private database). Once actually designing around it revealed two things — (a) it has no draft/approval workflow at all, so its live editor could never be used by the agent without breaking the standing no-unreviewed-changes rule, and (b) `homelab-infrastructure`'s actual contents made a live wiki app's real differentiators (multi-user live editing, WYSIWYG) irrelevant, since literally nothing here would ever be edited that way — the remaining case for running Wiki.js at all shrank to "renders a git repo of markdown with navigation and search," which a static site generator does with far less machinery (no database, no live sync-direction question, no ambiguity about non-markdown files). Switched to **MkDocs**: content stays exactly where it already lives in git, a build step generates a static site, and there is no "app" running with its own state to keep consistent with git at all. See 4b for the concrete pipeline.
- **Sync target confirmed: `homelab-infrastructure`'s existing root, no new dedicated repo** — unaffected by the Wiki.js→MkDocs switch, this was already decided once the repo's real contents were reviewed (a large, mature documentation corpus, not primarily infra-as-code as first assumed). **Docker01 remains the intended primary, canonical documentation library — git/Forgejo is the backup and version-history layer underneath it, not the other way around** — "the documentation agent is the librarian who authors and edits its own books with my direction and approval," working against the library the user already spent significant effort building. Plain branch/PR write access to every other repo (`Project_Polaris` included) for documentation living inside them remains the plan for anything outside `homelab-infrastructure` itself.
- **The no-live-editing conclusion holds regardless of platform, and is if anything cleaner under MkDocs.** The agent's real drafting/editing happens in a git branch (the workroom); only an approved, merged change ever appears in the built site (the library). There is no live app UI to accidentally edit directly and lose — MkDocs has no editor at all, so the earlier Wiki.js-specific risk (a direct in-app edit silently overwritten by the next sync) simply doesn't exist as a category. The user's own direct edits, if wanted, go through git via the same admin-bypass path `lab-admin` already has in 3k, same as before.
- **Confirmed: Nginx Proxy Manager already fronts most of Docker01's existing services** (`git.polaris.home.arpa`, `homepage.polaris.home.arpa`, etc., each with its own custom certificate) — the built static site gets served the same way, through the same proxy, for consistency with everything else already running there.
- **Execution pattern: sandbox-as-execution, clone-on-demand.** The agent's own dedicated container clones what it needs, edits in place, commits, pushes a branch, opens a PR, and (implicitly) discards the clone rather than keeping a persistent checkout around — deliberately avoiding the exact class of problem 3u found and fixed (a forgotten, still-credentialed leftover clone on CT402 from earlier 3k testing).
- **Own dedicated identity, matching 3k exactly**: a new account (e.g. `polaris-documentation-agent`), its own SSH key, scoped as a collaborator only on the repos it touches. It proposes via branch and PR; it never merges. Flow: foreman directs the documentation agent → agent drafts the change → pushes for review → the broker mechanism (or the foreman on the broker's behalf) submits the PR → the user approves → the user or the foreman merges. No new exception to the standing merge rule.
- **Remote/local interaction channel: a self-hosted Matrix homeserver, reachable only via Tailscale — not Telegram**, after weighing both. Telegram requires a public HTTPS webhook with no alternative (confirmed directly) — a genuinely different exposure posture than anything else built so far. A Tailscale-only Matrix homeserver gets a real, polished mobile client (Element) and genuine push notifications (waking the phone is an outbound call to Apple's/Google's push relay regardless of transport — it needs no inbound exposure at all) with **zero new public exposure**, the same trust boundary ntfy already proves works off-network. Telegram is not discarded permanently — it remains an option if the Matrix route hits a wall — but it is not the current direction.
- **Homeserver choice: a lightweight Rust implementation (the Conduit/Conduwuit lineage — verify the currently-actively-maintained fork/name at build time, this corner of the ecosystem renames often), Dendrite as fallback, Synapse considered and set aside.** Synapse's and Dendrite's real strengths (federation robustness, horizontal scale, maximum spec coverage for bridging) aren't needed by a single-operator, non-federating, tailnet-only deployment — the lightweight option's SQLite-only footprint (no separate Postgres service) and minimal resource use are the better fit. A software rename after deployment has no effect on a running instance — it only affects where future patches come from, and carries no forced-migration risk here specifically because there's no federation identity tied to a domain other servers have cached.
- **End-to-end encryption disabled for the bot's room(s).** Matrix's E2EE exists to protect messages crossing servers you don't control — since nothing here ever leaves the tailnet, the transport privacy already comes from Tailscale, and disabling encryption avoids real bot-side complexity (device verification, key management) for no meaningful privacy loss in this design.
- **The Matrix homeserver is its own dedicated piece of infrastructure, not owned by whichever agent tests it first.** It's fundamentally a foreman-level capability (how the user talks to the system at all) that happens to need a first real test — the documentation agent is the leading candidate for that first test given it's already the first agent being built, but this is explicitly reversible if it turns out to add too much risk/complexity to prove alongside the documentation agent's own core function.
- **n8n's Matrix integration depth (native node vs. raw Client-Server API via HTTP Request) is deliberately left unresolved until build time** — verify directly in n8n's node palette rather than trust an assumption, the same discipline that already corrected a wrong assumption about "Execute a command" nodes earlier in Phase 3.

### Decisions recorded from the 2026-09-21 session

These had been captured only in the session's resume brief; recorded here so
this document is again the complete source of truth.

- **Matrix (4d/4e) is reassigned to the foreman, not the documentation agent — a deliberate choice, not a shortcut.** Direct, foreman-free access to a sub-agent has real, ongoing value: it is exactly how every serious bug in 4c was found, by watching a sub-agent's raw tool traces without a foreman's own reasoning in between. n8n's own chat panel already provides that permanently and is the documentation agent's standing debug interface, not a placeholder. Matrix becomes the production interface reserved for the foreman once it exists. Revisit explicitly for each future sub-agent rather than assuming it carries over.
- **Build order confirmed: coding agent, then networking agent, then the foreman.** Deliberately in that order: the coding agent's work is safely reversible (an unmerged PR costs nothing), while the networking agent will eventually touch VLANs, bridges, DNS records, and ACLs with real, potentially live effects. Any genuinely new pattern (4c found several: model-output corruption, internal-detail leakage, node-naming collisions) is far better discovered on low-stakes ground first.
- **Every agent gets the same deliberate design conversation and safety-model scrutiny as the documentation agent — regardless of how dangerous its job sounds on paper.** What an agent ends up owning and touching often isn't knowable in advance; the documentation agent's own design changed repeatedly in-situ (Wiki.js to MkDocs, a new repo to the existing one, one overloaded tool to several narrow ones, single-write to read/search/write/rename), and the coding agent should be expected to evolve the same way.

## Build Plan

Lettered the same way Phase 3's was, starting fresh at 4a. Each step is meant
to be small enough to prove before moving to the next — per the Working
Philosophy above, expect this sequence to be adjusted as real building
reveals things.

### 4a: Documentation Agent — Execution Environment & Identity — COMPLETE (2026-09-17)
- **CT 403 "documentation-agent"** on the AI node — unprivileged, 2 cores,
  2048MB memory, 512MB swap, 16GB disk (`ai-storage`), `192.168.10.202/24`,
  Ubuntu 26.04, `nesting=0` (deliberately, since this container runs no
  Docker of its own). Privileged-vs-unprivileged and full-VM-vs-container
  both discussed explicitly before building — unprivileged/LXC confirmed as
  the right call given this container needs no GPU, no nesting, and holds no
  destructive credential; revisit container-vs-VM if a future agent's own
  scope ever grows real destructive power of its own.
- **Real, non-obvious problem found and fixed, not routed around:**
  `systemd-networkd` and `systemd-journald` both failed to start on first
  boot (`code=exited, status=243/CREDENTIALS`), leaving the container with
  no network at all despite Proxmox's own config showing an IP assigned.
  Root cause confirmed via host-side `dmesg`/`journalctl -k`: Proxmox's
  default AppArmor confinement profile for unprivileged containers was
  denying the `mount`/`move` operations systemd's own credentials mechanism
  needs at startup — a rough edge specific to this newer
  systemd/Ubuntu-26.04 combination against Proxmox's default profile, not a
  misconfiguration of this container specifically. Fixed by adding
  `lxc.apparmor.profile: unconfined` to `/etc/pve/lxc/403.conf` — the exact
  same setting `402.conf` already carries, which was almost certainly added
  there for Docker's sake and has likely been silently fixing this same
  underlying issue for CT 402 the whole time without anyone realizing it
  was doing double duty. See Open Items.
- `polaris-documentation-agent` created as its own Forgejo identity (not a
  repo-scoped deploy key — same reasoning as `polaris-coding-agent`: access
  needs to span multiple repos over this agent's lifetime, not one). SSH key
  generated on CT 403 itself, added to the account, hit and cleared the same
  `ssh-keygen -Y sign` first-use verification `polaris-coding-agent` hit in
  3k. Proven end-to-end against `Polaris-Pipeline-Testing` — the first clone
  attempt correctly failed with an authorization (not authentication) error
  before the account was added as a collaborator, confirming the
  authentication-vs-authorization distinction held exactly as expected; a
  clean clone followed once collaborator access was granted.

### 4b: Documentation Site Stand-up (MkDocs)
- **No live application, no database — a build pipeline instead.** MkDocs
  turns a tree of markdown plus one `mkdocs.yml` config into a static HTML
  site; there's no server-side state to keep in sync with git at all, which
  is exactly why this replaced Wiki.js (see Decisions Log). `mkdocs.yml`
  lives at `homelab-infrastructure`'s repo root, alongside the content it
  describes.
- **Trigger: the same Forgejo webhook pattern already proven in 3k**, not a
  new mechanism — a push/merge to `homelab-infrastructure`'s `main` fires a
  webhook to n8n. n8n itself has almost nothing installed (confirmed in 3u),
  so the actual build — `git pull`, `mkdocs build` — runs over SSH on a real
  host with real tools, the same delegation pattern used everywhere else in
  this project. Docker01 itself is the natural place for this to run, since
  it already holds the source repo and is where the built site should live
  and be served from — no cross-host artifact copying needed at all.
- **Serving the output:** the built static site sits behind the existing
  Nginx Proxy Manager, matching every other service already running on
  Docker01 (`git.polaris.home.arpa`, `homepage.polaris.home.arpa`, etc.) —
  a new host entry (e.g. `docs.polaris.home.arpa`) pointed at wherever the
  built site is served from (a minimal static-file container, or nginx
  itself pointed directly at the build output directory).
- **Deliberately not solved here: making the *entire* messy existing tree
  present cleanly in one navigation structure.** Reviewing the actual repo
  turned up real disorganization worth naming plainly, not smoothing over —
  there are two separate `architecture/` directories (one at the repo root,
  one under `docs/`) and two separate `operations/` directories the same
  way, plus obviously duplicated files (`CHANGELOG(1).md`, `CHANGELOG(2).md`,
  `dns-registry(1).md`, `port-registry(1).md`). Reorganizing that is
  explicitly the documentation agent's own future job, not something to
  hand-solve while just standing up the build pipeline. **4b's actual scope:
  prove the mechanism — webhook → build → serve — against one small, clean,
  self-contained subset of real content first** (a single existing directory
  with no obvious duplication), confirm it works end to end, and treat
  expanding `mkdocs.yml`'s nav to cover the full corpus as real, later work
  for 4c/4d once the agent exists to actually do the reorganizing rather
  than a human hand-curating it during infrastructure stand-up.
- Non-markdown content (the real `.docx` files, `.tar.gz` build artifacts,
  actual `docker-compose.yaml` service definitions all living in the same
  repo root) is a non-issue under MkDocs specifically, unlike the earlier
  Wiki.js uncertainty — `docs_dir`/`nav` in `mkdocs.yml` explicitly lists
  what's included; anything not named simply isn't part of the built site,
  no ambiguous rendering behavior to test for.

**Stage 1 (manual build) and Stage 2 (serving) — COMPLETE (2026-09-17/18).**

- **Credential:** `polaris-mkdocs-build`, a repo-scoped **deploy key** on
  `homelab-infrastructure` (not a full Forgejo user account like
  `polaris-documentation-agent` — this process only ever reads one specific
  repo, a deploy key is the narrower, correctly-scoped tool for that),
  read-only (write access left unchecked). Generated on Docker01 itself.
- **Build:** cloned to `~/mkdocs-build/homelab-infrastructure` (a plain home
  directory, not `/opt`, since the working account has `sudo` rights but not
  root, and `/opt` is conventionally root-owned). `mkdocs.yml` at the repo
  root, `docs_dir: engineering/adr` — scoped to one clean, well-numbered,
  duplication-free subset of the real content, deliberately not the full
  (currently disorganized) tree. Built via a throwaway `python:3.12-slim`
  container rather than installing Python packages onto Docker01's host OS
  directly. **Real gotcha hit and fixed:** running the container with
  `--user "$(id -u):$(id -g)"` alone isn't sufficient to avoid root-owned
  output — the container has no `/etc/passwd` entry for that UID, so `$HOME`
  resolves to `/` and `pip install --user` fails outright trying to write to
  `/.local`. Fixed with an explicit `-e HOME=/docs` pointing at the same
  mounted, already-owned directory. Verified correct by confirming build
  output was owned by the real user, not root.
- **Proof of exact-content fidelity, not just "it built something":** the
  first build only showed ADRs `0000`-`0013`, not the full `0000`-`ADR-022`
  range visible in the originally-uploaded zip. Confirmed via direct
  `ls` on both the source directory and a fresh clone that this was
  MkDocs correctly reflecting what's actually committed to `main` —
  the missing ADRs exist only in a local, never-uploaded copy. Good,
  reassuring proof the pipeline doesn't leak or infer content from anywhere
  outside git; also surfaced a real, separate task (getting that
  never-committed content, including real `.docx` files needing conversion
  to markdown, actually into the repo) for the documentation agent's own
  future work rather than something to fix now.
- **Serving:** a plain `nginx:alpine` container (`mkdocs-site`), bind-mounted
  read-only against the build's `site/` output, joined to the `infrastructure`
  Docker network — confirmed via `docker inspect` to be the same network
  Forgejo and Nginx Proxy Manager already share, rather than the separate
  `monitoring` network NPM is also attached to. No host port published at
  all; reachable only via NPM over the internal Docker network, matching
  every other service on Docker01.
- **A real 403 hit and deliberately left as-is:** no `index.md` exists in
  `engineering/adr/`, so there's no homepage for nginx to serve at the site
  root — expected behavior (nginx correctly refusing to list directory
  contents), confirmed as exactly that by verifying a real built page
  *did* serve correctly (a clean `200 OK`, correct size, correct timestamp)
  while only the bare root returned 403. **Deliberately left as a known,
  named gap** — creating a good homepage is planned as the documentation
  agent's own first real proof-of-concept task once 4c exists (small,
  low-stakes, easy to judge — a good first exercise of the full
  reason → branch → PR → approval → merge → rebuild loop before trusting
  the agent with anything more consequential).
- **NPM proxy host:** `docs.polaris.home.arpa` → `mkdocs-site:80` (by
  container name, matching how every existing entry references its own
  backend), same SSL/certificate approach as the existing entries.
- **Real, non-obvious DNS gap found and fixed, worth remembering for any
  future hostname added to this environment:** adding the NPM proxy host
  alone did nothing — `docs.polaris.home.arpa` came back `NXDOMAIN`.
  Confirmed via `resolvectl status` on Docker01 that DNS for this whole
  segment resolves through `192.168.10.1` (firewall01, pfSense) — NPM
  itself creates no DNS records at all, it only decides what to do once a
  request already arrives there. **The `.polaris.home.arpa` zone has no
  wildcard record** — every hostname (`git`, `homepage`, `proxy`, `status`,
  `storage`, `vault`, and now `docs`) has its own individual **Host
  Override** entry in pfSense's **DNS Resolver** (confirmed active over the
  alternative DNS Forwarder mode) under Services. Any future new hostname on
  this network needs the exact same manual step — there is no
  automatic/wildcard path that will ever make a new subdomain resolve on its
  own.
- **Fully verified end-to-end**, not just piecewise: a real browser, on the
  real domain, loaded a real built page — DNS → NPM → nginx → the MkDocs
  build output, every layer proven, not just individually `curl`-tested in
  isolation.

**Stage 3 (Forgejo webhook → automatic rebuild) — steps 1-3 of 5 complete (2026-09-18).**

- **Identity design, decided deliberately rather than defaulted:** a third,
  separate identity for this job — not `polaris-documentation-agent`'s own
  key, and not named after n8n (the *caller*) — matching the exact 3k
  three-way split (proposer / mechanical executor / approver).
  `polaris-mkdocs-rebuild`: a genuinely new Linux account on Docker01, `docker`
  group only, no `sudo`, no interactive use intended (forced-command SSH
  restriction planned as step 4, not yet done). Its own clone of
  `homelab-infrastructure`, reusing the *existing* `polaris-mkdocs-build`
  deploy key for git access (correctly scoped already — read-only, this one
  repo — no reason to duplicate it) rather than a login credential, which is
  what's actually new here.
- **Three real, concrete problems hit and fixed while proving this — each
  worth remembering for the next similar build, not just this one:**
  1. **A deploy key sitting in one account's home directory isn't usable by
     another account on the same box**, even with correct key-file
     permissions — the home directory's own permissions (correctly private
     by default) block the second account from ever reaching it. Fixed by
     copying the key into `polaris-mkdocs-rebuild`'s own `~/.ssh`, not by
     loosening `lab-admin`'s directory permissions.
  2. **Docker's bind-mount auto-creation always runs as root**, regardless
     of any `--user` flag on the container using that mount — if a bind
     mount's host path doesn't already exist when a container starts, Docker
     silently creates it root-owned, no error, no warning. This produced a
     `PermissionError` inside the *build* container (a completely different
     container, running correctly as an unprivileged user) trying to write
     into a directory Docker itself had created as root moments earlier.
     Fixed with a one-time `chown` once identified — worth remembering for
     any future container whose mount target doesn't pre-exist.
  3. **`mkdocs-site` was still pointed at `lab-admin`'s original
     proof-of-concept path**, not `polaris-mkdocs-rebuild`'s real clone —
     the two were quietly disconnected until the container was recreated
     with the corrected mount. A subtle trap: testing continued to show
     stale results that looked like the old problem persisting, when the
     actual pipeline had already moved on to a completely different
     directory.
  4. **`.pub` vs. private key** — a plain, easy mixup: `id_ed25519.pub` (the
     shareable half, meant to be uploaded to Forgejo) is not usable as an
     SSH client identity; SSH's own "bad permissions" complaint on a `.pub`
     file is a symptom of trying to use the wrong file entirely, not a real
     permissions problem to chase.
- `mkdocs.yml` itself had been sitting **uncommitted** in `lab-admin`'s
  original proof-of-concept clone since stage 1 — never pushed, which is why
  `polaris-mkdocs-rebuild`'s fresh clone never had it. Committed directly to
  `main` (a deliberate, explicit choice for this first infrastructure-setup
  file, reasoned the same way as any other sole-human-authored change — no
  one else exists to review it) using `lab-admin`'s existing write-capable
  "docker01" key.
- **Fully re-verified end to end after all fixes**: a real `200 OK`, correct
  size, fresh timestamp, on the real domain, built and served entirely by
  the dedicated `polaris-mkdocs-rebuild` account — not `lab-admin`, not a
  stale mount.

**Step 4 (forced-command SSH key) — COMPLETE (2026-09-18).** A second,
separate key on `polaris-mkdocs-rebuild` — `polaris-mkdocs-rebuild-login`,
distinct from the `polaris-mkdocs-build` deploy key already there for git —
generated for this one purpose: letting n8n authenticate as this account at
all. Locked down in `authorized_keys` with `command="/home/polaris-mkdocs-rebuild/rebuild.sh"`
plus `no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty` —
regardless of what a connecting client actually requests, only the rebuild
script can ever run, no tunneling, no interactive shell under any
circumstance. **Proven, not assumed**: a test connection deliberately
requested `whoami; ls /` and the forced command overrode it, running the
real rebuild instead — confirms the restriction actually intercepts an
arbitrary request rather than just working when nobody tries anything else.

**Step 5 (Forgejo webhook → n8n workflow) — COMPLETE (2026-09-18). 4b is now
fully complete.**

- n8n's container had never been touched for any AI/agent/backup purpose
  before this step — recreated from a standalone `docker run` (not
  compose-managed) to add a second, dedicated environment variable
  (`FORGEJO_MKDOCS_WEBHOOK_SECRET`, distinct from the merge-broker's own
  secret), reconstructed field-for-field from `docker inspect` output rather
  than guessed. Confirmed the `n8n_data` volume (not the container itself)
  holds all workflow state, so recreation carried zero risk to the existing
  3k merge-broker workflow — verified directly rather than assumed.
- Workflow: **Webhook** (POST, raw body enabled, `homelab-infrastructure-rebuild`
  path) → **Code** (HMAC verification reusing 3k's proven `x-forgejo-signature`
  pattern exactly, adapted to also check `ref === 'refs/heads/main'`, since
  Forgejo's push webhook fires for any branch) → **IF** (`routeRebuild`) →
  **SSH** (the new `polaris-mkdocs-rebuild` credential, command field
  functionally a formality given the server-side forced-command
  restriction).
- **Proven in stages, never skipped ahead**: signature/branch logic verified
  against a real Forgejo Test Delivery before the IF/SSH nodes were even
  built; each new node confirmed individually before being connected to the
  next; Test URL exercised fully before switching to Active/Production.
  **Final proof was a genuinely ordinary `git push`** — no manual trigger of
  any kind — with the live site confirmed updated afterward, the actual bar
  for "this works unattended."
- **Process note, not a technical one, worth carrying forward:** this step's
  build was conducted strictly one instruction at a time (one action, its
  reason stated separately and briefly beforehand, confirmation before the
  next), after direct, warranted feedback that earlier steps in this same
  session mixed too much explanation, too many steps, and too little
  explicit direction into single responses. Given how well this format
  worked for a multi-account, multi-system build with real
  webhook/credential/container stakes, it's the default going forward for
  any comparably complex step still ahead in this project, not something
  applied only after being asked again.

**4b (Documentation Site Stand-up) is now fully complete**: a working,
automatically-rebuilding static documentation site, served through the
existing Nginx Proxy Manager, triggered by ordinary pushes to
`homelab-infrastructure`'s `main` branch, with every credential in the chain
narrowly scoped to exactly one job.

### Model Selection for the AI Host — Decisive, Evidence-Based (2026-09-18/19)

Real detour from the build itself, deliberately taken before committing 4c
to a specific model — Phase 2 had only ever proven `qwen2.5:14b-instruct`
worked *at all*, never that it was the *best* available choice, and this
phase's every future agent depends on getting this right rather than
inheriting a default.

**Methodology — three genuinely different tests, not one:**
1. **Raw throughput/VRAM fit**, one consistent prompt ("explain what DNS is
   in about 250 words") across 14 pulled models, using `ollama ps` (the
   authoritative GPU/CPU split — confirmed more precise than raw `rocm-smi`
   VRAM bytes, which don't attribute usage to a specific model's placement
   decision) alongside `rocm-smi`/`amd-smi` for live utilization.
2. **Tool-calling reliability**, via direct `/api/chat` calls with a real
   `tools` schema — one prompt that should trigger a call, one that
   deliberately shouldn't, since a model that over-calls tools is its own
   kind of unreliable, not just one that under-calls them.
3. **Coding correctness**, in two rounds: a simple bash bug-hunt first,
   then a deliberately harder Python interval-merging task modified with
   one specific twist (preserving original input indices through a sort) —
   chosen specifically because the unmodified version of this problem is
   one of the most heavily memorized problems in programming, and the twist
   forces genuine reasoning rather than reproducing a familiar template.

**Concrete findings, several load-bearing for more than just model choice:**
- **`qwen3.6:27b` conclusively ruled out** — confirmed a real thing, not a
  theoretical concern from earlier design discussions: 78%/22% GPU/CPU
  split, 1.56 tokens/sec, unusable. Directly validates the general
  VRAM-headroom reasoning behind capping consideration at ~22B models.
- **`llama3.1:8b` and `qwen3-vl:8b` both refused a trivial arithmetic
  question** ("what is 12×7") outright rather than answering — a real
  reliability red flag for `llama3.1:8b` as a general candidate; less
  disqualifying for `qwen3-vl:8b` given its role is vision, not general
  reasoning.
- **Two independent, hand-verified bugs in the two coding-specialized
  models, on the harder test only** — `qwen2.5-coder:14b` sorted its input
  in place and then used post-sort list positions as if they were original
  input indices, a bug invisible in its own test suite because all three of
  its self-authored test cases happened to already be pre-sorted;
  `deepseek-coder-v2:16b` introduced an off-by-one (`start <= end + 1`) that
  silently over-merges genuinely non-touching intervals, directly
  contradicted by its own test case's stated comment. Both looked complete
  on a surface read; both were wrong in ways their own provided tests
  failed to catch — confirming the harder test's specific design goal (surfacing confident-but-wrong answers, not just incomplete ones) actually worked.
- **`gpt-oss:20b` won or tied on every single test in the entire series** —
  clean tool-calling on both cases, the most defensively-written bash fix
  (input validation, clear stderr messaging, `-print` before delete —
  matching this project's own scripting conventions independently), and the
  *only* model of four to correctly solve the index-preservation twist,
  verified by hand-tracing its own deliberately-adversarial (pre-shuffled)
  test case and confirming the output matched exactly what it claimed.
- **`qwen3:14b` performed nearly as well** — passed both tool-calling tests
  and solved the hard coding test's actual algorithm correctly, only
  falling short on delivering the explicitly-requested three separate test
  cases (a completeness gap, not a correctness one).

**Decision: no dedicated coding-specialist model.** Both models tested
specifically for coding showed real, hand-verified bugs on the one task
that actually required reasoning rather than pattern-matching a familiar
problem, while the two general-purpose finalists both handled it correctly.
The added architectural complexity of routing "write code" to a separate
model was not earning its keep against the actual evidence.

**Final model assignment:**
- **`gpt-oss:20b`** — general-purpose workhorse for every text-based agent
  in this phase (documentation, and by extension backup/coding-reasoning
  once those are built).
- **`qwen3:14b`** — legitimate backup, not a demotion; nearly identical
  results throughout, worth keeping loaded/available rather than discarded.
- **`qwen3-vl:8b`** — vision, settled without real competition —
  `llama3.2-vision:11b` failed to load at all on this Ollama version
  (`unknown model architecture: 'mllama'`), and `qwen3-vl:8b` described a
  real test screenshot correctly and in full.

**Explicit caveat, stated deliberately rather than left implied:** this is
the best result *from the testing actually done, for the purposes actually
planned* — not a claim that these are the best possible models for every
future circumstance, or that this list is closed. If a future agent's job
turns out to need something these tests never probed for (a much larger
context window, a narrower specialist skill, a model that didn't exist yet
at testing time), that's a real opportunity worth testing on its own merits,
not something to skip on the assumption this round of testing already
covers it. Model selection is a per-task question to keep asking, not a
one-time decision this document closes out permanently.

### 4c: Documentation Agent — Reasoning Layer

**Workflow and connectivity — COMPLETE.** New, dedicated n8n workflow
(`Documentation Agent`), deliberately separate from Phase 2's own
proof-of-concept "AI Agent" workflow (left untouched, still functional) —
building real logic on top of a demo workflow would blur "temporary test"
and "real agent" the same way reusing a broad credential blurs "who did
this." Reused the existing **"Ollama account" credential** (a connection is
shareable across agents; only the model selected inside it is per-agent),
pointed at `gpt-oss:20b`. Chat Trigger → AI Agent → Ollama Chat Model, proven
end to end.

**A real, if minor, finding along the way**: asked the model directly to
confirm its own identity, and it confidently claimed to be GPT-4/GPT-4o —
completely wrong, but not a misconfiguration. Confirmed via `ollama ps`
(never trust a model's self-report; verify independently, same principle as
checking `git log` rather than trusting a commit's claimed authorship) that
`gpt-oss:20b` was genuinely loaded and answering. This is a well-documented,
near-universal LLM behavior — models pattern-match "what does an AI
assistant sound like" toward whatever identity dominates their training
text, having no real introspective access to their own deployment. Practical
consequence: this model's identity or role must always be stated explicitly
in any prompt that depends on it — it cannot be trusted to know or report
this about itself.

**Identity and credentials for Forgejo access — COMPLETE.**
`polaris-documentation-agent` (existing identity from 4a) granted read-only
collaborator access to `homelab-infrastructure`, plus a narrowly-scoped
Forgejo API token (Forgejo's token scoping is coarse — a single
Repository-level read/write toggle, not finer sub-permissions; "Repository:
Read" is the narrowest available). **A real gap found while setting up the
credential**: n8n has no dedicated Gitea/Forgejo credential type at all, and
GitHub's credential type targets `api.github.com`'s specific API shape, not
a generic git host. The correct, already-proven approach: a generic
**Header Auth** credential, `Authorization` / `token <secret>` — the exact
mechanism `Forgejo - polaris-merge-broker` already uses for the 3k webhook
integration, copied rather than reinvented once confirmed by inspecting
that existing credential directly.

**Read-only tool set — COMPLETE, after a real design failure and several
concrete bugs, all worth remembering:**

- **First design, abandoned**: one HTTP Request Tool covering both "list
  the root" and "read a specific path" via a single `$fromAI('file_path', ...)`
  parameter (empty string for root, a path otherwise). Failed repeatedly and
  in different ways — the model stuffed unrelated prompt text into the
  parameter once, and even after the instruction was tightened, reliably
  producing *both* "empty when appropriate" *and* "correctly prefixed with a
  slash when not" from one field proved to be more precision than the model
  consistently delivered. Three distinct failures on one overloaded field is
  itself the signal, not each failure individually.
- **Real Forgejo routing behavior, confirmed the hard way**: `/contents`
  (no trailing anything) and `/contents/{filepath}` are genuinely separate
  registered routes, not variations of the same one — a trailing slash with
  an empty final segment matches neither and 404s. This is why the original
  design's "empty string appended after a fixed trailing slash" approach
  could never work, independent of anything about the model's behavior.
- **Final design: two single-purpose tools**, matching the "one job per
  tool" principle used everywhere else in this project:
  - **`List Repository Root`** — fully fixed URL
    (`.../contents`, deliberately no trailing slash), zero model-supplied
    content, cannot be garbled.
  - **`Read File or Directory`** — `$fromAI('file_path', ...)` for a
    single, already-known path; the leading slash is now a fixed character
    in the static URL template, never something the model has to supply
    correctly itself.
- **A credential typo (`Authorzation`) silently caused every single 404**
  seen while debugging the routing issue above — Forgejo deliberately
  returns a generic 404, not 401/403, when authentication fails against a
  *private* repository, specifically so a failed request can't even confirm
  the repo exists. This meant a real routing bug and a real credential typo
  were stacked and indistinguishable from each other until the typo was
  found by inspection, not deduced from the error alone.
- **A UI misclick** set one tool's URL field to "let the model define this"
  with a blank description — produced a fabricated call to
  `api.github.com` for a nonexistent user/repo. Not the model hallucinating
  unprompted; an ungoverned field getting filled with the single most
  common real-world pattern for "look up a repo via API." Resolved by
  reverting the field to its fixed string.
- **Context window was 2048 tokens by default** — too small for a
  multi-tool agentic loop that resends the full conversation, both tools'
  schemas, and every prior (verbose) tool result on each iteration.
  Contributed to at least one "Max iterations reached" failure and likely to
  garbled tool-call output. Raised to 8192; confirmed via `amd-smi`/`rocm-smi`
  that this left comfortable VRAM headroom (~13.5GB/17GB, 2% GPU busy) —
  checked directly rather than assumed safe, same discipline as every other
  VRAM decision this project has made.
- **The most serious finding, and the reason this tool set is trusted now
  rather than earlier**: even after the plumbing was fully fixed, the model
  produced a long, specific, entirely fabricated description of seven
  subdirectories' contents — exact byte counts, exact filenames — while the
  real tool-call trace showed at most one or two actual calls. Ruled out
  session/memory leakage directly (no Memory node was ever connected to the
  AI Agent) and ruled out a leaked system prompt (it read only "You are a
  helpful assistant"). Conclusion: confident template-completion, not
  information leakage — the fabricated structure matched generic
  "well-organized IT documentation" conventions closely enough to look
  real, precisely because the real repository also happens to follow fairly
  conventional naming. Fixed with an explicit system-message rewrite:
  never state anything not backed by an actual tool call in the current
  conversation; a directory's reported size is always `0` and never implies
  emptiness; say plainly what hasn't been checked rather than inferring it.
- **That fix's own overcorrection**: the very next test, the model did the
  correct, complete tool work and then returned a non-answer ("I'm ready to
  help — what would you like to know?") instead of reporting what it had
  just verified. Fixed with two further rules appended to the system
  message: give a complete answer once enough real data has been gathered,
  and never call the same tool with the same input more than once in one
  turn.
- **Final verification**: a real, multi-part question (list `docs`, an
  actual 9-entry mix of files and directories) answered completely,
  correctly, and with exactly one call per tool needed — no fabrication, no
  redundant calls, no non-answer. This is the first fully proven
  agent-plus-tools interaction in this phase.

**A second, more serious fabrication found immediately after the first fix
— base64-encoded file content, structurally solved rather than
prompted around.** Every test above only ever touched directory metadata or
empty files. Asking the agent to read a real, populated file
(`engineering/adr/0000-Project-Polaris-Architectural-Charter.md`, 10.5KB)
produced a long, specific, entirely fabricated answer — invented
technologies (Terraform, Pulumi, HashiCorp Vault, Prometheus/Grafana/Loki,
GitHub Actions) that appear nowhere in the real document, while every real,
specific detail actually in the file (pfSense, Forgejo, Vaultwarden, the
four real trust zones, Docker01, Admin01) was completely absent from the
answer. **Independently decoded the same base64 with plain Python outside
n8n entirely** to establish ground truth before diagnosing anything — the
real content is a genuine, coherent architectural charter, confirming the
tool had delivered the exact correct data and the model simply didn't use
it.

- **Root cause, and why it's not model- or prompt-specific**: base64
  decoding is a precise, character-level transformation that doesn't map
  cleanly onto how language models tokenize and reason over subword chunks
  — a near-universal weak point across models generally, not a `gpt-oss`
  quirk. The model appears to recognize "this is an encoded document" and
  generate a plausible *generic* architecture document from training
  patterns, rather than actually performing the decode. Confirmed with the
  user this isn't worth testing against a different model — the failure
  mode is architectural, not a quality difference between models.
- **Fix: never ask the model to decode base64 at all.** Built a standalone,
  reusable **`Base64 Decode`** utility workflow (Execute Workflow Trigger →
  a plain Code node running `Buffer.from(x, 'base64').toString('utf-8')`) —
  deterministic, zero LLM involvement, proven standalone with a known
  string before being trusted anywhere else. Deliberately built as a
  generic, reusable utility rather than inlined logic, matching the same
  reasoning behind `lib/polaris-common.sh` in the bash side of this project
  — any future tool reading file content from a git host will hit this
  identical encoding, and fixing/improving the decode logic once, in one
  place, beats duplicated copies later.
- **`Read File or Directory` rebuilt as its own sub-workflow**, not a
  single HTTP Request Tool node: Execute Workflow Trigger → HTTP Request
  (the same proven Forgejo call, now fed a plain `file_path` rather than a
  live `$fromAI()` expression) → a Code node determining whether real
  decoding is needed at all (exactly one entry, `type: "file"`, non-null
  `content` — correctly excludes both directory listings and genuinely
  empty files) → IF branch → either a call to `Base64 Decode` followed by a
  Code node reassembling the full result with real content substituted in,
  or a straight pass-through for anything not needing decoding → both
  branches recombined via a **Merge (Append)** node, since exactly one
  branch ever produces real output per execution and the other is always
  empty.
- **Two real, non-obvious n8n bugs hit and fixed while building this,
  worth remembering for any future sub-workflow:**
  1. **The Code node's two "run once" modes require different return
     shapes** — "Run Once for All Items" needs an array (`return [{ json:
     {...} }]`); "Run Once for Each Item" needs a bare object (`return {
     json: {...} }`). Mismatching the two produces a validation error, not
     a silent wrong answer, but it's an easy, non-obvious trap.
  2. **The HTTP Request node silently splits a top-level JSON array
     response into one n8n item per array element** — a 9-entry directory
     listing arrives as 9 separate items, never one item containing an
     array of 9. The first version of the branching Code node used
     `$input.item` (only ever "the current item") and, combined with a
     downstream node that only read the *first* of several items, silently
     dropped 8 of 9 real directory entries with no error at all — the
     "Read Once for Each Item" node deprecation warning n8n now shows for
     Execute Workflow nodes is a related, current-generation instance of
     this same general class of trap. Fixed by switching to `$input.all()`,
     which correctly sees every item regardless of how many the HTTP node
     produced.
- **A real design question resolved along the way**: confirmed that a
  single agent request for multiple files always becomes multiple
  independent calls through this sub-workflow, one per file, combined into
  one answer by the agent's own reasoning — proven both before and after
  today's fix by direct observation of real multi-call traces. The
  sub-workflow itself has no multi-file concept, and doesn't need one, both
  because the trigger only accepts one path and because Forgejo's API can
  never return multiple real file contents from a single-file request.
- **Final integration**: the AI Agent's tool connection switched from the
  original HTTP Request Tool to a **Call n8n Workflow Tool** node pointed
  at the new sub-workflow — the exact node type Phase 2's own VM-listing
  tool already uses, not a new pattern. Ran the old and new tools side by
  side briefly and found a real, if obvious in hindsight, problem: two
  tools with near-identical descriptions gives the agent no way to know
  which one to prefer, so it isn't a real test of the new one at all until
  the old tool is fully removed. Deleted the original, then re-ran the same
  charter-reading test with the new tool as the only option — the result
  matched the independently-verified real content exactly, section for
  section, including highly specific, easy-to-hallucinate details (a Proton
  VPN/Tailscale CGNAT routing note) that would be very unlikely to survive
  intact through fabrication. **This closes out the base64 fabrication
  problem completely, not just for this one file, and proves the
  sub-workflow/wrapper pattern end to end through the real agent, not just
  in isolation.**

**Third tool: `Search Files by Name` — COMPLETE.** Two more real gaps
identified before building: finding a file by a word in its name, and
finding files by a word in their *content*, are genuinely different jobs at
genuinely different costs, and neither was covered by anything built so
far. Deliberately checked whether Forgejo's own code-search feature could
be used before building anything — its documented form (git-grep or an
admin-configurable indexer) is web-UI-oriented with no confirmed clean JSON
API endpoint, and whether it's even enabled is an admin setting with no
visibility from outside, so it wasn't trusted without a positive test that
never came together cleanly.

- **Found a better-fitting, well-documented alternative instead: the Git
  Trees API** (`/git/trees/{ref}?recursive=true`), functionally identical
  to GitHub's own well-known endpoint — returns the repository's entire
  file tree (confirmed: all 254 real entries, `"truncated": false`) in one
  call, rather than one directory at a time like the contents endpoint.
  This made filename search nearly free: one fetch, then a plain
  deterministic Code node filtering by substring — no recursion, no
  repeated calls, no LLM involvement in the matching itself.
- **Design choices made explicit, not silently assumed**: case-insensitive
  matching (a search for "readme" should find `README.md`), and returning
  only `path`/`size` per match rather than full blob metadata, since the
  agent only needs a path to hand to `Read File or Directory` next.
- **A real, if mundane, node-reference bug**: the Code node initially
  referenced the trigger node as `When Executed by Another WorkFlow`
  (capital F) when the actual node was named `When Executed by Another
  Workflow` (lowercase f) — n8n's node references are exact-match,
  case-sensitive, and this class of typo produces "Referenced node doesn't
  exist" rather than a silent wrong answer, at least making it loud rather
  than sneaky.
- **A real design fork surfaced by the first live test, not assumed away**:
  searching "recovery" correctly returned 10 matches, but a look at *why*
  each matched showed the tool does full-path substring matching, not
  filename-only — 6 of the 10 matches (e.g. `test.inf`,
  `System_Setting_202607161047.bak`) only matched because a *parent
  folder* was named `recovery/`, not because of anything in the filename
  itself. Confirmed this was actually wanted, not a bug to fix: reasonable
  today, and expected to become more correct over time once the
  documentation agent's own future write-path work actually reorganizes
  the corpus into more consistently relatable folder structures.
- **Proven chained with `Read File or Directory` in one real request** —
  "find files related to recovery, then read the one about DC01" — with
  raw tool output from both calls independently confirmed to match the
  final chat answer exactly, including a genuine repeat run (session reset
  this time) producing identical, real, correctly-sourced results.

**Content search and the write path re-sequenced, after real design discussion
rather than proceeding on the original plan by default.** Planning content
search surfaced the actual, larger goal it was a small piece of: the user's
real intent isn't just "find a string in a file" but a documentation agent
that can locate a file by describing its *contents* even when the name
doesn't match, judge when a name or location no longer makes sense, and
reorganize (rename, move) accordingly — genuine reasoning over content, not
pattern matching, and it structurally requires the write path (rename/move
means actually writing changes) to mean anything at all. Rather than build a
narrow grep-only content search now and revisit it once the write path
exists, agreed to build the write path first, then content search once, in
its full intended form, avoiding rework. Revised order, agreed explicitly:

1. Confirm `polaris-documentation-agent`'s SSH access actually extends to
   `homelab-infrastructure` (not just the `Polaris-Pipeline-Testing` test
   repo it was proven against in 4a) — **done, this entry**.
2. Build the write path.
3. Build content search via `grep`/`egrep` against a real local clone,
   rather than looping the Git Trees API + per-file HTTP fetches — a
   genuinely better design surfaced during this same discussion: faster,
   cheaper on Forgejo, no per-file base64-decode overhead, and the write
   path was already going to need a real local clone as its own first step
   regardless, so this reuses rather than duplicates that mechanism.
4. Build the reasoning layer that actually accomplishes "find by
   description, judge if reorganization is needed, do it" — genuinely
   dependent on both 2 and 3 existing first.
5. Extend everything (tools and access) to `Project_Polaris` as well —
   explicitly named as real, necessary scope ("no point in an agent owning
   all documentation if it does not actually own all documentation"), and
   explicitly kept as its own deliberate step rather than folded silently
   into today's work, since every tool built so far has the
   `homelab-infrastructure` repo hardcoded into it.

**Step 1 confirmed, with a real, worth-recording identity clarification
along the way.** First clone attempt failed as plain `root` with no SSH
identity specified — expected, not a real finding, since `root` has no
credential of its own. Second attempt tried `su - polaris-documentation-agent`
directly and failed, because **`polaris-documentation-agent` was never a
Linux user account at all** — unlike `polaris-mkdocs-rebuild` on Docker01
(a real, separate Linux login, deliberately created there because a
forced-command SSH restriction needed its own distinct account on a
*shared* host), `polaris-documentation-agent` is purely a credential (an
SSH keypair plus a Forgejo identity) — CT403 already belongs entirely to
this one identity, so there was never a shared-host reason to carve out a
second Linux user inside it. The correct, already-established pattern:
stay as `root`, pin the specific key via `GIT_SSH_COMMAND`, exactly as
every other clone this whole project has done. **Confirmed working**: a
clean clone of `homelab-infrastructure` (355 objects, 68.36 MiB) using
`polaris-documentation-agent`'s existing key — its collaborator access
extends to real git operations, not just the Forgejo API calls every tool
has used so far.

**Write path — design settled, manual proof complete (2026-09-20).**

**A real architectural fact surfaced before any building started**: every
read-only tool in 4c talks to Forgejo's API directly from n8n's own
container — plain HTTP calls, nothing more needed. CT403 was built and
its identity proven back in 4a, but had never actually been wired into n8n
over SSH until this point — the write path is the first thing in this
phase that genuinely needs a real shell with real git tooling, unlike
everything built so far.

- **Design, split by what actually needs a shell versus what's just an API
  call**: git-level work (clone, branch, write, commit, push) happens via
  SSH on CT403; opening the actual PR is a plain Forgejo API call
  (`POST /repos/{owner}/{repo}/pulls`), made directly from n8n with no SSH
  at all — the same pattern every read tool already uses.
- **A real mechanism discovery changed the original plan for the better**:
  n8n's SSH node has a File/Upload mode, not just a single Command string.
  The original plan (base64-encode everything, including the actual
  document content, to survive a single command-line string safely) was
  revised once this was found — the agent's real content now travels as a
  genuine file upload, byte-exact, no encoding needed at all. Base64 is
  still exactly right for the two things that *do* still travel through
  the command string (target path, commit message), since even short text
  can contain quotes.
- **The forced-command mechanism, worth recording precisely since it's
  used differently here than on Docker01**: a forced command doesn't
  block the client's attempted command from arriving at all, only from
  actually running — the attempted text lands in `$SSH_ORIGINAL_COMMAND`,
  which the forced script can read and parse. Docker01's `rebuild.sh`
  never needed this (it ignores whatever's requested and always does the
  same fixed thing); this script genuinely needs real parameters, which is
  exactly what this mechanism is for.
- **`write-doc.sh`, built and proven on CT403**: takes two base64-encoded
  arguments (target path, commit message; written first as plain
  positional arguments for manual testing, to become
  `$SSH_ORIGINAL_COMMAND`-parsed once the forced-command restriction is
  actually applied), reads pre-staged real content from a fixed path
  (`/tmp/polaris-doc-staging/content.txt`), clones fresh into a temp
  directory (never persistent), creates a timestamped branch
  (`docs-agent-YYYYMMDD-HHMMSS`), writes the file, commits with the real
  git identity (`Polaris Documentation Agent
  <polaris-documentation-agent@polaris.homelab>`), and pushes — with a
  cleanup trap removing both the temp clone and the staged content file on
  any exit, success or failure. Includes a basic sanity check rejecting
  absolute paths or `..` segments in the target, so nothing can write
  outside the repo.
- **First manual test failed correctly, not surprisingly**: everything
  through the commit worked; the push was rejected outright by Forgejo —
  `"User permission denied for writing"` — because
  `polaris-documentation-agent` still only had the **read-only**
  collaborator access granted for the read tools hours earlier. **Fixed
  correctly, not with the broader available option**: rather than simply
  grant blanket Write access (which would also permit direct pushes to
  `main`), added `main` branch protection mirroring `Project_Polaris`'s
  existing rule — collaborators can push a *branch* and open a PR, but
  `main` itself stays protected. Gets the agent exactly the capability it
  needs (propose, never merge) without a broader grant than necessary,
  same discipline as every credential-scoping decision this whole project
  has made.
- **Second manual test succeeded completely**: clone, branch, write,
  commit, push, all correct — Forgejo's own response included the compare
  URL for opening a PR, confirming the branch genuinely existed
  server-side, not just locally.
- **Decided, deliberately, not to manually prove the PR-open step yet**:
  no approval infrastructure (a merge-broker equivalent for the
  documentation agent) exists yet to actually act on a PR once opened, so
  there's nothing real to prove beyond what a plain API call already is.
  Real future shape discussed and worth remembering when that
  infrastructure is built: a broker informs the user a PR is open,
  approves per the user's decision, and the documentation agent itself
  handles cleanup (deleting the now-merged branch) afterward.
- **Branch deletion proven separately, and correctly understood as
  simpler than expected**: an initial `git push --delete` attempt failed
  with `"fatal: not a git repository"` — not, as first suspected, anything
  related to the PR/merge process, but simply that the delete command was
  run from `~` after the script's own temp-directory cleanup had already
  removed the only local clone that had ever existed for that branch. `git
  push --delete` is a remote-ref operation and needs no working tree
  checkout of its own — run from the older, still-present manual-test
  clone at `~/homelab-infrastructure`, it succeeded immediately.
- **A known, accepted limitation, deliberately deferred rather than
  solved speculatively**: a single fixed staging path
  (`/tmp/polaris-doc-staging/content.txt`) means two writes happening at
  the same moment could collide. Not worth solving now, for one person
  directing one agent sequentially — real shape of the fix isn't yet
  knowable without seeing how concurrent use, if any, actually looks.

**Write path fully wired into n8n and proven end to end (2026-09-20).** The
manual proof above generalized into a real `Propose Documentation Change`
sub-workflow: Execute Workflow Trigger (`target_path`, `content`,
`commit_message`) → a Code node converting plain text into real binary data
→ SSH Upload → a Code node base64-encoding the two metadata fields → SSH
Command (firing the forced-command script) → a Code node extracting the
real branch name from the script's own output → a direct Forgejo API call
opening the PR. Three genuinely new, non-obvious findings surfaced only
once this was built for real, none of them visible from the manual-proof
stage:

- **A forced command and SFTP are structurally incompatible on the same
  key — not a configuration problem, a protocol one.** `command="..."` in
  `authorized_keys` intercepts *every* session type a key can request,
  including the special session SFTP relies on to reach a real SFTP
  server; substituting a forced script in its place breaks the SFTP
  handshake outright (confirmed via a real `SFTP session` failure, not
  inferred). **Fixed with a third, separate key**, restricted to OpenSSH's
  own built-in `internal-sftp` (not a shell command, so it cannot be
  hijacked into running anything else) and confined via `-d` to the
  staging directory specifically — one credential for uploading content,
  a completely separate one for actually triggering the write. Same
  one-credential-per-purpose principle as everywhere else in this project,
  just revealing a case where "upload" and "run this script" are
  genuinely two different capabilities on the same host, not one.
- **n8n's SSH Command node silently prepends `cd <working-directory> ;`
  to whatever command is configured, and the Working Directory field
  cannot be left empty.** Found only by adding a temporary debug line to
  the script that echoed the raw `$SSH_ORIGINAL_COMMAND` value
  verbatim — the actual received text was `cd / ; <our real payload>`,
  not our payload alone as assumed. Real, mechanically correct base64 on
  both sides (independently re-verified by decoding both values directly)
  had made every other explanation look exhausted before this one
  surfaced; the debug line was the thing that actually resolved it, not
  further reasoning about the pieces already checked. Fixed by stripping
  everything through the first `; ` in the script's parsing, rather than
  depending on the working directory's specific value.
- **Forgejo enforces two independent permission layers, and only one had
  been touched.** Collaborator role (Read/Write) governs raw git
  push/pull — already fixed earlier for the git-level proof. A token's
  own scope, set at creation and not editable afterward (confirmed:
  Forgejo's UI only offers Regenerate/Delete/Create New, never
  broaden-in-place), separately governs what that token can do through
  the REST API — PR creation is a write action there, and the existing
  token had only ever been scoped to Repository: Read. Fixed by
  generating a new, correctly-scoped token and updating the *existing*
  `Forgejo - polaris-documentation-agent` credential's value in place,
  deliberately not creating a second credential, since every prior read
  tool already depends on that one credential continuing to work
  unchanged.
- **Full end-to-end proof, mock trigger data through a real PR**: PR #1
  opened correctly — right title (from the commit message), right body,
  right branch, right target, under `polaris-documentation-agent`'s own
  identity. Forgejo's own response independently confirmed the safety
  design is doing its job, not just the mechanics: `"0 of 1 approvals
  granted"` (branch protection genuinely blocking an unreviewed merge) and
  an explicit note that only an administrator could still merge it
  directly — the exact same admin-bypass path 3k already established,
  now available here too. Closed and cleaned up (branch deleted) as a
  mechanical test, not real content worth keeping.

**`Propose Documentation Change` wired into the AI Agent as a real Call n8n
Workflow Tool (2026-09-20)** — `target_path`, `content`, and
`commit_message` each mapped via `$fromAI()`, with an explicit warning in
`target_path`'s own guidance that an absolute path or one containing `..`
will always be rejected, and `content`'s guidance stating plainly that this
replaces the entire file, not an append. Tool description states the real
guarantee precisely: nothing becomes final without human approval — a
branch and PR only, never a direct change to `main`.

**A real, still-open reasoning gap found immediately, worth treating as a
genuine limitation rather than something already solved.** The first real
test handed the agent an open-ended task closely modeled on 4b's own
long-standing plan (write the MkDocs homepage 4b deliberately left
unbuilt, specifically earmarked as this agent's first real job) —
"look at what's actually in `engineering/adr/` and write a short homepage
introducing this documentation." Failed three times in a row, each attempt
nearly identical: one or two redundant, identical `List Repository Root`
calls, `engineering/adr/` itself never actually inspected, then a
generic, disengaged non-answer with no attempted content at all — a
different failure shape from anything seen in 4c's read-only build, where
the model always attempted something, right or wrong.

- **First hypothesis, tested and disproven**: that the six-rule
  anti-fabrication system message (written for the read-only tools) was in
  direct tension with being asked to author genuinely new text, and the
  model was resolving that conflict by disengaging rather than writing.
  Added an explicit seventh rule distinguishing "never claim unverified
  facts about existing content" from "original authorship is expected and
  fine" — re-ran the identical request with the new rule in place, and it
  failed the same way a third time, with the same shape (redundant calls,
  no investigation of the actual named folder, generic non-answer).
  Conclusively ruled out a rules conflict as the explanation.
- **Deliberately isolated a smaller, fully-specified variant next**,
  stripping out both open-ended investigation and self-authored content at
  once, to at least confirm the tool itself works correctly in isolation:
  "create a file at this exact path with this exact content and this exact
  commit message." **Succeeded immediately and completely** — correct
  upload, correct forced-command trigger, correct branch, a real PR (#2)
  confirmed via Forgejo's own response with the exact given title, path,
  and content. This conclusively separates two different things that had
  been getting evaluated together: the write-path *mechanism* (fully
  proven, reliable, three-for-three when given a complete, explicit
  instruction) versus the *reasoning* required to get from an open-ended
  request to a complete instruction on its own (three-for-three failing).
- **Genuinely unresolved as of this entry**: whether the failure is driven
  by open-ended investigation, by being asked to author original text, or
  specifically by the combination of both together — the one isolation
  test run so far removed both variables at once, so it cannot yet
  distinguish between them. Real next step, already agreed: a test handing
  over the exact path and commit message directly, while still requiring
  the agent to author the actual content itself — isolating self-authored
  text specifically from open-ended investigation, the one combination not
  yet tested.
- **Both real test artifacts (PR #2, its branch) closed/deleted as
  mechanical tests**, not real content — same cleanup discipline as every
  other test tonight.

**The actual root cause found, resolving the entire investigation above —
not a reasoning gap at all, the same category of bug fixed once already
tonight, recurring at a larger scale.** Checking the Ollama Chat Model
node's own raw output on a failed run showed `completionTokens: 0` against
a `promptTokens` already past the 8192-token ceiling set earlier in 4c —
the model wasn't disengaging or refusing, it was being asked to respond
inside zero remaining space. Every failing test in this investigation
called at least one large-JSON read tool; both "successes" that briefly
looked like progress never called one at all — the actual variable the
whole investigation had been chasing.

- Raised context to `16384`, then found a *second*, genuinely distinct bug
  on the very next test: a malformed, truncated tool-call JSON, unrelated
  to context size (well under the new ceiling at the time). Traced to the
  Call n8n Workflow Tool node's own name still containing its copy-pasted
  label, `Call 'Read File or Directory'` — apostrophes and quotes inside
  what tool-calling conventions expect to be a clean identifier. Renamed to
  a plain `Read File or Directory`; fixed immediately.
- With both real bugs fixed, raised context further (`32768`, then
  `65536`), checking `ollama ps` for a CPU/GPU split (the real ceiling to
  respect, per `qwen3.6:27b`'s collapse during model selection) rather than
  a percentage of VRAM used — stayed 100% GPU throughout, comfortable
  headroom even after a real multi-file investigation.
- **A genuine second content-accuracy issue found along the way, distinct
  from the context bug**: an earlier "successful"-looking run had invented
  a generic, plausible ADR template (Title/Status/Context/Decision/
  Consequences) without ever reading a single real file's content — the
  same fabrication pattern as the base64 incident, just narrower and
  disguised as a general statement rather than a claim about one named
  file. Added an explicit rule requiring at least two real files be read
  before describing a category's structure, with zero-or-one-file cases
  treated as having no established pattern to fabricate against. Also took
  the opportunity to reorganize the whole system message by topic
  (verifying existing content / authoring new content / tool use and
  answering) rather than flat chronological numbering, since an earlier
  cross-referencing rule (7, referencing rules 1-4) sat separated from them
  by unrelated rules — adjacency, not numbering, is what actually helps a
  model apply a cross-reference correctly.
- **Final, fully successful real-world run**: the actual `engineering/adr/`
  homepage task, read five real files including the genuine outlier
  (ADR-000's non-standard structure), correctly generalized from what the
  majority actually showed rather than either guessing blind or being
  thrown by the one exception, and produced a real, reviewed, user-approved
  PR. **Approved and merged** — this is a real, live milestone, not another
  test: the first genuinely agent-authored content ever merged into
  `homelab-infrastructure`, confirmed via the 4b webhook firing correctly
  and the live MkDocs site actually updating — closing 4b's own
  long-standing deferred homepage gap for real, and proving the full,
  final loop (reason → investigate → author → propose → human review →
  merge → automatic rebuild) end to end for the first time in this phase.

**Two real, forward-looking design questions surfaced by this milestone,
deliberately discussed and left for later rather than solved now:**

- **Revising an already-open PR has no support at all today, for two
  concrete, confirmed reasons, not just "not built yet."** Every read
  tool's URL silently resolves to `?ref=main` by Forgejo's own default
  (never explicitly requested by any tool) — structurally blind to
  anything sitting in an unmerged branch. `write-doc.sh` only ever
  branches from `main` fresh; it has no update-an-existing-branch mode at
  all. A genuine revision loop needs both fixed, plus some way of
  identifying which open PR feedback refers to — real, deliberate future
  design work, not a quick addition.
- **Whether the Memory connector could stand in for this was discussed and
  set aside, for a precise reason rather than a vague one**: Memory is a
  linear, per-session conversational transcript, not an indexed or
  searchable document store — there's no way to ask it "find the message
  where I proposed a file called X." The sharper, generalizable test that
  came out of this discussion: **whether a piece of context has an
  authoritative record outside the conversation at all.** File content
  always does (git) — memory of it is redundant at best, staleness-prone
  at worst, regardless of which agent or how long its session runs. A
  debugging or diagnostic reasoning trail (approaches already tried and
  ruled out) usually has no other home — memory is genuinely valuable
  there, for any agent, not just the foreman. This reframes the
  agent-vs-foreman memory question from a role-based rule into a
  context-based one: a sub-agent mid-task benefits from memory exactly
  like anyone mid-conversation; what actually differs is that a sub-agent's
  natural task scope tends to be short-lived, while the foreman's is a much
  longer continuous arc — worth remembering that a coding or networking
  agent's own debugging trail is a plausible future case where memory adds
  real value, not just documentation's read/write-real-files pattern.
  Forward-looking note for whenever foreman design actually starts: the
  foreman's own durable decision history likely needs the same
  "write it down externally, don't rely purely on an ever-growing
  transcript" discipline this very runbook has embodied all along, rather
  than trusting conversational memory to hold years of cross-agent history
  reliably.

**Fourth tool, `Search File Content` — COMPLETE (2026-09-20), closing out
step 3 of the revised order.** Same real fresh-clone-then-cleanup pattern
as the write path, run via SSH on CT403 with its own third, narrowly-scoped
forced-command key (`n8n-search-restricted`, restricted to
`search-content.sh` alone) — a fourth distinct SSH credential to CT403
now, alongside the write-triggering and SFTP-only keys, each doing exactly
one job.

- **A real, specific shell-scripting gotcha unique to this script**: `grep`
  exits with status `1` when it finds zero matches — a normal, valid
  outcome, not a real error — which would have made `set -e` (used in
  every other script tonight) crash the script on a legitimate "nothing
  found" result. Deliberately omitted `-e` here, with a comment explaining
  why, and handled the zero-match case explicitly instead
  (`NO_MATCHES`, not a blank result or a crash).
- **`$SSH_ORIGINAL_COMMAND`'s `set -u` caught a real mistake immediately,
  functioning exactly as intended**: the very first manual forced-command
  test (`whoami; ls /`, the same deliberately-wrong-request proof used for
  every restricted key tonight) failed on an unbound `$1` before the
  restriction even reached the point of misinterpreting anything — the
  script had briefly kept `write-doc.sh`'s original plain-positional-argument
  form before being updated to parse `$SSH_ORIGINAL_COMMAND`, the same
  fix already known necessary from the write path.
- **The `cd <working-directory> ; ` prefix n8n's SSH Command node adds
  (first found during the write path) was anticipated proactively this
  time**, added before it could cause a failure rather than rediscovered
  via a fresh debug cycle — direct payoff from writing it down clearly the
  first time.
- **A second, genuinely new variant of the same category of bug, this time
  actually requiring a fresh debug capture**: the first real n8n-driven
  test returned nearly the entire repository rather than real matches, with
  `stderr: "base64: error: invalid input"`. The debug-line technique
  (proven effective on `write-doc.sh` and reused directly here) showed the
  raw command contained *multiple* spaces after the semicolon
  (`cd / ;   <payload>`), not the single space the existing `#*; }`
  stripping pattern assumed — leaving a stray leading space that broke the
  base64 decode, which in turn left the search term empty, which in turn
  made `grep` match every line of every file (an empty pattern's
  well-known behavior) — one root cause producing two compounding visible
  symptoms. Fixed by explicitly stripping all whitespace before decoding,
  safe because real base64 text never legitimately contains a literal
  space character.
- **Fully proven standalone, then through the real agent, on the exact
  real-world scenario that originally motivated building this tool**:
  asked "what is the IP address for WS01," the agent correctly tried
  `Search Files by Name` first (reasonable, got an honest zero results),
  fell through to `Search File Content` (18 real candidates), correctly
  selected `IP-Address-Plan.md` specifically to actually read out of that
  list, and reported `192.168.10.42` — independently verified against the
  real table row in the tool's own raw output
  (`| 192.168.10.42 | ws01 | Windows Workstation 1 |`, under "Windows
  Infrastructure"), matching exactly.

**Step 4 — COMPLETE (2026-09-20/21): find-by-description, the rename
mechanism, and reorganization judgment, all proven end to end.**

**Capability 1 (find a file by describing its contents) needed no new
tool at all — confirmed by testing before building anything.** Asked to
find "why the cyber range network is kept separate," with no keyword or
filename hint given, the agent adaptively reformulated `Search File
Content` five times, correctly discarded a real but insufficient match
(`HW-003-cyberrange.md`, a hardware sheet, not an explanation) once it
actually read it, and landed on the one genuinely correct document —
verified independently against the raw tool output, near-verbatim in
places. `Search File Content` plus the agent's own reasoning already
covers this; the instinct to test before building here was correct.

**Capability 2 (judge and fix a bad name/location) required a genuinely
new mechanism — nothing built before this could rename or move a file at
all.** Built `rename-doc.sh`, the third distinct forced-command SSH
identity on CT403, using `git mv` specifically (not separate `rm`/`add`
steps) so git's own rename-detection correctly recognizes a moved file as
moved, not deleted-and-recreated — confirmed directly in both the raw
script output (`rename docs/{...} (100%)`) and, later, in a real PR's own
`additions: 0, deletions: 0` fields.

- **A real, useful realization comparing this script to the prior two**:
  `write-doc.sh` never needed an explicit whitespace-stripping fix for
  n8n's `cd <dir> ; ` prefix, and it's now clear why — it was never really
  about spaces, but about *how* each script parses input.
  `write-doc.sh`'s `read -ra` (word-splitting) naturally collapses
  repeated whitespace as a side effect; `search-content.sh`'s single-value
  string manipulation does not, which is why it alone needed the explicit
  fix. `rename-doc.sh`, parsing three values, used `read -ra` from the
  start and got the same protection for free, proactively rather than
  rediscovered via another debug cycle.
- **`set -u` caught a real mistake immediately on the very first forced-command
  proof** (the same deliberately-wrong-request test as every restricted
  key tonight) — an unbound `$1` before the script had been updated to
  read `$SSH_ORIGINAL_COMMAND`, the exact fix already known necessary from
  the write path, applied a beat late here and caught instantly rather
  than silently misbehaving.
- **A genuinely richer, more informative version of the same restriction
  proof surfaced during the second forced-command test**: `whoami; ls /`
  decoded to empty strings (base64 failing safely rather than crashing,
  since this script deliberately doesn't use `-e`), which passed the
  sanity check's *shape* validation (empty is neither absolute nor
  contains `..`) and let the script proceed to genuinely clone and branch
  before failing on a nonexistent empty-named file. Confirmed the forced
  restriction itself worked completely; also surfaced a real, worth-fixing
  gap — the sanity check never rejected an empty path outright. Fixed by
  adding an explicit empty-string check, re-verified to fail immediately
  now, before any clone or branch.
- **Sanity-checks both the old and new path**, mirroring `write-doc.sh`'s
  own check, extended to both sides of a rename rather than the single
  path a write only ever touches.
- Fully proven standalone, then through n8n end to end (SFTP-free this
  time — no large content to upload, only three short metadata values,
  all traveling through the command string as base64) — a real test
  rename, a real PR, correctly showing a true rename in git's own terms,
  cleaned up as a mechanical test afterward.

**A real, load-bearing bug found and fixed during the first true
find-and-judge-and-act test, not a design flaw in the reasoning itself.**
Asked to evaluate `operations/recovery/test.inf` and rename it if
warranted (with explicit approval), the agent correctly diagnosed the same
real problem three separate times across two full test rounds — real,
repeatable judgment, not a fluke — but the first attempt to actually act
on it hit "Max iterations reached." Root cause, found by inspecting the
real trace rather than assuming: an unrelated `Read File or Directory`
call failed with a raw, unhandled n8n execution error (a genuinely
different kind of failure than every clean, JSON-based "not found" seen
elsewhere tonight, since none of the sub-workflows had explicit
error-handling configured on their HTTP Request nodes). The model's
recovery from that raw failure was poor — a much broader, 66-match
re-search rather than a clean retry — burning through its remaining
iterations without ever reaching the rename call.

- **Fixed at the source, not by suppressing the symptom**: set the HTTP
  Request node's On Error behavior to "Continue (using error output)" —
  deliberately not plain "Continue," which would silently carry forward
  stale prior data with no signal anything failed. Added a small Code node
  on the new error branch producing the same clean, consistent `{ result:
  [...] }` shape every successful call already returns, now carrying a
  clear, actionable message (verify the path came from a real prior
  result; don't guess or retry blindly) instead of a raw stack trace.
  Wired into the existing Merge node as a genuine third input, confirmed
  not to disturb the two existing paths by re-testing the original
  success case afterward.
- **Iteration cap raised from 10 to 20, this time for a concrete, observed
  reason** rather than pre-emptively — matching the standing "wait for a
  real failure to show the shape of the fix" position taken when this was
  first discussed. A well-reasoned task lost its remaining room specifically
  because of one unlucky raw crash, not because the task itself was
  unreasonable.
- **Re-run from a clean session, single combined request (evaluate, then
  act on approval): fully successful.** Correct investigation (checked
  both the original file and its literal duplicate in `RecoveryArtifacts`
  before deciding), one correct call to `Rename or Move File`, a real,
  correctly-formed PR confirmed via Forgejo's own response.

**Two honest findings from comparing this run against the earlier
evaluation-only ones, worth recording plainly rather than only reporting
the success:**

- **The core diagnosis (the name "test.inf" is wrong) was completely
  consistent across three separate runs — real, repeatable judgment.** The
  *secondary* judgment (exactly which folder the file should live in)
  was not — one run proposed a new `operations/policies/` folder, another
  kept it in place. Worth treating naming judgment as solid and
  folder-placement judgment as more variable, pending more evidence
  either way.
- **The investigation itself surfaced a real, literal duplicate file**
  (`operations/recovery/RecoveryArtifacts/test.inf`, identical content,
  identical bad name) that this task never touched, since deduplication
  was outside its actual scope — a good, concrete, already-identified
  candidate for future reorganization work, not something invented for
  this entry.

**Step 5 — COMPLETE (2026-09-21): full tool parity extended to
`Project_Polaris`, plus a serious model-output-corruption bug found and
fixed.** This section is written as a standalone architectural reference,
not just a narrative — intended to be enough on its own to understand
exactly where the documentation agent's tooling stands, without needing to
reconstruct it from the surrounding build history.

**Current complete inventory — every credential and identity CT403 now
holds for the documentation agent, one job each:**

| Purpose | Key file on CT403 | Forced command | n8n SSH credential |
|---|---|---|---|
| Git/API access (both repos) | `polaris-documentation-agent` | *(none — full git identity)* | *(not an SSH-login credential; used directly by scripts and as the Forgejo API token)* |
| Trigger write, `homelab-infrastructure` | `n8n-login-restricted` | `write-doc.sh` | `CT403 - polaris-documentation-agent write path` |
| Trigger write, `Project_Polaris` | `n8n-write-project-polaris-restricted` | `write-doc-project-polaris.sh` | `CT403 - write trigger Project_Polaris` |
| Trigger rename, `homelab-infrastructure` | `n8n-rename-restricted` | `rename-doc.sh` | `CT403 - rename trigger` |
| Trigger rename, `Project_Polaris` | `n8n-rename-project-polaris-restricted` | `rename-doc-project-polaris.sh` | `CT403 - rename trigger Project_Polaris` |
| Trigger content search (both repos) | `n8n-search-restricted` | `search-content.sh` | `CT403 - search content trigger` |
| SFTP upload (both write sub-workflows share this) | `n8n-sftp-restricted` | `internal-sftp -d /tmp/polaris-doc-staging` | `CT403 - SFTP upload only` |

**Why content search needed only one key/script pair while write and
rename each needed two — a deliberate distinction, not an oversight**:
`search-content.sh` never writes anything regardless of which repo it's
pointed at, so it was parameterized (a `repo_name` argument, validated
against an explicit allow-list of the two real repo names) rather than
duplicated. `write-doc.sh`/`rename-doc.sh` and their `Project_Polaris`
counterparts remain deliberately separate scripts with separate
forced-command keys, since each script can genuinely commit and push —
narrowing what one leaked key could do was worth the duplication, the same
reasoning already applied to every credential decision this project has
made.

**Current complete inventory — every n8n sub-workflow and its Agent-facing
tool, both repos:**

| Repository | Read: root listing | Read: file/dir | Search: by name | Search: content | Write: propose | Write: rename |
|---|---|---|---|---|---|---|
| `homelab-infrastructure` | `List Repository Root` | `Read File or Directory` | `Search Files by Name` | `Search File Content` | `Propose Documentation Change` | `Rename or Move File` |
| `Project_Polaris` | *(same tool, parameterized)* | *(same tool, parameterized)* | *(same tool, parameterized)* | *(same tool, parameterized)* | `Propose Documentation Change - Project Polaris` | `Rename or Move File - Project Polaris` |

The four read/search tools are genuinely shared, multi-repo tools — each
takes an explicit `repo_name` parameter (guided to only ever be
`homelab-infrastructure` or `Project_Polaris`) rather than being duplicated,
since none of them can write anything regardless of which repo they're
pointed at. Only the two write-capable actions are duplicated per repo,
consistent with the reasoning above.

**Confirmed directly, not assumed, before any of this was built**: Forgejo
personal access tokens are scoped by category (Repository: Read/Write),
never by a specific named repository — the existing
`Forgejo - polaris-documentation-agent` credential required zero changes
to work against `Project_Polaris` the moment `polaris-documentation-agent`
became a collaborator there. This is why only the four write-side SSH
identities needed to be newly created; every API-based read/search
credential was already correctly scoped.

**Two genuinely new bugs found and fixed during this extension, both
worth understanding precisely since either could recur in any future tool
built the same way:**

1. **A stray leading space, generated by the model itself inside an
   otherwise-correct value, silently broke `Read File or Directory`
   against `Project_Polaris` on first real use** — `"repo_name": "  Project_Polaris"` (two leading spaces) produced a 404 against a
   repository that, character-for-character, doesn't exist. This is a
   fundamentally different category of bug than every `cd ; ` /
   multi-space fix earlier in this phase — those came from n8n's own
   infrastructure and were fixed once, permanently, at the source. This
   one comes from the model's own non-deterministic output and has no
   single permanent fix — the correct response is defensive trimming at
   the point every such value is used (`.trim()` in HTTP node expressions;
   a `sed`-based trim added to all five CT403 scripts, applied to leading
   *and* trailing whitespace only, deliberately never a blanket
   space-strip, since a commit message or search phrase can legitimately
   contain internal spaces).
2. **A far more serious version of the same category, found while testing
   the `Project_Polaris` rename tool through the real agent**: the model
   generated a rename call with a two-space prefix baked into *all three*
   parameters at once, causing the script to correctly refuse (the
   leading-space filename genuinely didn't exist) — but the resulting
   error message named `BRANCH_NAME`, an internal implementation detail of
   the Code node's own parsing logic, with no meaning to the model. The
   model then reasoned about this internal detail as if it were a missing
   *tool parameter*, invented a `branch_name` field, and mixed its own
   reasoning narration directly into what was supposed to be pure JSON —
   producing a second, completely different parse failure on retry. Fixed
   at both layers: the defensive trim above (closing the actual root
   cause) and rewriting every BRANCH_NAME-extraction Code node (all four
   write/rename sub-workflows, both repos) to describe the *likely, plain-
   language* problem instead of exposing an internal variable name — the
   same "never leak raw internals to the model" principle already applied
   to `Read File or Directory`'s HTTP error handling in step 4, now
   extended to the write path's own failure path.
3. **A real, unrelated naming-collision risk found and fixed while
   applying the above**: both write sub-workflows contain two SSH nodes
   (SFTP upload, then the actual trigger), both originally left at n8n's
   default label "Execute a command" — meaning `$('Execute a command')`
   inside the BRANCH_NAME-extraction Code node was genuinely ambiguous by
   name, working only because of execution-order timing, not anything
   guaranteed. Fixed by explicitly renaming the second node
   (`Execute a command - Rename` / equivalent) in all four affected
   sub-workflows and updating each Code node's reference to match — and,
   more importantly, adopted as a new standing habit: every node added to
   any future workflow gets a distinct, descriptive name at creation time,
   not left at a default that might collide with a sibling added later.

**A real infrastructure gap found during final cleanup, with a genuine,
permanent fix applied — not just a one-time tidy-up.** Both repositories'
`default_delete_branch_after_merge` setting had been `false` for this
entire project, meaning every merged PR (test or real) has been leaving
its branch behind indefinitely — not a series of isolated cleanup misses,
a single systemic setting. **Fixed permanently on both repos** (enabled
"automatically delete branch after merge" in each repo's settings) —
every future merge, on either repository, now cleans up after itself
without requiring a manual step.

**One genuine, unresolved anomaly, stated plainly rather than papered
over**: at least three branches were independently confirmed deleted via
CLI (`git push origin --delete ...`, with Forgejo's own `[deleted]`
response each time) earlier in this session, yet reappeared in a later
branch listing regardless. The eventual full cleanup was performed through
Forgejo's own web UI instead, and — confirmed via an explicit page
refresh — held cleanly with nothing reappearing. This is not a fully
explained root cause; it's a real, observed difference in outcome between
the CLI and UI deletion paths on this specific Forgejo instance, worth
treating as a standing preference (delete via the UI when it matters) and
worth revisiting if it recurs, rather than a solved mystery.

**Step 5 is complete — both repositories now have full, identical
tool parity** (read, search-by-name, search-content, propose, rename),
each independently proven standalone and through the real agent, including
correct tool selection between each repo's write-side siblings and a real,
serious model-output-corruption bug found and fixed along the way. This
closes out the originally agreed five-step revised order in full.

### 4d: Matrix Homeserver Stand-up

**Status note (2026-09-21):** reassigned to the foreman's own build, later — see "Decisions recorded from the 2026-09-21 session." Not a documentation-agent prerequisite. Content below is otherwise unchanged.

- Its own dedicated container on the AI node, independent of the
  documentation agent's own container.
- Verify current actively-maintained project name/repo before deploying
  (per the naming-churn note above).
- SQLite backend, no federation, reachable only via the container's Tailscale
  address — never a public listener, never Funnel, never a reverse proxy.
- Encryption disabled for the room(s) this will actually use.

### 4e: Interaction Channel — Wire Into n8n

**Status note (2026-09-21):** likewise reassigned to the foreman's build. Until then n8n's own chat panel is the standing interface to every sub-agent.

- Confirm n8n's real Matrix capability directly (native node vs. raw
  Client-Server API) before designing around an assumption.
- First real test: proven against whichever agent makes sense once 4a-4d are
  done — the documentation agent is the leading candidate, not a
  commitment; revisit if it adds too much complexity to prove alongside 4c.

### 4f: Documentation Agent — End-to-End Proof

**Status note (2026-09-21):** Matrix is no longer a prerequisite for this step (see above). The full loop this step describes (request, reasoning, PR, human approval, merge, 4b webhook, rebuilt site) was already proven for real via n8n's chat panel in 4c's `engineering/adr/` homepage milestone.

- Full loop: a real question or request, asked via whatever channel is
  working by this point (n8n manual trigger at minimum, Matrix if 4d/4e are
  ready), reasoned over by the agent, resulting in either a direct read-only
  answer or a real drafted change — branch, PR, human approval, merge, the
  4b webhook firing, and confirmation that the rebuilt static site actually
  reflects it.

### 4g: Coding Agent — design settled (2026-09-21), build in progress (stage 1)

Designed in conversation before any building, per the standing principle that
every agent gets the same deliberate design scrutiny the documentation agent
did. Expect this section to change as real building reveals things. The goal
below is fixed; the path to it is not.

**Ultimate scope, stated explicitly so incremental steps stay aimed at it:**
the coding agent owns all coding work for the homelab — bash and Python
scripts, Ansible playbooks, n8n workflow JSON, and general "build me X"
requests, including code for things on or outside the homelab. General-purpose,
but coding-specific. It is **not** scoped to the backup agent's collectors;
that is only the first and narrowest proving ground. The build is deliberately
modular: start narrow, add one language or domain at a time, each proven
before the next.

**Standing rule (agreed 2026-09-21; intended to apply to any future agent that
authors something executable):** *the coding agent authors and tests in
isolation. It never holds credentials to real targets and never deploys.* A
scope of "all coding work" has no natural ceiling, so real-target credentials
can never be attached to it. Running code against production belongs to the
owning domain agent or to the user, through the approval path.

**Delivery model — the intended flow:**

1. The coding agent authors code and tests it in its own sandbox until it
   expects it to work. Its deliverable is tested, expected-to-work code, not a
   deployment.
2. It proposes via branch and PR, never merging (same as every agent).
3. The merge decision follows 3k: the deterministic broker for Tier 1, the
   user for Tier 2.
4. The owning domain agent (documentation, backup, networking, ...) — through
   the broker mechanism — or the user then deploys the code to its real
   target. How each owning agent picks up merged code is designed with that
   agent, not here; the Phase 3 vision's example (a backup agent picking up a
   new collector on its next run) is the prototype.

**Design decisions agreed so far:**

- **Whole-file replacement, not diffs.** Models are unreliable at diff line
  arithmetic; the PR's own diff exposes any accidental drift in an unrelated
  line, and changes to shared files land in Tier 2 review regardless.
- **A per-task workspace, not the documentation agent's one-shot write.** A
  self-correcting agent must write, check, read the failure, edit, and check
  again before proposing anything, so `write-doc.sh`'s atomic clone-write-push-
  discard cycle doesn't fit. Instead: a workspace on the agent's own container,
  created when a task starts, holding a fresh clone, discarded when the task
  ends (the 3u lesson — no forgotten credentialed clones — applied at task
  granularity). Planned tools: start workspace, list/read/search inside the
  workspace, write file, run checks, propose as PR, discard. Workspace IDs are
  issued by the script, never invented by the model, which also closes the
  staging-path collision the documentation agent deferred. Multi-file changes
  accumulate in the workspace and ship as one commit.
- **Shares nothing with other agents unless it must** (agreed: each agent runs
  independently, based on its job). The coding agent gets its own container,
  its own credentials, and its own copies of any tooling. It does not reuse the
  documentation agent's read tools or the search script on CT403 — note those
  currently authenticate as the documentation agent, and that credential was
  upgraded in place to Read/Write in 4c. Duplicate maintenance is accepted as
  cheaper than blurring who did what.
- **Self-correction is a core capability, with three guardrails specific to
  that loop:** (1) a bounded number of fix attempts per task, separate from
  n8n's iteration cap, after which the agent stops and reports what is still
  failing — "I couldn't get this passing" must be a valid, honest outcome;
  (2) the deterministic propose step re-runs the checks itself and embeds
  their real output in the PR description, so "checks passed" is never the
  model's own claim (same principle as decoding base64 in code, not by the
  model); (3) checker configuration lives outside the workspace, and any inline
  suppressions the agent adds (e.g. `# shellcheck disable=...`) are flagged in
  the PR, so passing can't be achieved by silencing the checker.
- **Execution is a ladder, each rung proven before the next:** (1) static
  checks only (`bash -n`, `shellcheck`; no execution); (2) run in a throwaway
  container with no network and fake fixtures; (3) much later, disposable
  targets the agent may create and destroy on the AI node, which Ansible- and
  service-type code eventually needs. Starting at rung 1.
- **Identity and container.** New dedicated container (planned CT 404) on the
  AI node, unprivileged, functioning as the agent's own build/test playground.
  Keep the existing `polaris-coding-agent` Forgejo account (Write collaborator,
  no deploy key, no whitelist entries — proven in 3k against a real protected
  `main`), but generate a **fresh SSH key on CT 404** and retire the old
  `polaris-coding-agent-git` key currently living on CT 402 (the orchestrator
  — the same category as the leftover credentialed clone 3u cleaned up).
  Close the open bot-hygiene item at the same time (org creation off, generic
  non-personal email). Sizing, CT ID confirmation, and IP deferred to build
  time.
- **Revising an already-open PR is scheduled early, not late.** For code,
  review feedback followed by a fix is central, not occasional. Inside a
  workspace, reading a branch is just a checkout; what's needed is an
  update-existing-branch mode and a way to identify which open PR feedback
  refers to.
- **The task interface is effectively the contract the foreman will later
  call**, so it is designed deliberately now even though n8n's chat panel is
  the only caller for the foreseeable future: what to build, where it lives,
  acceptance criteria, target language/tooling. What comes back: the PR URL,
  the real check output, a summary, or an honest failure report.
- **The merge-broker is tracked as its own item** (see Carried-Forward Open
  Items) — audit first, decision trigger before the first PR against
  `Project_Polaris`.

**Growth path (a sketch to adjust, not a commitment):**

1. CT 404, identity, workspace tools, bash static checks. First proof against
   `Polaris-Pipeline-Testing`, including a seeded-bug test: hand it broken code
   plus real `shellcheck` output and see whether the loop converges without
   breaking anything else.
2. PR revision loop (feedback updates the same branch).
3. A first real job on `Project_Polaris` (a small collector following existing
   conventions). The merge-broker decision point sits here.
4. Language modules, one at a time, each a checker plus conventions plus a
   proof: Python, then Ansible (`--syntax-check`, `ansible-lint`), then n8n
   workflow JSON — expected to be the most fragile to author and hardest to
   validate statically, likely wanting a throwaway n8n instance eventually.
5. The execution rungs, and ad hoc "build me X" requests, including where
   non-repo code lives.

**Open questions and things to verify before or during the build:**

- **Does `polaris-backup` auto-discover collectors by filename?** 3k's Tier 1
  premise is that "a genuinely new, isolated file" is inert until something
  references it. That only holds if collectors aren't picked up automatically.
  Check in the real code before Tier 1 auto-merge is ever enabled for the
  coding agent's output.
- **Confirm `polaris-coding-agent`'s current access to `Polaris-Pipeline-
  Testing`** before relying on it for the first proof.
- **Toolchain installation versus runtime network access (agreed in
  principle 2026-09-21 — the first concrete "outside connection" question; the
  enforcement mechanics are still to design).** Linters need
  installing from package registries, which needs network. Proposal: bake the
  toolchain into the container at build time (versions pinned, done deliberately
  by the user), then restrict the running container's egress to Forgejo only.
  Any later need for outside documentation lookups goes through a separate,
  controlled, read-only fetch tool rather than open egress, and fetched content
  is treated as untrusted data, never as instructions. Still open: where the
  egress restriction is enforced (the container's own Proxmox firewall, since
  `firewall=1` is already set on its NIC, versus pfSense) and how a build-time
  install differs operationally from the running container.
- **AppArmor on CT 404.** 4a found unprivileged containers on this
  Ubuntu 26.04 needed `lxc.apparmor.profile: unconfined`. For a container that
  will eventually execute agent-authored code, that trade-off gets weighed
  deliberately (rung 1 executes nothing, which defers the question, not
  answers it).
- **Model check (suggested, not agreed).** `gpt-oss:20b` stands per the model
  selection findings, but this is the first agent whose core job is the thing
  those coding tests only sampled; a coding-task evaluation grounded in real
  repo conventions may be worth running before locking the choice in.
- **n8n workflow JSON authoring and validation strategy** — deferred to that
  module's own design.
- **Outcome routing beyond "propose a PR" — captured for later, not designed
  now (2026-09-21).** Today's build always proposes at the fix-attempt cap,
  with the real reasoning embedded, regardless of severity — settled and
  final for the current build. But three outcome shapes were identified in
  discussion, and only one of them fits a PR: (1) requirements are ambiguous
  or infeasible as given — belongs in chat/reasoning back to whoever assigned
  the task, not a PR; (2) a contained bug needing more work — the current
  cap-hit PR, unchanged; (3) a bug whose scope reaches beyond the file at hand
  — the user's stated lean is that this should ultimately route coding agent →
  foreman → Matrix → user directly, rather than only ever surfacing as a PR
  comment. This directly intersects the standing decision that Matrix is
  foreman-only, revisited per agent — not resolved here, deliberately: it
  needs its own design conversation once there's a foreman to route to.
- **A CA/PKI structure already exists on the homelab node, not yet on the AI
  node — captured for later, not pursued now (2026-09-21).** Raised in the
  context of whether short-lived, issued-per-request credentials (as opposed
  to today's dedicated-scoped standing keys) would ever suit a genuinely
  external connection. Real infrastructure work (a CA presence on the AI node,
  an issuance mechanism), out of scope until the base workspace-tools
  structure is built and proven — recorded so it isn't reinvented or
  forgotten when that need actually arrives.

**Stage 1 build progress (2026-09-21):**

- **CT 404 `coding-agent` created and verified.** Unprivileged, `nesting=0`,
  Ubuntu 26.04 (from the existing `local` template — nothing downloaded), 2
  cores, 4096MB memory (double CT 403's, since Python/Ansible tooling plus
  several concurrent workspaces is heavier than git and grep), 512MB swap,
  32GB disk on `ai-storage` (9% used beforehand; a disk can grow but not
  shrink, and the toolchain will be its bulk), `onboot=1`, on `vmbr0` with
  `firewall=1`, `192.168.10.203/24`, gateway `192.168.10.1`. Every other
  setting mirrors CT 403's real config, read directly from `pct config 403`
  rather than assumed. The IP was checked three ways before use: ICMP got no
  reply, the ARP entry showed `FAILED` (ARP answers even when ICMP is
  blocked, so this is the stronger check), and the user independently
  confirmed `.203` is the next intended address in the subnet.
- **`lxc.apparmor.profile: unconfined` was added while the container was
  still stopped, before its first boot** — the 4a lesson applied up front, not
  rediscovered. First boot was clean: correct IP on `eth0`, the gateway
  answered at 0% loss, and `systemctl --failed` listed nothing, so 4a's
  `243/CREDENTIALS` failure did not recur. `pct start` printed a warning
  ("Systemd 259 detected. You may need to enable nesting"), which is Proxmox
  flagging the deliberate `nesting=0` choice; nothing failed as a result. The
  AppArmor trade-off (see open questions) is accepted for now, since rung 1
  executes no agent-authored code, and gets revisited before rung 2.
- **DNS finding, worth remembering for every future container on the AI node:
  the AI node does not resolve through pfSense.** Its own resolver is
  `192.168.30.2` with search domain `polaris.arpa`, and every container on it
  inherits that through Proxmox's managed `resolv.conf`. That resolver does not
  know the `.polaris.home.arpa` zone, so `git.polaris.home.arpa` fails to
  resolve from both CT 403 and CT 404 (`getent` exit 2, identical on both — the
  first check ran against CT 404 alone and looked like a CT 404 problem until
  CT 403 was tested alongside it). This is a different situation from 4b's
  Docker01 finding (there, DNS did go through pfSense at `192.168.10.1`, and the
  per-hostname Host Override requirement applies to hosts that resolve
  through it). **Decision: no per-container nameserver override.** CT 403
  already reaches Forgejo by IP (`192.168.10.20:2222`) and CT 404 will do the
  same; an override would make the two containers differ for a name the agent
  doesn't need, and the planned egress restriction is by IP anyway. Revisit
  only if a real need for `.polaris.home.arpa` names appears.
- **Reachability confirmed from inside CT 404**: Forgejo's SSH port
  (`192.168.10.20:2222`) accepts a plain TCP connection (no credentials
  involved), and outside names resolve (`archive.ubuntu.com` returned records).
  One caveat: `getent hosts` lists IPv6 records first when they exist, so that
  result shows only IPv6 addresses and does not confirm IPv4 records or that the
  container can route IPv6 at all — the real proof of outbound package access is
  `apt` itself, which is the first step of base setup.
- **Base setup complete.** Locale fixed the same way CT402 needed it in
  Phase 2 (`locales` package, `en_US.UTF-8` generated, set via `LANG` only —
  deliberately *not* `LC_ALL`, so nothing overrides other locale categories
  system-wide). `locale -a` confirms `en_US.utf8` present; `env -u LC_ALL
  locale` confirms every category resolves correctly with `LC_ALL` unset in
  the container's own files — the earlier all-`C` output was `pct enter`
  injecting `LC_ALL=C` into that interactive shell only, not a container
  setting. Timezone left at UTC (a container has no NTP of its own; deliberate,
  makes cross-host log comparison easier). `apt-get update` proved clean
  against all three real Ubuntu repos with no errors, closing the earlier
  IPv6-only-DNS-answer concern.
- **Toolchain (stage 1 scope) installed: `git`, `openssh-client`,
  `shellcheck`.** `openssh-server` deliberately not installed yet — CT404 has
  no inbound access need until n8n's own connection method (forced-command
  keys, mirroring CT403) is designed alongside the workspace tools, so
  installing it now would just be a running service nothing uses.
- **`polaris-coding-agent`'s identity fully migrated off CT402 (2026-09-21).**
  A fresh `ed25519` key generated directly on CT404 (`/root/.ssh/id_ed25519`,
  comment `polaris-coding-agent@polaris.homelab` — same algorithm and filename
  convention as `polaris-documentation-agent`'s key on CT403). Same pattern as
  CT403 applies here too: `polaris-coding-agent` is a Forgejo identity, not a
  Linux account, and CT404 belongs entirely to it, so it stays as `root` and
  pins the key via `GIT_SSH_COMMAND` — no separate Linux user created.
  Old key retired for real, not just superseded: the CT404 key was added to
  the Forgejo account first and confirmed present, the account's *other* key
  (labeled only `polaris-coding-agent`, from 3k's original CT402 setup) was
  identified by fingerprint before touching anything — three independent
  reads of `SHA256:eyG5B40+yirj9WzlbyKpRR2R4Y9xI/ssmwry05gQN38` (Forgejo's own
  display, and the actual `.pub` file on CT402) all matched, so it was removed
  from Forgejo, then `polaris-coding-agent-git`/`.pub` deleted from CT402's
  `~/.ssh/` by exact filename, confirmed gone via a follow-up `ls`. n8n's
  credential list checked and holds nothing referencing CT402 or
  `polaris-coding-agent`, so no orphaned credential to clean up either.
  `polaris-coding-agent`'s Forgejo account confirmed already a Write
  collaborator on `Polaris-Pipeline-Testing` (no change needed — 4g's "confirm
  fresh or already granted" question is answered: already granted, from 3k).
- **CT404 → Forgejo authentication proven for real (2026-09-21).** First-ever
  connection from CT404, host key trust-on-first-use accepted, Forgejo greeted
  it by the key's own label: "Hi there, polaris-coding-agent! You've
  successfully authenticated with the key named CT404." No `ssh-keygen -Y
  sign` re-challenge this time — consistent with that flow only gating the
  cosmetic "Verified" badge, not actual authentication (3k hit the same
  challenge once, when the key was first added, not on every future
  connection).
- **Bot-account hygiene closed out across all three agent accounts, not just
  `polaris-coding-agent`.** Checking `polaris-coding-agent` surfaced that this
  had drifted further than Phase 3's open item described: its email had its
  own typo (`polaris.homlab`), and — not previously known — `polaris-merge-
  broker` was registered on an entirely different domain (`@homelab.local`),
  not merely an inconsistent local part. All three agent accounts are now
  confirmed consistent on both settings: "Can create organizations" unchecked,
  and `@polaris.homelab` email addresses — `polaris-coding-agent` →
  `codingagent@polaris.homelab`, `polaris-merge-broker` →
  `brokeragent@polaris.homelab`, `polaris-documentation-agent` →
  `polaris-documentation-agent@polaris.homelab`. Closes Phase 3's "3k:
  bot-account hygiene follow-up" item in full.
- **Minor cosmetic inconsistency noted, not fixed:** the email local-part
  convention itself isn't uniform — `codingagent`/`brokeragent` (compressed)
  versus `polaris-documentation-agent` (full account name). Not a security
  concern; worth aligning whenever convenient, no urgency.
- **CT404 identity work is now complete**: container built and verified,
  `polaris-coding-agent`'s key fully migrated from CT402, collaborator access
  on `Polaris-Pipeline-Testing` confirmed already in place, authentication
  proven live, and bot hygiene closed on all three agent accounts.
- **Deliberately not done yet:** no `openssh-server` on CT404 (deferred until
  its own inbound-access design), and no workspace tools (start/write/check/
  propose/discard) — the next real design step.

### 4g continued: Workspace Tools — built and proven live on CT 404 (2026-09-22)

Designed in conversation, same standard as everything else in 4g. Framed per
the standing principle above: these are general task-workspace operations
that happen to be provable against Forgejo today, not git-specific tooling.

**Task flow, as agreed:** clone fresh → list/read to scope what's being
worked on → write the file(s) → run checks, looping write→check with fixes
until either checks pass or the attempt cap is hit → propose (which re-runs
checks itself and embeds the real output, regardless of outcome) → discard
the workspace immediately after proposing. Long-lived workspaces kept alive
until merge were considered and deliberately rejected — that ties a
credentialed workspace's lifetime to an event CT404 can't observe (a human
merging on their own schedule), the same ownerless-lifetime shape 3u already
found and fixed once. PR revision instead gets its own start-with-existing-
branch mode later, so nothing needs to persist for it.

**Six operations, one workspace ID scheme:** `start-workspace`, `list`,
`read`, `write`, `run-checks`, `propose`, `discard` — IDs are generated by the
start script itself (`task-YYYYMMDD-HHMMSS-<6 hex chars>`), never supplied by
the model, closing the staging-path collision risk noted earlier in 4g.
Workspaces live under a fixed root on CT404 (exact path TBD at build time),
one directory per ID.

- **`run-checks` scope, and how "affected files elsewhere in the repo" is
  actually handled.** Because `start-workspace` clones the *whole* repo, not
  just the target file, every file is already present and reachable by
  `list`/`read`/`write` from the start — nothing needs to be specially
  "brought in." What varies is only what gets checked. Default: files changed
  since clone (`git diff --name-only` against the original head). A second,
  explicit check call against additional named paths is available when the
  agent has a specific reason to also verify something else it touched —
  deliberate and visible, never folded silently into the default. Reasoned
  safety basis (extending 4g's standing rule one step further): CT404 holds
  no real-target credentials and never deploys, so a check failing against a
  shared file inside this sandbox costs nothing — it's information for the PR
  reviewer, not damage anywhere real.
- **Propose-at-cap behavior, precisely.** If the attempt cap is hit but the
  workspace holds real, committable code, `propose` still runs — checks
  re-run for real, their actual output embedded in the PR body, and the PR's
  title or the top line of its body states plainly that checks are still
  failing after N attempts, so a human scanning open PRs can immediately tell
  which ones are routine versus need real attention. This is distinct from a
  more fundamental failure with nothing committable at all (the checker binary
  itself erroring, a push failing for an infrastructure reason) — that stays a
  plain failure report, no PR, since there's no code to open one around.
- **The fix-attempt cap is a separate mechanism from n8n's own reasoning
  iteration cap, tracked in n8n's existing loop state** — no new counting
  mechanism. n8n's cap guards the whole task's reasoning; this one guards
  specifically the write→check→fix cycle from thrashing on one stubborn
  error. Both apply; neither substitutes for the other.
- **Credentials — three keys, split on a single axis: does the operation ever
  leave CT404?** Two operations make a real outbound call (`start-workspace`
  clones from Forgejo; `propose` pushes and calls Forgejo's API) — each gets
  its own dedicated, fixed-command key, same one-key-one-purpose pattern as
  every prior agent. The other four (`list`, `read`, `write`, `run-checks`,
  `discard`) never leave CT404's own filesystem — no network call is reachable
  through any of them even if the key were compromised — so they share **one**
  internal-dispatcher key. Considered and deliberately rejected: literal
  single-use/expiring credentials (the nearest real analogue is short-lived
  SSH certificates issued by a CA per request — a genuinely heavier
  architecture needing an issuance mechanism this project doesn't have; see
  the CA/PKI open item above). The scoped-dedicated-purpose model already used
  everywhere in this project is the right fit here too — broader eventual
  scope means more operations to route, not a different credential
  philosophy.
- **The shared internal key needs a small dispatcher, not a fixed single
  command.** Every CT403 forced-command key maps to exactly one script.
  A key shared across four operations instead reads which one was requested
  out of `$SSH_ORIGINAL_COMMAND` and routes to the matching script —
  extending the same parsing technique `write-doc.sh` already uses for its
  own arguments to also select which script runs, not only supply its
  arguments. `start-workspace` and `propose` remain simple, single-fixed-
  command keys, unchanged from the established pattern.

**Dispatcher script — design settled (2026-09-21).** Handles the single
shared internal key's four operations (`list`, `read`, `write`, `run-checks`,
`discard` — five scripts, one dispatcher). Structure:

1. Strip n8n's known `cd <dir> ; ` prefix, then split the remaining text with
   `read -ra` — the same tokenizer `write-doc.sh`/`rename-doc.sh` already use,
   which naturally treats any run of whitespace *between* tokens as one
   delimiter (any amount, both ends, never touching what's inside a token).
   This is the deliberate fix for the exact bug class that broke
   `search-content.sh` (a fixed single-space assumption). Each extracted
   token then gets its own separate leading/trailing trim — covering step 5's
   separate finding that the model's own output can carry stray whitespace
   around an otherwise-correct value. Neither step ever alters what's inside
   a token.
2. First token: operation name, checked against a fixed allow-list before
   anything else happens.
3. Second token: workspace ID, validated against the exact generation pattern
   (`task-YYYYMMDD-HHMMSS-<6 hex chars>`) *before* it's used in any path —
   this is the check that stops a workspace ID from ever being usable to
   escape the workspace root, playing the same role one level up that the
   absolute-path/`..` check already plays inside a workspace.
4. Confirm that ID exists as a real directory; fail with a plain message if
   not.
5. Dispatch to the one real script for that operation, passing remaining
   arguments through untouched.

**Error handling: split by exit code, not by inspecting error text.** This
resolves a real tension surfaced in discussion — hiding raw internal errors
from the model (the `BRANCH_NAME`-leak lesson) must not come at the cost of
the agent's own ability to read a real, well-formed rejection and correct
itself. Two genuinely different situations were being called "an error":

- **A deliberate, well-formed rejection** (e.g. `write-file.sh`'s existing
  absolute-path/`..` check firing) — the harness working correctly, telling
  the agent exactly what it did wrong. Convention: the sub-script exits `2`
  with its own specific, already-safe message (already written clean of any
  internal detail, per 4c's "describe the likely problem in plain terms"
  principle), and the dispatcher passes that message straight through
  unchanged. This is the agent debugging *its own authored code* — it needs
  this, in full.
- **A genuine, unexpected crash** in the harness itself (a stack trace, an
  internal variable name, a missing tool) — not information about the
  agent's code at all, just plumbing noise. Convention: any exit code other
  than `0` (normal success) or `2` (deliberate rejection) triggers a fully
  generic message back to the agent (`"the <op> step failed unexpectedly"`,
  no snippet of the real text, however short), while the full raw output is
  logged to a fixed file (`/root/logs/coding-agent-dispatcher.log`:
  timestamp, PID, operation, workspace ID, exit code, full captured output)
  for the user's own troubleshooting of the agent's structure — a channel the
  agent itself never sees and has no path to.

`run-checks` is explicitly neither case: a checker tool (e.g. `shellcheck`)
finding lint problems is normal, wanted product data the agent is meant to
read and act on, not a failure of any kind — `ws-run-checks.sh` captures the
checker's own exit code as data in its output and exits `0` itself, so the
dispatcher never treats a real check result as case 2.

**Terminology convention adopted for this document and this conversation, at
explicit request:** "the agent debugging/correcting its own code" (case 1,
above) and "the user troubleshooting the agent's own structure" (case 2,
above) are now used explicitly rather than an ambiguous "debugging" — the
distinction matters enough to this design that it's worth never leaving
implicit.

**Workspace root and log paths confirmed:** `/root/workspaces` and
`/root/logs/coding-agent-dispatcher.log` on CT404, no longer placeholders.

**The seven files (`ws-common.sh`, `ws-list.sh`, `ws-read.sh`, `ws-write.sh`,
`ws-run-checks.sh`, `ws-discard.sh`, `ws-dispatch.sh`) were fully drafted, then
actually verified before being treated as ready — not just read over.**
Verification method: placed at their real intended path (`/root/bin`, since
`ws-common.sh` sourcing by relative assumption needs the real path to mean
anything), checked with `bash -n` and a real `shellcheck` install, then
exercised functionally end-to-end — every rejection path (`..`, absolute
paths, `.git`, unknown operations, malformed workspace IDs), the dispatcher's
n8n-prefix/irregular-spacing handling, and `discard`'s idempotency on a second
call. This is the same standard being designed *for* the coding agent itself
(checker output as real evidence, not a claim) applied to this harness's own
construction.

**Two real, concrete bugs found this way in `ws-run-checks.sh`, both silently
inverting its entire purpose — worth recording precisely since the same
category will recur in every future language module:**

1. Under `set -eu`, `shellcheck` (or `bash -n`) returning non-zero — which is
   the *normal, expected* case whenever a real problem is found — killed the
   script mid-output. The dispatcher would then see a raw exit code of `1`
   (neither `0` nor the deliberate-rejection `2`), misclassify a completely
   ordinary check result as an unexpected harness crash, log it as noise, and
   return the agent nothing but "the run-checks step failed unexpectedly" —
   hiding the exact information the agent most needs, every single time a
   check actually found something. Same root category as `search-content.sh`
   needing a deliberate `set -e` omission for `grep`'s own zero-match exit
   code (3k/4c) — a tool's own meaningful non-zero exit must never be allowed
   to look like the harness breaking.
2. A workspace with zero changes since clone failed identically, but
   silently: `grep -v '^$'` exits `1` when nothing survives the filter (its
   documented behavior on empty input), which under `set -e` aborted the
   script with no output at all before the dispatcher even got a chance to
   log anything useful.

**Fix applied to both:** the checker invocations are now bracketed with
`set +e` / `set -e` so their real exit code is captured as data instead of
triggering an abort, echoed explicitly (`exit=$bn_ec`, `exit=$sc_ec`); and
`grep -v '^$'` was replaced with `sed '/^$/d'`, which exits `0` regardless of
whether anything matched, plus an explicit `[ -z "$changed" ]` early-return
printing "no changes since clone". Both fixes proven against the exact two
cases that broke — a real buggy script (correctly walked to completion with
real `shellcheck` findings intact) and a genuinely empty workspace (clean
"no changes" message, exit 0) — not just asserted fixed.

**Everything else — `ws-common.sh`, `ws-list.sh`, `ws-read.sh`, `ws-write.sh`,
`ws-discard.sh`, `ws-dispatch.sh` — passed real testing with no changes
needed.** One incidental confirmation worth noting: `ws-discard.sh`'s
belt-and-suspenders workspace-root check (considered "redundant with the
dispatcher today, but cheap" when designed) fired for real during testing on
a malformed path from a testing mistake, rejecting it cleanly before `rm -rf`
was ever reached — the exact scenario it exists for.

**`start-workspace.sh` and `propose.sh` — final design, including two real
bugs found and fixed after the first draft, before deployment (2026-09-22).**

- **`start-workspace.sh <repo> <mode> [branch] [pr_number]`**: repo checked
  against a fixed allow-list (`Polaris-Pipeline-Testing`, `Project_Polaris`)
  via the same `case` pattern the dispatcher uses for operations — a
  deliberate boundary, not an open parameter: which repos this agent can ever
  touch is decided by editing this script, a conscious act, never a side
  effect of a task description. `mode` is explicit (`new` or `revise`), never
  inferred from argument count. Clones with `GIT_SSH_COMMAND` pinning the
  exact key (same technique `polaris-documentation-agent` uses on CT403).
- **Revision mode, added after the base design**: `revise <branch>
  <pr_number>` checks out an already-existing branch instead of leaving a
  fresh one for `propose` to create. Two safety checks specific to this mode:
  the branch name must match the agent's own generation pattern
  (`^coding-agent-[0-9]{8}-[0-9]{6}$`) — restricting revision to branches this
  agent created itself, never `main` or anyone else's branch — and its
  existence on the remote is checked explicitly
  (`git show-ref --verify refs/remotes/origin/<branch>`) before checkout is
  even attempted, so a closed PR/deleted branch is a clear, plain rejection
  ("that branch no longer exists on the remote") rather than a raw git error
  falling through to a generic crash. **Proven against a local stand-in
  remote**: a branch pre-seeded with one commit was checked out into a fresh
  clone by name alone (confirming plain `git checkout <branch>` correctly
  tracks a remote-only branch, no special flags needed), a second commit
  pushed onto it, and the remote confirmed afterward to hold two commits on
  one branch — no duplicate branch, no duplicate PR created.
- **The repo/mode/branch/PR-number binding is a property of the workspace
  itself**, written by `start-workspace.sh` to a sibling `$WORKSPACE_ROOT/
  <id>.meta` file (small `key=value` lines, covering both modes under one
  schema) and read back by `propose.sh` — not re-supplied by the caller,
  closing the risk of a workspace's actual remote silently disagreeing with
  what it's later assumed to be. The file is a sibling of the workspace
  directory, never a child of it, because `run-checks.sh`'s own `git add -A`
  runs *inside* `$ws_path` — a metadata file living there would be staged,
  committed, and pushed straight into a real PR. **Proven**: confirmed
  sitting beside the workspace directory, absent from a listing of the
  workspace's own contents, and absent from `git status` after a real
  `git add -A` inside it. `ws-discard.sh` was updated to remove both the
  directory and its `.meta` file — the sibling design would otherwise have
  leaked one small orphaned file per completed task, forever; confirmed both
  gone after a single `discard` call.
- **Real bug #1, found by actually writing the two scripts out in full, not
  by executing them: neither one was parsing `$SSH_ORIGINAL_COMMAND`.** Every
  earlier draft used plain positional arguments (`$1`, `$2`), which only
  worked because sandbox tests called them directly — under their real
  dedicated forced-command keys, arguments never arrive that way at all; the
  attempted command lands in `$SSH_ORIGINAL_COMMAND` for the script to parse,
  exactly like the dispatcher. Fixed by moving the dispatcher's own parsing
  logic (`trim`, plus a new `parse_ssh_tokens` populating a `TOKENS` array)
  into `ws-common.sh` as a shared helper, used by all three real SSH entry
  points (`ws-dispatch.sh`, `start-workspace.sh`, `propose.sh`) — never by the
  five internal `ws-*.sh` scripts, which the dispatcher always calls with
  plain argv, never directly over SSH.
- **Real bug #2, more subtle, found while fixing error handling for these two
  scripts: a command substitution failing while building another command's
  *argument* is not caught by `set -e` at all**, unlike `var=$(cmd)` failing
  directly. `propose.sh`'s original `-d "$(jq -n ...)"` inline inside its
  `curl` call meant a missing `jq` binary (genuinely absent from CT404 at the
  time) produced an empty, silently-swallowed substitution — the script kept
  going with a broken payload and only surfaced curl's own later, unrelated
  failure. This is exactly the class of raw-internal-leak this whole error
  design exists to prevent, reappearing through a gap the dispatcher's own
  discipline didn't cover, since neither of these two scripts sits behind the
  dispatcher's relay — they're invoked directly by their own dedicated keys.
  **Fixed with two changes**: hard prerequisites (`jq`, `curl`, a readable
  token file) are checked explicitly, once, at the top of `propose.sh`, via a
  small `require()` helper that logs and exits cleanly on failure; and the
  JSON payload is built as its own guarded assignment (checked directly, like
  `var=$(cmd)`, which *is* subject to `set -e`) before ever being passed to
  `run_or_log`'s `curl` call — so `run_or_log` only ever receives
  fully-resolved plain values, never a live substitution that could fail
  invisibly inside it.
- **`run_or_log`, a generalization of the dispatcher's error-code split to
  both dedicated-key scripts.** The dispatcher's "exit 2 is a deliberate,
  safe rejection; anything else is an unexpected crash, logged for the user,
  genericized for the agent" discipline only covered the five relayed
  operations. `start-workspace.sh` and `propose.sh` have no relay in front of
  them at all, so the same discipline needed its own implementation: added to
  `ws-common.sh` as `run_or_log`, wrapping `clone`, `commit`, `push`, `open-pr`,
  and `post-comment` — each captures real output, logs it in full to the same
  `LOG_FILE` on any unexpected failure, and returns one generic message,
  never raw git/curl/network detail, to the agent.
- **A third real, nameable case found during testing, not designed in
  advance: calling `propose` twice with nothing new written the second time**
  was falling through to a generic "commit step failed unexpectedly" (`git
  commit` on a clean tree fails). Fixed with an explicit check
  (`git diff --cached --quiet` after `git add -A`) that rejects plainly
  ("no changes to propose") before ever attempting a commit — a real,
  legitimate situation the agent should hear about clearly, not a harness
  crash.
- **`propose.sh` classifies checks via a plain-text match on the real output**
  (`checks passing` / `checks still failing`) — acknowledged as pattern-
  matching text, not a structured result, adequate for stage one, worth
  revisiting once a second language's check output format exists.
- **Revision pushes always post a visible comment on the existing PR with the
  real check output — never silent**, matching new-mode's PR body exactly in
  spirit: every `propose` call, regardless of mode, leaves a real, visible
  trace.
- **A real, generalizable finding surfaced by testing, not asserted in
  advance**: a trivial script with no shebang line is classified `checks
  still failing`, because `shellcheck` flags a missing shebang at error
  severity by default — meaning almost anything the agent authors without
  deliberately including one will show this status. **Deliberately left
  open**: whether to require a shebang mechanically (in `write-file.sh`) or
  via the agent's own task-facing instructions — deferred until those
  instructions are designed, so the requirement is shaped by real need.
- **`polaris-coding-agent`'s Forgejo API token**: generated the same way
  `polaris-merge-broker`'s already is (Repository Read and Write only),
  stored at `/root/.polaris_coding_agent_api_token` on CT404, `chmod 600`.
  Kept out of this conversation and this document entirely throughout —
  generated in the Forgejo UI and written directly to the file by the user.
  **Confirmed complete 2026-09-22** (file present, correct size and
  permissions, checked directly rather than assumed).

**Real deployment to CT404 and live proof (2026-09-22) — the harness is
built, not just designed.**

- **Three keypairs generated directly on CT404**, one per dedicated purpose,
  following the established descriptive-filename convention (distinct from
  the outbound `id_ed25519` identity used for cloning/pushing to Forgejo):
  `coding-agent-start-key`, `coding-agent-internal-key`,
  `coding-agent-propose-key`. Public halves appended to root's own
  `/root/.ssh/authorized_keys` on CT404 (no separate Linux user — CT404
  belongs entirely to this one identity, same reasoning as CT403), each with
  its own `command="..."` pointing at the right script plus
  `no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty` —
  confirmed as three distinct, correctly-formed lines, nothing pre-existing
  in the file overwritten. Private halves handed to n8n as three separate SSH
  credentials, kept out of this conversation and this document entirely —
  displayed on the container's own terminal and copied directly into n8n,
  the same handling as the API token.
- **All nine files (`ws-common.sh` and the eight executable scripts)
  transferred to `/root/bin` on CT404 in one pass, exactly as verified in
  sandbox testing** — file sizes on CT404 matched the sandbox-tested
  originals exactly, byte for byte, confirming nothing was altered or
  truncated in transfer. Permissions confirmed correct: `ws-common.sh`
  non-executable (only ever sourced), the other eight `-rwxr-xr-x`.
- **The forced-command restriction proven twice, deliberately, not assumed
  from the `authorized_keys` syntax alone** — same standard CT403's write
  path was held to. **First pass, before the scripts existed on disk**: all
  three credentials, sent `whoami; ls /` through a real n8n SSH node, each
  returned `bash: ... No such file or directory` (exit 127) — proving the
  override itself was already working (neither command ever ran; SSH
  substituted the fixed command and only then found it missing), before any
  script logic could be tested. **Second pass, after transfer**: same exact
  test, now hitting real logic — `start` returned `REJECTED: unknown repo`
  (exit 2), `internal` returned `ERROR: unknown operation` (exit 1), both
  exactly as designed. `propose` initially returned `ERROR: the coding
  agent's environment is not fully set up` (exit 1) — not a bug, but the new
  `require` check correctly catching a real, previously-unconfirmed gap:
  `jq` and `curl` were genuinely never installed on CT404, only proven in
  sandbox. Installed both for real
  (`apt-get install -y jq curl`), re-ran the same test a third time, and
  `propose` then reached its real logic too: `REJECTED: workspace not found`
  (exit 2) — the malformed single token `whoami;` correctly failing workspace
  lookup, exactly as predicted.
- **This closes out 4g's core build.** Every one of the nine scripts exists
  on CT404, is wired to a proven, restricted forced-command key, and has been
  exercised through a real SSH connection with a genuinely adversarial input
  (an attempted arbitrary command), not just a well-formed one.

### 4g continued: Task-Facing Design — settled 2026-09-22

**Propose-timing: workflow-enforced, not model-initiated (a deliberate choice
between two real options).** The alternative — the model deciding for itself
when checks have passed enough times, or when to give up — would have been
exactly the kind of self-report this whole project has refused to trust
anywhere else (base64 decoding done in code rather than by the model, real
check output embedded rather than a model's summary, `run_or_log`'s refusal
to let a script claim its own success). Settled instead: `start-workspace`
runs before the model is ever invoked (the task arrives already knowing its
repo and mode); the model's own tool surface is exactly four operations —
`list`, `read`, `write`, `run-checks` — looping under a real, counted n8n
loop node; when the loop ends, by success or by a hard cap, one final
narrow model call produces only a summary/commit message; `propose` and
`discard` then run deterministically, always, regardless of outcome. The
model never calls `start-workspace`, `propose`, or `discard` directly — those
three dedicated keys are never placed in its own tool list at all.

**A standing principle on model choice, stated explicitly and worth
preserving precisely: the right model should be used for the job; the job
should never be shaped to fit whatever model happens to be on hand.** The
only hard constraint is the AI node's own hardware ceiling, roughly a 24B-
parameter model — real and fixed. Which specific model sits under that
ceiling is never considered settled. `gpt-oss:20b` remains the pick for the
coding agent's first real tasks, kept **not** because testing proved it
final, but because switching before any real task has run would be guessing
at a problem that might not exist — live task data is a better judge than
synthetic tests, exactly as the earlier model-selection methodology's own
caveat ("best from what was tested, not a closed list") already said. This
principle is written here in general terms because it is meant to apply to
every future agent and every future model choice, not just this one.

**Language freedom: the model is not limited to any language — three
options were weighed, and the reframing that decided between them was
recognizing what rung 1 actually needs.** Rung 1 never executes the agent's
own code — it only runs a *static checker* against it, which needs no
runtime for the language being checked (Python source is inert text until
something executes it; nothing does at rung 1). This meant the real choice
was never "which languages to support" but "which checkers to preload," and
checkers are lower-risk than full toolchains since they only ever read code.
- **Preload checkers for common languages now, batched and deliberate, same
  as `shellcheck` was — adopted.** See the checker batch below.
- **The model is explicitly told it isn't limited to languages with a
  checker, and should recommend what's needed when one is missing —
  adopted in full**, and required no new building: `propose` already embeds
  "no checker configured for this file type yet" verbatim into the PR/
  comment, which is already the exact trigger a human needs to decide
  whether to add a language module.
- **Live self-install via `apt-get` on the running container — declined,
  explicitly, as a reversal of an earlier agreed decision, not a new
  standalone judgment.** The earlier egress design (bake the toolchain in
  once, at build time, with a human's hand on the network switch, then
  restrict the *running* container to Forgejo-only egress) exists
  specifically so a live agent reasoning over untrusted repo content never
  has an open path outside at the same moment. Live install reopens exactly
  that path. The real risk was named precisely: not losing CT404 (trivially
  rebuilt) but the *combination*, live, of outbound network access, real git
  push credentials, and an LLM reasoning over content it didn't write.
  **What was kept from the underlying want**: a genuine "I need X" surfaces
  in the model's own final summary, same as an unchecked language, and
  becomes a fast, deliberate, human-triggered install — the same operation
  as installing `shellcheck` was, just triggered by an observed real need
  instead of a guess made today. Fast, never autonomous.

**The checker batch — designed, then proven against real clean and real
broken fixtures for every entry, catching two concrete bugs a visual read
would have missed:**

- **Bash** (`.sh`): `bash -n` + `shellcheck` — unchanged from the original
  design.
- **Python** (`.py`): `python3 -m flake8`. **Real bug caught before
  handoff**: the bare `flake8` command does not exist on this apt package's
  PATH at all — only `python3 -m flake8` works. Using the bare word would
  have failed silently on the very first Python task.
- **JSON** (`.json`): `jq empty <file>` — no new install needed, `jq` was
  already present for `propose.sh`'s own API calls. Syntax-only, as
  intended; confirmed a trailing-comma error is caught with a nonzero exit.
- **C++** (`.cpp`/`.cc`/`.cxx`/`.h`/`.hpp`/`.hh`): `cppcheck --enable=
  warning,style,performance,portability --suppress=missingIncludeSystem
  --error-exitcode=1`. **Real bug caught before handoff, more serious than
  the Python one**: `cppcheck`'s default exit behavior is `0` regardless of
  findings unless `--error-exitcode` is set — but the first attempt at that
  fix, `--enable=all --error-exitcode=1`, flagged a plain, correct
  `#include <iostream>` as a failing "issue," meaning *every* valid C++ file
  using standard headers would have permanently failed checks, with no code
  change able to fix it — a worse version of the shebang problem, since it
  could never be resolved by writing better code. Fixed with the narrower
  `--enable=` set plus the explicit suppression; proven afterward that clean
  code genuinely passes while real bugs (a memory leak, an uninitialized
  variable) are still caught.
- **HTML** (`.html`/`.htm`): `tidy -errors -quiet`. **A genuine ambiguity
  found, not a bug — resolved the same way the shebang question was, by
  prompt rather than by mechanism.** A bare fragment (no doctype/head/title)
  is legitimate agent output when a task calls for a snippet, but `tidy`
  flags its absence regardless — even `tidy`'s own `--show-body-only auto`
  fragment-detection flag was tested and did not change this. Unlike the
  C++ case, there is no flag that can tell "a fragment, and that's fine"
  apart from "a fragment, and it should have been a full document" — only
  the task itself knows which was intended. Left as `tidy`'s honest default;
  the system prompt states the expectation instead.
- **JavaScript deliberately still not covered** — `eslint` pulls in the
  whole npm/Node ecosystem and real configuration conventions, a heavier,
  more deliberate decision than the others; held for its own pass rather
  than folded into this batch.
- **Proven together, not just individually**: a real mixed-language
  changeset (one file each of `.cpp`, `.py`, `.json`, `.sh`, `.html`, plus
  one genuinely unsupported `.rb`) run through `run-checks.sh` in a single
  call — every checker correctly isolated its own real exit code as data via
  the established `set +e`/`set -e` bracket, the unsupported type correctly
  fell through to the honest fallback message, and the overall script still
  exited `0` cleanly despite three of the five checked files reporting real
  problems (including `good.sh` catching its own missing-shebang case again,
  an incidental reconfirmation that behavior survived the rewrite).

**Base64 encoding/decoding is explicitly the tool wrapper's job on both
sides, never the model's** — stated plainly now, though implicit since the
read path's original design: the model should only ever see and produce
plain text. Asking it to compute base64 for writes would be the same
fabrication risk in reverse that the read path was built to avoid.

**The finalized system prompt:**

```
You are the Polaris coding agent, working inside an isolated sandbox on
your own dedicated container. Your job is to write correct, working code
for one specific task. You do not deploy anything, and you never touch
any system outside this sandbox.

You have four tools: list, read, write, run-checks. The repository you're
working in is already cloned into your workspace — explore it with list
and read before writing, so you understand what you're changing and why.

You are not limited to any particular programming language. Choose
whatever language is actually right for the task, not whatever happens
to be convenient. Checkers currently exist for: bash (.sh), Python (.py),
JSON (.json), C++ (.cpp/.cc/.cxx/.h/.hpp), and HTML (.html/.htm) — their
findings are real and authoritative, and you should trust them completely
over your own judgment about whether your code is correct. If the right
language for this task has no checker yet, write it anyway: say so
plainly in your final summary, including what tool would be needed to
check it, so a human can decide whether to add it. Never assume you can
install anything yourself.

Rules:
- Write complete files. You cannot write partial diffs or patches — every
  write replaces a whole file.
- Every bash script (.sh) must begin with a proper shebang line
  (e.g. #!/bin/bash). Checks will flag a missing one as an error.
- If you are asked to write a complete HTML page, include a proper
  doctype, head, and title — the checker will flag their absence. If you
  are deliberately writing a fragment or snippet meant for inclusion
  elsewhere, warnings about a missing doctype or title are expected and
  not a real problem.
- Call run-checks after writing. Its output is real and authoritative.
- If checks fail, read the output carefully, fix the specific problem
  named, and check again. Don't rewrite unrelated working code.
- You cannot access anything outside your current workspace. The .git
  directory is off-limits.
- If the task's requirements are genuinely ambiguous, contradictory, or
  impossible to satisfy as written, say so clearly and specifically at
  the very start of your final summary (for example, beginning it with
  "TASK CONCERN:") rather than guessing at what was meant or forcing
  something that doesn't actually work. Your work is still proposed for
  human review either way — a clear, upfront flag just helps a reviewer
  immediately understand what happened.
- When you believe the task is complete, or you've made your best
  attempt, stop and wait — you will be asked to summarize your work.
```

The "TASK CONCERN" rule gives real, immediate value to the outcome-routing
question captured earlier as deferred (infeasible/ambiguous requirements
eventually wanting a path other than a PR): today's build still always
proposes regardless, but a reviewer scanning PRs can already tell, at a
glance, which ones carry the model's own flagged concern about the task
itself — without building anything new to get it.

**Deployment status — designed and proven in sandbox; real CT404 install not
yet confirmed.** Install commands given for `python3-flake8`, `cppcheck`,
`tidy` (all three genuinely absent from CT404, confirmed by the same
`command -v`-style check pattern used for the `jq`/`curl` gap earlier), and
the updated `ws-run-checks.sh` content given for redeployment. Following
this document's own standard for unconfirmed steps (as the API token was
tracked until directly confirmed): **not** marked complete until verified on
the real container.

**Resolved: the model's attempt count/cap position stays invisible to it —
decided 2026-09-22, and for a stronger reason than "informational only."**
The cap's enforcement was never in question either way (n8n's deterministic
loop, unchanged regardless). The real reason: telling the model "this is
your last attempt" could actively bias it toward *accepting* flawed work
under a felt need to "produce something" before the cap hits — rather than
giving its genuine best assessment of whether the code is actually correct.
That would work directly against the reason the write→check→fix loop exists.
This extends the same standing principle behind never trusting the model's
own claim about its state or progress (base64 decoded in code, checks
reported by the pipeline, `run_or_log` never letting a script claim its own
success): visibility into its own remaining budget is itself a kind of
self-referential state that could distort its judgment, so it stays out of
the model's view entirely, same as everything else in this category.

**Open items still outstanding:**
- **A practical constraint worth being aware of as scope broadens (not yet a
  problem, not yet solved)**: every write travels as one SSH command string,
  base64-encoded. A very large generated file could plausibly approach
  practical command-length limits on the SSH channel — untested, likely fine
  for realistically-sized task files at this stage, but worth remembering
  once "general-purpose coding agent" tasks get less narrow. **One possible
  future direction raised, not yet explored**: splitting a large piece of
  work across multiple smaller tasks/writes rather than one giant file —
  worth revisiting if this ever becomes a real constraint rather than a
  theoretical one.

### 4g continued: n8n Build — in progress (2026-09-22)

**Mirroring the documentation agent's own proven n8n patterns, not
inventing new ones — examined directly rather than assumed.** The
documentation agent's real workflow (screenshots reviewed 2026-09-22) uses
n8n's built-in AI Agent node with each tool as its own subworkflow
(trigger → build command → Execute Command/HTTP → format result), Ollama as
chat model, and a hard `Max Iterations` field on the Agent node itself
(currently 20 there). Two real findings from this, one a correction to
Claude's own earlier guess, one a genuine gap in the design as stated:

- **A real gap, not a Claude error: the Agent node errors out and halts the
  entire workflow when Max Iterations is hit — it does not hand control back
  gracefully.** This directly breaks the standing rule that a cap-out must
  still produce a PR with honest reasoning. Confirmed directly from the
  user's own experience operating the documentation agent's identical
  mechanism, not assumed. **Fix: n8n's built-in Error Workflow feature** — a
  separate workflow named as the main workflow's error handler, invoked
  automatically on any unhandled failure, including a Max-Iterations error.
  This cleanly separates the two real end states without restructuring the
  main workflow itself: **success** (model voluntarily stops calling tools)
  flows normally to a deterministic wrap-up; **cap-out** (Max Iterations
  fires) is caught by the Error Workflow, which performs its own
  deterministic wrap-up (one narrow summary call, then `propose`, then
  `discard`).
- **Confirmed still uncertain, not resolved by inspection**: what data an
  Error Workflow trigger actually receives (full failed run context, or only
  the error and which node failed) remains unverified — Claude has no way to
  test n8n directly. **Design deliberately made robust to either answer**:
  the cap-out summary is grounded in **real, current workspace state**
  (`run-checks` output, file listing) rather than the model's own
  recollection of the conversation — consistent with the existing "the
  deterministic layer reports, not the model" principle, and sidesteps the
  memory-backend question entirely (Simple Memory only, in-memory,
  confirmed via the Memory node's own options list) since nothing depends on
  conversation history surviving the failure.
- **A small defensive step planned for the main workflow's first steps**:
  write `ws_id` to a lookup keyed by `{{$execution.id}}` immediately after
  `start-workspace` runs, so the Error Workflow can always find which
  workspace to clean up regardless of what else its trigger does or doesn't
  provide.
- **A deliberate, confirmed divergence from the documentation agent's own
  proven pattern, not an oversight**: the documentation agent's model calls
  `Propose` as a tool it chooses to invoke itself. This design keeps
  `propose` (and `start-workspace`, `discard`) entirely outside the model's
  own tool list, invoked only by the deterministic workflow — per the
  earlier workflow-enforced-propose-timing decision. Confirmed as still the
  right call for this agent specifically: **the documentation agent's
  "propose-as-a-tool" pattern is a real, working thing to build on, not
  something to imitate wholesale into the coding agent** — as the user put
  it, the coding agent operates differently and has different calls it does
  or doesn't need to make.

**Real corrections found by examining actual, working screenshots — two
places Claude's own earlier guesses were wrong, caught before more was built
on top of them:**

1. **Tool output shape.** The documentation agent's proven convention wraps
   every tool result as `{ result: [...] }` — always an array — regardless
   of whether the underlying content is a single file, a directory listing,
   or an error. Claude's original suggestion (`{ output: $json.stdout }`)
   didn't match this at all. Corrected across all four tools to
   `return [{ json: { result: [<text>] } }];`, honoring the same convention
   the Agent node already knows how to consume.
2. **`ws_id` must never be a `$fromAI` field, on any of the four tools.**
   The documentation agent's own tools use `$fromAI` for fields the model
   genuinely should decide (`file_path`, `repo_name`) — but applying that
   same pattern to `ws_id` would mean trusting the model to correctly repeat
   an opaque identifier across every tool call, exactly the class of
   self-report this whole project has refused to trust elsewhere (the same
   reasoning behind `propose.sh` reading its repo from a sibling `.meta`
   file rather than asking for it again). **Fix**: in the main Agent
   workflow, `ws_id` is captured once, right after `start-workspace` runs,
   and every Tool node's `ws_id` input uses a **fixed expression** pointing
   at that stored value — never `$fromAI`. Only genuinely judgment-requiring
   fields (`subpath`, `relpath`, `content`, `extra_paths`) use `$fromAI`.

**A real, already-proven precedent for the deferred SSH-command-length
concern, found but deliberately not adopted yet.** The documentation agent's
`Propose Documentation Change` workflow doesn't send file content over SSH
at all — it uploads via SFTP to a staging path first, then sends only small
metadata (`target_path`, `commit_message`) over the command channel.
**Recorded as the known, proven fallback** if a real file ever does approach
a practical length limit — deliberately not adopted now, since the current
design is already built and tested as-is and the concern remains
theoretical; adopting it now would mean designing a workspace-scoped
staging convention to fix a problem that hasn't actually occurred.

**Finalized tool descriptions**, in the documentation agent's own proven
`$fromAI` phrasing style rather than invented wording:

```
list — List the contents of a directory inside your workspace.
  subpath: A path, relative to your workspace root, to list. Use '.' to
  list the root. Do not include a leading slash.

read — Get the full contents of a specific file inside your workspace.
  Content is always returned as plain, readable text — never raw encoded
  data.
  relpath: The exact path to a file, relative to your workspace root,
  exactly as returned by a previous list result. Do not include a leading
  slash. The .git directory cannot be read.

write — Write a file inside your workspace, creating it if it doesn't
  exist. This always replaces the entire file — partial edits are not
  supported.
  relpath: The exact path to write, relative to your workspace root. Do
  not include a leading slash.
  content: The complete contents of the file. You must provide the entire
  file every time, never a partial edit or diff.

run-checks — Run real static checks against every file you've changed so
  far, and report their exact output. Trust this output completely over
  your own judgment.
  extra_paths: Optional — additional file path(s), relative to your
  workspace root, to also check beyond what you have already changed.
  Leave empty unless you have a specific reason to check something else.
```

**Finalized system prompt**, rewritten in the documentation agent's own
proven numbered-rules style (confirmed working with this exact model in
this exact environment) rather than the earlier looser prose draft:

```
You are the Polaris coding agent, working inside an isolated sandbox
container. Your job is to write correct, working code for one specific
task. You never deploy anything, and you never touch any system outside
your own workspace.

You have four tools: list, read, write, run-checks. Your workspace already
contains a real clone of the repository for this task.

Language:
1. You are not limited to any particular programming language. Choose
   whatever language is genuinely right for the task.
2. Checkers currently exist for: bash (.sh), Python (.py), JSON (.json),
   C++ (.cpp/.cc/.cxx/.h/.hpp), and HTML (.html/.htm). Their findings are
   real and authoritative — trust them completely over your own judgment.
3. If the right language for this task has no checker yet, write it
   anyway. State this plainly in your final summary, including what tool
   would be needed to check it. Never assume you can install anything
   yourself.

Writing files:
4. Every write replaces an entire file. Partial diffs or patches are not
   supported — always write the complete file.
5. Every bash script (.sh) must begin with a proper shebang line (e.g.
   #!/bin/bash). A missing one will be flagged as an error.
6. If asked for a complete HTML page, include a proper doctype, head, and
   title. If deliberately writing a fragment for inclusion elsewhere,
   warnings about a missing doctype or title are expected and not a real
   problem.
7. The .git directory is off-limits and cannot be read or written.

Checking your work:
8. Call run-checks after writing. Its output is real and authoritative.
9. If checks fail, read the output carefully, fix the specific problem
   named, and check again. Do not rewrite unrelated working code.

Reporting:
10. If the task's requirements are genuinely ambiguous, contradictory, or
    impossible to satisfy as written, say so clearly and specifically at
    the very start of your final summary, beginning it with "TASK
    CONCERN:", rather than guessing at what was meant. Your work is still
    reviewed either way — this just helps a reviewer immediately
    understand what happened.
11. When you believe the task is complete, or you have made your best
    attempt, stop calling tools and give a concise final summary of what
    you did or attempted.
```

**Max Iterations set to 12** — a real, deliberate departure from the
documentation agent's own 20, reasoned rather than copied: a write→check→fix
cycle burns at least two tool calls per attempt, often more with
exploration, so 12 allows several genuine fix attempts without letting a
stuck task spin indefinitely.

**Build progress on the four tool subworkflows:**
- **`list`**: built, corrected to the real `{ result: [...] }` output shape.
- **`read`, `write`, `run-checks`**: not yet built. All three share `list`'s
  exact four-node skeleton (trigger → build-command Code node → Execute
  Command → format-result Code node); only the trigger's input fields and
  the build-command node differ per tool. `write` and `run-checks`'s final
  format-result node is an exact copy of `list`'s (`{ result: [$json.stdout] }`);
  `read`'s final node is the one genuine difference, decoding stdout as
  base64 first, since `ws-read.sh` returns encoded content.

**Follow-up flagged, not fixed now (2026-09-22): the task-parsing step's
hard `throw` on missing fields (`repo`/`mode`/`task`) surfaces a raw n8n
error rather than a plain, friendly message.** Acceptable today, since the
user reads n8n's own output directly — but a real, named problem once the
foreman calls this workflow on someone else's behalf: the foreman needs a
plain, parseable rejection to relay onward, not raw n8n internals. Deferred
deliberately, since fixing it now would mean guessing at a response shape
before the foreman's own calling convention exists — revisit when the
foreman is actually built.

**All five tool subworkflows built (2026-09-22)**: `list`, `read`, `write`,
`run-checks` (all sharing the corrected `{ result: [...] }` output shape),
and `discard` — the last confirmed as never a Tool under the Agent node
(the model never calls it; only deterministic workflow logic does), using
the shared "Coding Agent - Internal" credential, not `propose`'s dedicated
one, with a plain passthrough result rather than the Agent-facing wrapper
since nothing reads it that way.

**The Agent node's own "On Error" setting (`Continue (using error output)`)
was noticed and flagged as a possible simpler alternative to a separate
Error Workflow** — if Max Iterations can be treated as a same-workflow
error-output branch, `ws_id` would already be in scope normally, with no
`{{$execution.id}}` lookup file needed at all. **Not yet tested or decided
either way** — deliberately deferred until the Agent node itself is built,
rather than resolved by guessing.

**Main Agent workflow: intake through the gate built and proven live,
including three real, distinct configuration bugs found only by testing
against the actual Forgejo server — not caught by any amount of sandbox
testing, since sandbox testing had no real server to be wrong about.**

- **Steps built**: Chat Trigger → parse-task-input (Code node, plain
  line-based `key: value` parsing, no model involved) → build
  start-workspace command (Code node, branches on `mode` to include
  `branch`/`pr_number` only for `revise`) → Execute Command
  ("Coding Agent - Start Workspace" credential) → gate (IF node,
  `{{ $json.code }}` equals `0`).
- **Confirmed real chat-trigger field name**: `chatInput` (verified directly
  from a real test message, not assumed) — the parsing Code node was
  simplified once this was confirmed rather than left carrying an
  unnecessary fallback.
- **Follow-up flagged, not fixed now**: the parsing step's hard `throw` on
  missing `repo`/`mode`/`task` surfaces a raw n8n error. Fine while the user
  reads n8n directly; a real problem once the foreman calls this workflow on
  someone else's behalf and needs a plain, parseable rejection to relay
  onward instead. Deliberately deferred until the foreman's own calling
  convention exists, rather than guessing at a response shape now.
- **Real bug #1 — wrong SSH port, found via the log's own recorded
  detail, not assumed**: the clone URL used SCP-style syntax
  (`git@host:path`), which always connects on port 22 with no way to
  override inline. Port 22 and port 2222 on this host are genuinely two
  different SSH servers (confirmed via `ssh-keyscan` against both — entirely
  different software versions and host keys): 22 is the host machine's own
  system SSH, 2222 is Forgejo's embedded git-SSH service, the only one that
  has ever known this agent's key. The bare clone URL was never
  almost-correct — it targeted a server with no knowledge of the key at all.
  **Fixed** with the explicit `ssh://git@host:2222/...` form, which permits
  a port; **`-o StrictHostKeyChecking=accept-new` added at the same time**,
  for a reason beyond this one bug — the only reason the original (wrong)
  URL had gotten as far as a clean host-key rejection at all was that root's
  `known_hosts` had already been manually, interactively populated by an
  earlier proof step. Without this flag, a rebuilt CT404 would hit the exact
  same failure non-interactively, with no way to fix it short of another
  manual SSH session. `propose.sh` needed the identical flag added for
  consistency, though not the URL fix — git remembers the remote URL from
  the clone that created a workspace, so a corrected `start-workspace.sh`
  alone fixes every later push too.
- **Real bug #2 — wrong Forgejo owner/organization name.** Both scripts
  hardcoded `polaris` throughout, an assumption drawn from the project's own
  name, never verified against the real server. The actual owner is
  `lab-admin` — confirmed directly from the real Forgejo web UI's own repo
  URLs, not inferred. Fixed in `start-workspace.sh`'s clone URL and both of
  `propose.sh`'s API URLs (PR-opening and comment-posting).
- **Real bug #3 — wrong URL scheme in `propose.sh`.** Hardcoded `https`;
  Forgejo's API is actually served over plain `http` on port 3001,
  confirmed as consistent with the documentation agent's own established
  pattern before changing anything. Fixed in both API URLs.
- **A third real repo surfaced and added**: `homelab-infrastructure`, named
  by the user as needing to be reachable eventually alongside the two
  already allow-listed. Added to `start-workspace.sh`'s fixed `case`
  allow-list now, at the user's explicit request, rather than held back —
  the allow-list boundary itself (only editable by a conscious, deliberate
  edit, never expanded by a task description) is unchanged; this is simply
  that deliberate edit being made.
- **Both directions of the gate proven live against the real server after
  all three fixes**: a genuine successful clone (`Polaris-Pipeline-Testing`,
  `code: 0`, a real `task-YYYYMMDD-HHMMSS-<hex>` ID returned) and the
  original unknown-repo rejection re-confirmed still working correctly
  (`code: 2`, `REJECTED: unknown repo`) — the fixes changed nothing about
  behavior already proven correct.

**The Agent node itself, and the full deterministic success-path wrap-up,
were built and proven (2026-09-23).**

- **Memory deliberately left unwired**, confirmed with the user rather than
  assumed: one task is one execution start to finish, with no human
  turn-taking mid-task the way the documentation agent's conversational use
  requires; the ReAct loop's own internal scratchpad already covers
  reasoning across tool calls within a single execution. Recorded as
  revisitable per-agent, not a universal rule — the foreman and possibly the
  networking agent are expected to need real memory.
- **`ws_id` correctly wired as a fixed Expression** (`{{ $('Extract ws_id').item.json.ws_id }}`)
  on all four tools, confirmed via a real screenshot of n8n's own UI that
  each field carries an independent Fixed/Expression toggle — resolving the
  earlier open question cleanly. The model-driven alternative (the small
  sparkle → "Defined automatically by the model") was tested by the user
  before committing to anything, confirmed as a genuine free-text
  description box functionally equivalent to `$fromAI`, and correctly never
  applied to `ws_id`.
- **A real, generalizable n8n fact discovered by testing, not documented in
  advance**: the Execute Command (SSH) node does not merge or forward any
  fields from its input — it replaces the item entirely with its own result
  shape (`code`/`signal`/`stdout`/`stderr`). This broke the Agent's prompt
  source (`{{ $json.task }}`) the first time it was tried, since `task` had
  already been silently dropped several nodes earlier, at the
  `start-workspace` Execute Command node. Fixed by having `Extract ws_id`
  reach back explicitly to the node that still held it
  (`$('start-workspace command').item.json.task`) rather than relying on
  passthrough.
- **The chat's own final response field name, `output`, was confirmed
  empirically, not assumed** — the AI Agent node's own final answer landed
  in a field called `output` and rendered as clean text in chat, and this
  same field name was then deliberately reused for the deterministic
  wrap-up's own final response node, since n8n's chat trigger displays
  whatever the last node in the workflow outputs, with no dedicated
  "respond to chat" node existing in this setup.
- **The first real end-to-end test produced a fully correct model response**
  on the very first attempt — a properly shebanged, working `hello.sh`,
  written without needing `list`/`read` first (a reasonable judgment call
  for a brand-new, self-contained file, not a shortcut), and an accurate
  final summary matching what actually happened.

**A genuinely difficult, multi-stage debugging arc followed, worth recording
honestly, including several wrong turns before the real root cause was
found — because the eventual fix came from direct evidence-gathering, not
from further theorizing, which is the exact lesson worth preserving.**

- **First real bug, found immediately and correctly**: the "Propose command"
  Code node's output was pinned from earlier manual testing, causing every
  "fresh" chat run to silently replay a stale, already-discarded `ws_id`.
  Diagnosed correctly from first principles (an identical randomly-suffixed
  ID appearing twice is not a real possibility) and fixed by unpinning.
- **After that fix, a second, different failure appeared**: `propose`
  rejecting with "workspace not found" despite a demonstrably real,
  freshly-created workspace confirmed to exist through the same execution's
  own `write` and `run-checks` tool calls moments earlier. **Two further
  hypotheses were pursued and, through the user's own careful, methodical,
  screenshot-by-screenshot testing, both were disproven — worth recording
  precisely so they aren't re-suspected later:**
  1. *A race condition between `propose` and `discard` running in parallel
     off a wiring mistake* — investigated via real web research into n8n's
     documented concurrency behavior, which surfaced a genuinely plausible
     mechanism (unbounded node-level concurrency, `discard`'s near-instant
     `rm -rf` easily outracing `propose`'s slower multi-step git/API chain).
     **Disproven**: the node's own input dropdown already showed the
     correct single upstream source, and controlled, single-node-at-a-time
     before/mid/after testing showed no wiring anomaly at all.
  2. *A published-vs-draft version mismatch* (production chat executions
     use the last Published version, not unsaved canvas edits, per n8n's
     own documentation) — **disproven**: the workflow was confirmed already
     fully published with no pending changes.
- **The actual root cause, found only once real, direct evidence was added
  to the system itself rather than reasoned about further**: a single debug
  line inserted directly into `propose.sh` on CT404, logging the exact raw
  `SSH_ORIGINAL_COMMAND` received and the real, live contents of
  `/root/workspaces/` at that exact moment. This settled it immediately and
  unambiguously: the real workspace genuinely existed at the moment
  `propose.sh` ran — there was no race, no stale publish, no wiring fault.
  **The true bug was a simple, mundane parameter-count mismatch introduced
  across two different points in this same design conversation and never
  reconciled**: `propose.sh`'s own parsing was written expecting exactly two
  tokens (`ws_id`, then the base64 commit message) — correct, since it is a
  single-purpose dedicated script, unlike the shared dispatcher key which
  genuinely does need an operation-name token to route between five
  operations. But the "Propose command" Code node's instructions, given
  several turns earlier in this same conversation, built the string as
  `propose ${wsId} ${commitB64}` — carrying a leftover literal word
  `"propose"` that never belonged there. The practical effect: `TOKENS[0]`
  became the literal string `"propose"` (silently misread as `ws_id`), and
  the real workspace ID was misread as the commit message — so the script
  was correctly, honestly reporting that a workspace literally named
  `propose` did not exist, every single time, with total consistency. This
  was Claude's own authoring error, not an n8n quirk or an infrastructure
  fault, and it went uncaught through every earlier test because those
  tests happened to exercise `start-workspace` and the four Agent tools
  thoroughly, but this exact command-building step was never independently
  verified against `propose.sh`'s actual, real parsing logic until direct,
  on-box evidence forced the comparison.
- **The explicit lesson, worth stating plainly rather than letting it pass
  quietly**: multiple plausible-sounding theories were pursued and
  ultimately wasted real time and the user's patience, while the actual fix
  was found the moment real ground-truth logging replaced further inference
  — the same "confirm, don't assume" discipline this entire project has
  applied to the coding agent's own design, now validated at the meta level
  against Claude's own debugging process too.
- **Fix**: the leading literal `propose ` removed from the Code node's
  template string, so it sends only `${wsId} ${commitB64}`, matching
  `propose.sh`'s actual parsing exactly. The temporary debug line was
  removed from `propose.sh` immediately after the fix was confirmed.

**MILESTONE (2026-09-23): the first fully autonomous run succeeded
completely, end to end, with nothing manually touched mid-run.** A chat
message describing a task became: a real cloned workspace, a model
correctly reasoning about and writing a working file, real, honest static
checks, a real commit on a real branch, and a genuine, live pull request —
**Polaris-Pipeline-Testing PR #28**, titled `[checks passing] The file
hello.sh was created with a proper shebang, comment, and echo statement to
print the required message. All syntax checks passed.`, branch
`coding-agent-20260923-051614` into `main`, diff exactly matching the real
file written. Chat responded with `propose.sh`'s own real status line,
confirming the wrap-up worked correctly too. This is the coding agent's
equivalent of 4c's "first genuinely agent-authored change" milestone for
the documentation agent — the harness, the loop, and the full deterministic
wrap-up are now proven to work together for real, not just individually.

**Not yet built:** the Error Workflow (cap-out handling — genuinely
untested against a real Max-Iterations failure), the false-branch chat
response for a failed `start-workspace`, and any second language module
beyond the checker batch (Ansible, n8n workflow JSON) per 4g's original
growth path.

### 4h and beyond (not yet detailed)

- **Networking agent** — confirmed next after the coding agent (see
  "Decisions recorded from the 2026-09-21 session" for why the order matters).
- **The foreman itself, built last**, once there is more than one working
  sub-agent for it to actually coordinate — per the standing sequencing rule
  carried from Phase 3's original Multi-Agent Architecture Vision section.
  Owns Matrix (4d/4e) as its production interface.
- **Backup agent and a hardware-inventory agent** (the latter from the user's
  illustrative example: it discovers a new VM or hardware and prompts whether
  it should be added to backup) — neither is placed in the sequence yet.
- Additional sub-agents as they're prioritized.

## Open Items (Phase 4, as of this planning session)

- Exact container sizing/naming/CT ID for the documentation agent's execution environment and for the Matrix homeserver — deferred to build time.
- Which currently-maintained fork of the Conduit lineage to actually deploy — verify at build time, not from this document.
- n8n's real Matrix integration depth — verify at build time.
- Whether the documentation agent is the actual first proof of the Matrix channel, or something simpler takes that role instead — explicitly undecided, revisit once 4a-4c are further along.
- Exact scoping of the documentation agent's git access to existing repos (which repos, read vs. branch-and-PR-write, at what point in the build sequence) — to be defined when 4c's write path is actually built, not before it's needed.
- **4a: CT 402's own `lxc.apparmor.profile: unconfined` setting may be doing more than its originally-intended job.** It was very likely added purely to enable Docker nesting, but 4a's own finding suggests it may *also* be quietly working around the same systemd-credentials/AppArmor friction just found on CT 403. Not urgent — CT 402 works today — but worth understanding whether removing Docker-related settings from CT 402 in the future would resurface this same networking failure, so it isn't mistaken for a Docker-only setting later.
- **4g (coding agent): the remaining answers to 4g's own "open questions" list** (collector auto-discovery premise, `polaris-coding-agent`'s test-repo access, where the egress restriction is enforced, the AppArmor trade-off before rung 2) — deferred to the point in the build each one actually matters. CT 404's ID, sizing, and IP are settled (see 4g stage 1 build progress).
- **Merge-broker audit and tie-in trigger** — see Carried-Forward Open Items; must be decided before the coding agent's first PR against `Project_Polaris`.

## Change Log

- 2026-09-16/17: Phase 4 design and planning session. Grounded the plan in what Phase 1/2 already built (CT401 Ollama, CT402 n8n+Ansible, the proven AI-Agent-calls-tool pattern) and in Phase 3's binding rules (3k's no-reasoning-agent-holds-credentials rule, 3u's credential-scoping discipline). Chose the documentation agent as the first sub-agent to prove, per the existing "prove sub-agents before the foreman" sequencing rule. Researched and decided the documentation platform (Wiki.js, git-sync-backed, new dedicated repo plus scoped access to existing repos) and the remote-interaction channel (self-hosted Matrix over Tailscale only, lightweight Rust homeserver, encryption disabled, Telegram considered and set aside but not discarded). Converged into a stepped build plan (4a-4f) with the foreman explicitly deferred until multiple sub-agents exist. Carried Phase 3's still-open items forward as an explicit, non-blocking, address-opportunistically list. This document created; no build steps executed yet.
- 2026-09-17: Added an explicit standing note (Working Philosophy) restating this project's existing learning-first standard from Phases 1-3 for Phase 4 specifically, given how much of this phase (n8n internals, LLM agent structures) is genuinely new ground for the user compared to the bash/Proxmox/git work most of Phase 3 involved. No build steps executed yet.
- 2026-09-17: 4a complete. Built CT 403 (documentation-agent), unprivileged, on the AI node. Found and fixed a real, non-obvious AppArmor/systemd-credentials conflict blocking basic networking and journald on first boot — root-caused via host-side kernel audit logs rather than guessed at, fixed with the same `unconfined` setting CT 402 already carries (likely added there for Docker but probably doing double duty). Built and proved `polaris-documentation-agent` as its own Forgejo identity, end-to-end against `Polaris-Pipeline-Testing`, including correctly hitting and resolving an authorization-vs-authentication error along the way. Moving into 4b (documentation platform stand-up).
- 2026-09-17: Reviewed the actual contents of `homelab-infrastructure` and Docker01's real port/service layout before starting 4b. Reversed the earlier new-repo decision once the repo turned out to already be a mature documentation corpus rather than primarily infra-as-code — 4b now targets its existing root directly. Confirmed directly (not assumed) that Wiki.js has no draft/approval workflow at all, which settled a real design question: the documentation agent's actual editing work happens in a git branch exactly like `polaris-coding-agent`, never through a live wiki app's own UI/API. Confirmed Nginx Proxy Manager already fronts Docker01's other services.
- 2026-09-17: Second course correction the same session, this time on the platform itself — switched from Wiki.js to MkDocs. Once the no-live-editing conclusion above was reached, Wiki.js's actual remaining value (navigation and search over a git repo) no longer justified running a live app with its own database and sync-direction risk; a static site generator does the same job with no server-side state to keep consistent with git at all, and resolves the earlier open question about non-markdown files unambiguously (simply not included, rather than uncertain). 4b redesigned around a build pipeline (Forgejo webhook → n8n → SSH-delegated `mkdocs build` on Docker01 → served via the existing Nginx Proxy Manager), reusing the exact webhook mechanism already proven in 3k rather than adding a new one. Scoped 4b's actual first proof to one small, clean subset of the real content, deliberately deferring full-corpus reorganization (real disorganization found and named plainly: duplicate `architecture/`/`operations/` directory trees, several obviously duplicated files) to the documentation agent's own future work rather than hand-solving it during infrastructure stand-up. 4b not yet built.
- 2026-09-17/18: 4b stages 1 and 2 complete. Built and proved the MkDocs pipeline manually, end to end, against the real `engineering/adr/` content — a dedicated read-only deploy key, a rootless containerized build (with a real UID-mapping/HOME gotcha found and fixed along the way), a static-file nginx container joined to the correct existing Docker network, and a working Nginx Proxy Manager entry. Confirmed the build faithfully reflects only what's actually committed to `main`, not local-only content, surfacing a real future task for the documentation agent. Found and fixed a genuine DNS gap unrelated to anything built so far (no wildcard for `.polaris.home.arpa`; every hostname needs its own explicit pfSense DNS Resolver Host Override) — this generalizes to any future hostname on this network. Deliberately left the site's homepage (a 403 with no `index.md` present) as a known gap, earmarked as the documentation agent's own first real proof-of-concept task once 4c exists. Moving into stage 3 (Forgejo webhook → automatic rebuild).
- 2026-09-18: 4b stage 3, steps 1-3 complete. Built the dedicated `polaris-mkdocs-rebuild` identity (Linux account, git clone, rebuild script) as a third, separate role distinct from both the documentation agent's own identity and n8n as the caller, matching 3k's three-way split. Hit and resolved four real, concrete problems in sequence: a deploy key unreachable across two accounts' home directories, a Docker bind-mount auto-creation gotcha (always root-owned regardless of the consuming container's own `--user`), a stale/disconnected mount path from an earlier stage, and a `.pub`-vs-private-key mixup. Fully re-verified end to end afterward. Added a standing process rule to Working Philosophy: every multi-account command sequence must label which account each block runs under explicitly, rather than relying on context carrying over between turns — a real gap in this session's own explanations, not a user error, caused two of the confusions in this round. Remaining: step 4 (forced-command SSH restriction) and step 5 (the actual n8n webhook workflow).
- 2026-09-18: 4b stage 3 step 5 complete — the Forgejo webhook → n8n workflow (signature verification, branch check, forced-command SSH rebuild), built and proven end to end including a genuine unattended push with zero manual triggering. **4b is now fully complete.** Partway through this step, adopted a stricter one-instruction-at-a-time build format after direct feedback that earlier steps mixed too much explanation and too many steps into single responses; the remainder of step 5 was built this way and went cleanly, now adopted as the default for comparable future work rather than a one-time correction. Moving into 4c (the documentation agent's actual reasoning layer).
- 2026-09-18/19: Deliberate detour to select the AI host's actual model, rather than defaulting to Phase 2's `qwen2.5:14b-instruct` untested against alternatives. Real, empirical three-part methodology (raw throughput/VRAM via `ollama ps`, tool-calling reliability via direct API tests with both should-call and should-not-call cases, and a coding-correctness test deliberately modified to defeat memorized-solution pattern-matching). Confirmed `qwen3.6:27b` unusable (VRAM overflow), found real reliability red flags in `llama3.1:8b` and hand-verified genuine, self-test-invisible bugs in both dedicated coding models (`qwen2.5-coder:14b`, `deepseek-coder-v2:16b`) on the harder test. `gpt-oss:20b` won or tied every test in the series. **Decided: `gpt-oss:20b` as the general-purpose model for every text-based agent in this phase, `qwen3:14b` as a genuine backup, `qwen3-vl:8b` for vision, no dedicated coding-specialist model.** 4c's reasoning layer now specified against this decision rather than an untested default.
- 2026-09-19: Built and proved the documentation agent's read-only tool set (4c), the first real agent-plus-tools interaction in this phase. Real chain of findings, each caught and fixed rather than papered over: n8n has no native Gitea/Forgejo credential type (Header Auth, copied from the existing 3k pattern, is correct); a single overloaded tool trying to handle both root-listing and specific-path-reading failed three different ways before being split into two single-purpose tools; a genuine Forgejo routing distinction between `/contents` and `/contents/{filepath}`; a credential typo that was indistinguishable from the routing bug because Forgejo returns a generic 404 for both a bad path and a failed auth against a private repo; a UI misclick that let a tool's URL field go model-defined with no guidance, producing a fabricated GitHub API call; a default 2048-token context window too small for a multi-tool agentic loop, raised to 8192 with VRAM headroom confirmed directly. Most significantly: caught the model confidently fabricating a detailed, specific, entirely wrong description of real repository content after the plumbing was already fixed - ruled out memory/session leakage and system-prompt leakage directly, diagnosed as confident template-completion, and fixed via an explicit anti-fabrication system message, which then had to be balanced against its own overcorrection (a correct-data non-answer) with two further rules. Final test: a real multi-part question answered completely and accurately with no redundant calls. Write path (branch/PR) not yet built.
- 2026-09-19: Found and fully, structurally fixed a serious base64-content fabrication problem in the documentation agent's read-only tools - the model confidently invented an entire fictional architecture document (Terraform, Pulumi, HashiCorp Vault, none of which exist in the real repo) when asked to read a real, populated file, despite the tool delivering the exact correct base64 data. Independently decoded the same content in plain Python to establish ground truth before diagnosing. Root-caused to base64 decoding being a near-universal LLM weak point (tokenization, not a model-specific flaw) and fixed architecturally rather than via prompting: built a standalone, reusable `Base64 Decode` utility workflow and rebuilt `Read File or Directory` as a proper sub-workflow (HTTP call -> deterministic decode-or-passthrough -> merge) that never exposes raw base64 to the model at all. Hit and fixed two real, non-obvious n8n bugs along the way (Code node return-shape mismatch between its two "run once" modes; the HTTP Request node silently splitting a JSON array response into multiple items, which combined with `$input.item` usage silently dropped 8 of 9 real directory entries with no error). Verified the new Call n8n Workflow Tool integration end-to-end after removing the old, now-redundant HTTP Request Tool entirely - the final answer matched an independent ground-truth decode exactly, including highly specific details unlikely to survive fabrication. This closes out the base64 fabrication problem completely and proves the sub-workflow pattern through the real agent, not just in isolation.
- 2026-09-20: Built and proved the third read-only tool, `Search Files by Name`. Checked whether Forgejo's own code-search feature could shortcut this before building anything - not confirmed to have a clean JSON API or to be enabled on this instance, so not trusted without a positive test. Found the Git Trees API (`/git/trees/{ref}?recursive=true`) instead - a well-documented, GitHub-equivalent endpoint returning the entire 254-entry repository file tree in one call, confirmed complete via `total_count`/`truncated: false`. Built filename search as a cheap, deterministic filter over that one fetch. Hit a real node-reference typo bug (case-sensitive exact match on node names) and a real, worth-keeping design fork (full-path vs. filename-only matching) surfaced by the first live test rather than assumed in advance. Proven chained with `Read File or Directory` in one real multi-tool request, independently confirmed via raw tool output, including a genuine repeat with a properly reset session. Content search (the fourth tool) is next - same file-tree foundation, but requires fetching and decoding every candidate file's real content rather than just filtering metadata, a meaningfully heavier operation worth designing deliberately.
- 2026-09-20: Paused before building content search once planning it surfaced a larger, real goal (find-by-description, judge and fix bad naming/organization) that structurally depends on the write path existing first. Re-sequenced deliberately rather than building a narrower version now and reworking it later: write path next, then content search via a real local grep (reusing the write path's own clone mechanism, better than looping the Git Trees API), then the reasoning layer for reorganization, then extending everything to `Project_Polaris` as its own explicit step. Confirmed `polaris-documentation-agent`'s git access genuinely extends to `homelab-infrastructure`, clarifying along the way that this identity is a credential only, not a Linux account - unlike Docker01's `polaris-mkdocs-rebuild`, which is a real login for a different, shared-host reason. Moving into building the write path.
- 2026-09-20: Designed and fully manually proved the write path's git-level mechanics, before any n8n wiring. Found CT403 had never actually been connected to n8n over SSH despite existing since 4a - every prior tool used direct API calls only. A real mechanism discovery (the SSH node's File/Upload mode) improved the original plan: actual document content now travels as a real file upload, not base64 inside a command string, with base64 reserved for the short metadata (path, commit message) that still passes through the command line. Built and hand-tested `write-doc.sh` on CT403 end to end - hit and correctly diagnosed a real permission gap (read-only collaborator access rejecting the push) and fixed it the scoped-right way (branch protection mirroring `Project_Polaris`, not a blanket write grant), then proved the full clone/branch/write/commit/push/delete sequence successfully. Deliberately deferred proving the PR-open step itself, since no approval infrastructure exists yet to act on it. Remaining: the actual n8n SSH credential, applying the forced-command restriction, and the file-upload/PR-creation wiring.
- 2026-09-20: Wired the write path's git-level mechanics into a real n8n sub-workflow (`Propose Documentation Change`) and proved it fully end to end, from mock trigger data through a real, correctly-protected pull request. Found and fixed three genuinely new problems invisible at the manual-proof stage: a forced command and SFTP are structurally incompatible on one key (fixed with a third, `internal-sftp`-restricted key dedicated to uploads only); n8n's SSH Command node silently prepends `cd <working-directory> ;` to every command it sends, found only via a temporary debug line echoing the raw received text rather than further reasoning about already-verified pieces; and Forgejo's collaborator role and a token's own API scope are two separate, independently-enforced permissions, with only the first having been fixed earlier. Final proof (PR #1) independently confirmed the safety design itself, not just the mechanics - branch protection correctly blocked an unreviewed merge, with the same admin-bypass path from 3k available. Closed and cleaned up as a mechanical test. Remaining: wiring this sub-workflow as a real tool on the AI Agent, so the agent's own reasoning - not mock JSON - decides what to write.
- 2026-09-20: Wired `Propose Documentation Change` as a real tool on the AI Agent and immediately found a genuine, still-open reasoning limitation, distinct from every plumbing issue fixed earlier tonight. An open-ended "investigate and author new content" task (deliberately the exact homepage task 4b left earmarked for this agent) failed three consecutive times with the same shape: redundant identical tool calls, the actually-named folder never inspected, then a disengaged generic non-answer. Tested and disproved a rules-conflict hypothesis (added an explicit rule distinguishing anti-fabrication from expected original authorship; failed identically anyway). Isolated the tool mechanism itself as fully reliable by stripping investigation and authorship out entirely - a fully-specified "write this exact content to this exact path" instruction succeeded completely and immediately, confirmed via a real PR. This cleanly separates a fully-proven mechanism from a genuinely unresolved reasoning gap: whether open-ended investigation, self-authored content, or specifically their combination is the real trigger remains unknown, with the next isolation test (fixed path/message, agent authors the content) already agreed and pending. Continuing in the same session by deliberate choice, to avoid losing context in this active investigation.
- 2026-09-20: Resolved the open-ended reasoning-gap investigation - root cause was context overflow (`completionTokens: 0`), the same category of bug fixed once already in 4c, recurring at a larger scale once a fourth tool's schema and larger tool outputs pushed prompts past 8192 tokens. Found and fixed a second, unrelated bug along the way (a tool name containing stray punctuation, breaking JSON tool-call generation) and a second real fabrication issue (a generic ADR template invented without reading real files), fixed with an explicit two-file-minimum rule and a topic-based system message reorganization. Raised context to 65536 with VRAM/GPU headroom confirmed safe throughout. **Achieved the first real, user-approved, agent-authored merge into `homelab-infrastructure`** - the `engineering/adr/` homepage 4b had left deliberately unbuilt - confirmed via the 4b webhook firing and the live MkDocs site updating, proving the complete reason-investigate-author-propose-approve-merge-rebuild loop end to end for the first time. Discussed and deliberately deferred two forward-looking design questions: revising an already-open PR (confirmed unsupported today for two specific, concrete reasons) and whether the Memory connector could substitute for it (a precise, generalizable answer emerged - memory's value depends on whether the context has an authoritative record outside the conversation, not on which agent role holds it), with a forward note that the foreman's own future decision history likely needs this same runbook's externalized-record discipline rather than relying on conversational memory alone.
- 2026-09-20: Built and proved the fourth read-only tool, `Search File Content` (step 3 of the revised write-path-first order), via a real local `grep` against a fresh CT403 clone rather than looping the Git Trees API. Third distinct forced-command SSH key on CT403, this one requiring a deliberate `set -e` omission (grep's own zero-match exit code is normal, not an error). One anticipated bug (the `cd ; ` prefix, already known from the write path) was fixed proactively; a genuinely new variant of the same category was found via the same debug-line technique (multiple spaces after the semicolon breaking the existing single-space stripping pattern, silently producing an empty search term and, via grep's empty-pattern behavior, a near-complete repository dump disguised as a plausible result). Fully proven standalone and through the real agent on the exact real-world scenario that motivated building it - a WS01 IP-address lookup, independently verified correct against the tool's own raw output. Content search (step 3) is complete; moving into step 4 (the reasoning layer for find-by-description and reorganization judgment).
- 2026-09-20/21: Completed step 4 - find-by-description (confirmed to need no new tool, via a real adaptive test), and a genuinely new rename/move mechanism (`rename-doc.sh`, git mv, a third forced-command SSH identity on CT403). Applied a realization from comparing all three CT403 scripts: `read -ra`'s natural whitespace-collapsing (not an explicit fix) is why `write-doc.sh` never needed the strip step `search-content.sh` did, and built the rename script to use that same parsing style proactively. Found and fixed a real, load-bearing gap during the first true find-judge-act test: an unhandled raw n8n error on one tool crashed the agent's reasoning path and burned its remaining iterations on poor recovery, fixed by adding explicit error-output handling (a clean, consistent result shape instead of a raw stack trace) and raising the iteration cap from 10 to 20 for a concrete, observed reason. Final clean-session re-test succeeded completely: correct investigation, a correct rename call, a real PR. Recorded two honest findings rather than only the success - naming judgment proved consistent across three runs, folder-placement judgment did not, and the investigation itself surfaced a real duplicate file outside this task's own scope, a good candidate for future reorganization work. Step 4 complete; step 5 (extending everything to `Project_Polaris`) remains.
- 2026-09-21: Completed step 5 - extended full tool parity (read, search-by-name, search-content, propose, rename) to `Project_Polaris`, closing out the revised five-step order in full. Confirmed Forgejo API tokens are scoped by category not by repo, so only the write-side SSH identities needed duplicating; parameterized the four read/search tools instead of duplicating them, since none can write regardless of target repo. Found and fixed a genuinely new bug category: the model's own generated output (not n8n's infrastructure) can contain stray whitespace inside otherwise-correct values, requiring defensive trimming added to all five CT403 scripts and the HTTP-based read tools. A more serious instance of the same bug, combined with an internal implementation detail (`BRANCH_NAME`) leaking into an error message, caused the model to misdiagnose the failure and corrupt its own retry - fixed by rewriting every write/rename sub-workflow's error handling to describe the likely problem in plain terms rather than exposing internals, extending step 4's "never leak raw internals to the model" principle to the write path. Also found and fixed a real node-naming collision risk (two identically-named SSH nodes in each write sub-workflow) and adopted a new standing habit: rename every node distinctly at creation time. Found and permanently fixed a systemic infrastructure gap (`default_delete_branch_after_merge: false` on both repos since the project began) rather than continuing to manually clean up its symptoms. Noted one genuine, unresolved anomaly - CLI-deleted branches reappearing on at least three occasions, resolved via UI-based deletion instead, without a fully confirmed root cause. This entry is written as a standalone architectural reference (full credential/tool inventory tables included) given the volume of infrastructure now in place, not just a narrative.
- 2026-09-21: Coding agent design session (4g). Recorded, from the session's resume brief, three decisions that had lived only there: Matrix (4d/4e) reassigned to the foreman (n8n's chat panel is the documentation agent's permanent debug interface, not a placeholder), the confirmed build order (coding, then networking, then foreman, reversible-work-first), and the principle that every agent gets equal design scrutiny. Settled the coding agent's ultimate scope (all coding work for the homelab, modular, start narrow) and a new standing rule: it authors and tests in isolation, never holds real-target credentials, never deploys; delivery is tested code via PR, merged by the broker (Tier 1) or the user (Tier 2), then rolled out by the owning domain agent or the user. Found that Phase 3's Multi-Agent Vision text ("foreman directs the coding agent to merge") predates and contradicts 3k's own later corrections; this runbook's delivery model supersedes it and the Phase 3 paragraph needs a one-line annotation. Design choices agreed: whole-file replacement over diffs, a per-task workspace (instead of one-shot writes) on its own container so the agent can test and self-correct, three guardrails specific to a self-correction loop (bounded attempts, deterministic re-run of checks reported by the pipeline not the model, checker configuration outside the agent's reach), an execution ladder starting at static checks only, complete independence from the documentation agent's tools/credentials/container, a fresh SSH key on a new CT 404 with the old CT 402 key retired, PR revision scheduled early, and the task interface treated as the foreman's future contract. The merge-broker was re-scoped as its own tracked item (holistic status audit, decision trigger before the first PR against `Project_Polaris`). Added a Working Philosophy note that non-linear ideas and outside connections are welcome provided their security is considered alongside their usefulness; the first concrete instance (toolchain install versus runtime egress) is recorded as a proposal, not a decision. Also refreshed this document's stale header status. No build steps executed.
- 2026-09-21 (later): Started the coding agent's build (4g stage 1). Adopted a refinement to the working format at the user's request: grouped instructions are fine when each group states what it is for, which account runs it, and which box it runs on, with a new group at every host/account switch and a stop wherever a result decides the next step. Created CT 404 `coding-agent` (192.168.10.203, unprivileged, 2 cores/4096MB/32GB), mirroring CT 403's real config, with the IP verified via ICMP, ARP, and the user's own confirmation, and with the AppArmor `unconfined` setting applied before first boot so 4a's networking failure was avoided rather than rediscovered; first boot verified clean. A DNS check initially looked like a CT 404 defect but proved identical on CT 403: the AI node resolves through `192.168.30.2`, not pfSense, so `.polaris.home.arpa` names don't resolve from any AI-node container — recorded as a per-node fact, resolved by continuing to use Forgejo by IP rather than adding a per-container override. Confirmed Forgejo's SSH port is reachable from CT 404. Moved the toolchain-install-versus-runtime-egress proposal from proposed to agreed in principle, with enforcement mechanics left open. Base setup inside the container is next.
- 2026-09-21 (later still): Completed base setup on CT404 (locale fixed per the Phase 2 precedent, `LANG`-only not `LC_ALL`; timezone left UTC; `apt-get update` proved clean, closing the IPv6-only-answer concern) and installed stage-1 toolchain (`git`, `openssh-client`, `shellcheck`; `openssh-server` deliberately deferred until CT404's own inbound access design). Generated `polaris-coding-agent`'s fresh key directly on CT404 and fully retired the old CT402 key: identified it by fingerprint before deleting anything (three independent reads matched), removed it from the Forgejo account, deleted both files from CT402's `~/.ssh/` by exact name, and confirmed no orphaned n8n credential exists. Confirmed `polaris-coding-agent` was already a Write collaborator on `Polaris-Pipeline-Testing` from 3k, so no access change was needed. Bot-hygiene item (org creation, placeholder email) remains open, tracked separately, untouched by this key swap. Next: prove the new key actually authenticates to Forgejo from CT404.
- 2026-09-21 (later still): Proved CT404's new key against Forgejo for the first time — clean authentication, host key trusted on first connect, no re-challenge of the earlier `ssh-keygen -Y sign` first-use verification (that flow gates the "Verified" UI badge on initial key addition, not every subsequent connection). Closed Phase 3's open bot-hygiene item across all three agent accounts, not just `polaris-coding-agent` as originally scoped: turning it off surfaced that `polaris-coding-agent`'s email had its own typo and `polaris-merge-broker` was on a different domain entirely (`@homelab.local`) rather than merely inconsistent, both previously unknown. All three now share "Can create organizations" unchecked and `@polaris.homelab` addresses; a minor, non-security local-part naming inconsistency (compressed vs. full account name) was noted but left as-is. CT404's identity work is complete end to end. Next: design the workspace tools (start/write/check/propose/discard) before any building begins on them.
- 2026-09-21 (later still): Settled the coding agent's workspace-tools design in full conversation, before any building. Confirmed task flow (clone, scope via list/read, write, check-and-fix loop bounded by a cap separate from n8n's own, propose regardless of cap outcome with real reasoning embedded, immediate discard — long-lived until-merge workspaces deliberately rejected as an ownerless-lifetime risk, same shape 3u already fixed once). Resolved the "affected files elsewhere in the repo" question as already solved by cloning the whole repo up front, needing only a scoping choice for checks (default: changed files; explicit, visible opt-in for more) rather than a new mechanism. Settled propose-at-cap precisely: still opens a PR with real check output and an explicit "still failing after N attempts" flag, distinct from a more fundamental failure with nothing committable, which stays a plain report with no PR. Landed the credential design at three keys, split strictly on whether an operation ever leaves CT404 (dedicated keys for start-workspace and propose; one shared dispatcher key for list/read/write/run-checks/discard, none of which can reach the network) — and designed the dispatcher concept needed to make one key serve four operations. Considered and declined short-lived/expiring credentials for now (recorded as a future item tied to a homelab-node CA/PKI structure that doesn't yet exist on the AI node). Captured, deliberately without resolving, a broader outcome-routing question (infeasible-requirements and scope-beyond-this-file cases eventually wanting a path other than a PR, likely coding agent → foreman → Matrix → user) since it depends on the not-yet-built foreman. Adopted a new standing principle after noticing the framing recur across sessions: design for the whole three-node homelab and treat Forgejo as this agent's proving ground, not its boundary — a throwaway container or VM built purely to prove a concept is an accepted cost of that approach. Next: the dispatcher script's actual internal structure.
- 2026-09-21 (later still): Settled the dispatcher script's design in full. Parsing: n8n's `cd ; ` prefix stripped, then `read -ra` tokenizes (matching `write-doc.sh`/`rename-doc.sh`'s existing whitespace-between-tokens handling, deliberately not repeating `search-content.sh`'s fixed-single-space bug), each token separately trimmed on both ends only, operation name checked against an allow-list, workspace ID validated against its exact generation pattern before touching any path (closing the same escape risk the absolute-path/`..` check already closes one level down), existence confirmed, then dispatch. Resolved a real tension between hiding internal errors from the model and preserving its ability to self-correct: settled on splitting by exit code specifically, not by inspecting error text — exit `2` is a script's own deliberate, already-safe rejection message, passed through to the agent unchanged (this is the agent's own debugging of its own code, and needs full information); any other nonzero exit is a genuine unexpected crash, flattened to one generic message for the agent while the real text is logged to a fixed file exclusively for the user's own troubleshooting of the agent's structure, a path the agent itself never has. Reconfirmed `run-checks` sits outside this split entirely, since checker findings are normal product data, not failure. Adopted explicit terminology, at the user's request, distinguishing "the agent debugging its own code" from "the user troubleshooting the agent's structure" for the remainder of this design work, since the two were at real risk of being conflated. Next: workspace root path, log directory, and the actual `ws-*.sh` scripts.
- 2026-09-22: Confirmed workspace root (`/root/workspaces`) and log path (`/root/logs/coding-agent-dispatcher.log`). Before treating any of the seven designed scripts as ready, ran a real verification pass rather than a visual review: placed them at their real intended path, checked with `bash -n` and a real `shellcheck`, then exercised every script functionally, including every rejection path and the dispatcher's exit-code split. Found and fixed two real, concrete bugs in `ws-run-checks.sh` that would have silently inverted its purpose — `set -eu` treating a checker's own normal non-zero exit (real findings, the expected case) as a harness crash, and `grep -v '^$'` aborting the whole script on a workspace with zero changes — both proven fixed against the exact cases that broke. All other scripts passed as designed with no changes needed; `ws-discard.sh`'s belt-and-suspenders path check fired for real during testing on a malformed path, confirming it earns its keep. Next: design `start-workspace.sh` and `propose.sh`.
- 2026-09-22 (later): Designed and verified `start-workspace.sh` and `propose.sh`. Repo access is a fixed allow-list in `start-workspace.sh`, the same deliberate-boundary pattern the dispatcher uses for operations. Found and fixed a real design gap before building anything: the repo a workspace belongs to must not be re-suppliable per call, so it's bound once at clone time into a sibling `<id>.meta` file (not a child of the workspace, since anything inside the workspace is subject to `run-checks.sh`'s own `git add -A` and would otherwise leak into a real PR) and read back by `propose.sh`, dropping a parameter entirely rather than merely adding a safeguard. Proved the mechanism against a local stand-in remote: meta file confirmed invisible to `list`/`git status` alike, and `ws-discard.sh` updated and confirmed to clean up both the workspace and its meta file, closing an orphan-file leak the sibling design would otherwise have introduced. `propose.sh`'s rejection paths and real success path both confirmed against the test remote. A real finding fell out of that same test rather than being guessed at: `shellcheck`'s default severity flags a missing shebang as an error, so most unshebanged agent output will read "checks still failing" — deliberately left unresolved until the agent's task-facing instructions are designed, so the fix is shaped by real need. Gave instructions for generating and storing `polaris-coding-agent`'s Forgejo API token, deliberately keeping the token itself out of this conversation and this document — completion not yet confirmed. Remaining: the update-existing-branch mode for PR revision.
- 2026-09-22 (later still): Finalized `start-workspace.sh` and `propose.sh`, correcting two real bugs the first draft had — neither script was actually parsing `$SSH_ORIGINAL_COMMAND` (fixed by moving that logic into a shared `ws-common.sh` helper used by all three real SSH entry points), and a command substitution failing while building another command's argument (a missing `jq` binary inside an inline `-d "$(jq ...)"`) was not being caught by `set -e` at all, silently producing a broken payload — fixed via explicit upfront prerequisite checks and guarding payload construction as its own checked assignment before it ever reaches `run_or_log`. Generalized the dispatcher's exit-code error discipline (`run_or_log`) to these two scripts as well, since neither sits behind the dispatcher's relay. Designed and proved PR-revision mode end to end against a local stand-in remote (branch-name and remote-existence validation, a real second commit landing on an existing branch with no duplicate PR), and found+fixed a third real case: calling `propose` twice with nothing new to commit now rejects plainly instead of crashing generically. Settled, per explicit instruction, that revision pushes always post a visible PR comment with real check output — nothing silent. Confirmed the Forgejo API token setup complete. Then executed the real build for the first time: generated three dedicated keypairs directly on CT404, wired `authorized_keys` with the correct forced-command and restriction flags for each, handed private keys to n8n as three separate credentials (kept out of this document throughout), and transferred all nine finalized, sandbox-tested scripts to `/root/bin` — file sizes and permissions confirmed to match exactly. Proved the forced-command restriction live, twice: once before the scripts existed (proving the override itself worked, via a "no such file" result), and once after transfer, reaching each script's real logic — including catching a genuine, previously-unknown gap (`jq`/`curl` never installed on CT404) via the new prerequisite check, then confirming the fix. This closes out 4g's core workspace-tools build: all nine scripts exist, are wired to proven restricted keys, and have been exercised through real, adversarial SSH input. Remaining: the agent's task-facing instructions (which will also resolve the open shebang question) and any future language module.
- 2026-09-22 (later still): Settled the coding agent's task-facing design in full, before writing any n8n nodes. Chose workflow-enforced propose timing over model-initiated (extending the project's standing refusal to trust a model's own self-report to the loop's stop condition itself), reducing the model's own tool surface to four operations with `start-workspace`/`propose`/`discard` all deterministic and outside its reach. Recorded, as a general standing principle meant to apply beyond this one agent, that model choice should always fit the job rather than the reverse, with the AI node's ~24B-parameter ceiling as the only hard constraint and `gpt-oss:20b` an unfixed current pick. Resolved a three-way language-freedom question: adopted preloading checkers (not full toolchains) for common languages, adopted telling the model to recommend missing tools rather than guess, and explicitly declined live self-install via apt-get as a direct extension of the earlier build-time-toolchain/restricted-runtime-egress decision, preserving the underlying want via the model's own final summary surfacing real gaps for fast, deliberate, human-triggered installs instead. Designed and rigorously tested a five-checker batch (bash, Python, JSON, C++, HTML), catching two real, concrete bugs in the process — flake8's bare command not existing on PATH, and cppcheck's default `--enable=all` flagging valid standard-library includes as failures, which would have permanently broken every correct C++ file — and resolving one genuine ambiguity (tidy's fragment warnings) by prompt rather than by mechanism, the same pattern as the earlier shebang question. Proved the full batch together against one real mixed-language changeset, confirming exit-code isolation held across all five checkers plus the unsupported-type fallback. Finalized the system prompt, adding a "TASK CONCERN" rule that gives the previously-deferred outcome-routing question real value today with no new infrastructure. Recorded two open items for later (dynamic attempt-count context; a not-yet-a-problem SSH command-length ceiling on very large writes). Real installation of the three new checker packages and redeployment of `ws-run-checks.sh` on the actual CT404 has been instructed but not yet confirmed. Next: the actual n8n loop nodes.
- 2026-09-22 (later still): Began the actual n8n build, grounded directly in the documentation agent's real, working workflow (examined via screenshots) rather than assumptions about n8n's node behavior. Found a real, confirmed gap (not a design error): the Agent node errors out and halts entirely on hitting Max Iterations rather than handing control back, which would silently break the standing "always propose at the cap" rule — fixed via n8n's built-in Error Workflow feature, with the cap-out summary deliberately grounded in real current workspace state rather than conversation memory, sidestepping an unresolved question about what an Error Workflow trigger actually receives. Found and corrected two real mistakes in Claude's own earlier guesses by examining actual working nodes: the tool output shape (must be `{ result: [...] }`, not `{ output: ... }`) and, more importantly, that `ws_id` must never be a `$fromAI` field on any tool — it is now designed to be captured once after `start-workspace` and referenced by a fixed expression on every tool call, never re-supplied by the model. Found and deliberately declined (for now) a real, already-working fallback for the deferred SSH-command-length concern: the documentation agent's own SFTP-staging pattern, recorded for future use rather than adopted preemptively. Finalized both the tool descriptions and the system prompt in the documentation agent's own proven phrasing/structure conventions rather than independently drafted wording. Set Max Iterations to 12, reasoned from the write→check→fix cycle's higher per-attempt cost rather than copied from the documentation agent's 20. Built and corrected the `list` tool subworkflow; laid out the exact, mostly-shared structure for `read`, `write`, and `run-checks` still to be built. Next: build the remaining three tool subworkflows, then the main Agent workflow and Error Workflow.
- 2026-09-22 (later still): Built all five tool subworkflows (list, read, write, run-checks, discard), confirming discard uses the shared internal credential rather than propose's dedicated one and is never wired as an Agent-facing Tool. Built the main Agent workflow's intake-through-gate section and tested it live against the real Forgejo server for the first time — surfacing three genuine configuration bugs invisible to any amount of sandbox testing, since sandbox testing had no real external server to be wrong about: an SCP-style clone URL silently targeting the wrong SSH server entirely (port 22, the host's own system SSH, rather than port 2222, Forgejo's actual git-SSH service — two different servers with different host keys, confirmed via ssh-keyscan), a hardcoded Forgejo owner name (`polaris`, an unverified assumption) that should have been `lab-admin` (confirmed directly from Forgejo's own UI), and a hardcoded `https` scheme in propose.sh's API calls where Forgejo actually serves plain `http`. Fixed all three directly on CT404, and added `-o StrictHostKeyChecking=accept-new` so a rebuilt CT404 never again depends on a prior manual trust step. Added a third real repo, `homelab-infrastructure`, to the allow-list at the user's explicit request. Re-proved both the success and rejection paths through the gate live, confirming the fixes changed nothing about already-correct behavior. Flagged (not fixed) that the parsing step's hard-error behavior will need friendlier handling once the foreman calls this workflow directly. Noted the Agent node's own error-output option as a possible simpler alternative to a separate Error Workflow, deliberately left untested until that node is actually built. Next: extract ws_id, then build the Agent node itself.
- 2026-09-23: MILESTONE — the coding agent's first fully autonomous chat-to-PR run succeeded completely, end to end. Built and proved the Agent node itself (Memory deliberately left unwired, per-agent decision confirmed with the user; ws_id correctly wired as a fixed Expression on all four tools, confirmed against real n8n UI rather than assumed) and the full deterministic success-path wrap-up (propose, discard, chat response). Found and fixed a real, generalizable n8n behavior along the way: Execute Command nodes replace their item entirely rather than merging fields, which silently broke the Agent's prompt source and was fixed by reaching back to an earlier node directly. Then debugged a difficult, multi-stage failure the hard way: two real hypotheses (a propose/discard race condition, informed by genuine web research into n8n's documented concurrency behavior; a published-vs-draft version mismatch) were both raised and both disproven through the user's own careful, methodical testing, before the actual root cause was found by adding real debug logging directly to propose.sh on CT404 rather than continuing to theorize — a simple, mundane parameter-count mismatch between propose.sh's own parsing (expecting exactly ws_id + commit message, no operation-name token, unlike the shared dispatcher key) and a Code node template written several turns earlier that still prepended a leftover literal "propose" token. This was Claude's own authoring error, recorded honestly, with the explicit lesson that real ground-truth evidence resolved in one step what extended inference could not. Fixed with a one-line change; the temporary debug logging was added and then removed once confirmed. The result: a genuine, live pull request (Polaris-Pipeline-Testing PR #28) opened entirely autonomously from a single chat message, with the full loop, checks, and deterministic wrap-up all working correctly together for the first time. Remaining: the Error Workflow (still genuinely untested against a real cap-out), the false-branch chat response, and any future language module.
- 2026-09-23 (later): Built and confirmed the false-branch chat response for a rejected `start-workspace` call (a small Code node passing the rejection's own real message through as `output`, with no `discard` call needed since no workspace was ever created) — tested live with a deliberately invalid repo name, confirmed clean. Began the deliberately-harder multi-cycle test the user requested (a real, honestly-scoped `inventory.py` task, not an engineered trick, per explicit instruction that real tasks never contain intentional traps and testing shouldn't either), which surfaced a new, real failure: a malformed JSON tool call from the model on a large, complex file killed the Agent node outright under n8n's default `Stop Workflow` error setting. Used this as the natural trigger to finally test the long-deferred `Continue (using error output)` alternative to a separate Error Workflow. Re-running the same task under that setting surfaced the true root cause: `context_length` on the Ollama Chat Model node was left at a small default, and the run's real token count (~8,530, later runs even higher) silently exceeded it — confirmed via real, cited research that Ollama truncates context with no error or warning, and confirmed independently by the user's own prior, direct experience fixing the identical symptom (repeated tool calls, apparent non-convergence, eventual cap-out) on the documentation agent the same way. Recorded as a new cross-agent Standing Principle: `num_ctx` must be explicitly and generously set on every reasoning agent's Chat Model node, never left at a node default, with `ollama ps` as the way to confirm the real, applied value rather than assuming. Next: set context length to a real, generous value (~80,000, pending VRAM confirmation via `ollama ps`) and re-run the same `inventory.py` task to confirm this was the true root cause.
- 2026-09-23 (later still): Set the Ollama Chat Model node's context length to 80,000 and confirmed it actually applied — `ollama ps` showed 12 of 17 GB VRAM used, 100% GPU utilization, no CPU spillover, real headroom remaining. Re-ran the exact same `inventory.py` multi-cycle test under the new context length: **the cap-length theory was cleanly ruled out, not just left unconfirmed** — the run still hit Max Iterations (12) at only ~8,000 of the 80,000-token budget, nowhere near truncation. This is recorded as a genuine, valuable negative result: it eliminates one real hypothesis with certainty, and the 80,000 setting is correctly kept regardless (it fixed a real, previously-confirmed identical problem on the documentation agent, and removes a real risk factor for future, longer tasks even though it wasn't the cause here). New evidence gathered from the real cap-out, pointing at a different, more specific puzzle: the model's own final reasoning at iteration 12 was coherent and specific, not garbled or repetitive ("Need to fix flake8 line length >79. Lines near 68, 84, 94. Let's open around those lines."); two consecutive `write` calls produced genuinely different byte counts (4,691 vs 4,590), proving real edits were happening, not a stalled no-op loop; yet the same three line numbers were still being cited as unresolved at the very last iteration. Two candidate explanations were laid out, not yet distinguished: (A) genuine incremental progress on three independent issues that simply needed more than 12 iterations to fully converge, fixable by nudging the prompt to address all reported issues in one edit rather than iteratively; or (B) a deeper reliability problem with whole-file regeneration itself — a model struggling to faithfully reproduce a large, mostly-unchanged file while reliably landing one small, precise correction each time, which would revisit the earlier whole-file-over-diffs tradeoff (chosen specifically to avoid diff line-arithmetic unreliability) and suggest it may trade that risk for a different one at larger file sizes. The concrete next diagnostic step, not yet performed: compare the actual `write` content at the three specific flagged lines across two or three consecutive iterations of this same run's history, to determine directly whether the underlying text at those lines was genuinely still too long each time, or whether the coincidence is in the line numbers themselves (shifted by unrelated edits above them) while real, different problems were actually being fixed. Session paused here on a practical constraint (this chat's image-upload limit), not a design blocker — a full turnover prompt was written for continuation in a fresh session.
