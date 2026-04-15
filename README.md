# Docker Swarm + GlusterFS + Traefik + HAProxy + Portainer

Коротко: этот репозиторий с Ansible-ролями поднимает инфраструктурный контур для Docker Swarm:

- L7-роутинг (Traefik)
- внешний edge (HAProxy + опциональный keepalived VIP)
- Web UI управления (Portainer)
- общее хранилище (GlusterFS)

## Описание контуров

```mermaid
flowchart LR
  subgraph clients[Клиенты / DNS]
    U[Пользователи]
  end

  subgraph edge[HAProxy optional VIP]
    H[HAProxy :80/:443]
  end

  subgraph traefik_hosts[Группа traefik или managers]
    T[Traefik Swarm :8080/:8443]
  end

  subgraph swarm[Docker Swarm managers + workers]
    P[Portainer UI :9090]
    A[Portainer Agent :9991 внутри overlay]
    S[Сервисы за Traefik]
  end

  subgraph storage[Gluster brick-ноды]
    G[Glusterd + bricks]
  end

  U --> H
  H -->|"HTTP(S) L7"| T
  T --> S
  T --> P
  P -.->|данные| GF[(GFS /mnt/gfs)]
  G --> GF
```

Вход пользователей идет в HAProxy, затем трафик проксируется в Traefik на хостовые entrypoints, после чего L7-роутинг выполняется до сервисов Docker Swarm. Данные сервисов размещаются в общем пути `gluster_mount_path` (обычно `/mnt/gfs`).

## Инвентори и группы

Основной шаблон групп:

- `[haproxy]` - edge-узлы с HAProxy
- `[swarm_managers]` - менеджеры Swarm
- `[swarm_workers]` - воркеры Swarm (опционально)
- `[gluster_nodes]` - Gluster-узлы
- `[traefik]` - отдельные Traefik-узлы (или может быть `:children` от managers)
- `[all:vars]` - общие переменные окружения

Основные инвентори в репозитории:

- `inventory.ini`
- `inventory-dev.ini`
- `inventory-preprod.ini`
- `inventory-prod.ini`
- `inventory-infra-btnxlocal.ini`
- `inventory-localdomain.ini`

## Остальная документация

- `README-1-brief.md` - краткое описание, порты, firewall режимы, базовая проверка
- `README-2-install.md` - основной install/deploy workflow и команды Ansible
- `README-3-usage-variants.md` - варианты применения, примеры стеков, мониторинг и эксплуатация
