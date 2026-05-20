#!/bin/bash
docker service ps portainer_portainer --no-trunc | head -8
CID=$(docker ps -aq -f name=portainer_portainer | head -1)
echo "CID=$CID"
if [ -n "$CID" ]; then docker logs "$CID" 2>&1 | tail -8; fi
timeout 3 ls -la /mnt/gfs/portainer_gfs/ || echo "ls timeout on gfs"
