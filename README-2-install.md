# README 2 - Основной install

## Минимальные требования

- 5 хостов Debian/Ubuntu (обычно: 1 HAProxy/Traefik, 3 managers + 2 workers )
- SSH доступ по ключу (наличие sudo не обязательно)
- Рабочая машина с Windows + wsl или Linux
- отдельный диск одинакового размера на [managers] под Gluster bricks (если необходимо реплики сетевого файлового хранилища держать на отдельном устройстве)

## Подготовка рабочего места перед деплоем

```bash
sudo apt update
sudo apt install -y ansible python3-venv python3-pip

git clone https://github.com/.../docker-swarm-ansible.git
cd docker-swarm-ansible

python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
```

## Проверка доступа

```bash
ansible all -i inventory*.ini -m ping
```

## Основной деплой

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory-dvsprtbt.ini -u root --private-key ~/.ssh/id_ed25519 playbooks/install.yml 2>&1 -vvv | tee inventory-dvsprtbt-$(date +%Y%m%d-%H%M).log
```

Если в WSL `ansible.cfg` игнорируется (каталог под `/mnt/c/...`), всегда задавайте `ANSIBLE_CONFIG="$PWD/ansible.cfg"`.

## Рабочий цикл с логами (без firewall на этапе отладки)

```bash
ANSIBLE_STDOUT_CALLBACK=yaml ANSIBLE_CONFIG="$PWD/ansible.cfg" \
ansible-playbook -i inventory.ini playbooks/install.yml -u root --private-key ~/.ssh/id_ed25519 \
  --skip-tags firewall-iptables -vvv 2>&1 | tee deploy-$(date +%Y%m%d-%H%M).log
```

Потом смотрите лог на `FAILED`, `fatal:`, `ERROR!`.

## Частичные запуски

```bash
ansible-playbook -i inventory.ini playbooks/install.yml --tags haproxy
ansible-playbook -i inventory.ini playbooks/plays/11-haproxy.yml
ansible-playbook -i inventory.ini playbooks/plays/03-firewall-iptables.yml
ansible-playbook -i inventory.ini playbooks/run-role.yml -e target_role=haproxy -e target_hosts=haproxy
```

## Syntax-check

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.ini playbooks/install.yml --syntax-check
```

Что будем запускать





Основной entrypoint: [playbooks/install.yml](playbooks/install.yml) — импортирует все стадии по порядку (plays/01-host-defaults.yml … plays/13-traefik.yml).



Конфиг Ansible: [ansible.cfg](ansible.cfg) задаёт roles_path=playbooks/roles и другие дефолты; inventory по умолчанию ./inventory.ini, поэтому в командах явно указываем ваш inventory-infra-btnxlocal.ini.

Команда «полный прогон, но только новый хост»





Dry-run (рекомендую сначала):

ansible-playbook -i inventory-infra-btnxlocal.ini playbooks/install.yml --limit 188.225.43.161 --check --diff





Реальный прогон:

ansible-playbook -i inventory-infra-btnxlocal.ini playbooks/install.yml --limit 188.225.43.161

На что обратить внимание (важно для --limit)





install.yml включает plays, которые таргетят разные группы. С --limit 188.225.43.161 выполнятся только те задачи, где этот хост попадает в hosts: (например, если он в [haproxy]/[traefik]). Остальные стадии будут просто пропущены.



Если на каком-то этапе окажется, что новой ноде нужно взаимодействовать с уже настроенными менеджерами (например, swarm join), то один --limit может быть недостаточен — тогда корректнее временно расширять лимит на нужные группы (например, --limit '188.225.43.161:swarm_managers'). Это станет видно по ошибкам вида «нужно выполнить действие на manager/leader».

Опциональные ускорители/обходы (если упирается)





Если есть проблемы/долгая отладка с firewall, в install.yml прямо указан вариант:

ansible-playbook -i inventory-infra-btnxlocal.ini playbooks/install.yml --limit 188.225.43.161 --skip-tags firewall-iptables

Мини-проверка перед прогоном





Убедиться, что SSH-ключ из inventory доступен с вашей машины (ansible_ssh_private_key_file=~/.ssh/id_ed25519) и что на хосте есть Python3 (в ansible.cfg задан ansible_python_interpreter=/usr/bin/python3).

