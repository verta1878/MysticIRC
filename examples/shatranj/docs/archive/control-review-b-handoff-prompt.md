# Prompt operativo — Revisión B (independiente) de lógica DRAW/RESIGN/RESET/DISCONNECT

Segunda revisión del mismo alcance con otro modelo, para contraste. El
worktree YA existe; hay otro revisor (A) trabajando en él en paralelo — este
prompt garantiza independencia y cero colisiones. Copiar el bloque íntegro.

~~~text
Purpose:

Auditoría READ-ONLY e INDEPENDIENTE de la lógica de control de sesión de
NetChessZX: DRAW, RESIGN, RESET y DISCONNECT (BYE + pérdida de enlace), en
TODAS las combinaciones de target, transporte, rol e iniciador. Eres la
revisión B de un par de revisiones paralelas: tu valor es el contraste
independiente, no la velocidad. Objetivo: mapa de verdad por combinación
(correcta / divergente / sin cobertura). No arreglas nada.

Task:

Análisis ESTÁTICO puro: leer código y contratos, producir un único informe.
REGLAS DURAS DE SOLO-LECTURA:
- CERO ediciones de producto, tests, Makefile o docs normativos.
- CERO ejecución de make/builds/tests (otro proceso usa build/ en este
  worktree; además tu mandato es estático).
- Tu ÚNICO fichero de escritura: docs/control-logic-review-b.md (sufijo -b).
- Existe o aparecerá docs/control-logic-review.md (del revisor A): NO LO LEAS
  bajo ningún concepto — tu independencia es el valor del ejercicio.
- No toques ficheros de coordinación de otros hilos (docs/codex-ping*.md,
  docs/claude-review*.md, docs/session-core-size-ledger.md).

Context:

Worktree obligatorio, ya creado: experiments/control-review
HEAD esperado (detached): 1d52ef0 ("Reset Next sprites before restore redraw")

Primera acción exacta:
git rev-parse HEAD
Si no es 1d52ef0..., informa y detente. No hagas checkout/reset/clean/status
destructivo. Ficheros sin trackear ajenos (p.ej. control-logic-review.md)
pueden existir: ignóralos.

Estado del proyecto que debes asumir:
- Fase 5 HW cerrada; M03 atribuido a firmware ESP (fuera de alcance).
- c8ec143 arregló "reset-after-reset" (latch de RESET del Spectrum sobrevivía
  a la aceptación y re-ACKeaba sin preguntar). VERIFICA la completitud de ese
  fix en todas las combinaciones, incluida su interacción con el latch de
  DRAW (mismo commit lo limpia en el boundary de rematch).
- El wedge de TAKEBACK (prompt expirado atasca ambos peers) es CONOCIDO y
  fuera de alcance — no lo re-reportes; pero si su mecanismo toca
  DRAW/RESET/RESIGN, eso SÍ es hallazgo.
- Hay un reducer MQTT canónico de fase 6 en otro worktree sin commitear: no
  lo busques; tus normas son los contratos committeados en ESTE árbol.

Superficies de lectura, en este orden (sin exploración general):
1. docs/wire-contract.md — gramática, retransmisión, idempotencia.
2. docs/session-core-contract.md — semántica de control, link loss, duplicados.
3. docs/mqtt-session-policy.md — asientos/presencia MQTT.
4. src/common/session/session.c + direct_session.c — reducer canónico.
5. src/spectrum/app/app.c — FSM compacta: process_local_key,
   session_control_handle_event, confirm_action, control_pending,
   last_control_accept, retry_pending_outgoing,
   handle_opponent_disconnected*.
6. src/spectrum/session/*.c (event/ping/poll).
7. src/pc/client/main.cpp — SOLO funciones de control/disconnect/BYE y sus
   seams de presentación.
8. tests/session/ y tests/spectrum/ — cobertura existente (por LECTURA de los
   tests, sin ejecutarlos).

Matriz obligatoria — para CADA verbo (DRAW, RESIGN, RESET, DISCONNECT):
- transporte: DIRECT / MQTT;
- rol del iniciador: host / guest;
- target iniciador y respondedor: ZX / Next / PC (ZX y Next comparten app.c:
  trátalos como uno salvo #ifdef NETCHESSZX_NEXT relevante, y señálalos);
- iniciador local vs remoto;
- casos por verbo: aceptar / rechazar / expirar prompt / duplicado del
  request / duplicado tras aceptación / cruce (ambos a la vez) / fallo de TX
  del request o de la respuesta / control durante MOVE pendiente / control
  tras game-over / DISCONNECT con control pendiente.

Veredicto por celda: CORRECTA (cumple contrato, cita file:line), DIVERGENTE
(flujo exacto + resultado observable para el usuario), o SIN COBERTURA.
Severidades: 🔴 desync/atasco entre peers, 🟡 incorrecto recuperable,
🔵 aspereza UX, 🟢 nota.

Método:
- Evidencia por función y rama de código; cita file:line en cada afirmación.
- Contrato manda sobre código; si el contrato calla, compara canónico-PC vs
  FSM-Spectrum y marca la asimetría.
- Ante duda irresoluble estáticamente, celda = SIN COBERTURA con la pregunta
  concreta que un test debería contestar; no especules.

Effort Level: high. Exhaustividad de matriz y exactitud de citas; un falso
hallazgo cuesta más que una celda vacía.

Output (docs/control-logic-review-b.md — ÚNICO fichero que escribes):
1. Tabla-matriz por verbo con veredicto por celda.
2. Hallazgos numerados: severidad, file:line, combinación exacta, flujo,
   dirección sugerida (SIN parche).
3. Celdas SIN COBERTURA como candidatas a transcripts futuros.
4. Resumen: ¿más familia del bug reset-after-reset (latches que sobreviven
   donde no deben)?

Mensaje final de máximo 10 líneas: nº celdas evaluadas, hallazgos por
severidad, top-3 más graves. Sin ceremonias.

Stop Conditions: detente e informa si HEAD no coincide, si avanzar exigiría
editar o ejecutar algo, o si una afirmación exigiría hardware. No abras otros
temas del backlog.
~~~
