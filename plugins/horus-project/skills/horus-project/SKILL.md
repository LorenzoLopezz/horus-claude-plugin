---
name: horus-project
description: Explica cómo usar el servidor MCP "horus-project" (proyectos y nodos de Horus Project) y qué hacer cuando una tool falla por token OAuth expirado.
---

# MCP horus-project

El servidor MCP "horus-project" expone los proyectos y nodos del usuario autenticado:
listar proyectos, ver/crear/actualizar nodos, y mover nodos por su workflow. El acceso está
limitado a los proyectos en los que el usuario participa y a los permisos que tiene asignados.

Las tools de este plugin aparecen con el nombre `mcp__plugin_horus-project_horus-project__<tool>`.

## Autenticación

El servidor usa OAuth 2.1 (authorization_code + PKCE).

- En sesiones locales, el login se hace una sola vez en el navegador desde `/mcp`.
- En sesiones cloud no hay navegador: el plugin toma el token de `HORUS_TOKEN`, o lo renueva
  con `HORUS_REFRESH_TOKEN` + `HORUS_CLIENT_ID`, según lo configurado en el entorno.

## Caché local del listado de proyectos

Antes de llamar a la tool `listar-proyectos`, ejecuta primero:

    "${CLAUDE_PLUGIN_ROOT}/scripts/cache.sh" get proyectos

Si el comando imprime datos y termina con código 0, usa ese JSON como resultado y NO llames a
la tool MCP. Si termina con código 1 (sin salida), llama a `listar-proyectos` normalmente y
guarda el resultado para que la próxima consulta (hasta por 1 día) no necesite ir al servidor:

    <resultado-json-de-la-tool> | "${CLAUDE_PLUGIN_ROOT}/scripts/cache.sh" set proyectos

Si el usuario indica explícitamente que la lista de proyectos cambió (se creó/eliminó un
proyecto) y quiere ver el cambio reflejado de inmediato, ejecuta
`"${CLAUDE_PLUGIN_ROOT}/scripts/cache.sh" clear proyectos` antes de volver a listar.

En Windows sin bash, usa `~/.horus-project-mcp/bin/cache.ps1` con los mismos subcomandos, o
salta el caché y llama a la tool directamente.

## Actualizar un nodo

La tool `actualizar-nodo` modifica título, detalle (Markdown), prioridad, peso estimado/revisado,
fechas, nodo padre y orden de un nodo existente. Solo se envían y modifican los campos indicados
explícitamente; el resto del nodo queda intacto.

No llames a `actualizar-nodo` por iniciativa propia. Úsala únicamente cuando el usuario pida de
forma explícita cambiar uno o más de esos datos de un nodo (por ejemplo "cambia el título de
TAR-0004" o "sube la prioridad de este nodo"). Para mover un nodo entre estados del workflow usa
`avanzar-nodo` / `retroceder-nodo`, no `actualizar-nodo`.

## Si una tool de "horus-project" falla con un error de autenticación (401/token expirado)

Claude Code vuelve a ejecutar el `headersHelper` y reintenta una vez por su cuenta. Si el error
persiste, la sesión con Horus expiró:

1. Informa al usuario que su sesión con el servidor MCP "horus-project" expiró.
2. En una sesión local, pídele que ejecute `/mcp` y vuelva a iniciar sesión en "horus-project".
   En una sesión cloud, pídele que actualice `HORUS_TOKEN` o `HORUS_REFRESH_TOKEN` en las
   variables de entorno del entorno cloud y abra una sesión nueva.
3. Vuelve a intentar la operación una vez que confirme que volvió a iniciar sesión.

No intentes resolverlo de otra forma (por ejemplo, reintentando la misma llamada varias
veces): el problema es la sesión, no la petición.
