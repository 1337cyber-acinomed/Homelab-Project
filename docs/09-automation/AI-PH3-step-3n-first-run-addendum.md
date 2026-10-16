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
