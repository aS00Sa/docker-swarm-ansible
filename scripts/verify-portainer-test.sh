#!/bin/bash
set -euo pipefail
echo "=== stack compose bind ==="
grep -A3 'portainer_data:' /home/root/stacks/portainer-agent-stack.yml || grep device /home/root/stacks/portainer-agent-stack.yml
echo "=== services ==="
docker stack services portainer
echo "=== portainer UI tasks ==="
docker service ps portainer_portainer --no-trunc | head -5
echo "=== gfs data dir ==="
ls -la /mnt/gfs/portainer_gfs/ 2>&1 | head -15
