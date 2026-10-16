# Phase 2 Runbook: n8n + Ansible Orchestration Layer

**Status:** Core pipeline working end-to-end (chat → AI Agent → tool call → Ansible → Proxmox API → real data)
**Container:** CT 402 "orchestrator-n8n" on node `AI`
**Last updated:** 2026-09-08

## Overview

This runbook documents standing up n8n (workflow orchestration) and Ansible (execution/automation) on a dedicated container, and wiring them together so an AI Agent inside n8n can autonomously decide to trigger real infrastructure automation. It builds directly on Phase 1 (see `phase1-ai-host-runbook.md`).

## Environment Summary

| Item | Value |
|---|---|
| Container | CT 402, "orchestrator-n8n", Ubuntu 26.04 LTS, privileged, 2 cores, 4GB RAM, 32GB disk on `ai-storage`, static IP `192.168.10.201/24` |
| Features enabled | Nesting (Options → Features) |
| Host-level config | `/etc/pve/lxc/402.conf` includes `lxc.apparmor.profile: unconfined` |
| n8n | Running via Docker, web UI at `http://192.168.10.201:5678` |
| Ansible | Installed directly on the container's OS (not in Docker), control node for all Proxmox automation |

## Build Steps

### 1. Create the container
Same pattern as CT 401: privileged, Ubuntu 26.04 template, `ai-storage` for disk, static IP `192.168.10.201/24`, Nesting enabled under Options → Features. No GPU passthrough needed for this container.

### 2. Install Docker
```bash
curl -fsSL https://get.docker.com | sh
```

### 3. Fix AppArmor so Docker containers can actually start
Docker normally applies its own AppArmor profile to every container it launches, but LXC containers (even privileged ones) don't have the `CAP_MAC_ADMIN` capability needed for that by default. From the **host shell**:
```bash
nano /etc/pve/lxc/402.conf
```
Add:
```
lxc.apparmor.profile: unconfined
```
Then `pct reboot 402`.

**Important:** this host-level line only stops Proxmox from confining the container itself — it does **not** automatically fix every Docker container launched inside it. Every individual `docker run` command still needs its own flag:
```
--security-opt apparmor=unconfined
```

### 4. Launch n8n
```bash
docker volume create n8n_data

docker run -d \
  --name n8n \
  --restart unless-stopped \
  --security-opt apparmor=unconfined \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e N8N_SECURE_COOKIE=false \
  -e GENERIC_TIMEZONE="America/Los_Angeles" \
  -e WEBHOOK_URL="http://192.168.10.201:5678/" \
  docker.n8n.io/n8nio/n8n
```
`WEBHOOK_URL` is not optional — without it, n8n defaults to assuming it's reachable at `localhost`, and Chat Trigger nodes fail silently with a generic "Failed to receive response" error (browser console shows a CORS/NetworkError referencing `localhost:5678`, since your browser is on a different machine than n8n itself).

Set up the owner account at `http://192.168.10.201:5678`, then activate the free community license under **Settings → Usage and plan → Enter activation key**.

### 5. Open Ollama to the network
By default Ollama only listens on `127.0.0.1` inside its own container (401) — n8n living in a *different* container (402) can't reach it until this is opened up. On container **401**:
```bash
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF
systemctl daemon-reload
systemctl restart ollama
```
(Note: `systemctl edit ollama.service` — the "normal" way to do this — silently failed to save in this build, printing "new contents are empty, not writing file." Writing the override file directly, as above, is more reliable.)

Verify from container 402: `curl http://192.168.10.200:11434` should return `Ollama is running`.

### 6. Install Ansible
```bash
apt update && apt install -y ansible
```
Minimal Ubuntu images often have no locale generated, which Ansible requires — fix immediately:
```bash
apt install -y locales
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
echo 'export LANG=en_US.UTF-8' >> ~/.bashrc
echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

### 7. The Python 3.13 segfault, and the pivot to API-based automation
Attempting standard Ansible modules (`ping`, `command`, etc.) against the Proxmox host over SSH consistently **segfaulted** (`rc: 139`) on the host's Python 3.13. Confirmed this was specific to Ansible's module-execution mechanism (AnsiballZ), not SSH or Python themselves:
- `ansible ... -m raw -a "echo hello"` → worked (bypasses target Python entirely)
- Plain `ssh ... "python3 -c 'print(1+1)'"` → worked
- `ansible ... -m ping` and `-m command` → both segfaulted identically

No clean root-cause fix was found for this specific Ansible-core + Python 3.13 combination. **Decision: don't fight it.** Proxmox hosts aren't meant to have their Python environment manipulated anyway. Pivoted to API-based automation instead — Ansible modules that talk to the Proxmox REST API over HTTPS directly from the control node, never touching the target's Python at all.

Install the required libraries **on the control node (402)**:
```bash
pip install proxmoxer requests --break-system-packages
ansible-galaxy collection list | grep -i proxmox   # confirm community.proxmox is present
```

### 8. Create a scoped Proxmox API token
Proxmox web UI → **Datacenter → Permissions → API Tokens → Add**:
- User: `root@pam`
- Token ID: `ansible`
- Privilege Separation: unchecked (inherits full root for now — **bootstrap-only choice, revisit and scope down later**, especially to exclude the cyberrange node/pool)

Copy the Secret immediately — Proxmox shows it exactly once.

Store it securely rather than passing it inline (which would otherwise leak into n8n's execution logs):
```bash
nano /root/.proxmox_token_secret     # paste secret, save
chmod 600 /root/.proxmox_token_secret
```

### 9. First working playbook
`~/ansible/playbooks/test-proxmox-api.yml`:
```yaml
---
- name: Test Proxmox API connectivity
  hosts: localhost
  gather_facts: false
  tasks:
    - name: List VMs on the AI node
      community.proxmox.proxmox_vm_info:
        api_host: 192.168.10.124
        api_user: root@pam
        api_token_id: ansible
        api_token_secret: "{{ lookup('file', '/root/.proxmox_token_secret') }}"
        validate_certs: false
        node: AI
      register: vm_list
    - name: Show result
      debug:
        var: vm_list
```
Run with `ansible-playbook ~/ansible/playbooks/test-proxmox-api.yml` — confirmed working, correctly lists CT 401 and CT 402 with live status/resource data.

### 10. Bridge n8n → Ansible (SSH loopback)
n8n runs inside Docker, isolated from container 402's own filesystem where Ansible lives. The bridge is SSH, looping back into the container's own OS:
```bash
apt install -y openssh-server
systemctl enable --now ssh

ssh-keygen -t ed25519 -C "n8n-loopback" -N "" -f ~/.ssh/n8n_loopback_key
cat ~/.ssh/n8n_loopback_key.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
cat ~/.ssh/n8n_loopback_key   # copy this private key into n8n's SSH credential
```
n8n SSH credential: Host `192.168.10.201`, Port `22`, Username `root`, Private Key = the key just printed.

### 11. Exposing SSH as an AI Agent tool
n8n's AI Agent "Tool" search only surfaces purpose-built `*Tool` nodes (third-party integrations like "Google Sheets Tool") — core nodes like SSH don't appear there directly, even though the underlying capability supports "any node as a tool." The working pattern:

1. Build a **separate sub-workflow** ("List Proxmox VMs") containing:
   - **Execute Workflow Trigger** node — set **Input data mode = "Accept all data"** (leaving it on "Define using fields below" with zero fields throws a validation error demanding at least one field)
   - → connected to an **SSH node** (same credential as above), command: `ansible-playbook /root/ansible/playbooks/test-proxmox-api.yml`
2. **Publish** this sub-workflow (Publish button, top right) — a saved-but-unpublished workflow causes a "workflow is not active" error when called as a tool, even though it runs fine when tested manually in the editor.
3. In the main chat workflow, on the **AI Agent** node → **+** under **Tool** → search **"Call n8n Workflow Tool"** (this one does appear in the tool palette).
4. Configure: Workflow → From list → select "List Proxmox VMs" (if the dropdown appears empty, click directly into the field and start typing — it's a search-as-you-type field, not a pre-populated dropdown, despite how the UI looks). Name: `list_proxmox_vms`. Description: `Lists all VMs and containers running on the AI Proxmox node, including their status, resource usage, and uptime.`

**Confirmed working end-to-end:** asking the chat "What VMs are currently running on the AI node?" causes the agent to autonomously invoke the tool and respond with real, live data (not a hallucinated guess).

## Benchmarking Note
First response through the full pipeline took ~24.5s (cold model load into VRAM). Second question, same session, took 6.7s. This is expected — treat the first request after any Ollama restart as a warm-up, not a performance baseline.

## GPU Noise Fix (Phase 1 addendum)
A steady, load-triggered tone (not fan noise, not classic coil buzz — a clean pitched tone appearing only at sustained full power draw) was resolved by forcing a fixed performance state instead of the GPU's default auto-boost behavior. This must be set at the **host** level, not inside the container — the container's device passthrough only grants compute access (`/dev/kfd`, `renderD128`), not the sysfs power-management interface.

Host shell:
```bash
echo high > /sys/class/drm/card1/device/power_dpm_force_performance_level
```
Made persistent via a systemd oneshot service (`/etc/systemd/system/gpu-perflevel.service`, enabled at boot) — see the project resume notes for the exact unit file if it needs to be recreated.

## Known Gotchas / Troubleshooting Reference

- **Ollama registry CDN occasionally serves a corrupted blob.** Signature: repeated `digest mismatch` errors on the *same tag*, with the *identical* wrong SHA256 each time. Fix: pull a different tag/quantization of the same model rather than retrying — sidesteps whatever edge node is serving the bad copy.
- **`pct enter` doesn't load a full shell environment.** Commands like `ollama --version` can report "not found" despite being installed — check/fix PATH before concluding something's missing.
- **LXC device passthrough only carries numeric GIDs, not names.** A container's own `render`/`video` groups may not be the same numbers as the host's — always verify with `ls -la` + `getent group` rather than assuming names match.
- **Debian has no official ROCm support for Radeon consumer GPUs** (Instinct/datacenter cards only) — use Ubuntu.
- **Ubuntu's non-LTS interim releases** (25.04, etc.) have ~9-month support windows — only use even-year `.04` LTS releases.
- **`systemctl edit` can silently fail to save**, printing "new contents are empty, not writing file" without erroring loudly. Write override files directly with a heredoc instead when this happens.
- **Docker inside a privileged LXC needs AppArmor disabled twice**: once at the container level (`lxc.apparmor.profile: unconfined` in the `.conf` file) and again on *every individual* `docker run` (`--security-opt apparmor=unconfined`). The first alone is not sufficient.
- **Self-hosted n8n needs an explicit `WEBHOOK_URL`** matching its real network address, or Chat Trigger nodes fail silently referencing `localhost`.
- **Ansible's SSH+Python module execution (AnsiballZ) segfaults against this Proxmox host's Python 3.13.** Use the `community.proxmox` API-based collection for anything Proxmox-specific instead of SSH+module execution. Plain `raw`/`command`-over-SSH or direct SSH exec both work fine if ever genuinely needed.
- **n8n's AI Agent Tool search only shows purpose-built `*Tool` nodes.** Wrap other logic (SSH, custom scripts, etc.) in a sub-workflow behind an "Execute Workflow Trigger," and expose it via "Call n8n Workflow Tool" instead.
- **Sub-workflows called as tools must be Published**, not just saved, or the parent gets a "workflow not active" error.
- **The "Call n8n Workflow Tool" node's workflow picker is a search field, not a pre-populated dropdown** — click in and type if it looks empty.
- **GPU coil/power-tone noise** during bursty inference load was fixed via a fixed performance-level lock at the host sysfs level (see above) — container-level GPU passthrough doesn't include power-management sysfs access.

## Open Items / Next Steps

- **Scope down the Proxmox API token** — currently full root via `root@pam` with privilege separation off. Should be narrowed via Proxmox RBAC, and explicitly excluded from the cyberrange node/pool, per the original security design intent.
- **First real automation task**: migrate the existing NAS01 cron backup script into an Ansible-driven workflow — this was the intended first "fully autonomous" task from the original project plan and hasn't been started yet.
- **Secrets handling**: the Proxmox token is in a root-only file for now; Ansible Vault (proper encryption) is the intended eventual upgrade, not yet implemented.
- **Docs / networking / coding "agent hats"**: still conceptual — planned to share the same Ollama model/host as different system-prompt personas in future n8n workflows, not yet built.
- **Cybersecurity model on the cyberrange host**: planned for dedicated hardware physically inside the cyberrange Proxmox node (not the AI host), to avoid crossing the OPNsense isolation boundary. Initial hardware: existing RX 580 8GB via Ollama's Vulkan backend (not ROCm — Polaris/gfx803 is unsupported in current ROCm). Planned upgrade path: Ryzen 7 5800X3D + X570 Taichi AM4 + RX 7700 XT + 850W PSU (repurposed from a separate build). Not yet started.
