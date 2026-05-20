#!/bin/bash
CID=$(docker ps -aq -f name=portainer_portainer | head -1)
echo "CID=$CID"
if [ -n "$CID" ]; then
  docker inspect "$CID" --format 'Status={{.State.Status}} Error={{.State.Error}} ExitCode={{.State.ExitCode}}'
  docker logs "$CID" 2>&1 | tail -20
  docker start "$CID" 2>&1 || true
  sleep 2
  docker inspect "$CID" --format 'AfterStart Status={{.State.Status}} Error={{.State.Error}}'
  docker logs "$CID" 2>&1 | tail -20
fi
