#!/bin/bash
cat /home/root/stacks/portainer-agent-stack.yml
echo "---"
docker stack services portainer
docker service logs portainer_portainer 2>&1 | tail -10
