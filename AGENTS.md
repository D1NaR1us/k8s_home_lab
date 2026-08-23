# AGENTS.md — k8s_home_lab

## Что это
GitOps-репозиторий для домашнего Kubernetes-кластера (2× Proxmox NUC). Все приложения разворачиваются через ArgoCD из одного Helm-чарта.

## Структура репозитория

```
k8s_home_lab/
├── home_lab/
│   ├── defaults/
│   │   ├── helm_media/                    # Единый Helm-чарт для всех приложений
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml                # Дефолтные значения (nginx:latest)
│   │   │   ├── templates/
│   │   │   │   ├── HM-app.yaml            # Deployment (shared PVC, extraVolumeMounts)
│   │   │   │   ├── HM-svc.yaml            # Service
│   │   │   │   ├── HM-ingress.yaml        # Traefik IngressRoute (*.home.lab, websecure)
│   │   │   │   └── HM-postgres-secret.yaml
│   │   │   └── homepage-config/           # Конфиги для Homepage dashboard
│   │   │       ├── services.yaml          # Сервисы (Jellyfin, Notes, *arr, etc.)
│   │   │       ├── widgets.yaml           # Виджеты (search, datetime, погода)
│   │   │       ├── bookmarks.yaml
│   │   │       └── proxmox.yaml
│   │   └── home-media_pv_secret/          # PersistentVolume + Secret для NFS
│   │       └── HM-pv.yaml
│   └── argocd_apps/
│       ├── root_argocd/
│       │   └── main.yaml                  # Root App — смотрит в argocd_apps/apps/
│       ├── apps/                          # ArgoCD Applications
│       │   ├── PV.yaml                    # pv-secret
│       │   ├── personal_notes.yaml        # my-notes (NoteDiscovery: Alice-personal + skills)
│       │   ├── notes.yaml                 # notes (NoteDiscovery: Work_Notes)
│       │   ├── torrent.yaml               # qBittorrent
│       │   ├── sonarr.yaml                # Sonarr
│       │   ├── radarr.yaml                # Radarr
│       │   ├── jackett.yaml               # Jackett
│       │   └── homepage.yaml              # Homepage dashboard
│       └── examples/
│           └── vault_test/
└── tools/
    ├── 1-helm/README.md
    ├── 2-metallb/                         # MetalLB (LoadBalancer IP)
    ├── 3-traefik/                         # Traefik (Ingress, TLS, *.home.lab)
    ├── 4-argocd/                          # ArgoCD (GitOps)
    └── 5-vault/                           # HashiCorp Vault (секреты)
```

## Ключевые принципы

1. **Один Helm-чарт для всех приложений** — `helm_media`. Новое приложение = новый ArgoCD App, указывающий на тот же чарт с кастомными values (image, port, extraVolumeMounts).
2. **Shared PVC** — все поды монтируют `hm-claim` (NFS `home-media`).
3. **Traefik Ingress** — каждое приложение получает `<name>.home.lab` через `websecure` entrypoint (TLS).
4. **GitOps через ArgoCD** — push в main → ArgoCD синхронизирует. Self-heal включён.
5. **Timezone** — Europe/Sofia.

## Приложения в кластере

| ArgoCD App | Helm Release | Образ | Port | Доступ |
|---|---|---|---|---|
| my-notes | my-notes | notediscovery:latest | 8000 | my-notes.home.lab |
| notes | notes | notediscovery:latest | 8000 | notes.home.lab |
| bittorrent | bittorrent | qbittorrent:4.6.7 | 8080 | qbittorrent.home.lab |
| sonarr | sonarr | sonarr:latest | 8989 | sonarr.home.lab |
| radarr | radarr | radarr:latest | 7878 | radarr.home.lab |
| jackett | jackett | jackett:latest | 9117 | jackett.home.lab |
| homepage | homepage | homepage:latest | 3000 | homepage.home.lab |

## Железо

- **Proxmox10** — NUC6i3SYK, 32GB
- **Proxmox11** — NUC8i7HVK, 64GB
- **mcprag** — отдельный LXC (192.168.50.113), RAG MCP-сервер, не в кластере
- **Alice (Hermes)** — отдельный LXC, не в кластере

## Как добавить новое приложение

1. Скопировать любой ArgoCD App из `home_lab/argocd_apps/apps/`
2. Поменять `name`, `namespace`, image, port, extraVolumeMounts
3. Добавить в `homepage-config/services.yaml` (опционально)
4. Push → ArgoCD сам всё развернёт
