#!/usr/bin/env bash
set -uo pipefail

# Estado
ESTADO_DIR="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/horus-project-plugin}"
ARCHIVO_REFRESH="${ESTADO_DIR}/refresh_token"

# Endpoints
MCP_URL="${CLAUDE_CODE_MCP_SERVER_URL:-${HORUS_MCP_URL:-https://horus.egob.sv/mcp/proyectos}}"
BASE_URL="${HORUS_BASE_URL:-$(printf '%s' "$MCP_URL" | sed -E 's#^(https?://[^/]+).*#\1#')}"
CLIENT_CREDENTIALS_URL="${BASE_URL}/api/oauth/token"
REFRESH_URL="${BASE_URL}/oauth/token"

emitir_bearer() {
  printf '{"Authorization": "Bearer %s"}\n' "$1"
}

sin_encabezados() {
  printf '{}\n'
  exit 0
}

extraer_campo() {
  printf '%s' "$2" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
}

if [ -n "${HORUS_TOKEN:-}" ]; then
  emitir_bearer "$HORUS_TOKEN"
  exit 0
fi

if [ -n "${HORUS_CLIENT_ID:-}" ] && [ -n "${HORUS_CLIENT_SECRET:-}" ]; then
  respuesta="$(curl -sS -m 15 -X POST "$CLIENT_CREDENTIALS_URL" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=client_credentials' \
    --data-urlencode "client_id=${HORUS_CLIENT_ID}" \
    --data-urlencode "client_secret=${HORUS_CLIENT_SECRET}" 2>/dev/null)" || sin_encabezados

  access_token="$(extraer_campo access_token "$respuesta")"
  [ -n "$access_token" ] || sin_encabezados

  emitir_bearer "$access_token"
  exit 0
fi

refresh_token="${HORUS_REFRESH_TOKEN:-}"
if [ -r "$ARCHIVO_REFRESH" ]; then
  refresh_token="$(cat "$ARCHIVO_REFRESH")"
fi

if [ -z "$refresh_token" ] || [ -z "${HORUS_OAUTH_CLIENT_ID:-}" ]; then
  sin_encabezados
fi

respuesta="$(curl -sS -m 15 -X POST "$REFRESH_URL" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=refresh_token' \
  --data-urlencode "refresh_token=${refresh_token}" \
  --data-urlencode "client_id=${HORUS_OAUTH_CLIENT_ID}" \
  --data-urlencode 'scope=mcp:use' 2>/dev/null)" || sin_encabezados

access_token="$(extraer_campo access_token "$respuesta")"
[ -n "$access_token" ] || sin_encabezados

nuevo_refresh="$(extraer_campo refresh_token "$respuesta")"
if [ -n "$nuevo_refresh" ]; then
  mkdir -p "$ESTADO_DIR" 2>/dev/null && {
    umask 077
    printf '%s' "$nuevo_refresh" > "${ARCHIVO_REFRESH}.tmp.$$" &&
      mv "${ARCHIVO_REFRESH}.tmp.$$" "$ARCHIVO_REFRESH"
  }
fi

emitir_bearer "$access_token"
