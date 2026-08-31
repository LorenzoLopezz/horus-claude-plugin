# Horus Project — plugins para Claude Code y Codex

Marketplaces públicos con el plugin `horus-project`, que conecta Claude Code al servidor MCP de
[Horus Project](https://horus.egob.sv) (proyectos, nodos y equipos) y habilita en Codex la Skill que
explica cómo usarlo. El código del producto vive en un repo aparte; aquí solo está lo que cada cliente
necesita descargar.

## Contenido

```
.claude-plugin/marketplace.json          # catálogo de Claude Code
.agents/plugins/marketplace.json         # catálogo de Codex
plugins/horus-project/
├── .claude-plugin/plugin.json           # manifiesto de Claude Code
├── .codex-plugin/plugin.json            # manifiesto de Codex
├── .mcp.json                            # servidor MCP http + headersHelper para Claude Code
├── scripts/headers.sh                   # resuelve el Authorization en cada conexión
├── scripts/cache.sh                     # caché en disco del listado de proyectos
└── skills/horus-project/SKILL.md        # skill de uso del MCP
```

Una vez instalado, las tools quedan como `mcp__plugin_horus-project_horus-project__<tool>` y la
skill se invoca con `/horus-project:horus-project`.

## Instalar en Claude Code local

```
/plugin marketplace add LorenzoLopezz/horus-claude-plugin
/plugin install horus-project@horus
/reload-plugins
```

Después, `/mcp` → `horus-project` → iniciar sesión en el navegador. Verifica con `/mcp` que el
servidor quede en `connected`.

Si ya tenías el MCP `horus-project` configurado a mano en `~/.claude.json` (por el instalador
`install.sh` del servidor), quítalo antes para no tener el servidor duplicado:

```bash
claude mcp remove horus-project
```

## Instalar en Codex

Agrega el marketplace público una sola vez por máquina e instala el plugin. La Skill queda
disponible junto con el plugin:

```bash
codex plugin marketplace add LorenzoLopezz/horus-claude-plugin
codex plugin add horus-project@horus
```

Después, inicia una tarea nueva para que Codex cargue la Skill. El manifiesto de Codex empaqueta la
Skill y no duplica el servidor MCP: si todavía no lo tienes configurado, agrégalo y autentícalo una
sola vez:

```bash
codex mcp add horus-project --url https://horus.egob.sv/mcp/proyectos
codex mcp login horus-project
```

Si `codex mcp list` ya muestra `horus-project`, omite esos dos comandos.

## Instalar en sesiones cloud (claude.ai/code)

En cloud no existe `/plugin`: el plugin se declara en el repo donde trabajas y se instala solo al
arrancar la sesión. Agrega esto al `.claude/settings.json` de ese proyecto y commitéalo:

```json
{
  "extraKnownMarketplaces": {
    "horus": {
      "source": { "source": "github", "repo": "LorenzoLopezz/horus-claude-plugin" }
    }
  },
  "enabledPlugins": { "horus-project@horus": true }
}
```

Como este marketplace es público y vive en GitHub, la sesión lo descarga sin credenciales y sin
tocar la lista de dominios permitidos.

Falta configurar el entorno cloud, en claude.ai/code → icono de nube sobre la caja de mensajes →
engranaje del entorno:

1. **Network access**: elige **Custom**, agrega `horus.egob.sv` y marca *Also include default list
   of common package managers* para no perder npm, PyPI y compañía.
2. **Environment variables**: agrega `HORUS_CLIENT_ID` y `HORUS_CLIENT_SECRET` de la credencial de
   cliente (ver [Crear la credencial de cliente](#crear-la-credencial-de-cliente)).

Si el repo del proyecto tiene su `.claude/` ignorado, acuérdate de destaparlo, porque si no el
settings nunca llega a la sesión:

```gitignore
/.claude/*
!/.claude/settings.json
```

## Cómo resuelve la autenticación

El MCP de Horus acepta dos esquemas: el OAuth 2.1 de Passport (`authorization_code` + PKCE, para
clientes con navegador) y una credencial de cliente (`client_credentials`) para agentes que no
pueden abrir un navegador. `scripts/headers.sh` elige según las variables presentes:

| Escenario | Variables | Qué hace `scripts/headers.sh` |
| --- | --- | --- |
| Sesión local | ninguna | Devuelve `{}` y deja que Claude Code haga el OAuth por navegador desde `/mcp` |
| Sesión cloud (recomendado) | `HORUS_CLIENT_ID`, `HORUS_CLIENT_SECRET` | Pide un access token a `/api/oauth/token` con `grant_type=client_credentials` en cada conexión |
| Token puntual | `HORUS_TOKEN` | Manda `Authorization: Bearer $HORUS_TOKEN` |
| Refresh de Passport | `HORUS_REFRESH_TOKEN`, `HORUS_OAUTH_CLIENT_ID` | Canjea el refresh token en `/oauth/token` y guarda el rotado en `$CLAUDE_PLUGIN_DATA/refresh_token` |

`HORUS_MCP_URL` permite apuntar a otra instancia (por defecto `https://horus.egob.sv/mcp/proyectos`);
`HORUS_BASE_URL` solo hace falta si los endpoints de OAuth no viven en el mismo host que el MCP.

Cuando una tool devuelve 401 o 403, Claude Code vuelve a ejecutar el helper, reconecta con los
encabezados nuevos y reintenta la llamada una vez.

### Crear la credencial de cliente

Desde tu cuenta en Horus, en la sección de credenciales OAuth (`/api/cuenta/oauth-client`), crea una
credencial y otórgale las acciones que quieras que el agente pueda ejecutar; como mínimo
`proyecto_listar` para listar proyectos. Guarda el `client_id` y el `client_secret` que devuelve.

La credencial queda asociada a tu usuario: el MCP actúa **como vos**, sobre los proyectos en los que
participás y con los permisos que le concediste a esa credencial, nunca más que eso. El access token
que emite dura lo que indique `OAUTH_ACCESS_TOKEN_TTL_MINUTES` (60 minutos por defecto) y el helper
pide uno nuevo en cada conexión, así que no hay nada que renovar a mano.

## Publicar cambios

```bash
claude plugin validate ./plugins/horus-project
claude plugin validate .
git add -A
git commit -m "feat(plugin): describe el cambio"
git push origin main
```

Los usuarios refrescan su copia con `/plugin marketplace update horus`. Cada commit cuenta como
versión nueva salvo que `version` esté fijada en `plugin.json`; súbela ahí cuando quieras que la
actualización se distribuya.

## Limitaciones conocidas

- **Las variables del entorno cloud no son un almacén de secretos.** Cualquiera que use ese entorno
  puede leer el `client_secret`, y los propios docs de Claude Code desaconsejan poner credenciales
  ahí. Crea una credencial dedicada, concédele solo las acciones que el agente necesita, y revócala
  desde Horus si el entorno deja de ser tuyo.
- **El grant `client_credentials` no se anuncia en el discovery OAuth del MCP.** Los metadatos de
  `/.well-known/oauth-authorization-server` describen el servidor de Passport, que vive en otro
  endpoint (`/oauth/token`); la credencial de cliente se emite en `/api/oauth/token`. Por eso el
  plugin la conoce por configuración y no por descubrimiento: un cliente MCP genérico solo verá el
  flujo de navegador.
- **El refresh token de Passport rota y se revoca al usarse.** Solo aplica al modo de respaldo
  `HORUS_REFRESH_TOKEN`: el valor que dejes en las variables de entorno queda inservible tras el
  primer canje. Usa `client_credentials` en su lugar.
- `scripts/cache.sh` es una copia del stub que el backend de Horus sirve a sus instaladores
  (`backend/resources/stubs/mcp/cache-horus-project-mcp.sh.stub`). Si cambia allá, cópialo aquí.

## Problemas frecuentes

| Síntoma | Causa probable |
| --- | --- |
| `/mcp` muestra el servidor como *needs authentication* | No hay token en cloud, o el refresh ya fue revocado |
| El plugin no aparece en la sesión cloud | `.claude/settings.json` no está commiteado en el repo del proyecto |
| El helper devuelve `{}` y el MCP pide autenticación | El `client_secret` es incorrecto, la credencial está inactiva o no alcanza `/api/oauth/token` |
| Las tools existen pero todo devuelve 401 | `horus.egob.sv` no está en la lista de dominios permitidos del entorno |
| `Plugin directory not found` | La ruta `source` de `marketplace.json` no coincide con la carpeta del plugin |
