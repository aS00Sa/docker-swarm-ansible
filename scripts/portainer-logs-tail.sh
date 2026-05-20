#!/bin/bash
docker service logs portainer_portainer 2>&1 | tail -15
docker ps --filter name=portainer_portainer --format '{{.Names}} {{.Status}}'
ls -la /var/lib/portainer/data/
