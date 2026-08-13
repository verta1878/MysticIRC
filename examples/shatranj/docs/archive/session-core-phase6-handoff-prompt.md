# Prompt operativo — Session Core Phase 6 MQTT

Copia y pega íntegramente el bloque siguiente únicamente después del `OK` de
Claude. El segundo Codex debe arrancar en el worktree independiente indicado;
este prompt no autoriza a crearlo, cambiar de rama ni tocar el worktree principal.

~~~text
Purpose:

Continuar el refactor Session Core de NetChessZX desde el cierre probado de
Phase 5 y obtener la semántica MQTT canónica ejecutable en host. Mantener la
arquitectura "una semántica, dos implementaciones, un juez": PC usa reducers
comunes canónicos; ZX/Next conservan sus FSM compactas; Phase 6 crea el corpus
MQTT neutral que Phase 8 aplicará después a ambas familias.

Task:

Abre solo Phase 6. Escribe primero transcripts MQTT target-neutral y sus
expectativas únicas. Después implementa `src/common/session/mqtt_session.c`
detrás del ABI de `session_step()` para la ruta canónica/PC, sin adaptar Qt ni
enlazar nada en Spectrum. Completa Phase 6 o detente ante un bloqueo real.

Context:

Worktree obligatorio, ya creado antes de esta sesión:
C:\Users\ignac\Dropbox\Retro\Software\Para divMMC\NetChessZX\experiments\phase6-mqtt

Rama obligatoria:
refactor/session-core-phase6-mqtt

Base inmutable esperada:
2762c566032e36a9d9994edf94798a58553bb4ef

Tu primera acción debe ser exactamente:

git status --short --branch
git rev-parse HEAD
git log --oneline -5

Debe salir rama `refactor/session-core-phase6-mqtt`, árbol limpio y HEAD
`2762c566032e36a9d9994edf94798a58553bb4ef`, con debajo:

- `7464d9a Record Phase 5 hardware closure`;
- `37b4cc9 Add DIRECT postmortem diagnostics`;
- `e880843 Fix DIRECT IPD bounds and PC status`;
- `c621207 Harden Session Core host gates`.

Si no coincide, informa y detente. No hagas switch, reset, restore, clean,
stash, rebase ni reparación automática. No crees el worktree por tu cuenta.

Phase 5 está cerrada. M03 quedó atribuido por intervención en la misma unidad a
firmware ESP-AT obsoleto; la actualización soportó el gate físico prolongado sin
relajar PING, wire ni timeout. La instrumentación post-mortem fue purgada y el
NEX normal quedó byte-idéntico. El límite de integridad del parser ASM MOVE ya
está cerrado en contrato: fallo puede dejar prefijo parcial dentro de seis
bytes, pero el único caller descarta el destino si el parser devuelve 0. No
reabras DIRECT, M03 ni ese parser.

Lee solo estas superficies, en este orden; no hagas exploración general:

- `docs/wire-contract.md`: completo; es la gramática neutral canónica MQTT.
- `docs/mqtt-session-policy.md`: completo; fija política de asientos y sesión.
1. `docs/session-core-contract.md`:
   - Purpose, Purity Boundary, Public Operation e Initial Configuration;
   - Input Events y Output Actions;
   - Link Loss, Time, Payload Ownership y Transmission Result Semantics;
   - C Dialect And Cost Rules y Acceptance Invariants;
   - Spectrum MOVE Parser Integrity Boundary solo para confirmar que está
     cerrado, no para investigarlo.
2. `docs/session-core-refactor-plan.md`:
   - estado y tabla de fases;
   - secciones 1-3;
   - Phase 6 completa;
   - Validation schedule, Global stop conditions y Definition of done.
3. `docs/source-layout.md`: solo entradas de `src/common/session/`, protocolo
   MQTT común, PC y tests host.
4. ABI/patrón canónico existente:
   - `src/common/session/session.h`;
   - `src/common/session/session_internal.h`;
   - `src/common/session/session.c`;
   - `src/common/session/direct_session.c` solo como patrón, sin modificarlo;
   - `tests/session/test_session_core.c` y
     `tests/session/test_direct_session_core.c` solo como patrón de runner.
5. Gramática real ya compartida:
   - `src/common/protocol/mqtt_session_protocol.h`;
   - `src/common/protocol/mqtt_session_protocol.c`;
   - su test nativo existente.
6. PC v1.0 como árbitro de campo únicamente por símbolos MQTT en
   `src/pc/client/main.cpp`: `mqttHandshake`, `activateMqttSide`,
   `announceMqttSetup`, `handleMqttPacket`, `handleMqttPayload`,
   `handleMqttSessionPayload`, `handleRxLine`, liveness y TX. No leas el fichero
   entero ni edites PC/Qt en Phase 6.

No leas ni escribas estos tres ficheros del worktree principal, aunque existan
en tu base:

- `docs/session-core-size-ledger.md`;
- `docs/codex-ping.md`;
- `docs/claude-review.md`.

Usa coordinación exclusiva de Phase 6 dentro de tu worktree:

- escribes `docs/session-core-phase6-ledger.md`;
- solo append en `docs/codex-ping-phase6.md`;
- solo lees `docs/claude-review-phase6.md`; jamás lo editas.

Si el buzón Phase 6 aún no existe, no lo fabriques ni te bloquees: continúa
hasta el siguiente punto natural y vuelve a comprobarlo entonces. Léelo antes
de abrir cada bloque, tras cada rojo y antes de declarar un cierre. No hagas
polling. Pinga solo después de dejar evidencia suficiente en el ledger:

AAAA-MM-DD HH:MM | TIPO | resumen corto | ref ledger

`TIPO` pertenece a `RED`, `CLOSE`, `ARBITRO`, `PREGUNTA` o `FYI`.

No me devuelvas una introducción larga. En un máximo de diez líneas confirma:

- rama, HEAD y árbol;
- worktree y coordinación exclusivos;
- Phase 5 cerrada y Phase 6 como único bloque abierto;
- arquitectura "una semántica, dos implementaciones, un juez";
- Phase 6 host-only: transcripts + reducer canónico MQTT;
- cero DIRECT, Qt, broker, Spectrum, z88dk y builds target;
- link loss termina y descarta partida; nueva conexión crea sesión fresca;
- un `ACT_SEND` máximo por step y TX local distinto de ACK de aplicación;
- PC v1.0 como árbitro solo cuando el contrato no fija el resultado;
- primer transcript `mqtt-seat-acquire-retained-vs-live`.

Effort Level:

high. El coste relevante es corrección semántica y pureza host: mismo wire y
UX desplegados; cero bytes/BSS/stack/overlay target porque Phase 6 no se enlaza
en ZX/Next; sin Qt, broker, plataforma, heap ni reloj dentro del core.

Boundaries:

- un solo bloque semántico abierto;
- primero transcript neutral y rojo creíble; producto después;
- PC conserva reducer común canónico;
- Spectrum conserva FSM compacta y no se toca en Phase 6;
- no crear todavía runner Spectrum MQTT: pertenece a Phase 8;
- no abrir adapter PC MQTT/Qt: pertenece a Phase 7;
- framing de topic, QoS, retain, SUB/PUBLISH/PUBACK y socket queda en adapter;
- el reducer recibe ruta, retained/live y payload ya extraídos;
- el reducer sí posee H/J/O/F, roles, color, sesión, seat/BUSY, presencia,
  readiness/start, MOVE/ACK, controles, duplicados, liveness y link loss;
- PUBACK o `EV_TX_RESULT(OK)` prueba handoff local, nunca aceptación peer;
- como máximo un `ACT_SEND` por `session_step()`; el siguiente requiere otro
  evento, normalmente el `EV_TX_RESULT` correlacionado;
- link loss activo emite ENDED, invalida pendientes y exige handshake/sesión/
  partida nueva; retained/live nunca autoriza resume, replay ni restore;
- no expectativas, corpus ni semántica específicos por target;
- no modificar wire, topics, QoS, retain policy, ABI público, baseline, guards,
  tamaños, overlays, DIRECT, PC UI ni hardware;
- no nuevas dependencias, frameworks, callbacks, colas dinámicas o ejecutores;
- no commits salvo petición expresa de Ignacio en esa sesión;
- reporta progreso al menos cada 60 segundos en Caveman full, denso y técnico.

Antes de editar producto crea en el ledger Phase 6 este option ledger mínimo:

| Opción | Evidencia | Coste/riesgo | Verificación | Decisión |
|---|---|---|---|---|
| Corpus neutral + reducer C host-only detrás del ABI actual | Plan Phase 6 | Superficie mínima | suites nativas | do |
| Reutilizar lógica Qt o introducir broker framing en core | PC v1.0 | dependencia/plataforma y tercera policy | guard de fuentes | reject |
| Enlazar/probar Spectrum o z88dk ahora | Plan Phase 8 | mezcla de fases y coste target | no comandos target | reject |

Primer bloque obligatorio: `mqtt-seat-acquire-retained-vs-live`.

Cobertura del bloque, como escenarios y no como expectativas inventadas:

1. guest observa H retained válido, aprende el asiento potencial solo para
   hacer la sonda, sin aceptar ese retained como setup live;
2. O retained del asiento potencial y sesión correlacionada detecta ocupación y
   produce BUSY/fin según la semántica de campo;
3. el mismo O como eco live propio no produce falso BUSY;
4. O retained stale/wrong-session no ocupa la sesión actual;
5. H live válido fija sesión/color y permite la secuencia J/O correspondiente;
6. H/J/O duplicados se resuelven idempotentemente;
7. TX fallido durante la secuencia deja salida fail-hard y no un asiento zombi.

Donde contrato y protocolo común no fijen el resultado, deriva primero la
conducta observable de PC v1.0. La lista anterior no decide por sí sola.

Método obligatorio para cada divergencia:

1. transcript target-neutral;
2. rojo archivado en `session-core-phase6-ledger.md` antes de producto;
3. decidir si falla producto, instrumento o contrato incompleto;
4. si falta semántica, PC v1.0 es árbitro de campo; extrae evidencia por función
   y rama, no por intuición;
5. escribir la decisión en `session-core-contract.md` antes del parche;
6. parche mínimo en corpus/runner/reducer incorrecto;
7. verde con un corpus y una expectativa única en el runner canónico; no fingir
   paridad Spectrum antes de Phase 8;
8. ejecutar suites nativas y guardas host del mismo estado;
9. cerrar resultado y evidencia en ledger antes del siguiente bloque.

Una divergencia no demuestra que el reducer tenga razón. Los shims son puntos
ciegos. Reutiliza C real de protocolo y PC cuando exista; stubs fail-fast para
cualquier acción no modelada. No copies política Qt dentro del runner.

Orden posterior, solo después de cerrar seat/retained/live:

1. bootstrap H/J/O/F y presencia/sesión/stale traffic completos;
2. side/ready/start;
3. MOVE/ACK y TX completion;
4. controles y duplicados;
5. liveness;
6. link loss y fresh-session obligatoria;
7. cierre formal Phase 6.

No abras más de uno a la vez.

Verification Rules:

- focused test del transcript actual primero;
- conservar verdes existentes:
  `make NO_COLOR=1 session-core-test`,
  `make NO_COLOR=1 session-direct-core-test` y
  `make NO_COLOR=1 session-direct-parity-test`;
- añadir un target nativo focalizado, preferentemente
  `session-mqtt-core-test`, sin Qt ni z88dk;
- `make NO_COLOR=1 module-guards` solo si se toca Makefile, layout o guardas;
- no ejecutar `make test`: incluye `tap-next`;
- no ejecutar `tap`, `tap-next`, `next`, `nex`, `abi-check`, `size-check`,
  `client`, `client-msvc` ni CMake/Qt;
- demostrar con búsqueda que `mqtt_session.c` y sus tests no incluyen Qt,
  broker client, Spectrum, z88dk ni headers de plataforma;
- toda expectativa debe ser idéntica para el futuro runner Spectrum;
- registrar comando, exit code y estado exacto en el ledger Phase 6;
- no afirmar hardware desde host.

Acceptance Phase 6:

- corpus MQTT target-neutral único cubre H/J/O/F, retained/live, seat/BUSY,
  presencia, sesión/stale, side/ready/start, MOVE/ACK, controles, liveness, TX,
  duplicados y fresh-session tras link loss;
- reducer MQTT canónico compila detrás del ABI de `session_step()` para PC/host;
- suites DIRECT canónicas permanecen verdes;
- suite MQTT nativa completa verde con una sola expectativa por transcript;
- core sin Qt, broker, Spectrum, z88dk ni plataforma;
- ninguna fuente o artefacto target tocado;
- ledger Phase 6 cerrado y `CLOSE` enviado a Claude para gate.

Stop Conditions:

Detente antes de editar si rama/HEAD/árbol no coinciden. Detén el bloque y pinga
`ARBITRO` si una observación exige expectativa específica por target, política
Qt/broker dentro del core, nuevo wire, cambio de ABI no demostrado, estado
oculto, más de un send por step sin TX_RESULT, buffer con lifetime ambiguo, o
semántica MQTT que PC v1.0 y contrato contradicen. Detente si cualquier camino
retiene o restaura tablero/historial tras link loss. No abras Phase 7/8/9.

No pares por contexto ya escrito ni por un síntoma heredado ajeno al gate.
Phase 6 termina al cumplir toda su aceptación o al documentar un bloqueo real.

Output Format:

Durante el trabajo: updates Caveman de máximo diez líneas, con bloque actual,
rojo/causa/decisión y próximo gate. Al cierre: archivos y ownership, corpus y
casos, divergencias y árbitro, comandos/exits, guardas de pureza, opciones
rechazadas, riesgo restante y siguiente gate exacto. Sin claims de Spectrum,
bytes target o hardware.
~~~
