#!/bin/bash
# One-time: copy Portainer DB from shared /mnt/gfs to local bind path (if local DB missing).
set -euo pipefail
SRC="${1:-/mnt/gfs/portainer_gfs}"
DST="${2:-/var/lib/portainer/data}"
mkdir -p "$DST"
if [ -f "$DST/portainer.db" ]; then
  echo "Skip: $DST/portainer.db already exists"
  exit 0
fi
if [ ! -f "$SRC/portainer.db" ]; then
  echo "No source DB at $SRC/portainer.db — empty dst only"
  exit 0
fi
echo "Copying $SRC -> $DST"
rsync -a "$SRC/" "$DST/"
ls -la "$DST/portainer.db"
