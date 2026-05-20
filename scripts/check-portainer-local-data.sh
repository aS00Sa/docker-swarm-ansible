#!/bin/bash
set -euo pipefail
echo "=== stack ==="
docker stack services portainer
echo "=== bind path ==="
LOCAL=/var/lib/portainer/data
ls -la "$LOCAL" 2>&1 || true
findmnt "$LOCAL" 2>&1 || findmnt /var/lib 2>&1 || true
df -h "$LOCAL" 2>&1 || true
echo "=== stack volume device ==="
grep -A5 portainer_data /home/root/stacks/portainer-agent-stack.yml || true
echo "=== find old db on gfs ==="
find /mnt/gfs -name portainer.db 2>/dev/null | head -5 || true
