# Homepage Config

Template configs for [gethomepage/homepage](https://gethomepage.dev).  
Real secrets are stored on NFS and **never committed to git**.

## Setup

1. Copy all files from this directory to your NFS homepage config path
2. Replace all `<PLACEHOLDER>` values with real ones:

| Placeholder | Where to find |
|---|---|
| `<JELLYFIN_IP>` | Jellyfin host IP |
| `<JELLYFIN_API_KEY>` | Jellyfin → Dashboard → API Keys |
| `<QBITTORRENT_PASSWORD>` | qBittorrent WebUI password |
| `<SONARR_API_KEY>` | Sonarr → Settings → General → API Key |
| `<RADARR_API_KEY>` | Radarr → Settings → General → API Key |
| `<ARGOCD_API_TOKEN>` | ArgoCD → User Info → Generate Token |
| `<PIHOLE_IP>` | Pi-hole host IP |
| `<PROXMOX0_IP>` | Proxmox node 0 IP |
| `<PROXMOX1_IP>` | Proxmox node 1 IP |
| `<PROXMOX_API_TOKEN_SECRET>` | Proxmox → Datacenter → API Tokens |
| `<YOUR_GITHUB_USERNAME>` | Your GitHub username |

## Proxmox API Token

Create a read-only token for homepage:
```bash
# In Proxmox shell
pveum user token add root@pam homepage --privsep 0
pveum aclmod / -token root@pam!homepage -role PVEAuditor
```
