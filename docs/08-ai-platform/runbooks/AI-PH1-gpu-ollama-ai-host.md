# Phase 1 Runbook: GPU-Accelerated Ollama on the AI Proxmox Host

**Status:** Complete
**Container:** CT 401 "AI-Brain" on node `AI`
**Last updated:** 2026-09-07

## Overview

This runbook documents the build of the AI homelab's first working component: an LXC container with GPU-accelerated Ollama for local LLM inference. It exists so this exact build can be reproduced quickly if the container ever needs to be rebuilt — several steps here were non-obvious and cost real troubleshooting time the first time around.

## Environment Summary

| Item | Value |
|---|---|
| Proxmox cluster | `polaris` — 3 nodes (AI, homelab, cyberrange) + NAS01 as QDevice |
| Host node | `AI` — Ryzen 9 7900X, 32GB DDR5-6000, Gigabyte X870 AORUS Elite WiFi7 ICE |
| Discrete GPU | AMD Radeon RX 9060 XT, 16GB GDDR6, gfx1200 (RDNA4), PCI `03:00.0` |
| iGPU (unused) | Raphael (built into the 7900X), PCI `76:00.0` — do not pass this one through |
| Storage | `ai-storage` — LVM-Thin pool on the 2.05TB SPCC NVMe (dedicated to AI workloads). 1.02TB Intel NVMe held in reserve, untouched. |
| Container | CT 401, "AI-Brain", Ubuntu 26.04 LTS ("Resolute Raccoon"), privileged, 8 cores, 16GB RAM, 1TB disk on `ai-storage`, static IP `192.168.10.200/24`, gateway `192.168.10.1` |

## Key Decisions & Why

- **LXC, not a VM.** Consumer AMD GPUs have a known "reset bug" under VFIO/PCI passthrough to VMs. An LXC container shares the host kernel, so the GPU is exposed as two device files instead — no IOMMU groups, no VFIO, no reset bug.
- **Ubuntu 26.04 LTS, not Debian, not Ubuntu 24.04.** AMD's ROCm officially supports Debian only for Instinct (datacenter) GPUs, not Radeon consumer cards — Debian was a dead end. Ubuntu 26.04 LTS (released April 2026) ships ROCm natively in its own package archive, so install is a plain `apt install rocm` instead of AMD's multi-step external-repo process.
- **Privileged container.** Simplifies GPU device passthrough considerably; the trade-off is accepted since this container isn't exposed outside the trusted management network.

## Build Steps

### 1. Identify the correct GPU on the host
Two AMD GPUs exist on this host (the discrete card and the CPU's iGPU). Confirm which is which before passing anything through:
```bash
lspci -nnk | grep -A3 -i "VGA\|Display"
ls -la /dev/dri/by-path/
dmesg | grep -i vram
```
On this build: PCI `03:00.0` (discrete RX 9060 XT) → `/dev/dri/renderD128`. PCI `76:00.0` (iGPU) → `renderD129`. Confirmed 16GB VRAM via dmesg on the `03:00.0` device.

### 2. Create the LXC container
- Storage: `ai-storage` (LVM-Thin pool created on the 2.05TB NVMe first, via Datacenter → AI → Disks → LVM-Thin → Create: Thin Pool)
- Template: `ubuntu-26.04-standard`
- Privileged (uncheck "Unprivileged container" under Advanced)
- 8 cores, 16GB RAM, 1TB disk
- Network: `vmbr0`, static IP `192.168.10.200/24`
- Enable **Nesting** under Options → Features (avoids systemd warnings, future-proofs for Docker if ever needed)

### 3. Pass the GPU into the container
From the **host shell**, edit `/etc/pve/lxc/401.conf` and add:
```
lxc.cgroup2.devices.allow: c 234:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/kfd dev/kfd none bind,optional,create=file
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
```
`234:0` is `/dev/kfd` (ROCm's compute interface — shared across all GPUs). `226:128` is `renderD128` specifically — the discrete GPU's render node. Start the container and verify both device files exist inside it (`ls -la /dev/kfd /dev/dri/renderD128`).

### 4. Install ROCm
Inside the container:
```bash
apt update && apt upgrade -y
apt install rocm
apt install rocm-smi
```
`rocm-smi` is a separate package, not pulled in automatically by the `rocm` meta-package. Verify with `rocminfo` — look for an Agent entry listing the GPU by name with a `gfx1200` ISA.

### 5. Install Ollama
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### 6. Fix GPU permissions (the non-obvious step)
Bind-mounting a device file into an LXC container only carries over the **numeric** group ID, not its name. On the host, that GID belongs to `render`. Inside this specific container, that same number happened to already belong to an unrelated group (`clock`) — so the container's own `render`/`video` groups were real, but the *wrong numbers*, and the `ollama` service user had no actual access to the device files.

Diagnose:
```bash
ls -la /dev/kfd /dev/dri/renderD128   # note the group name/number that actually owns them
id ollama                              # compare against ollama's group memberships
```
Fix (using whatever group name actually owns the files — `clock` in this build, but re-check on any rebuild, it may differ):
```bash
usermod -aG clock ollama
systemctl restart ollama
```

## Benchmark Results

Tested with `ollama run <model> "<prompt>" --verbose` using an identical prompt, GPU utilization cross-checked live with `rocm-smi` in a second session.

| Model | Quantization | Eval rate | Notes |
|---|---|---|---|
| hermes3:8b | default (Q4) | **59.13 tok/s** | Fast; good baseline |
| qwen2.5:14b-instruct | Q5_K_M | **27.48 tok/s** | **Chosen daily-driver model** |
| qwen2.5:32b | Q4 | Not benchmarked | Would exceed 16GB VRAM (~19-20GB required); abandoned as not worth the partial CPU-offload slowdown for this use case |

**Decision:** `qwen2.5:14b-instruct` as the main agent brain; an 8B model (`hermes3:8b`) kept loaded as a fast fallback for trivial tasks.

## Known Gotchas / Troubleshooting Reference

- **Orphaned disks after destroying a container:** if "Destroy disk(s)" wasn't checked, the underlying disk image survives on the storage even though the container is gone. Recover the space with:
  ```bash
  pvesm list ai-storage          # find the orphaned volume name
  pvesm free ai-storage:vm-XXX-disk-0
  ```
- **`ollama pull` fails with a digest mismatch, and repeat attempts return the *identical* wrong hash:** this points to a corrupted file cached at a CDN edge node in front of Ollama's registry, not local disk/network corruption. Retrying the same tag won't help. Pulling a *different* file — e.g. a different quantization tag of the same model — sidesteps the bad cached blob entirely.
- **`ollama`/other commands report "not found" inside a container you just entered with `pct enter`:** this can be a PATH issue, not a missing install — `pct enter` doesn't always load a full login shell environment. Check with `export PATH="/usr/local/bin:$PATH"` before concluding something isn't installed.
- **Ubuntu's non-LTS interim releases** (e.g. 25.04) get only ~9 months of support and go end-of-life fast. Only use even-year `.04` releases (24.04, 26.04, 28.04...) for anything long-lived.

## Useful Commands Reference

```bash
pct enter 401                                                    # enter the container from the host shell
journalctl -u ollama --no-pager | grep -iE "gpu|rocm|hip|gfx|amd"  # check GPU detection at Ollama startup
rocm-smi                                                          # live GPU stats (power, clocks, utilization)
rocminfo                                                          # full device/ISA info
ollama run <model> "<prompt>" --verbose                          # one-shot benchmark with tokens/sec
```

## Open Items / Future Work

- A fourth model, dedicated to offensive/defensive cybersecurity work on the cyberrange, will **not** live on this container — it's planned for dedicated hardware physically inside the cyberrange's own Proxmox host, to avoid opening a new network path across the OPNsense isolation boundary. See separate planning notes for that build (RX 580 via Vulkan backend initially, upgrading later to a Ryzen 7 5800X3D + RX 7700 XT).
- Phase 2: stand up n8n and Ansible on this container as the orchestration/execution layer for the docs, networking, and coding agent roles.
