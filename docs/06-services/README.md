# 06 — Services Catalogue

| Service | Host | Access | Docs |
|---|---|---|---|
| Nginx Proxy Manager | docker01 (VM 103) | `proxy.polaris.home.arpa`, :81 admin | `docker01/nginx-proxy-manager/` |
| Vaultwarden | docker01 | `vault.polaris.home.arpa` (via NPM, :3003) | `docker01/vaultwarden/` |
| Homepage | docker01 | `homepage.polaris.home.arpa` (:3000) | `docker01/homepage/` |
| Uptime Kuma | docker01 | `status.polaris.home.arpa` (:3002) | `docker01/uptime-kuma/` |
| Forgejo | docker01 | `git.polaris.home.arpa` (:3001, SSH :2222) | `docker01/forgejo/`, `forgejo/` |
| Portainer | docker01 | :9443 | `docker01/portainer/` |
| MkDocs site | docker01 | Auto-rebuilds on push (built by the documentation agent) | `../08-ai-platform/` |
| Jellyfin + File Browser + Caddy + Samba | jellyfin01 (VM 111) | `https://media.internal`, Tailscale remote | `media/jellyfin01-media-server-reference.md` |
| Pi-hole | pihole01 (CT 108) | 192.168.30.2 | `pihole/` (config snapshot is pre-cutover staging — re-export) |
| AD DS / DNS | dc01 (VM 200) | `ad.polaris` | `../05-identity-pki/` |
| PKI | ROOTCA01 (VM 109, offline), CA01 (VM 204) | — | `../05-identity-pki/` |
| AI agents (Ollama, n8n, Matrix) | AI node CT 401–405 | Element chat | `../08-ai-platform/` |

Port details: [NET-005](../02-network/NET-005-port-registry.md).
