#!/bin/bash
set -euo pipefail
echo "=== stack services ==="
docker stack services portainer
echo "=== portainer tasks ==="
docker service ps portainer_portainer --no-trunc
echo "=== portainer logs (last 30) ==="
docker service logs portainer_portainer 2>&1 | tail -30 || true
echo "=== nodes ==="
docker node ls
echo "=== gfs path on this host ==="
hostname
ls -la /mnt/gfs/portainer_gfs 2>&1 || true
