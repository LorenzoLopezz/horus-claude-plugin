# Horus Project — plugin para Claude Code

Marketplace público con el plugin `horus-project`, que conecta Claude Code con el servidor MCP de
[Horus Project](https://horus.egob.sv) (proyectos y nodos) y agrega la skill que explica cómo
usarlo. El código del producto vive en un repo aparte; aquí solo está lo que Claude Code necesita
descargar.

## Contenido

```
.claude-plugin/marketplace.json          # catálogo
plugins/horus-project/
├── .claude-plugin/plugin.json           # manifiesto del plugin
├── .mcp.json                            # servidor MCP http + headersHelper
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
2. **Environment variables**: agrega `HORUS_CLIENT_ID` y `HORUS_REFRESH_TOKEN` (o `HORUS_TOKEN`).

Si el repo del proyecto tiene su `.claude/` ignorado, acuérdate de destaparlo, porque si no el
settings nunca llega a la sesión:

```gitignore
/.claude/*
!/.claude/settings.json
```

## Cómo resuelve la autenticación

Horus expone OAuth 2.1 con `authorization_code` + `refresh_token`, PKCE y cliente público
(`token_endpoint_auth_methods_supported: ["none"]`). No hay `client_credentials`, así que el
plugin usa `headersHelper` para cubrir los dos escenarios:

| Escenario | Variables | Qué hace `scripts/headers.sh` |
| --- | --- | --- |
| Sesión local | ninguna | Devuelve `{}` y deja que Claude Code haga el OAuth por navegador desde `/mcp` |
| Sesión cloud, token directo | `HORUS_TOKEN` | Manda `Authorization: Bearer $HORUS_TOKEN` |
| Sesión cloud, refresh | `HORUS_REFRESH_TOKEN`, `HORUS_CLIENT_ID` | Canjea el refresh token en `/oauth/token` en cada conexión y guarda el refresh rotado en `$CLAUDE_PLUGIN_DATA/refresh_token` |

`HORUS_MCP_URL` permite apuntar a otra instancia (por defecto `https://horus.egob.sv/mcp/proyectos`);
`HORUS_BASE_URL` solo hace falta si el endpoint de OAuth no vive en el mismo host que el MCP.

Cuando una tool devuelve 401 o 403, Claude Code vuelve a ejecutar el helper, reconecta con los
encabezados nuevos y reintenta la llamada una vez.

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
  las puede leer, y los propios docs de Claude Code desaconsejan poner credenciales ahí. Úsalo con
  un usuario de servicio de alcance reducido, no con tu cuenta personal.
- **El refresh token de Passport rota y se revoca al usarse.** El helper guarda el token rotado en
  `$CLAUDE_PLUGIN_DATA`, con lo que las reconexiones dentro de una misma máquina o sesión siguen
  funcionando; pero el valor que dejaste en las variables de entorno queda inservible tras el primer
  canje, así que una sesión cloud nueva necesita uno fresco.
- **La salida buena es del lado servidor**: agregar `client_credentials` (o un endpoint de token de
  servicio de larga vida) al OAuth de Horus elimina las dos limitaciones anteriores y deja el plugin
  autosuficiente en la nube. Mientras tanto, la alternativa sin mantenimiento es registrar
  `https://horus.egob.sv/mcp/proyectos` como *custom connector* en
  [claude.ai/customize/connectors](https://claude.ai/customize/connectors): el OAuth se hace en el
  navegador, los tokens quedan del lado de Anthropic y el tráfico no pasa por la lista de dominios
  permitidos. Esa vía da el MCP pero no la skill; el plugin sigue siendo útil para eso.
- `scripts/cache.sh` es una copia del stub que el backend de Horus sirve a sus instaladores
  (`backend/resources/stubs/mcp/cache-horus-project-mcp.sh.stub`). Si cambia allá, cópialo aquí.

## Problemas frecuentes

| Síntoma | Causa probable |
| --- | --- |
| `/mcp` muestra el servidor como *needs authentication* | No hay token en cloud, o el refresh ya fue revocado |
| El plugin no aparece en la sesión cloud | `.claude/settings.json` no está commiteado en el repo del proyecto |
| Las tools existen pero todo devuelve 401 | `horus.egob.sv` no está en la lista de dominios permitidos del entorno |
| `Plugin directory not found` | La ruta `source` de `marketplace.json` no coincide con la carpeta del plugin |
