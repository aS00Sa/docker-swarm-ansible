#!/usr/bin/env bash
# Деплой Portainer на тест (inventory-tstsprtbt.ini) с логом в корне репозитория.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LOG="inventory-tstsprtbt-10-portainer-$(date +%Y%m%d-%H%M).log"
export ANSIBLE_CONFIG="$ROOT/ansible.cfg"
echo "Log: $ROOT/$LOG"
ansible-playbook -i inventory-tstsprtbt.ini -u root --private-key ~/.ssh/id_ed25519 \
  playbooks/plays/10-portainer.yml -vv 2>&1 | tee "$LOG"
echo "Done. Check: grep -E 'FAILED|fatal|device:' $LOG"
