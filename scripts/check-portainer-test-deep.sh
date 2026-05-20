#!/bin/bash
set -euo pipefail
echo "=== docker ps portainer ==="
docker ps -a --filter name=portainer_portainer --no-trunc
echo "=== published ports on host ==="
ss -tlnp | grep -E ':9998|:9999' || echo "no 9998/9999 listen"
echo "=== recent events ==="
docker events --since 10m --until 0s --filter service=portainer_portainer 2>&1 | tail -20 || true
echo "=== service inspect state ==="
docker service inspect portainer_portainer --pretty 2>&1 | head -40
