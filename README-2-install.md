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
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory-dev.ini -u root --private-key ~/.ssh/id_ed25519 playbooks/install.yml 2>&1 -vvv | tee install-dev-$(date +%Y%m%d-%H%M).log
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

