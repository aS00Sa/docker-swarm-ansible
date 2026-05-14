#!/usr/bin/env bash
# Сверка имён пакетов из Ubuntu cloud image manifest с локально установленными (dpkg).
# Запускать на целевой машине Debian/Ubuntu (нужны dpkg-query и curl или локальный файл).
#
# Пример (URL по умолчанию — noble 20260216, можно передать свой):
#   ./scripts/compare-ubuntu-cloud-manifest-packages.sh
#   ./scripts/compare-ubuntu-cloud-manifest-packages.sh \
#     'https://cloud-images.ubuntu.com/noble/20260216/noble-server-cloudimg-amd64.manifest'
#   ./scripts/compare-ubuntu-cloud-manifest-packages.sh /path/to/noble-server-cloudimg-amd64.manifest
#
# Результаты по умолчанию пишутся в каталог ./manifest-pkg-compare-ГГГГММДД-ЧЧММСС/ (текущая директория).
# Явный каталог:
#   MANIFEST_COMPARE_OUT=./my-diff ./scripts/compare-ubuntu-cloud-manifest-packages.sh 'URL'
# Только консоль, без файлов:
#   MANIFEST_COMPARE_NO_SAVE=1 ./scripts/compare-ubuntu-cloud-manifest-packages.sh

set -euo pipefail

DEFAULT_MANIFEST_URL='https://cloud-images.ubuntu.com/noble/20260216/noble-server-cloudimg-amd64.manifest'
MANIFEST_INPUT="${1:-$DEFAULT_MANIFEST_URL}"
MANIFEST_COMPARE_OUT="${MANIFEST_COMPARE_OUT:-}"
MANIFEST_COMPARE_NO_SAVE="${MANIFEST_COMPARE_NO_SAVE:-}"

step() {
  printf '\n=== %s ===\n' "$1"
}

die() {
  echo "Ошибка: $*" >&2
  exit 1
}

step "Проверка: нужны dpkg-query и comm"
command -v dpkg-query >/dev/null || die "dpkg-query не найден — скрипт предназначен для Debian/Ubuntu."
command -v comm >/dev/null || die "comm не найден."

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/manifest-pkg-compare.XXXXXX")"
cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

MANIFEST_RAW="$WORKDIR/manifest.raw"
MANIFEST_PKGS="$WORKDIR/manifest_pkgs.txt"
INSTALLED_PKGS="$WORKDIR/installed_pkgs.txt"
MISSING_LOCAL="$WORKDIR/missing_on_local.txt"
EXTRA_LOCAL="$WORKDIR/extra_on_local.txt"

step "Шаг 1: загрузка или чтение манифеста"
if [[ "$MANIFEST_INPUT" =~ ^https?:// ]]; then
  command -v curl >/dev/null || die "Для URL нужен curl."
  curl -fsSL -o "$MANIFEST_RAW" -- "$MANIFEST_INPUT"
else
  [[ -f "$MANIFEST_INPUT" ]] || die "Файл не найден: $MANIFEST_INPUT"
  cp -- "$MANIFEST_INPUT" "$MANIFEST_RAW"
fi

step "Шаг 2: извлечение имён пакетов из манифеста (только первое поле строки «пакет версия»)"
# Отбрасываем служебные строки без «пакет + версия» (заголовки экспорта и т.п.).
grep -E '^[a-z0-9][a-z0-9+.-]*(:[a-z0-9][a-z0-9+.-]*)?[[:space:]]+[^[:space:]]' "$MANIFEST_RAW" \
  | awk '{print $1}' \
  | sort -u >"$MANIFEST_PKGS"
echo "Уникальных имён в манифесте: $(wc -l <"$MANIFEST_PKGS")"

step "Шаг 3: локально установленные пакеты (binary:Package, как в dpkg)"
dpkg-query -W -f='${binary:Package}\n' | sort -u >"$INSTALLED_PKGS"
echo "Уникальных имён среди установленных: $(wc -l <"$INSTALLED_PKGS")"

step "Шаг 4: есть в манифесте, но не установлены локально (comm -23)"
comm -23 "$MANIFEST_PKGS" "$INSTALLED_PKGS" >"$MISSING_LOCAL"
echo "Таких пакетов: $(wc -l <"$MISSING_LOCAL")"
if [[ -s "$MISSING_LOCAL" ]]; then
  cat "$MISSING_LOCAL"
else
  echo "(пусто — все имена из манифеста присутствуют среди установленных)"
fi

step "Шаг 5: установлены локально, но нет в манифесте (comm -13)"
comm -13 "$MANIFEST_PKGS" "$INSTALLED_PKGS" >"$EXTRA_LOCAL"
echo "Таких пакетов: $(wc -l <"$EXTRA_LOCAL")"
if [[ -s "$EXTRA_LOCAL" ]]; then
  cat "$EXTRA_LOCAL"
else
  echo "(пусто — среди установленных нет имён вне манифеста)"
fi

step "Шаг 6: пересечение (и в манифесте, и установлены)"
BOTH="$WORKDIR/both.txt"
comm -12 "$MANIFEST_PKGS" "$INSTALLED_PKGS" >"$BOTH"
echo "Таких пакетов: $(wc -l <"$BOTH")"

if [[ -z "$MANIFEST_COMPARE_NO_SAVE" ]]; then
  if [[ -z "$MANIFEST_COMPARE_OUT" ]]; then
    MANIFEST_COMPARE_OUT="$(pwd)/manifest-pkg-compare-$(date +%Y%m%d-%H%M%S)"
  fi
  step "Сохранение списков в $MANIFEST_COMPARE_OUT"
  mkdir -p -- "$MANIFEST_COMPARE_OUT"
  {
    echo "manifest_input=$MANIFEST_INPUT"
    echo "generated_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "host=$(hostname -f 2>/dev/null || hostname)"
  } >"$MANIFEST_COMPARE_OUT/report_meta.txt"
  cp -- "$MANIFEST_RAW" "$MANIFEST_COMPARE_OUT/manifest.raw"
  cp -- "$MANIFEST_PKGS" "$MANIFEST_COMPARE_OUT/manifest_pkgs.txt"
  cp -- "$INSTALLED_PKGS" "$MANIFEST_COMPARE_OUT/installed_pkgs.txt"
  cp -- "$MISSING_LOCAL" "$MANIFEST_COMPARE_OUT/missing_on_local.txt"
  cp -- "$EXTRA_LOCAL" "$MANIFEST_COMPARE_OUT/extra_on_local.txt"
  cp -- "$BOTH" "$MANIFEST_COMPARE_OUT/in_both.txt"
  echo "Файлы отчёта: $MANIFEST_COMPARE_OUT"
fi
