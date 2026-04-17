# README 1 - Краткое описание

## Что используется

- Docker / Docker Swarm: оркестрация контейнеров
- Traefik: L7 роутинг
- HAProxy: внешний edge и точка входа
- Portainer: Web UI для управления Swarm
- GlusterFS: общее хранилище данных

Полезно:

- https://www.portainer.io/blog/monitoring-a-swarm-cluster-with-prometheus-and-grafana
- https://github.com/portainer/templates/tree/v3

## Порты по умолчанию

Порты берутся из defaults ролей (`haproxy`, `traefik`, `portainer`, `cluster-defaults`) и могут быть переопределены в inventory.

| Порт | Протокол | Назначение |
|------|----------|------------|
| 80 | TCP | HAProxy HTTP и `/stats` |
| 443 | TCP | HAProxy HTTPS |
| 8080 | TCP | Traefik web |
| 8443 | TCP | Traefik websecure |
| 9090 | TCP | Portainer UI |
| 9091 | TCP | Traefik dashboard/API |
| 22 | TCP | SSH |
| 9991 | TCP | Portainer Agent (overlay) |
| 9998 | TCP | Portainer tunnel |
| 2377 | TCP | Swarm manager control plane |
| 7946 | TCP/UDP | Swarm gossip |
| 4789 | UDP | Swarm VXLAN |
| 24007 | TCP | Gluster glusterd |
| 49152+ | TCP | Gluster brick range |

## Режимы firewall

### Мягкий режим (`firewall_lockdown=false`)

Роль `firewall-iptables` не режет глобально `INPUT/DOCKER-USER`, а применяет отдельные цепочки:

- `SWARM-NODE-PORTS`
- `PORTAINER-NODE-PORTS`
- `GLUSTER-NODE-PORTS`

### Жесткий lockdown (`firewall_lockdown=true`)

Включается вручную, отдельно:

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.ini playbooks/plays/03-firewall-iptables.yml \
  -u root --private-key ~/.ssh/id_ed25519 \
  -e firewall_lockdown=true \
  --tags lockdown
```

## Базовая проверка после деплоя

- Portainer: `http://portainer.domain.name:9090`
- HAProxy stats: `http://<haproxy_ip>/stats`

