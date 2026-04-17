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

## Пример: InHome (Postgres + Redis + RabbitMQ + MinIO)

Файл: `examples/inhome/docker-compose.yml`

Подготовка каталогов:

```bash
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/inhome/postgres-data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/inhome/redis-data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/inhome/rabbitmq-data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/inhome/minio-data state=directory mode=0775"
```

Каталог для дампов Postgres (на локальный диск manager-ноды, не в GFS):

```bash
ansible -i inventory.ini swarm_managers -m file -a "path=/var/backups/inhome/postgres-backups state=directory mode=0775"
```

Деплой:

```bash
docker stack deploy -c examples/inhome/docker-compose.yml inhome
```

Дампы Postgres будут появляться в `/var/backups/inhome/postgres-backups` каждые 15 минут (их удобно забирать через `rsync`).

## Пример: BetHome app (только приложения) + экспорт Postgres

Файл: `examples/bethome-app/docker-compose.yml`

Каталог для дампов Postgres (на локальный диск manager-ноды, не в GFS):

```bash
ansible -i inventory.ini swarm_managers -m file -a "path=/var/backups/bethome/postgres-backups state=directory mode=0775"
```

Деплой:

```bash
docker stack deploy -c examples/bethome-app/docker-compose.yml bethome
```

## Пример: BetHome infra (redis/postgres/rabbitmq/minio/prometheus) + экспорт Postgres

Файл: `examples/bethome-infra/docker-compose.yml`

Подготовка каталогов (данные сервисов в GFS):

```bash
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/bethome-redis/data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/bethome-postgres/data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/bethome-rabbitmq/data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/bethome-rabbitmq-balancer/data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/bethome-minio/data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/bethome-prometheus/data state=directory mode=0775"
```

Каталог для дампов Postgres (на локальный диск manager-ноды, не в GFS):

```bash
ansible -i inventory.ini swarm_managers -m file -a "path=/var/backups/bethome-infra/postgres-backups state=directory mode=0775"
```

Деплой:

```bash
docker stack deploy -c examples/bethome-infra/docker-compose.yml bethome-infra
```

## Пример: InHome infra (postgres/redis/rabbitmq/minio) + экспорт Postgres

Файл: `examples/inhome-infra/docker-compose.yml`

Подготовка каталогов (данные сервисов в GFS):

```bash
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/inhome-postgres/data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/inhome-redis/data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/inhome-rabbitmq/data state=directory mode=0775"
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/inhome-minio/data state=directory mode=0775"
```

Каталог для дампов Postgres (на локальный диск manager-ноды, не в GFS):

```bash
ansible -i inventory.ini swarm_managers -m file -a "path=/var/backups/inhome-infra/postgres-backups state=directory mode=0775"
```

Деплой:

```bash
docker stack deploy -c examples/inhome-infra/docker-compose.yml inhome-infra
```

## Пример: Frontend infra (MinIO)

Файл: `examples/frontend-infra/docker-compose.yml`

Подготовка каталога (данные MinIO в GFS):

```bash
ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/frontend-minio/data state=directory mode=0775"
```

Деплой:

```bash
docker stack deploy -c examples/frontend-infra/docker-compose.yml frontend-infra
```


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

ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory-dvsprtbt.ini -u root --private-key ~/.ssh/id_ed25519 playbooks/plays/manual-deploy-monitoring-stack.yml -v 2>&1 | tee "inventory-dvsprtbt-manual-deploy-monitoring-stack-$(date +%Y%m%d-%H%M).log" 

  -e grafana_user=admin \
  -e grafana_password='NewStrongPass123!'

  Перезадеплоить мониторинг (или хотя бы Grafana):
ansible-playbook -i inventory-sprtbt.ini playbooks/plays/manual-deploy-monitoring-stack.yml
Принудительно обновить Grafana/Prometheus сервисы:
docker service update --force monitoring_grafana
docker service update --force monitoring_prometheus
Если всё ещё No data, проверьте таргеты Prometheus
docker exec -it $(docker ps --filter name=monitoring_prometheus -q | head -n1) \
  wget -qO- http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job:.labels.job, health:.health, endpoint:.scrapeUrl}'

Как исправить сейчас (быстро)
Удалить стек мониторинга:
docker stack rm monitoring
Подождать, пока сервисы уйдут:
watch -n 2 "docker service ls | grep monitoring || true"
Удалить старые configs стека:
docker config ls --format '{{.Name}}' | grep '^monitoring_' | xargs -r docker config rm
Запустить ваш playbook снова:
ansible-playbook -i inventory-dvsprtbt.ini playbooks/plays/manual-deploy-monitoring-stack.yml

