#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/mnt/c/Users/User/git/docker-swarm-ansible"
cd "$PROJECT_DIR"

export ANSIBLE_CONFIG="$PROJECT_DIR/ansible.cfg"
LOG_FILE="$PROJECT_DIR/inventory-dvsprtbt-install-$(date +%Y%m%d-%H%M%S).log"

echo "[INFO] Logging to $LOG_FILE"
ansible-playbook -i inventory-dvsprtbt.ini -u root --private-key ~/.ssh/id_ed25519 playbooks/install.yml -vvv 2>&1 | tee "$LOG_FILE"
