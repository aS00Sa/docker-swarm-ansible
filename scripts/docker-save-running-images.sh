#!/usr/bin/env bash
# Сохранить в .tar образы, которые реально используют *запущенные* контейнеры (docker ps).
# Удобно для Swarm: нужный тег в `docker images` может не отображаться, но у running task
# всё равно есть локальный image id — его и сохраняем (docker inspect → docker save).
#
# Пример: только релиз 1.1.5 в строке образа и имена контейнеров bethome / inhome:
#   IMAGE_REF_PATTERN='1\.1\.5' CONTAINER_NAME_PATTERN='bethome|inhome' \
#     ./scripts/docker-save-running-images.sh /backup/rel-1.1.5
#
# Переменные окружения:
#   IMAGE_REF_PATTERN   — если задан, оставляем контейнеры, у которых колонка Image (и/или Config.Image)
#                         совпадает с grep -E (пример: 1\.1\.5 или myregistry/app.*1\.1\.5).
#   CONTAINER_NAME_PATTERN — если задан, grep -E по полю Names (как в docker ps).
#   (без фильтров — все запущенные контейнеры на узле, каждый уникальный image id один раз).

set -euo pipefail

OUT_DIR="${1:-./docker-running-saves-$(date +%Y%m%d-%H%M)}"
IMAGE_REF_PATTERN="${IMAGE_REF_PATTERN:-}"
CONTAINER_NAME_PATTERN="${CONTAINER_NAME_PATTERN:-}"

mkdir -p "$OUT_DIR"

sanitize() {
  echo "$1" | sed 's/[^A-Za-z0-9._@-]/_/g' | sed 's/__*/_/g'
}

matches_ref() {
  local img_col="$1"
  local cfg_img="$2"
  [[ -z "$IMAGE_REF_PATTERN" ]] && return 0
  echo "$img_col" | grep -qE "$IMAGE_REF_PATTERN" && return 0
  echo "$cfg_img" | grep -qE "$IMAGE_REF_PATTERN" && return 0
  return 1
}

matches_name() {
  local names="$1"
  [[ -z "$CONTAINER_NAME_PATTERN" ]] && return 0
  echo "$names" | grep -qE "$CONTAINER_NAME_PATTERN"
}

declare -A SEEN_IMG=()

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  cid="${line%%$'\t'*}"
  rest="${line#*$'\t'}"
  img_col="${rest%%$'\t'*}"
  names="${rest#*$'\t'}"

  matches_name "$names" || continue

  cfg_img=$(docker inspect -f '{{.Config.Image}}' "$cid" 2>/dev/null || true)
  matches_ref "$img_col" "$cfg_img" || continue

  img_target=$(docker inspect -f '{{.Image}}' "$cid" 2>/dev/null || true)
  [[ -z "$img_target" ]] && continue

  if [[ -n "${SEEN_IMG[$img_target]:-}" ]]; then
    continue
  fi
  SEEN_IMG[$img_target]=1

  base_name="${cfg_img:-$img_col}"
  [[ -z "$base_name" || "$base_name" == "<none>" ]] && base_name="$img_target"
  fname=$(sanitize "$base_name")
  out="${OUT_DIR}/${fname}.tar"

  echo "save running -> $img_target ($base_name) -> $out"
  if ! docker save -o "$out" "$img_target"; then
    echo "warn: docker save failed for $img_target (нет локальных слоёв?). Пробуйте на ноде, где task запущен, или скачайте из registry." >&2
    unset "SEEN_IMG[$img_target]"
  fi
done < <(docker ps --format '{{.ID}}\t{{.Image}}\t{{.Names}}')

if ((${#SEEN_IMG[@]} == 0)); then
  echo "warn: no matching running containers (filters: IMAGE_REF_PATTERN=${IMAGE_REF_PATTERN:-<none>} CONTAINER_NAME_PATTERN=${CONTAINER_NAME_PATTERN:-<none>})." >&2
fi

echo "done. Archives in: $OUT_DIR"
