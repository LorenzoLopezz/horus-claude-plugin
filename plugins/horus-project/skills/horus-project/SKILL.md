---
name: horus-project
description: Explica cómo usar el servidor MCP "horus-project" (proyectos, nodos y equipos de Horus Project) y qué hacer cuando una tool falla por token OAuth expirado.
---

# MCP horus-project

El servidor MCP "horus-project" expone los proyectos, nodos y equipos (grupos) del usuario
autenticado: listar proyectos, consultar equipos y miembros, ver/crear/actualizar nodos, leer
documentos y mover nodos por su workflow. El acceso está limitado a los recursos en los que el
usuario participa y a los permisos que tiene asignados.

En Claude Code, las tools de este plugin aparecen con el nombre
`mcp__plugin_horus-project_horus-project__<tool>`. En Codex, el servidor MCP aparece como
`horus-project` y las tools se invocan por su nombre (`listar-proyectos`, `listar-nodos`, etc.).

## Autenticación

El servidor usa OAuth 2.1 (authorization_code + PKCE).

- En Claude Code local, el login se hace una sola vez en el navegador desde `/mcp`.
- En sesiones cloud, el plugin puede tomar `HORUS_TOKEN` o solicitar un token con
  `HORUS_CLIENT_ID` y `HORUS_CLIENT_SECRET`, según la configuración del entorno.
- En Codex, si la tool devuelve `401` o el servidor aparece sin autenticación, ejecuta
  `codex mcp login horus-project` y vuelve a intentarlo después de confirmar el login.

## Tools disponibles

### Proyectos y catálogos

- `listar-proyectos`: lista los proyectos en los que participa el usuario.
- `listar-estados-proyecto`: lista los estados disponibles de un proyecto.
- `listar-tipos-nodo`: lista los tipos de nodo.
- `listar-prioridades`: lista las prioridades.

### Equipos

Para responder en qué trabaja un equipo, no inventes el `id_grupo`:

1. Llama a `listar-equipos` y resuelve el equipo por `nombre` o `codigo`.
2. Con ese `id_grupo`, llama a `listar-nodos-equipo` para consultar el trabajo o a
   `listar-miembros-equipo` para consultar sus integrantes.

`listar-nodos-equipo` sin `categorias` devuelve solo estados abiertos. Para consultar terminados,
cancelados o bloqueados, envía `categorias` explícitamente. No caches el listado de equipos.

### Nodos

- `listar-nodos`: lista los nodos de un proyecto; sin `categorias`, devuelve solo nodos abiertos.
- `listar-mis-nodos`: lista los nodos asignados al usuario; sin `categorias`, usa sus estados
  predeterminados.
- `contar-nodos-asignados-por-usuario`: cuenta los nodos asignados a cada usuario visible y los
  ordena de mayor a menor. Acepta `id_proyecto`, `id_grupo` y `categorias`; sin `categorias`,
  incluye todos los estados.
- `listar-nodos-de-usuario`: lista los nodos asignados a un usuario específico. Requiere
  `id_usuario` y acepta `id_proyecto`, `id_grupo` y `categorias`; sin `categorias`, incluye todos
  los estados.
- `ver-nodo`: consulta el detalle de un nodo, incluida su lista de recursos.
- `ver-recurso`: devuelve los metadatos y la URL temporal de descarga de un recurso listado por
  `ver-nodo`, para que el agente pueda descargarlo y utilizarlo según la solicitud del usuario;
  los documentos incluyen además su contenido Markdown.
- `crear-nodo`: crea un nodo en un proyecto.
- `actualizar-nodo`: modifica únicamente los campos enviados explícitamente.
- `cambiar-fecha-fin-nodo`: cambia la fecha de finalización de un nodo.
- `avanzar-nodo` y `retroceder-nodo`: mueven un nodo por su workflow.

Las tools de nodos aceptan el UUID completo o el último bloque de 12 caracteres del UUID. Si el
usuario comparte un enlace corto como `https://app.example.com/n/1234abcd5678`, envía
`1234abcd5678` como `id_proyecto_nodo`.

No llames a `actualizar-nodo` por iniciativa propia. Úsala únicamente cuando el usuario pida
explícitamente cambiar datos del nodo. Para cambiar de estado usa `avanzar-nodo` o
`retroceder-nodo`, no `actualizar-nodo`.

El campo `participantes` de `actualizar-nodo` reemplaza la lista actual de responsables; una lista
vacía la limpia. Solo envíalo cuando el usuario solicite modificar responsables.

### Documentos y discusiones

- `leer-documento-proyecto`: lee un documento Markdown del proyecto.
- `listar-discusion-nodo`: consulta la discusión de un nodo.
- `agregar-discusion-nodo`: agrega un comentario Markdown a un nodo.

## Caché local del listado de proyectos

### Claude Code

Antes de llamar a `listar-proyectos`, ejecuta primero:

    "${CLAUDE_PLUGIN_ROOT}/scripts/cache.sh" get proyectos

Si el comando imprime datos y termina con código 0, usa ese JSON y no llames a la tool MCP. Si
termina con código 1, llama a `listar-proyectos` y guarda el resultado:

    <resultado-json-de-la-tool> | "${CLAUDE_PLUGIN_ROOT}/scripts/cache.sh" set proyectos

Si el usuario indica explícitamente que la lista de proyectos cambió, ejecuta:

    "${CLAUDE_PLUGIN_ROOT}/scripts/cache.sh" clear proyectos

En Windows sin bash, usa `~/.horus-project-mcp/bin/cache.ps1` con los mismos subcomandos o salta
el caché y llama a la tool directamente.

### Codex

En Codex no asumas que existe `CLAUDE_PLUGIN_ROOT`: el manifiesto de Codex instala la Skill, pero no
expone esa variable de Claude Code. En ese cliente llama a `listar-proyectos` directamente si no
dispones de una ruta local conocida para el script de caché.

## Si una tool falla por autenticación

Si una tool devuelve `401` o indica que el token expiró:

1. Informa al usuario que la sesión con el servidor MCP "horus-project" expiró.
2. En Claude Code local, pídele que ejecute `/mcp` y vuelva a iniciar sesión.
3. En Codex, pídele que ejecute `codex mcp login horus-project`.
4. En OpenCode, pídele que ejecute `opencode mcp auth horus-project`.
5. Reintenta la operación una vez que confirme el nuevo login.

No repitas la misma llamada sin renovar la sesión: el problema es la autenticación, no la
petición.
