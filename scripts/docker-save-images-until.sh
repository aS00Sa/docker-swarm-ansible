#!/usr/bin/env bash
# Сохранить в отдельные .tar образы, чей возраст соответствует логике
#   docker image prune ... --filter "until=<duration>" (образ создан *раньше*, чем указанная давность).
#
# Примечание: у `docker image ls` / `docker images` нет фильтра until=24h; критерий воспроизведён через Created.
#
# Использование:
#   chmod +x scripts/docker-save-images-until.sh
#   HOURS=24 ./scripts/docker-save-images-until.sh [каталог_вывода]
#
# Переменные окружения:
#   HOURS          — давность в часах (по умолчанию 24).
#   SKIP_DUP_ID=1  — не делать второй save для того же image ID (экономия места, по умолчанию 1).
#   FILTER_BY_CONTAINER_NAME=1 — учитывать только образы контейнеров, чьи имена совпадают с шаблоном (по умолчанию 1).
#   CONTAINER_NAME_PATTERN — ERE для поля Names (docker ps), по умолчанию bethome|inhome.

set -euo pipefail

HOURS="${HOURS:-24}"
OUT_DIR="${1:-./docker-image-saves-${HOURS}h-$(date +%Y%m%d-%H%M)}"
SKIP_DUP_ID="${SKIP_DUP_ID:-1}"
FILTER_BY_CONTAINER_NAME="${FILTER_BY_CONTAINER_NAME:-1}"
CONTAINER_NAME_PATTERN="${CONTAINER_NAME_PATTERN:-bethome|inhome}"

SECONDS_AGO=$((HOURS * 3600))
NOW_EPOCH=$(date +%s)
CUTOFF_EPOCH=$((NOW_EPOCH - SECONDS_AGO))

mkdir -p "$OUT_DIR"

sanitize() {
  # безопасное имя файла из repository:tag
  echo "$1" | sed 's/[^A-Za-z0-9._@-]/_/g' | sed 's/__*/_/g'
}

# Первые 12 hex символов image id (как в docker images) для сопоставления с inspect контейнера.
img_id_prefix() {
  local id="$1"
  id="${id#sha256:}"
  echo "${id:0:12}"
}

# Образы, которые используются контейнерами с подходящим именем (Names).
declare -A IMG_ALLOWED=()
if [[ "${FILTER_BY_CONTAINER_NAME}" == "1" || "${FILTER_BY_CONTAINER_NAME,,}" == "true" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    cid="${line%%$'\t'*}"
    names="${line#*$'\t'}"
    echo "$names" | grep -qE "$CONTAINER_NAME_PATTERN" || continue
    full=$(docker inspect -f '{{.Image}}' "$cid" 2>/dev/null || true)
    [[ -z "$full" ]] && continue
    prefix=$(img_id_prefix "$full")
    IMG_ALLOWED[$prefix]=1
  done < <(docker ps -a --format '{{.ID}}\t{{.Names}}')
  if ((${#IMG_ALLOWED[@]} == 0)); then
    echo "warn: no containers matched CONTAINER_NAME_PATTERN=$CONTAINER_NAME_PATTERN; nothing to save." >&2
  fi
fi

declare -A SEEN_IDS=()

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  img_id="${line%% *}"
  ref="${line#* }"

  [[ -z "$img_id" || "$img_id" == "<none>" ]] && continue

  if [[ "${FILTER_BY_CONTAINER_NAME}" == "1" || "${FILTER_BY_CONTAINER_NAME,,}" == "true" ]]; then
    if [[ -z "${IMG_ALLOWED[$img_id]:-}" ]]; then
      continue
    fi
  fi

  if [[ "${SKIP_DUP_ID:-}" == "1" || "${SKIP_DUP_ID,,}" == "true" ]]; then
    if [[ -n "${SEEN_IDS[$img_id]:-}" ]]; then
      echo "skip duplicate ID $img_id ($ref)"
      continue
    fi
  fi

  created=$(docker inspect -f '{{.Created}}' "$img_id" 2>/dev/null || true)
  [[ -z "$created" ]] && continue

  if ! created_epoch=$(date -d "$created" +%s 2>/dev/null); then
    echo "warn: cannot parse Created for $img_id: $created" >&2
    continue
  fi

  if ((created_epoch >= CUTOFF_EPOCH)); then
    continue
  fi

  fname=$(sanitize "$ref")
  if [[ -z "$fname" || "$fname" == "_" ]]; then
    fname=$(sanitize "$img_id")
  fi
  out="${OUT_DIR}/${fname}.tar"

  echo "save (older than ${HOURS}h) $ref -> $out"
  docker save -o "$out" "$ref"
  SEEN_IDS[$img_id]=1
done < <(docker images --format "{{.ID}} {{.Repository}}:{{.Tag}}")

echo "done. Archives in: $OUT_DIR"
