# Docker Swarm + GlusterFS + Traefik + HAProxy + Portainer

Коротко: этот репозиторий с Ansible‑ролями поднимает кластер из 5 Docker Swarm‑узлов с:

- **L7‑роутингом** (Traefik)
- **Web‑UI управления** (Portainer)
- **Распределённым хранилищем** (GlusterFS)
- **Внешним балансировщиком** (HAProxy + VIP)

## Что используется

- **Docker / Docker Swarm**: оркестрация контейнеров.
- **Portainer**: Web‑UI для Swarm (`http://portainer.docker.local` по умолчанию).
- **HAProxy**: балансировщик между Traefik‑узлами и точка входа в кластер.
- **Prometheus + Grafana**: мониторинг Swarm‑кластера.

Полезно почитать:  
`https://www.portainer.io/blog/monitoring-a-swarm-cluster-with-prometheus-and-grafana`  
Шаблоны приложений Portainer: `https://github.com/portainer/templates/tree/v3`

## Минимальные требования

- **5 хостов** c Debian/Ubuntu (1 для HAProxy, 3 для Swarm, 1 для Traefik).
- Доступ по SSH (один пользователь с `sudo` без пароля).
- На Swarm‑нодах:
  - 2 CPU, 4 ГБ RAM, диск 30 ГБ+ для ОС
  - Дополнительный диск 10 ГБ+ под GlusterFS
- Рабочая машина с установленным **Ansible**.

## Быстрый запуск

1. **Установить Ansible** (пример для Ubuntu):

   ```bash
   sudo apt update
   sudo apt install -y ansible python3-venv python3-pip
   ```

2. **Клонировать репозиторий и создать venv**:

   ```bash
   git clone https://github.com/.../docker-swarm-ansible.git
   cd docker-swarm-ansible

   python3 -m venv .venv
   source .venv/bin/activate
   pip install -U pip
   pip install -r requirements.txt
   ```

3. **Настроить инвентори** в файлах:

   - `inventory.ini` – список хостов и группы (`[haproxy]`, `[swarm_managers]`, `[swarm_workers]`, `[gluster_nodes]`)
   - `playbooks/vars/config.yml` – базовые переменные и домены

   Минимум нужно:

   - 1 хост в `[haproxy]`
   - 3 хоста в `[swarm_managers]`

4. **Проверить доступ по SSH** и работу Ansible:

   ```bash
   ### Test Connectivity to Hosts
   ssh-keygen -t rsa -b 4096 -C "$(whoami)@$(uname -n)-$(date -I)" -f ~/.ssh/id_rsa
   ssh-keygen -t ed25519 -b 4096 -C "$(whoami)@$(uname -n)-$(date -I)" -f ~/.ssh/id_ed25519
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_rsa

   ssh-copy-id -i ~/.ssh/id_rsa.pub $(whoami)@192.168.1.ХХ

   ansible all -i inventory.ini -m ping
   ```

5. **Запустить плейбук установки**:

   ```bash
   ansible-playbook -i inventory.ini playbooks/install.yml  --key-file /mnt/wslg/distro/home/assa/.ssh/id_ed25519 -u root
   ```

После выполнения будет настроен Swarm, GlusterFS, Traefik, HAProxy и Portainer.

## Что делает плейбук

- Обновляет пакеты и ставит зависимости.
- Устанавливает Docker CE и настраивает Swarm (1 лидер + 2 менеджера, опционально воркеры).
- Настраивает GlusterFS и монтирует общий volume в `/mnt/gfs` (на всех Swarm-нодах).
- Разворачивает Portainer (агенты + UI).
- Устанавливает и настраивает HAProxy, самоподписанный сертификат и маршрутизацию к менеджерам.

## DNS / hosts

Для L7‑роутинга необходимо, чтобы имена приложений указывали на хост с HAProxy.

Пример для локальной среды (`/etc/hosts` или `C:\Windows\System32\drivers\etc\hosts`):

```text
10.10.10.10 portainer.docker.local
10.10.10.11 traefik.docker.local
10.10.10.12 ha.docker.local
```

В проде вместо этого обычно настраивается нормальный DNS и/или облачный балансировщик.

## Мониторинг


### Установка мониторинга (Prometheus + Grafana)

1. Убедитесь, что Swarm‑кластер уже инициализирован и ноды в статусе `Ready`:

   ```bash
   docker node ls
   ```

2. На нужных нодах при необходимости добавьте метку для мониторинга (пример):

   ```bash
   docker node update --label-add monitoring=true <node-name>
   ```

3. Разверните стек мониторинга как Swarm‑стек:

   ```bash
   docker stack deploy -c monitoring/docker-compose.yml prom
   ```

   Пример вывода:

   ```text
   Creating network prom_net
   Creating service prom_node-exporter
   Creating service prom_grafana
   Creating service prom_prometheus
   Creating service prom_cadvisor
   ```

4. Проверьте состояние стека и сервисов:

   ```bash
   docker stack ps prom
   docker stack services prom
   ```

Используя Prometheus и Grafana для сбора и визуализации метрик кластера, а также Portainer для упрощения развёртывания, можно эффективно мониторить Swarm‑кластер и выявлять возможные проблемы до того, как они станут критичными.

После этого Prometheus, Grafana, node‑exporter и cadvisor будут работать как сервисы в стеке `prom`. Далее можно настроить дашборды в Grafana и алерты по метрикам Swarm/нод/контейнеров.

## Проверка

- **Portainer**: `http://portainer.docker.local` (логин/пароль по умолчанию смотрите в переменных Ansible).
- **HAProxy stats**: `http://<haproxy_ip>/stats`
- Простейший стек приложения в Swarm должен публиковать порт сервиса, например:

  ```yaml
  services:
    myservice:
      image: nginx:alpine
      ports:
        - "80"
  ```

## Общее хранилище (GlusterFS) в `docker stack deploy`

В Swarm “именованные каталоги” лучше делать так, чтобы они указывали на **одинаковый путь на всех нодах**.

- **Важно**: обычный `named volume` (без volume‑plugin’а) в Swarm — это **локальный** том на каждой ноде. Если задача переедет на другую ноду, она увидит другой том/пустые данные.
- **Рекомендуемый вариант** для общего хранилища: **bind** в путь, который примонтирован на всех нодах одинаково (в этом репо — GlusterFS в `/mnt/gfs`), и ограничить размещение `node.labels.gfs == true`.

Чтобы при этом сохранить “красивые имена” томов в compose, можно использовать **именованные volumes поверх bind** через `driver_opts` (см. пример ниже).

- **Создать каталоги под стек** (пример):

  ```bash
  ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/app-data state=directory mode=0775"
  ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/db-data state=directory mode=0775"
  ```

- **Пример compose для стека**: `[examples/stack-with-gfs/docker-compose.yml](examples/stack-with-gfs/docker-compose.yml)`
- **Деплой**:

  ```bash
  docker stack deploy -c examples/stack-with-gfs/docker-compose.yml example
  ```

В примере используется constraint `node.labels.gfs == true` (лейбл выставляется плейбуком), чтобы сервисы гарантированно запускались только на нодах с `/mnt/gfs`.

## MinIO (S3) в Docker Swarm (с GFS + Traefik)

Готовый пример стека: `examples/minio-s3/docker-compose.yml`.

- **Директория под данные на GFS**:

  ```bash
  ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/minio-data state=directory mode=0775"
  ```

- **Создать Swarm secrets** (выполнять на менеджере Swarm один раз):

  ```bash
  printf "minioadmin" | docker secret create minio_root_user -
  printf "change-me-strong-password" | docker secret create minio_root_password -
  ```

- **Деплой стека**:

  ```bash
  APP_DOMAIN_NAME=localdomain docker stack deploy -c examples/minio-s3/docker-compose.yml minio
  ```

- **Доступ**:
  - **S3 API**: `http://minio.<APP_DOMAIN_NAME>`
  - **Console UI**: `http://minio-console.<APP_DOMAIN_NAME>`

## Nexus Sonatype (docker swarm) (с GFS + Traefik)

Готовый пример стека: `examples/nexus-sonatype-swarm/docker-compose.yml`.

- **Директория под данные на GFS**:

  ```bash
  ansible -i inventory.ini gluster_nodes -m file -a "path=/mnt/gfs/nexus-data state=directory mode=0775"
  ```

- **Деплой стека**:

  ```bash
  APP_DOMAIN_NAME=localdomain docker stack deploy -c examples/nexus-sonatype-swarm/docker-compose.yml nexus
  ```

- **Доступ**:
  - `http://nexus.<APP_DOMAIN_NAME>`

Пароль админа при первом старте появляется внутри volume `admin.password` в `/nexus-data/admin.password` (на GFS это `/mnt/gfs/nexus-data/admin.password`).

## Повторный запуск и обслуживание

- Плейбук можно **безопасно перезапускать** для добавления новых менеджеров/воркеров или обновления пакетов/докера.
- Для служебных операций есть плейбуки `upgrade-docker`, `upgrade-packages`, `redeploy-apps`.

Примеры полезных команд (инвентори и параметры подставьте свои):

```bash
ansible -i inventory.ini all -m shell -a "yes | docker swarm leave --force" -b
ansible -i inventory.ini all -m shell -a "yes | sudo docker system prune -f" -b

ansible -i inventory.ini gluster_nodes -m shell -a "yes | sudo apt install -y software-properties-common"  --key-file /mnt/wslg/distro/home/assa/.ssh/id_ed25519 -u root

```

Step-by-Step Deployment GlusterFS (Run on all nodes)

Ubuntu/Debian: sudo apt install glusterfs-server -y.
Fedora/RHEL: yum install glusterfs-server -y.

Start Service: sudo systemctl start glusterd and sudo systemctl enable glusterd.

Prepare Bricks (Run on all nodes)
Format and mount the brick storage:
sudo mkfs.xfs -i size=512 /dev/sdb
sudo mkdir -p /glusterfs/bricks/10.20.10.5
echo '/dev/sdb /glusterfs/bricks/10.20.10.5 xfs defaults 0 0' | sudo tee -a /etc/fstab
sudo mount -a

Create a subdirectory (brick) for the volume: sudo mkdir -p /glusterfs/bricks/10.20.10.5/gfs
Create the Trusted Storage Pool (Run on Node 1 only)
Probe the other (ALL) nodes to join the cluster:
sudo gluster peer probe 10.20.10.6
sudo gluster peer probe 10.20.10.7

Verify connectivity: sudo gluster peer status.

Create and Start the Volume (Run on Node 1 only)
Create a replicated volume (high availability):
sudo gluster volume create gfs replica 3 \
10.20.10.5:/glusterfs/bricks/10.20.10.5/gfs \
10.20.10.6:/glusterfs/bricks/10.20.10.6/gfs \
10.20.10.7:/glusterfs/bricks/10.20.10.7/gfs force

Start the volume: sudo gluster volume start gfs
Mount the GlusterFS Volume (On Client Nodes)
sudo mkdir -p /mnt/glusterfs
sudo mount -t glusterfs 10.20.10.5:/gfs /mnt/gfs


Основные шаги настройки GlusterFS (Ubuntu):
Подготовка узлов: На всех узлах отредактируйте /etc/hosts, добавив IP-адреса и имена хостов:

sudo nano /etc/hosts
# Добавить: 192.168.10.11 node1, 192.168.10.12 node2 {Link: Cloud.ru https://cloud.ru/docs/evs/ug/topics/use-cases__evs-dedicated-clusterfs}

Установка GlusterFS:
sudo apt update
sudo apt install glusterfs-server -y
sudo systemctl start gluster thed && sudo systemctl enable glusterd

Создание пула (на node1):
sudo gluster peer probe node2
sudo gluster peer status

Создание и запуск тома (например, реплика 2):
sudo mkdir -p /data/glusterfs/brick1/gv0
sudo gluster volume create gv0 replica 2 node1:/data/glusterfs/brick1/gv0 node2:/data/glusterfs/brick1/gv0
sudo gluster volume start gv0

Монтирование (клиент):
sudo apt install glusterfs-client
sudo mount -t glusterfs node1:/gv0 /mnt/glusterfs

Удаление (rm) GlusterFS:
Для полного удаления (очистки) тома:
Остановить и удалить том: sudo gluster volume stop gv0 && sudo gluster volume delete gv0
Удалить данные: rm -rf /data/glusterfs/brick1/gv0
Удалить пакеты: sudo apt purge glusterfs-server -y && sudo apt autoremove -y