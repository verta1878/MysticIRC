# Prompt operativo — Revisión read-only de lógica DRAW/RESIGN/RESET/DISCONNECT

Antes de lanzar: crear el worktree con
`git worktree add experiments/control-review 1d52ef0 --detach`
(desde el árbol principal). Copiar el bloque siguiente íntegro al nuevo Codex.

~~~text
Purpose:

Auditoría READ-ONLY de la lógica de control de sesión de NetChessZX: DRAW,
RESIGN, RESET y DISCONNECT (BYE + pérdida de enlace), vista desde TODAS las
combinaciones de target, transporte, rol e iniciador. Objetivo: mapa de
verdad de cada combinación (correcta / divergente / sin cobertura), no
arreglar nada.

Task:

Revisar código y contratos; producir un único informe de hallazgos. CERO
ediciones de producto, tests, Makefile o docs normativos. Tu único fichero de
escritura es `docs/control-logic-review.md` dentro de tu worktree.

Context:

Worktree obligatorio, ya creado: experiments/control-review
HEAD esperado (detached): 1d52ef0a... ("Reset Next sprites before restore redraw")

Primera acción exacta:
git status --short --branch
git rev-parse HEAD
Si HEAD no es 1d52ef0 o el árbol no está limpio, informa y detente. No hagas
checkout/reset/clean.

Estado del proyecto que debes asumir:
- Fase 5 HW cerrada; M03 atribuido a firmware ESP (no toques ese tema).
- c8ec143 acaba de arreglar "reset-after-reset" (el latch de RESET del
  Spectrum sobrevivía a la aceptación y re-ACKeaba sin preguntar). VERIFICA
  que ese fix es completo en todas las combinaciones, incluida su interacción
  con el latch de DRAW (el mismo commit lo limpia en el boundary de rematch).
- El wedge de TAKEBACK (prompt expirado atasca a ambos peers) es CONOCIDO y
  está fuera de tu alcance — no lo re-reportes; pero si su mecanismo aparece
  ligado a DRAW/RESET/RESIGN, eso SÍ es hallazgo.
- Existe un reducer MQTT canónico de fase 6 en otro worktree SIN commitear:
  no lo busques; tus normas son los contratos committeados.

Superficies de lectura, en este orden (no exploración general):
1. docs/wire-contract.md — gramática y reglas de retransmisión/idempotencia.
2. docs/session-core-contract.md — semántica de control, link loss, duplicados.
3. docs/mqtt-session-policy.md — asientos/presencia MQTT.
4. src/common/session/session.c + direct_session.c — reducer canónico (ley PC
   DIRECT).
5. src/spectrum/app/app.c — FSM compacta: paths de control (process_local_key,
   session_control_handle_event, confirm_action, control_pending,
   last_control_accept, retry_pending_outgoing, handle_opponent_disconnected*).
6. src/spectrum/session/*.c (event/ping/poll) — clasificación y liveness.
7. src/pc/client/main.cpp — SOLO funciones de control/disconnect/BYE y sus
   seams de presentación (no leas el fichero entero).
8. tests/session/ y tests/spectrum/ — qué combinaciones YA tienen cobertura.

Matriz obligatoria — para CADA verbo (DRAW, RESIGN, RESET, DISCONNECT):
- transporte: DIRECT / MQTT;
- rol del que inicia: host / guest;
- target del que inicia y del que responde: ZX / Next / PC (nota: ZX y Next
  comparten app.c — trátalos como uno salvo donde haya #ifdef NETCHESSZX_NEXT
  relevante, y señala esos puntos);
- iniciador local vs remoto;
- casos especiales por verbo: aceptar / rechazar / expirar prompt / duplicado
  del request / duplicado tras aceptación / cruce (ambos piden a la vez) /
  fallo de TX del request o de la respuesta / control durante MOVE pendiente /
  control tras game-over / DISCONNECT con control pendiente.

Para cada celda de la matriz, veredicto: CORRECTA (cumple contrato, cita
file:line), DIVERGENTE (explica el flujo exacto y el resultado observable
para el usuario), o SIN COBERTURA (ni test ni certeza estática). No inventes
severidades: 🔴 desync/atasco entre peers, 🟡 comportamiento incorrecto
recuperable, 🔵 aspereza UX, 🟢 nota.

Método:
- Evidencia por función y rama de código, no por intuición; cita file:line en
  cada afirmación.
- Cuando contrato y código diverjan, el CONTRATO es la norma; si el contrato
  calla, compara canónico-PC vs FSM-Spectrum y marca la asimetría.
- Prohibido: editar producto/tests, ejecutar builds de target (tap/next/nex),
  tocar ficheros de coordinación de otros hilos (docs/codex-ping*.md,
  docs/claude-review*.md, docs/session-core-size-ledger.md). Puedes ejecutar
  las suites host existentes si ayudan a confirmar cobertura (make
  session-core-test / session-direct-core-test / session-direct-parity-test /
  session-spectrum-pair-test), sin modificarlas.

Effort Level: high. El coste relevante es exhaustividad de la matriz y
exactitud de las citas; un falso hallazgo cuesta más que una celda vacía.

Output (docs/control-logic-review.md de tu worktree):
1. Tabla-matriz por verbo con veredicto por celda.
2. Hallazgos numerados: severidad, file:line, combinación exacta, flujo, y
   sugerencia de dirección (SIN parche).
3. Lista de celdas SIN COBERTURA como candidatas a transcripts futuros.
4. Resumen: ¿hay más familia del bug reset-after-reset (latches que
   sobreviven donde no deben)?

Al terminar, mensaje final de máximo 10 líneas con: nº de celdas evaluadas,
nº de hallazgos por severidad, y los 3 hallazgos más graves. Sin ceremonias.

Stop Conditions: detente e informa si HEAD no coincide, si necesitas editar
algo para avanzar, o si una afirmación exigiría ejecutar hardware. No abras
ningún otro tema del backlog.
~~~
