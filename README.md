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
   ansible-playbook -i inventory.ini playbooks/install.yml
   ```

После выполнения будет настроен Swarm, GlusterFS, Traefik, HAProxy и Portainer.

## Что делает плейбук

- Обновляет пакеты и ставит зависимости.
- Устанавливает Docker CE и настраивает Swarm (1 лидер + 2 менеджера, опционально воркеры).
- Настраивает GlusterFS и Docker volume‑плагин.
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

## Повторный запуск и обслуживание

- Плейбук можно **безопасно перезапускать** для добавления новых менеджеров/воркеров или обновления пакетов/докера.
- Для служебных операций есть плейбуки `upgrade-docker`, `upgrade-packages`, `redeploy-apps`.

Примеры полезных команд (инвентори и параметры подставьте свои):

```bash
ansible -i inventory.ini all -m shell -a "yes | docker swarm leave --force" -b
ansible -i inventory.ini all -m shell -a "yes | sudo docker system prune -f" -b
```
