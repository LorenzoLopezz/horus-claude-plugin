#!/usr/bin/env bash
#
# Caché local en disco para resultados de tools del MCP "horus-project" (p. ej.
# listar-proyectos). Pensado para que un agente (Claude Code, Codex, OpenCode) consulte
# primero el caché y solo llame a la tool MCP cuando no haya una entrada válida.
#
# Uso:
#   cache.sh get <clave>              # imprime datos cacheados y sale 0, o sale 1 si no hay caché válido
#   cache.sh set <clave>               # lee JSON de stdin y lo guarda como entrada de caché
#   cache.sh clear <clave>             # borra la entrada de caché
#
# Variables de entorno:
#   HORUS_CACHE_TTL   TTL en segundos (default: 86400 = 1 día)
#
set -uo pipefail

CACHE_DIR="$HOME/.cache/horus-project-mcp"
TTL="${HORUS_CACHE_TTL:-86400}"

usage() {
  echo "Uso: cache.sh {get|set|clear} <clave>" >&2
  exit 2
}

cache_file() {
  echo "$CACHE_DIR/$1.json"
}

cmd_get() {
  local key="$1" file
  file=$(cache_file "$key")

  [ -f "$file" ] || exit 1

  local cached_at now
  cached_at=$(sed -n 's/^CACHED_AT=//p' "$file" | head -n1)
  [ -n "$cached_at" ] || exit 1

  now=$(date +%s)
  if [ $((now - cached_at)) -ge "$TTL" ]; then
    exit 1
  fi

  sed -n '/^DATA=$/,$p' "$file" | tail -n +2
}

cmd_set() {
  local key="$1" file tmp_file
  file=$(cache_file "$key")
  tmp_file="$file.tmp.$$"

  mkdir -p "$CACHE_DIR"

  {
    printf 'CACHED_AT=%s\n' "$(date +%s)"
    printf 'DATA=\n'
    cat
  } > "$tmp_file"

  mv "$tmp_file" "$file"
}

cmd_clear() {
  local key="$1" file
  file=$(cache_file "$key")
  rm -f "$file"
}

main() {
  local action="${1:-}" key="${2:-}"

  [ -n "$action" ] && [ -n "$key" ] || usage

  case "$action" in
    get) cmd_get "$key" ;;
    set) cmd_set "$key" ;;
    clear) cmd_clear "$key" ;;
    *) usage ;;
  esac
}

main "$@"
