# README 3 - Варианты применения

## DNS / hosts для локальной среды

```text
10.10.10.10 portainer.docker.local
10.10.10.11 traefik.docker.local
10.10.10.12 ha.docker.local
```

В проде используйте нормальный DNS или внешний балансировщик.

## Мониторинг (Prometheus + Grafana)

```bash
docker node ls
docker node update --label-add monitoring=true <node-name>
docker stack deploy -c monitoring/docker-compose.yml prom
docker stack services prom
docker stack ps prom
```

## Использование GlusterFS в stack deploy

Ключевая идея: использовать bind в одинаковый путь на всех нодах (`/mnt/gfs`), а не локальные named volumes.

Подготовка каталогов:

```bash
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/app-data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/db-data state=directory mode=0775"
```

Пример: `examples/stack-with-gfs/docker-compose.yml`

```bash
docker stack deploy -c examples/stack-with-gfs/docker-compose.yml example
```

## Пример: MinIO (S3)

Файл: `examples/minio-s3/docker-compose.yml`

```bash
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/minio-data state=directory mode=0775"
printf "minioadmin" | docker secret create minio_root_user -
printf "change-me-strong-password" | docker secret create minio_root_password -
APP_DOMAIN_NAME=localdomain docker stack deploy -c examples/minio-s3/docker-compose.yml minio
```

Доступ:

- `http://minio.<APP_DOMAIN_NAME>`
- `http://minio-console.<APP_DOMAIN_NAME>`

## Пример: Nexus Sonatype

Файл: `examples/nexus-sonatype-swarm/docker-compose.yml`

```bash
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/nexus-data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/nexus-db state=directory mode=0775"
APP_DOMAIN_NAME=localdomain docker stack deploy -c examples/nexus-sonatype-swarm/docker-compose.yml nexus
```

Админ-пароль при первом старте: `/mnt/gfs/nexus-data/admin.password`.

## Эксплуатация и обслуживание

```bash
ansible-playbook -i inventory-localdomain.ini playbooks/upgrade-docker.yml -e docker_upgrade_hosts=all -e docker_force_reinstall=true
ansible-playbook -i inventory-prod.ini playbooks/plays/manual-sysctl-high-load-profile.yml
ansible-playbook -i inventory-prod.ini playbooks/plays/manual-sysctl-high-load-profile.yml -e sysctl_high_load_state=absent
```

Сброс кластера (nuke):

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ANSIBLE_STDOUT_CALLBACK=default \
ansible-playbook -i inventory.ini playbooks/plays/manual-nuke-node-reset.yml \
  -e nuke_confirm=YES -e nuke-reboot=YES -u root --private-key ~/.ssh/id_ed25519 -vvv 2>&1 | tee reset-$(date +%Y%m%d-%H%M).log
```

