# Git Quick Reference

A practical reference built from real commands used in Project Polaris, not just a generic cheat sheet.

## The everyday loop

```bash
git status              # what's changed, what's staged, what isn't
git add <path>           # stage a specific file or folder
git add .                 # stage everything changed in the current directory
git commit -m "message"  # commit what's staged, with a message describing why
git push                  # send commits to the remote (Forgejo)
git pull                  # bring down and merge any new remote commits
```

**Good commit message habit**: describe *what* and *why* in one line, e.g. `"Add gateway01 collector; rename Firewall01 for clarity"` — future-you (or a documentation agent) reading `git log` later will thank you.

## Viewing history

```bash
git log                          # full history, most recent first
git log --oneline                 # same, one line per commit — easier to scan
git log --oneline -- <path>       # history for one specific file only
git show <commit-hash>            # full details of one commit (what changed, message, etc.)
git diff                          # what's changed but not yet staged
git diff <commit-hash>            # what's changed since a specific commit
```

## Recovering an old version of a file (used tonight to fix a real accidental deletion)

```bash
git show <commit-hash>:<path-in-repo> > /tmp/old-version.txt
```

This pulls one file, exactly as it existed at one specific commit, out to a new location — without touching your current working files at all. Useful for comparing, or for manually extracting a piece that got lost. This is exactly how the `_run_proxmox_collector`/`_run_switch_collector` recovery worked: pulled the last known-good commit's version of `polaris-backup` to a temp file, then copied the still-correct functions back out of it.

## Cloning a repo for the first time on a new machine

```bash
git clone ssh://git@<host>:<port>/<user>/<repo>.git <local-folder-name>
```

**If you're using a dedicated, non-default SSH key** (recommended — one key per host, matching how every credential in this project works), the plain command above will fail with `Permission denied`, because there's no repo yet for `git config` to save a key setting into. Use this for the *initial* clone only:

```bash
GIT_SSH_COMMAND="ssh -i /path/to/your/key" git clone ssh://git@<host>:<port>/<user>/<repo>.git <local-folder-name>
```

Then, **immediately after**, set the key permanently for that one repo, so you never have to type `GIT_SSH_COMMAND` again for it:

```bash
cd <local-folder-name>
git config core.sshCommand "ssh -i /path/to/your/key"
```

## When `git push` is rejected

```
! [rejected]  main -> main (fetch first)
```
or
```
! [rejected]  main -> main (non-fast-forward)
```

This means the remote has commits your local copy doesn't know about yet — usually because something else (another machine, another session) pushed first. Fix:

```bash
git pull
git push
```

**If `git pull` itself refuses and asks how to reconcile** (a newer Git safety behavior, not an error with your repo):

```bash
git pull --no-rebase
```

This does a normal merge. If it doesn't fast-forward cleanly, an editor may pop up asking for a merge commit message — the pre-filled default message is almost always fine; just save and close it (in `nano`: `Ctrl+O`, `Enter`, `Ctrl+X`).

To stop being asked this every time, set a permanent default for one repo:
```bash
git config pull.rebase false   # always merge (safe default for small teams / solo use)
```
or for every repo on this machine:
```bash
git config --global pull.rebase false
```

## Deploy keys (what this project actually uses instead of passwords)

Each machine that needs to push to Forgejo gets its **own** dedicated SSH keypair, registered as a separate deploy key on the repo — never a shared private key copied between machines. This means any one machine's access can be revoked independently if it's ever compromised, without affecting anything else.

```bash
ssh-keygen -t ed25519 -C "descriptive-name" -f ~/.ssh/your-key-name -N ""
cat ~/.ssh/your-key-name.pub   # copy this output into Forgejo's Deploy Keys settings
```

## Quick troubleshooting table

| What you see | What it usually means | Fix |
|---|---|---|
| `Permission denied (publickey)` | Wrong or missing SSH key for this specific repo/host | Check `core.sshCommand`, or the key was never registered as a deploy key on the server |
| `fatal: Could not read from remote repository` | Same as above — auth failed before Git could even see the repo | Verify the deploy key is added *and* has write access if you're pushing |
| `! [rejected] ... (fetch first)` / `(non-fast-forward)` | Remote has commits you don't have locally | `git pull` (see reconciliation note above), then `git push` |
| `Need to specify how to reconcile divergent branches` | Git wants an explicit merge strategy (newer Git versions) | `git pull --no-rebase` |
| Nothing happens / command seems to hang after `git commit` | An editor opened waiting for a commit message (common on merges) | Save and close it — the pre-filled message is usually fine |
