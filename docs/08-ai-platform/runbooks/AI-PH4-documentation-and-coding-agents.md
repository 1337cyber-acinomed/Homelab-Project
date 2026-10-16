# Phase 4g Runbook: Coding Agent (CT404)

**Status:** Core pipeline built and validated (new + revise flows working end to end). CT404 isolation hardened. Execution-based verification (real `run` tool) **built and empirically validated this session** — real-code-execution sandbox, `../../` traversal permission, `.git` lockout, and both success/cap-out PR-labeling paths all confirmed against live runs. Readiness call made: proceed to building the foreman agent now; remaining known issues are model-behavior limits, not wiring defects (see "Readiness Assessment" below).
**Primary host:** CT 404 "coding-agent-sandbox" — dedicated Proxmox LXC, unprivileged, `192.168.10.203/24`
**Related:** `n8n` orchestration on CT402 (`192.168.10.201`), Forgejo on Docker01 (`192.168.10.20`, git-ssh `:2222`, API `:3001`), Ollama on CT401 "AI-brains" (`192.168.10.200`, model `qwen3:14b`)
**Note on the uploaded `phase4-ai-agents-runbook.md`:** an earlier design-stage document (status "Design converged; build not yet started" as of 2026-09-17) exists as a chat attachment, not as a project doc — it covers the broader phase 4 multi-agent plan (docs agent, MkDocs pipeline, Matrix homeserver, model-selection testing). This doc is the real build/implementation record for phase 4g (the coding agent) specifically, superseding that file's coding-agent sections once they diverge.

## Overview

The coding agent is a sub-agent, triggered from n8n, that:
1. Clones a target Forgejo repo into an isolated per-task workspace on CT404.
2. Lets a local LLM (Ollama, `qwen3:14b`) read/write/check/**execute** files in that workspace via a restricted SSH forced-command dispatcher.
3. Opens a PR with the result (`new` mode), or pushes a revision and comments on the existing PR (`revise` mode, triggered from a Forgejo PR review-changes-requested comment).
4. On a genuine iteration-cap-out, routes through a distinct error path that still opens a PR, but clearly labeled `[INCOMPLETE - cap-out]`, carrying the model's own error message and the original task text — confirmed working end-to-end this session (see below).

Design goal (user's own framing): CT404 should function as a genuine "playground" — build, run, test, rebuild, re-run, retest before submitting — the same verification loop Claude Code itself uses in its own sandbox, not just a static linter. **That end state is now built and validated**, closing out what was the top open item as of the previous revision of this doc.

## Architecture

**n8n workflow:** Chat Trigger → Parse Task Input → `start-workspace` (SSH) → `If` (checks `start-workspace` exit code) → Extract `ws_id` → AI Agent node (Ollama `qwen3:14b`, tools: `list` / `read` / `write` / `run-checks` / **`run`**) → native Success/Error output ports → `propose`/`discard` command chain (Error branch feeds a distinct `Propose command - error` node) → response.

**SSH forced-command dispatcher on CT404:** restricted keypairs, each locked to a specific script via `command=` in `authorized_keys`:
- `start-workspace` — clones the repo (`new`) or recovers an existing task's workspace (`revise`)
- internal ops — `list` / `read` / `write` / `run-checks` / **`run`**, dispatched to the workspace the AI Agent is working in
- `propose` — commits, pushes, opens the PR or posts the revision comment

**`codebank/<ws_id>/` convention:** every `write` call lands under this path in the repo regardless of what relative path the model supplies, so each task's actual output is isolated and organized. `list`/`read` operate on the real cloned repo path — full visibility into whatever exists there, so the model can pull in any file it needs — except the `codebank/` directory itself is excluded, so the agent never sees other tasks' (or its own already-written) output and gets confused by same-named files across tasks. **`run` executes with cwd = `codebank/<ws_id>/`** — the model's own output directory — so anything outside it (the real repo root, `README.md`, other top-level folders) must be referenced with a `../../` relative prefix from inside an executed command; confirmed working (see "Execution Tool" section below).

## Execution Tool (`run`) — Built and Validated This Session (2026-09-27)

This is the tool that closes out what the previous revision of this doc listed as the top open item ("Execution-based verification"). It runs a shell command inside the workspace as an unprivileged, non-root user (`agentexec`), with hard resource limits and a configurable timeout, and returns real stdout/stderr plus the real exit code — the same build/run/test loop Claude Code itself uses in its own sandbox.

**`ws-run.sh` (CT404, `/root/bin/`) — current, fully validated state:**
```bash
#!/bin/bash
set -eu
source /root/bin/ws-common.sh

ws_path="$1"
command_b64="${2:-}"
timeout_b64="${3:-}"

[ -n "$command_b64" ] || reject "no command given"
cmd="$(b64d "$command_b64")"
[ -n "$cmd" ] || reject "empty command"

timeout_s=30
if [ -n "$timeout_b64" ]; then
  timeout_s="$(b64d "$timeout_b64")"
  [[ "$timeout_s" =~ ^[0-9]+$ ]] || reject "timeout must be a positive whole number of seconds"
  [ "$timeout_s" -ge 1 ]   || reject "timeout must be at least 1 second"
  [ "$timeout_s" -le 120 ] || reject "timeout cannot exceed 120 seconds"
fi

ws_id="$(basename "$ws_path")"
codebank_dir="$ws_path/codebank/$ws_id"
mkdir -p "$codebank_dir"

EXEC_USER="agentexec"

chown -R "$EXEC_USER:$EXEC_USER" "$codebank_dir"
chmod -R o-rwx "$ws_path"
chmod -R o+rX "$ws_path"
chmod -R o-rwx "$ws_path/.git"    # keep .git off-limits even after the ../../ regrant above

tmp_script="$(mktemp)"
outfile="$(mktemp)"
trap 'rm -f "$tmp_script" "$outfile"' EXIT

cat > "$tmp_script" <<SCRIPT
#!/bin/bash
cd "$codebank_dir" || exit 97
ulimit -t 20
ulimit -v 1048576
ulimit -u 64
ulimit -f 102400
exec bash -c "\$1"
SCRIPT
chmod 755 "$tmp_script"
chown "$EXEC_USER:$EXEC_USER" "$tmp_script"

set +e
setsid runuser -u "$EXEC_USER" -- "$tmp_script" "$cmd" > "$outfile" 2>&1 &
pid=$!
( sleep "$timeout_s"; kill -KILL -"$pid" 2>/dev/null ) &
watcher=$!
wait "$pid"
ec=$?
kill "$watcher" 2>/dev/null
wait "$watcher" 2>/dev/null
set -e

raw_output="$(cat "$outfile")"
max_bytes=20000
if [ "${#raw_output}" -gt "$max_bytes" ]; then
  raw_output="${raw_output:0:$max_bytes}
[output truncated at ${max_bytes} bytes]"
fi

note=""
[ "$ec" -eq 137 ] && note=" (likely hit the ${timeout_s}s timeout)"
[ "$ec" -eq 97 ]  && note=" (workspace access error, not your command)"

printf '%s\nexit=%s%s' "$raw_output" "$ec" "$note" | b64e
```

**Design:** runs as `agentexec` (no sudo, scoped to the workspace tree) via `runuser`, inside a `setsid` process group so the timeout watcher can reliably kill the whole group (not just the immediate PID) on timeout. Hard `ulimit`s cap CPU time (20s), virtual memory (~1GB), process count (64), and output file size (~50MB) independent of the caller-supplied wall-clock timeout (1–120s, default 30s). Output is byte-capped at 20000 chars before being returned. Exit code 137 is annotated as a likely timeout; 97 is a workspace-access error distinct from the executed command's own failure.

### Permissions history and empirical validation (2026-09-27)

Three real bugs were found and fixed in sequence, each confirmed against a live run rather than by code inspection alone:

1. **cwd/codebank mismatch (original root cause of the first-ever iteration-cap-out).** `run` originally `cd`'d to the raw workspace root while `write` always rewrote to `codebank/$ws_id/`, so the model's own written files were invisible to its own `run` commands — the model burned all 12 iterations unable to find what it had just written. Fixed by adding `mkdir -p "$codebank_dir"` and changing the wrapper's `cd` target from `$ws_path` to `$codebank_dir`.
2. **`../../` traversal lockout.** Scoping `chown` to `codebank_dir` alone, then blanket `chmod -R o-rwx "$ws_path"`, fully locked `agentexec` out of the rest of the repo (real source files, README, etc.) — the model could `read`/`list` them (those tools run as root) but not access them from inside an executed `run` command. Fixed by adding `chmod -R o+rX "$ws_path"` after the lockdown, regranting read+traverse to "other" across the whole workspace.
   - **Empirically confirmed 2026-09-27:** given an explicit task instructing the model to reference `../../README.md` from a script and actually execute it via `run` (not just write/lint it), the model initially misapplied the `../../` prefix to the *script invocation* itself (`run: ../../scripts/print_readme_first_line.sh: No such file or directory`, exit=127 — a model path-reasoning mistake, not a permissions failure), self-corrected via `list`, then successfully re-ran it: **`run` output `# homelab-infrastructure\nexit=0`** — the real first line of the real repo-root README, printed by a script executing as `agentexec` after traversing two directories up. PR opened cleanly (`[checks passing] ...`, PR #22).
3. **`.git` re-exposure.** The `o+rX` regrant above also reopened `.git` to read access for "other," undermining system-prompt rule 8 ("the `.git` directory is off-limits and cannot be read or written"). Fixed by adding `chmod -R o-rwx "$ws_path/.git"` as the final line of the permissions block, run *after* the `o+rX` regrant.
   - **Empirically confirmed 2026-09-27:** a dedicated read-only diagnostic task instructed the model to run `cat ../../.git/HEAD` and `ls -la ../../.git` via `run` and report the raw output. Both failed with `Permission denied` (`cat: ../../.git/HEAD: Permission denied\nexit=1`; `ls: cannot open directory '../../.git': Permission denied\nexit=2`) — not "not found," a clean confirmation the re-lock is enforced even with the wider `o+rX` grant in place. (Task made no changes, so `propose.sh` correctly returned "no changes to propose" — expected for a read-only diagnostic.)

### Cap-out / error-branch routing — empirically validated (2026-09-27)

Earlier investigation had established via direct AI Agent node output inspection that hitting the iteration cap genuinely throws and routes through the node's native Error output port with a populated `{ws_id, task, error}` payload (not the LangChain-default silent-continue behavior originally assumed). The downstream `Propose command - error` Code node builds a commit/PR message titled `[INCOMPLETE - cap-out] <error>` from that payload.

**Real end-to-end confirmation, 2026-09-27:** on the same `../../README.md` task (before the invocation-path fix above was in place), the run genuinely hit the iteration cap, routed through the Error branch, and opened **PR #21, titled exactly `[checks passing] [INCOMPLETE - cap-out] Max iterations (12) reached. The agent could not complete the task within the allowed number of iterations. Original task: "look at README.md in the repo root and write a script that prints its first line"`.** This is the first direct observation of a real cap-out's resulting PR title, and it matches the wiring's intended format precisely — `[<propose.sh's own check status>] [INCOMPLETE - cap-out] <model's error message>`. Combined with PR #22's clean `[checks passing] ...` title from a normal completion, both branches of the propose/discard routing are now confirmed on real runs, not just code review.

*Note:* the iteration cap value has been seen at both 12 (PR #21) and 20 (raised once during earlier JSON-leak troubleshooting, per Open Items below) across different points in testing — confirm the n8n AI Agent node's current setting before relying on either number.

## Known Residual Issues (Model-Tier, Not Wiring)

These are real, observed, and not fixable by further changes to the CT404 scripts or n8n wiring — they reflect the limits of `qwen3:14b` at this size combined with Ollama's native tool-calling implementation. They should inform the foreman's design (retry/escalation logic) rather than block it.

- **Ollama JSON-parse "leak."** Model reasoning text occasionally bleeds in front of the tool-call JSON, breaking Ollama's own Go-based `encoding/json` parser (`error parsing tool call: ... invalid character 'X' looking for beginning of value`). Confirmed via direct testing that this is **not reachable or patchable from n8n** — no Code node, LangChain-level setting, or agent-type selector exists in this n8n build that intercepts it. Mitigated (temperature lowered from 0.7, "enable thinking" turned off, explicit no-narration system-prompt rule added) but **not eliminated** — recurred at least once even with all mitigations active. Treat as inherent, bounded flakiness at this model tier.
- **Spec-fidelity misses.** On a `service_health_check.py` task explicitly asking for a socket-based, multi-port check against a CLI-supplied host, the model built a hardcoded HTTP GET against a placeholder URL **twice in a row** on the same task/revise cycle — a stable interpretation pattern for this model on this class of task, not a one-off fluke.
- **Model-generated file corruption.** Confirmed via `write`'s raw Input (not just Output) to be literal model-generated content — stray `*** End of file ***`-style sentinels, or a duplicated trailing `"""`. Not correlated with emoji/unicode content (also appeared in plain-ASCII files). No full fix exists; partially mitigated via the "Bug A" fix below, disabling "enable thinking," lowering temperature, and an explicit no-narration prompt rule. Accepted as residual, reduced-but-not-eliminated flakiness.
- **No batch failure-rate data yet.** Every result documented in this doc is a single point-test (one clean run, one cap-out, one traversal test, one `.git`-block test). There is no data yet on how often cap-outs, JSON-leaks, or spec deviations occur across a representative batch of varied tasks.

## Readiness Assessment: Proceed to Foreman? (2026-09-27)

**Call: yes, proceed to building the foreman now**, in parallel with (not blocked on) further isolated coding-agent hardening.

Rationale: the entire mechanical/wiring layer of the sub-agent is now validated end-to-end on live runs — sandboxed execution with correct cwd semantics, the `../../` read boundary working in both directions (real repo readable, `.git` blocked), binary-artifact git hygiene, and both success/cap-out PR-labeling paths. What remains open (the JSON-leak, spec-fidelity misses, corruption sentinel) are model-behavior limits of `qwen3:14b`, not defects that more isolated testing of this sub-agent will resolve. Continuing to test the coding agent alone has diminishing returns at this point — the more informative next test is how it behaves *under a foreman that has to react to its cap-outs and mislabeled successes*, which is exactly the missing layer (retry, re-scope, escalate) this sub-agent structurally cannot provide for itself.

Recommended in parallel with foreman work, not as a blocker:
- A batch of ~5–10 varied task runs to get a rough real cap-out/leak/deviation rate, to directly inform the foreman's retry/escalation thresholds.
- Foreman should be designed assuming: (a) any dispatch may cap out and come back with an `[INCOMPLETE - cap-out]`-titled PR that still needs review, (b) a "checks passing" / clean-completion PR is not proof the implementation matches spec, and (c) occasional silent tool-call parse failures are possible and not distinguishable in advance from a genuine model stall.

## Repo Tool Scripts (CT404, `/root/bin/`)

`ws-list.sh` — literal-path visibility, `codebank/` excluded:
```bash
#!/bin/bash
set -eu
source /root/bin/ws-common.sh
ws_path="$1"; subpath="$(b64d "$2")"
[ -z "$subpath" ] && subpath="."
check_relpath "$subpath"

case "$subpath" in
  codebank|codebank/*) reject "not visible from this workspace" ;;
esac

target="$ws_path/$subpath"
[ -d "$target" ] || reject "not a directory"
ls -la "$target"
```

`ws-read.sh` — same visibility rule:
```bash
#!/bin/bash
set -eu
source /root/bin/ws-common.sh
ws_path="$1"; relpath="$(b64d "$2")"
check_relpath "$relpath"

case "$relpath" in
  codebank|codebank/*) reject "not visible from this workspace" ;;
esac

target="$ws_path/$relpath"
[ -f "$target" ] || reject "file does not exist (use list for directories)"
b64e < "$target"
```

`ws-write.sh` — always reroutes to `codebank/$ws_id/`, plus an ASCII-only filename guard:
```bash
#!/bin/bash
set -eu
source /root/bin/ws-common.sh
ws_path="$1"; relpath="$(b64d "$2")"; content_b64="$3"
check_relpath "$relpath"

case "$relpath" in
  *[!a-zA-Z0-9._/-]*) reject "path contains unsupported characters (letters, digits, '.', '_', '-', '/' only)" ;;
esac

ws_id="$(basename "$ws_path")"
target="$ws_path/codebank/$ws_id/$relpath"
mkdir -p "$(dirname "$target")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
b64d "$content_b64" > "$tmp"

if [ -f "$target" ] && cmp -s "$target" "$tmp"; then
  mv "$tmp" "$target"
  echo "wrote $relpath ($(wc -c < "$target") bytes) — NOTE: byte-for-byte identical to what was already there; no actual change was made"
else
  mv "$tmp" "$target"
  echo "wrote $relpath ($(wc -c < "$target") bytes)"
fi
```

`ws-run-checks.sh` — hashes/lints everything changed since clone plus any caller-supplied extra paths, resolving each extra path against the real repo location first and the caller's own `codebank/$ws_id/` folder as fallback; **also strips any compiled binaries `run` may have produced before staging** (fixed this session, see Bugs below):
```bash
#!/bin/bash
set -eu
source /root/bin/ws-common.sh
ws_path="$1"; shift
ws_id="$(basename "$ws_path")"

# Strip any compiled binaries `run` may have produced inside the agent's
# own output directory before staging. These are build artifacts of a
# compile-and-test command — never something `write` puts there itself.
find "$ws_path/codebank/$ws_id" -type f 2>/dev/null | while IFS= read -r f; do
  case "$(file -b --mime-type "$f" 2>/dev/null)" in
    application/x-executable|application/x-sharedlib|application/x-pie-executable|application/x-mach-binary)
      rm -f "$f"
      ;;
  esac
done

git -C "$ws_path" add -A
changed="$(git -C "$ws_path" diff --name-only --cached HEAD)"

for a in "$@"; do
  extra="$(b64d "$a")"; check_relpath "$extra"
  case "$extra" in
    codebank|codebank/*) reject "not visible from this workspace" ;;
  esac
  if [ -e "$ws_path/$extra" ]; then
    resolved="$extra"
  elif [ -e "$ws_path/codebank/$ws_id/$extra" ]; then
    resolved="codebank/$ws_id/$extra"
  else
    resolved="$extra"
  fi
  changed="$changed
$resolved"
done

changed="$(printf '%s\n' "$changed" | sort -u | sed '/^$/d')"
if [ -z "$changed" ]; then
  echo "no changes since clone"
  exit 0
fi

while IFS= read -r f; do
  echo "FILE: $f"
  case "$f" in
    *.sh)
      echo "--- bash -n ---"; set +e; bash -n "$ws_path/$f" 2>&1; bn_ec=$?; set -e; echo "exit=$bn_ec"
      echo "--- shellcheck ---"; set +e; shellcheck "$ws_path/$f" 2>&1; sc_ec=$?; set -e; echo "exit=$sc_ec"
      ;;
    *.py)
      echo "--- flake8 ---"
      set +e; fl_out="$(python3 -m flake8 "$ws_path/$f" 2>&1)"; fl_ec=$?; set -e
      printf '%s\n' "$fl_out"
      if [ -n "$fl_out" ]; then
        echo "--- flagged lines (actual source text, for reference) ---"
        printf '%s\n' "$fl_out" | grep -oE ':[0-9]+:[0-9]+:' | cut -d: -f2 | sort -un | \
        while IFS= read -r ln; do printf 'line %s: %s\n' "$ln" "$(sed -n "${ln}p" "$ws_path/$f")"; done
      fi
      echo "exit=$fl_ec"
      ;;
    *.json)
      echo "--- jq empty (syntax check) ---"; set +e; jq empty "$ws_path/$f" 2>&1; jq_ec=$?; set -e; echo "exit=$jq_ec"
      ;;
    *.cpp|*.cc|*.cxx|*.hpp|*.h|*.hh)
      echo "--- cppcheck ---"
      set +e; cppcheck --enable=warning,style,performance,portability --suppress=missingIncludeSystem --error-exitcode=1 "$ws_path/$f" 2>&1; cc_ec=$?; set -e
      echo "exit=$cc_ec"
      ;;
    *.html|*.htm)
      echo "--- tidy ---"; set +e; tidy -errors -quiet "$ws_path/$f" 2>&1; td_ec=$?; set -e; echo "exit=$td_ec"
      ;;
    *) echo "no checker configured for this file type yet" ;;
  esac
  echo "==="
done <<< "$changed"
exit 0
```
(`.c` files intentionally have no checker configured yet — expected, per system-prompt rule 4, not a bug.)

`start-workspace.sh` — `new` clones fresh; `revise` recovers the *original* task's `ws_id` by checking out the given branch in a scratch clone and reading the single subdirectory name under that branch's own `codebank/` folder (branch names are `coding-agent-<timestamp>`, independent of `ws_id`, so this is the only reliable source of truth):
```bash
#!/bin/bash
set -eu
source /root/bin/ws-common.sh

parse_ssh_tokens
repo="${TOKENS[0]:-}"
mode="${TOKENS[1]:-}"

case "$repo" in
  Polaris-Pipeline-Testing|Project_Polaris|homelab-infrastructure) ;;
  *) reject "unknown repo" ;;
esac

case "$mode" in
  new)
    ws_id="task-$(date +%Y%m%d-%H%M%S)-$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    ws_path="$WORKSPACE_ROOT/$ws_id"
    run_or_log "clone" env \
      GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
      git clone --quiet "ssh://git@192.168.10.20:2222/lab-admin/${repo}.git" "$ws_path" > /dev/null
    { echo "repo=$repo"; echo "mode=new"; } > "$WORKSPACE_ROOT/$ws_id.meta"
    ;;
  revise)
    branch="${TOKENS[2]:-}"; pr_number="${TOKENS[3]:-}"
    [[ "$branch" =~ ^coding-agent-[0-9]{8}-[0-9]{6}$ ]] || reject "not a coding-agent branch"
    [[ "$pr_number" =~ ^[0-9]+$ ]] || reject "invalid PR number"

    scratch_id="scratch-$(date +%Y%m%d-%H%M%S)-$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    scratch_path="$WORKSPACE_ROOT/$scratch_id"
    run_or_log "clone" env \
      GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
      git clone --quiet "ssh://git@192.168.10.20:2222/lab-admin/${repo}.git" "$scratch_path" > /dev/null

    git -C "$scratch_path" show-ref --verify --quiet "refs/remotes/origin/$branch" \
      || { rm -rf "$scratch_path"; reject "that branch no longer exists on the remote"; }
    git -C "$scratch_path" checkout --quiet "$branch"

    entries=()
    if [ -d "$scratch_path/codebank" ]; then
      while IFS= read -r -d '' entry; do entries+=("$(basename "$entry")"); done \
        < <(find "$scratch_path/codebank" -mindepth 1 -maxdepth 1 -type d -print0)
    fi
    if [ "${#entries[@]}" -ne 1 ]; then
      rm -rf "$scratch_path"
      reject "could not determine the original task id from this branch (expected exactly one codebank folder, found ${#entries[@]})"
    fi
    ws_id="${entries[0]}"
    ws_path="$WORKSPACE_ROOT/$ws_id"
    rm -rf "$ws_path"
    mv "$scratch_path" "$ws_path"
    { echo "repo=$repo"; echo "mode=revise"; echo "branch=$branch"; echo "pr_number=$pr_number"; } \
      > "$WORKSPACE_ROOT/$ws_id.meta"
    ;;
  *) reject "unknown mode" ;;
esac

echo "$ws_id"
```

`propose.sh` — resolves `branch` for both modes before commit/push (fixes a real unbound-variable crash, see Bugs below); PR title/status always comes from `propose.sh`'s own fresh `run-checks` call, never the model's self-report:
```bash
cd "$ws_path"
if [ "$mode" = "new" ]; then
  branch="coding-agent-$(date +%Y%m%d-%H%M%S)"
  git checkout --quiet -b "$branch"
else
  branch="$(grep '^branch=' "$meta_path" | cut -d= -f2-)"
fi

run_or_log "commit" git -c user.email="polaris-coding-agent@polaris.homelab" \
  -c user.name="Polaris Coding Agent" commit --quiet -m "$commit_msg" > /dev/null

run_or_log "push" env GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  git push --quiet origin "$branch" > /dev/null

if [ "$mode" = "new" ]; then
  pr_title="[$status_line] $commit_msg"
  pr_body="$(printf '## Check output\n\n```\n%s\n```\n' "$check_output")"
  payload="$(jq -n --arg t "$pr_title" --arg b "$pr_body" --arg h "$branch" '{title:$t, body:$b, head:$h, base:"main"}')"
  run_or_log "open-pr" curl -sf -X POST \
    "http://192.168.10.20:3001/api/v1/repos/lab-admin/${repo}/pulls" \
    -H "Authorization: token $api_token" -H "Content-Type: application/json" -d "$payload" > /dev/null
  echo "proposed: $status_line, PR opened on $repo"
else
  pr_number="$(grep '^pr_number=' "$meta_path" | cut -d= -f2-)"
  comment_body="$(printf '## Revision pushed: %s\n\n```\n%s\n```\n' "$status_line" "$check_output")"
  payload="$(jq -n --arg b "$comment_body" '{body:$b}')"
  run_or_log "post-comment" curl -sf -X POST \
    "http://192.168.10.20:3001/api/v1/repos/lab-admin/${repo}/issues/${pr_number}/comments" \
    -H "Authorization: token $api_token" -H "Content-Type: application/json" -d "$payload" > /dev/null
  echo "proposed: $status_line, comment posted on PR #$pr_number"
fi
```

## AI Agent System Prompt (n8n) — "Polaris coding agent"

Now 18 rules (grown from the 14-rule version referenced by the previous revision of this doc); full text lives in the n8n node itself. Key points by section:
- **Language (rules 1–4):** not limited to any specific language; checkers exist for bash/.sh, Python/.py, JSON/.json, C++/.cpp,.cc,.cxx,.h,.hpp, HTML/.html,.htm; findings from checkers are authoritative; if the right language has no checker, write it anyway and state that plainly rather than avoiding the language.
- **Writing files (rules 5–8):** every `write` replaces the entire file (no partial diffs); bash scripts require a shebang; HTML fragments vs full pages are handled explicitly; **`.git` is off-limits and cannot be read or written** (now empirically enforced at the permissions layer too, not just prompt-level — see "Execution Tool" above).
- **Running and testing (rules 9–11):** `run` actually executes a shell command as a restricted non-root user with no general network access, hard time/resource limits, and returns real stdout/stderr plus real exit code; whenever the language supports it, actually compile/run what was written (not just lint it) and write/run a small companion test; `run-checks` and `run` answer different questions (well-formed vs. actually works) and neither alone is sufficient.
- **Checking work (rules 12–16):** call `run-checks` after writing; if checks fail, fix the specific named problem without rewriting unrelated working code; once `run-checks` names the wrong lines, act on it directly rather than re-reading; a check passing is necessary but not sufficient — **never stub out, simplify away, or placeholder real functionality to make a check pass more easily**; before declaring completion, the most recent relevant tool calls must include a confirming `run-checks` and, wherever possible, a real passing `run`.
- **Reporting (rules 17–18):** genuinely ambiguous/contradictory/impossible requirements must be flagged at the very start of the final summary with `TASK CONCERN:`; once complete (or at best attempt), stop calling tools and give a concise final summary.

## Bugs Found and Fixed (Static-Checking Pipeline Era)

1. **`propose.sh` unbound-variable crash in `revise` mode.** `branch` was only assigned inside the `mode = "new"` branch but referenced unconditionally at the `git push` line, crashing under `set -u` on every revise attempt. Fixed by resolving `branch` for both modes before commit/push (shown above).
2. **Forgejo API token missing `write:issue` scope.** PR-opening worked (needs `write:repository`) but posting a revision comment silently failed (`curl -sf` exit 22, empty output) until confirmed via manual `curl -i` showing `403 token does not have at least one of required scope(s): [write:issue]`. Fixed by regenerating the token with the correct scope.
3. **`ws-run-checks.sh` extra-args path resolution had no `codebank/$ws_id/` reroute.** When the model checked its own just-written file by its plain (non-rerouted) path, the script looked in the wrong location, producing false `FileNotFoundError`s and a cascading `sed` crash — contradictory, confusing check output. Fixed with plain-path-first / own-codebank-fallback resolution (shown above).
4. **Model produced a corrupted, partially non-ASCII filename** while confused by bug #3's bad check output, landing raw UTF-8 bytes (decoding to Chinese characters) in a real PR. Not a harness bug — a defensive mitigation was added anyway: `ws-write.sh` now rejects any path containing characters outside `[a-zA-Z0-9._/-]`.

## Bugs Found and Fixed (Execution-Tool Era, 2026-09-27 session)

5. **`run` cwd/codebank mismatch** — see "Execution Tool" section above; this was the root cause of the very first observed iteration-cap-out.
6. **`../../` traversal lockout** and **`.git` re-exposure** — both in the permissions sequence in `ws-run.sh`; see "Execution Tool" section above for the fix and the real-run confirmation of each.
7. **`ws-run-checks.sh` staged compiled binaries into git.** Only `ws-run-checks.sh` calls `git add -A` (`propose.sh` never does), so any build artifact `run` produced inside `codebank/$ws_id/` (e.g. a compiled test binary) got swept into the commit. Fixed via MIME-type-based detection (`file -b --mime-type`, checked against `application/x-executable`/`x-sharedlib`/`x-pie-executable`/`x-mach-binary`) that strips such files before staging (shown in the script above). Confirmed deployed and reviewed as correct.
8. **n8n "write" command-build Code node no-op bug.** The `write` tool's SSH-command-building Code node built `contentB64` from the raw `$json.content` instead of the locally cleaned `content` variable (which strips a stray "end of file" sentinel pattern the model sometimes emits) — a no-op that silently defeated the cleanup. Fixed to build from the cleaned `content` variable; confirmed deployed to all three `run-checks` paths.

## Structural Finding: Static Checkers Don't Verify Behavior — Now Resolved by the `run` Tool

On a real `revise` round (static-checking era), the model deleted a working implementation and replaced it with a 4-line non-functional stub, which trivially passed every checker (flake8/shellcheck/jq/cppcheck/tidy all validate style and syntax only, never behavior), then falsely declared success. `propose.sh`'s own independent `run-checks` call correctly reflected "checks passing" in the PR title — accurate, but the wrong thing to be measuring.

**First mitigation (static-checking era):** system prompt rules forbidding stubbing/deleting real functionality to pass checks more easily, and requiring a final `run-checks` call before any completion claim.

**Real fix — built and validated this session:** the `run` execution tool (see above), giving the model (and a reviewer) a genuine pass/fail signal beyond style/syntax. Note this closes the *mechanism* gap, not the *model-compliance* gap — the spec-fidelity misses documented under "Known Residual Issues" show the model can still produce something that runs cleanly without matching what was actually asked for; `run` proves code executes, not that it's correct.

## CT404 Isolation Audit

Confirmed facts: unprivileged LXC (`unprivileged: 1`), 2 cores / 4096MB RAM / 512MB swap / 32GB disk, `net0` on `vmbr0` at `192.168.10.203/24`, gateway `192.168.10.1`, everything inside runs as root (`uid=0`) except the `run` tool's dispatched commands, which execute as the dedicated unprivileged `agentexec` user (added this session).

**AppArmor.** `lxc.apparmor.profile: unconfined` is required — confirmed via a direct, reversible reboot test that reproduced `systemd-networkd`/`systemd-journald` failing with `code=exited, status=243/CREDENTIALS` when reverted to Proxmox's default confined profile. This is a systemd/Ubuntu-26.04 boot-time incompatibility with Proxmox's default AppArmor profile (documented precedent on CT403, the documentation-agent container) — **not**, as originally assumed, anything specific to Forgejo/webhook network traffic.

**Network.** Internet access was dropped entirely once model-pulling (Ollama images) was complete — the agent only ever needs Forgejo (git-ssh `:2222`, API `:3001`) and inbound SSH from n8n (`192.168.10.201`). The `run` tool's executed commands have no general network access by design (see CT404 Firewall section) and are further capped by resource `ulimit`s, independent of the container-level firewall.

## Incident: Homelab-Wide Internet Outage (2026-09-24)

**Cause.** Enabling the Proxmox **datacenter-level** firewall toggle (a cluster-wide master switch, distinct from per-VM/CT `.fw` files and the per-NIC `firewall=1`/`0` flag) — intended as a low-risk step toward isolating CT404 — instead cut internet access across every host in the homelab. This was a real misjudgment: the instruction was given without adequately flagging the blast radius of a datacenter-wide switch.

**Immediate response.** Reverted the toggle to "No" immediately. This did not fully restore connectivity — the primary WAN gateway (`gateway01`, VMID 107, pfSense) remained unreachable from the LAN side.

**Root cause.** `pve-firewall status` confirmed the daemon itself was `disabled/running` (not actively enforcing). The actual live cause was found in `iptables -L FORWARD -n -v` on the Proxmox host: the **FORWARD chain's base policy was left at DROP** — a residual effect of the brief datacenter-firewall-enable not cleanly reverted when the toggle was switched back off. `DOCKER-USER`/`DOCKER-FORWARD`/`ts-forward` (Tailscale) were present as jump targets for their own traffic only; nothing supplied a general ACCEPT for gateway01's WAN↔LAN forwarding, so it fell through to the DROP policy.

**Fix.** `iptables -P FORWARD ACCEPT` on the Proxmox host — confirmed connectivity restored and stable.

**Persistence insurance.** Since a policy change via `iptables -P` doesn't survive a reboot, and it wasn't certain `pve-firewall`'s disable path cleanly reverts it, a small systemd oneshot unit was added as a safety net, independent of `pve-firewall`:
```bash
cat <<'EOF' > /etc/systemd/system/forward-accept.service
[Unit]
Description=Ensure FORWARD chain policy is ACCEPT (safety net)
After=network.target pve-firewall.service
Wants=pve-firewall.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/iptables -P FORWARD ACCEPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now forward-accept.service
```

**Lesson, and resulting design pivot.** CT404's network lockdown was re-scoped away from the Proxmox datacenter/per-CT firewall system entirely, in favor of **in-container iptables only** — its blast radius is contained to the one container, and even a worst-case lockout is trivially recoverable via `pct enter 404` (LXC console, bypasses the network stack entirely), unlike a datacenter-level change which affects every host with no equivalent console fallback.

## CT404 Firewall (In-Container iptables, Final Design)

Scope: inbound SSH from n8n only (`192.168.10.201`); outbound to Forgejo only (`192.168.10.20:2222` git-ssh, `192.168.10.20:3001` API); ICMP allowed both directions for diagnostics; everything else dropped. No DNS needed (scripts use hardcoded IPs); no general internet (not needed since model pulls are complete).

Applied via a self-reverting script (`/root/bin/ct404-firewall-apply.sh`, 180s auto-revert armed via `systemd-run` before any rule is applied, cancelled with `systemctl stop ct404-fw-revert.timer` once confirmed working) and made permanent across reboots via a boot-time oneshot systemd unit (`ct404-firewall.service` → `/root/bin/ct404-firewall-boot.sh`), both using the same rule set:
```bash
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT
iptables -A INPUT -p tcp -s 192.168.10.201 --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp -d 192.168.10.20 --dport 2222 -j ACCEPT
iptables -A OUTPUT -p tcp -d 192.168.10.20 --dport 3001 -j ACCEPT
```
CT404's Proxmox-level `firewall=1` NIC flag was checked and confirmed already `0` — no Proxmox-side firewall involvement to clean up. Validated against a real end-to-end `new` coding-agent run (inbound SSH dispatch + list/read/write/run-checks + outbound clone/push/PR) before the revert timer was cancelled.

## Decisions Log

| Date | Decision |
|---|---|
| 2026-09-2x | `codebank/<ws_id>/` convention: writes always reroute here; read/list see the full literal repo except `codebank/` itself, so the agent has full context but never sees other tasks' (or its own committed) output |
| 2026-09-2x | Revise mode recovers the original `ws_id` from the branch's own `codebank/` contents rather than generating a new one — branch names are timestamp-based and carry no `ws_id` info themselves |
| 2026-09-2x | PR title/status is always driven by `propose.sh`'s own independent `run-checks` call, never the model's self-report |
| 2026-09-2x | Defensive ASCII-only filename guard added to `ws-write.sh` after a real corrupted-filename incident |
| 2026-09-2x | System prompt tightened against "pass checks by stubbing out real functionality," pending real execution-based verification |
| 2026-09-2x | CT404 confirmed to require `lxc.apparmor.profile: unconfined` for systemd/Ubuntu-26.04 boot compatibility — not Forgejo-specific, matches CT403 precedent |
| 2026-09-24 | Full internet outage caused by enabling the Proxmox datacenter-level firewall toggle; root cause found in a residual `iptables FORWARD` DROP policy on the Proxmox host, independent of `pve-firewall`'s own (disabled) state |
| 2026-09-24 | CT404 network lockdown pivoted from Proxmox datacenter/per-CT firewall to in-container iptables only, specifically because of the incident's blast-radius lesson and the `pct enter` console fallback it doesn't have at the datacenter level |
| 2026-09-24 | CT404 firewall scope: SSH from n8n in, Forgejo (2222/3001) out, ICMP both ways, everything else dropped; validated against a real pipeline run before being made permanent |
| 2026-09-27 | Built the `run` execution tool (unprivileged `agentexec` user, `setsid`-based reliable timeout enforcement, hard `ulimit`s) — closes out the top open item from the previous revision of this doc |
| 2026-09-27 | Diagnosed and fixed the `run` cwd/codebank mismatch that caused the first observed iteration-cap-out; the model's own written files are now visible to its own executed commands |
| 2026-09-27 | Adopted `chmod -R o+rX "$ws_path"` after the codebank-scoped `chown`/lockdown, to restore `agentexec`'s ability to read (not write) the rest of the repo from inside `run` — validated with a real `../../README.md` execution returning exit=0 and the correct content |
| 2026-09-27 | Added a `.git`-specific re-lock (`chmod -R o-rwx "$ws_path/.git"`) after the `o+rX` regrant, to keep rule 8 ("`.git` is off-limits") enforced at the permissions layer, not just the prompt layer — validated with real `Permission denied` results on both `cat ../../.git/HEAD` and `ls -la ../../.git` |
| 2026-09-27 | Fixed compiled-binary staging: `ws-run-checks.sh` now strips MIME-type-detected binaries from `codebank/$ws_id/` before `git add -A`, so `run`'s build artifacts never land in a PR |
| 2026-09-27 | Fixed the n8n `write` command-build Code node's no-op bug (was building `contentB64` from raw, uncleaned content) |
| 2026-09-27 | Confirmed via direct AI Agent node output inspection, then via a real cap-out (PR #21), that hitting the iteration cap throws and routes through the node's native Error output port with a correctly populated `{ws_id, task, error}` payload, and that the resulting PR title matches the intended `[<status>] [INCOMPLETE - cap-out] <error>` format |
| 2026-09-27 | Readiness call: proceed to building the foreman agent now, rather than continuing to test the coding agent in isolation — remaining known issues (Ollama JSON-leak, spec-fidelity misses) are model-tier limits that a foreman needs to design around, not wiring defects further isolated testing would resolve |

## Open Items

- **Iteration cap value.** Seen at both 12 (PR #21, most recent confirmed cap-out) and 20 (raised once during JSON-leak troubleshooting) — confirm the n8n AI Agent node's current setting; still an open question whether this is the right mechanism/value now that real execution-based verification exists, versus needing its own dedicated loop-prevention design.
- **No batch failure-rate data yet.** All validation so far is single-run point tests. A batch of ~5–10 varied tasks would give a real cap-out/leak/deviation rate to inform the foreman's retry/escalation design.
- **Ollama JSON-parse leak** — bounded, not eliminated; no further fix exists within reachable n8n/Ollama configuration. Foreman should assume occasional unexplained stalls are possible.
- **Spec-fidelity misses** — a real, repeatable pattern at this model tier on moderately fiddly tasks; not a wiring issue, informs what the foreman should treat as "needs human review" even on a "checks passing" PR.
- **Concurrency untested.** No testing yet of multiple simultaneous `run`/workspace dispatches (relevant once a foreman might direct several coding-agent tasks in parallel).
- Longer-term, not touched this session: foreman's natural-language-to-structured-task translation layer; the broker agent's all-repo-access design; whether the foreman itself needs all-repo access; foreman build has not started.

## Change Log

- 2026-09-2x: Corrected the codebank read/list design after an initial misunderstanding (had built full transparent-reroot-to-codebank-only, which broke the agent's ability to see the rest of the repo) — reverted to literal-path visibility with only `codebank/` excluded, per user correction.
- 2026-09-2x: Fixed `start-workspace.sh` so `revise` mode reuses the original task's `ws_id`, recovered from the branch's own `codebank/` contents, instead of generating a new one.
- 2026-09-2x: Diagnosed and fixed, in sequence, four real bugs blocking revise-mode: `propose.sh`'s unbound `branch` variable, the Forgejo token's missing `write:issue` scope, `ws-run-checks.sh`'s missing codebank reroute for extra paths, and a corrupted-filename incident (mitigated with an ASCII-only guard in `ws-write.sh`). Revise mode confirmed working end-to-end across at least two real PRs.
- 2026-09-2x: Found and named a genuine structural limitation — static checkers can't verify behavior, proven via a real revise round where the model stubbed out working code and still passed every check. Tightened the system prompt as a first mitigation; scoped real execution-based verification as a follow-on requiring CT404 isolation work first.
- 2026-09-2x: Audited CT404's isolation (privilege, AppArmor, network) ahead of building any execution capability, per explicit user direction to treat CT404 as a genuine build/run/test playground rather than lint-only. Confirmed AppArmor `unconfined` is a systemd/Ubuntu-26.04 boot requirement, not Forgejo-specific.
- 2026-09-24: A mistaken instruction to enable the Proxmox datacenter-level firewall toggle, intended as a step toward CT404 isolation, caused a full homelab-wide internet outage. Diagnosed and fixed via a residual `iptables FORWARD` DROP policy on the Proxmox host (`iptables -P FORWARD ACCEPT`), independent of `pve-firewall`'s own disabled state; connectivity confirmed restored and stable. Added a systemd oneshot safety net so the policy survives a reboot without depending on `pve-firewall`'s revert behavior.
- 2026-09-24: Pivoted CT404's firewall lockdown to in-container iptables only, per the incident's lesson. Built and deployed a least-privilege ruleset (SSH from n8n in, Forgejo out, ICMP both ways, everything else dropped), applied via a self-reverting safety-net script and made permanent via a boot-time systemd unit. Validated against a real end-to-end coding-agent pipeline run. Confirmed CT404's own Proxmox-level `firewall` flag was already off, closing out the isolation-hardening thread.
- 2026-09-27: Built the `run` execution tool on CT404 (unprivileged `agentexec` user, hard resource limits, `setsid`-based timeout enforcement). Diagnosed and fixed the cwd/codebank mismatch that caused the original iteration-cap-out. Fixed the `../../` traversal lockout (`o+rX` regrant) and then the resulting `.git` re-exposure (`.git`-specific re-lock) — both fixes empirically confirmed against real `run` executions, not just code review. Fixed compiled-binary staging in `ws-run-checks.sh` and a no-op content-cleaning bug in the n8n `write` command-build Code node. Confirmed, via two real runs, that both the success path (PR #22, `[checks passing] ...`) and the cap-out path (PR #21, `[checks passing] [INCOMPLETE - cap-out] ...`) produce correctly labeled PRs. Documented known residual model-tier issues (Ollama JSON-leak, spec-fidelity misses, file-corruption sentinel) as bounded rather than further fixable. Made the readiness call: proceed to building the foreman agent now, with a small batch failure-rate test recommended in parallel rather than as a blocker.
