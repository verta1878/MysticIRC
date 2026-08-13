# Revisión read-only de lógica DRAW/RESIGN/RESET/DISCONNECT

## Estado y alcance

- Worktree: experiments/control-review.
- HEAD auditado: 1d52ef0bfa396ee208b32627ef20be4a5c3968da.
- Árbol inicial: limpio y detached.
- Escrituras: sólo este informe.
- Builds de target/hardware: no ejecutados.
- Suites host ejecutadas: session-core-test, session-direct-core-test, session-direct-parity-test y session-spectrum-pair-test; las cuatro pasan.
- Celdas lógicas clasificadas: 704.

La norma no es internamente única para pérdida MQTT: session-core exige terminar y descartar el juego, mientras mqtt-session-policy exige congelarlo. Las celdas afectadas se marcan SIN COBERTURA normativa, no se fuerza una precedencia inventada [docs/session-core-contract.md:327-352; docs/mqtt-session-policy.md:85-94].

## Método y notación

S = ZX/Next. Ambos ejecutan src/spectrum/app/app.c; no hay rama de control NETCHESSZX_NEXT. La única diferencia relevante del alcance es la cadencia DIRECT de Next en src/spectrum/session/ping.c:5-10.

P = PC. En DIRECT usa el reducer común. En MQTT usa lógica legacy de main.cpp, no un reducer común [src/common/session/session.c:141-161; src/pc/client/main.cpp:4799-5078].

Una ruta, por ejemplo D-H-S>P, significa transporte DIRECT, iniciador HOST, iniciador S y respondedor P. La misma celda inspecciona el lado local del iniciador y el lado remoto del respondedor. G significa iniciador GUEST; el respondedor ocupa el rol complementario.

Los roles no cambian la gramática de control. La única rama de rol dentro del flujo auditado es quién adelanta RESET tras DRAW en MQTT Spectrum; no cambia el resultado normal [src/spectrum/app/app.c:2028-2035]. El contrato prohíbe variantes por tipo de cliente [docs/wire-contract.md:47-52].

Veredictos:

- C: CORRECTA por certeza estática y/o transcript.
- Dn: DIVERGENTE; n remite al hallazgo numerado.
- Un: SIN COBERTURA o sin norma única; n remite a la lista posterior.
- A: aceptar; R: rechazar; E: expirar/no contestar el prompt; D0: duplicado con prompt abierto; D1: duplicado tras aceptación; X: cruce simultáneo; TQ: fallo TX del request; TR: fallo TX de la respuesta; MI: iniciador ya tiene MOVE/TAKEBACK pendiente; MR: respondedor ya tiene MOVE/TAKEBACK pendiente; O: control tras game-over; DC: BYE/link-loss remoto durante el control. La preemption local se evalúa en DISCONNECT/CP/PR/GO.

El campo Arquitectura no forma parte de las 704 celdas de comportamiento. D6 allí significa que el comportamiento puede coincidir, pero incumple el contrato de ownership del reducer PC-MQTT.

## Matriz DRAW — 192 celdas

| Ruta | Arquitectura | A | R | E | D0 | D1 | X | TQ | TR | MI | MR | O | DC |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D-H-S>S | C | C | C | D2 | C | C | C | C | C | D1 | D1 | C | C |
| D-H-S>P | C | C | C | D2 | C | C | C | C | C | D1 | C | C | C |
| D-H-P>S | C | C | C | C | C | C | C | C | C | C | D1 | C | C |
| D-H-P>P | C | C | C | C | C | C | C | C | C | C | C | C | C |
| D-G-S>S | C | C | C | D2 | C | C | C | C | C | D1 | D1 | C | C |
| D-G-S>P | C | C | C | D2 | C | C | C | C | C | D1 | C | C | C |
| D-G-P>S | C | C | C | C | C | C | C | C | C | C | D1 | C | C |
| D-G-P>P | C | C | C | C | C | C | C | C | C | C | C | C | C |
| M-H-S>S | C | C | C | D2 | C | C | C | C | C | D1 | D1 | C | C |
| M-H-S>P | D6 | C | C | D2 | C | C | C | C | D3 | D1 | D1 | C | C |
| M-H-P>S | D6 | C | C | C | C | C | C | C | C | C | D1 | C | C |
| M-H-P>P | D6 | C | C | C | C | C | C | C | D3 | C | D1 | C | C |
| M-G-S>S | C | C | C | D2 | C | C | C | C | C | D1 | D1 | C | C |
| M-G-S>P | D6 | C | C | D2 | C | C | C | C | D3 | D1 | D1 | C | C |
| M-G-P>S | D6 | C | C | C | C | C | C | C | C | C | D1 | C | C |
| M-G-P>P | D6 | C | C | C | C | C | C | C | D3 | C | D1 | C | C |

Evidencia de las celdas C: el reducer DIRECT normaliza cruce, duplicados, aceptación y rematch en direct_session.c:1346-1489, 816-888 y 2017-2108. Spectrum maneja aceptación/rechazo/cruce/duplicado en app.c:2028-2043, 2683-2690 y 2831-2862. PC-MQTT hace lo equivalente en main.cpp:4873-4911, 5064-5067 y 5099-5112. DRAW fuera de ACTIVE se rechaza en direct_session.c:1401-1407, app.c:2853-2856 y main.cpp:4878-4883.

## Matriz RESET — 192 celdas

| Ruta | Arquitectura | A | R | E | D0 | D1 | X | TQ | TR | MI | MR | O | DC |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D-H-S>S | C | C | C | D2 | C | C | D4 | C | C | D1 | D1 | C | C |
| D-H-S>P | C | C | C | D2 | C | C | D4 | C | C | D1 | C | C | C |
| D-H-P>S | C | C | C | C | C | C | D4 | C | C | C | D1 | C | C |
| D-H-P>P | C | C | C | C | C | C | C | C | C | C | C | C | C |
| D-G-S>S | C | C | C | D2 | C | C | D4 | C | C | D1 | D1 | C | C |
| D-G-S>P | C | C | C | D2 | C | C | D4 | C | C | D1 | C | C | C |
| D-G-P>S | C | C | C | C | C | C | D4 | C | C | C | D1 | C | C |
| D-G-P>P | C | C | C | C | C | C | C | C | C | C | C | C | C |
| M-H-S>S | C | C | C | D2 | C | C | D4 | C | C | D1 | D1 | C | C |
| M-H-S>P | D6 | C | C | D2 | C | C | D4 | C | D3 | D1 | D1 | C | C |
| M-H-P>S | D6 | C | C | C | C | C | D4 | C | C | C | D1 | C | C |
| M-H-P>P | D6 | C | C | C | C | C | C | C | D3 | C | D1 | C | C |
| M-G-S>S | C | C | C | D2 | C | C | D4 | C | C | D1 | D1 | C | C |
| M-G-S>P | D6 | C | C | D2 | C | C | D4 | C | D3 | D1 | D1 | C | C |
| M-G-P>S | D6 | C | C | C | C | C | D4 | C | C | C | D1 | C | C |
| M-G-P>P | D6 | C | C | C | C | C | C | C | D3 | C | D1 | C | C |

Evidencia de las celdas C: DIRECT valida fase, busy, aceptación, rechazo y limpieza de latch en direct_session.c:1391-1457, 797-815, 867-888, 906-934 y 2017-2032. Spectrum abre/contesta RESET y limpia las rutas exitosas en app.c:2028-2043, 2675-2680 y 2769-2810. PC-MQTT lo hace en main.cpp:4914-4978, 5057-5063 y 5878-5909. RESET tras game-over está permitido; RESET antes de partida se rechaza [direct_session.c:1391-1399; app.c:2773-2808; main.cpp:4945-4948].

## Matriz RESIGN — 160 celdas

N = envío, aplicación y ACK normales. MI cubre RESIGN local durante MOVE pendiente; MR cubre RESIGN remoto mientras el respondedor espera su MOVE.

| Ruta | Arquitectura | N | D0 | D1 | X | TQ | TR | MI | MR | O | DC |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D-H-S>S | C | C | C | C | C | C | C | D8 | C | C | C |
| D-H-S>P | C | C | C | C | C | C | C | D8 | C | C | C |
| D-H-P>S | C | C | C | C | C | C | C | C | C | C | C |
| D-H-P>P | C | C | C | C | C | C | C | C | C | C | C |
| D-G-S>S | C | C | C | C | C | C | C | D8 | C | C | C |
| D-G-S>P | C | C | C | C | C | C | C | D8 | C | C | C |
| D-G-P>S | C | C | C | C | C | C | C | C | C | C | C |
| D-G-P>P | C | C | C | C | C | C | C | C | C | C | C |
| M-H-S>S | C | C | C | C | C | C | C | D8 | C | C | C |
| M-H-S>P | D6 | C | C | C | C | C | D3 | D8 | C | C | C |
| M-H-P>S | D6 | C | C | C | C | C | C | C | C | C | C |
| M-H-P>P | D6 | C | C | C | C | C | D3 | C | C | C | C |
| M-G-S>S | C | C | C | C | C | C | C | D8 | C | C | C |
| M-G-S>P | D6 | C | C | C | C | C | D3 | D8 | C | C | C |
| M-G-P>S | D6 | C | C | C | C | C | C | C | C | C | C |
| M-G-P>P | D6 | C | C | C | C | C | D3 | C | C | C | C |

Evidencia de las celdas C: el contrato hace RESIGN unilateral e idempotente [docs/session-core-contract.md:224-232; docs/wire-contract.md:31-32,49-50]. DIRECT ACKea siempre, aplica una vez y resuelve el cruce en direct_session.c:717-730, 836-897 y 1744-1807. Spectrum lo hace en app.c:2045-2052, 2813-2828 y 1650-1654. PC-MQTT lo hace en main.cpp:3696-3731, 4834-4842 y 5068-5072. RESIGN remoto preempta controles/MOVE pendientes en las tres familias.

## Matriz DISCONNECT — 160 celdas

LB = BYE local limpio; RB = BYE remoto; TL = pérdida física/broker del enlace activo; LV = pérdida detectada por liveness; CP = BYE local con control saliente; PR = BYE local con prompt entrante; MV = desconexión con MOVE pendiente; GO = desconexión en game-over/rematch; TX = fallo al transmitir BYE; FG = pérdida/aviso de enlace, presencia o sesión ajenos.

| Ruta | Arquitectura | LB | RB | TL | LV | CP | PR | MV | GO | TX | FG |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D-H-S>S | C | C | C | C | U3 | C | D5 | C | D5 | C | U5 |
| D-H-S>P | C | C | C | C | U3 | C | D5 | C | D5 | C | U5 |
| D-H-P>S | C | C | C | C | U3 | C | U4 | C | C | C | U5 |
| D-H-P>P | C | C | C | C | C | C | U4 | C | C | C | C |
| D-G-S>S | C | C | C | C | U3 | C | D5 | C | D5 | C | U5 |
| D-G-S>P | C | C | C | C | U3 | C | D5 | C | D5 | C | U5 |
| D-G-P>S | C | C | C | C | U3 | C | U4 | C | C | C | U5 |
| D-G-P>P | C | C | C | C | C | C | U4 | C | C | C | C |
| M-H-S>S | C | C | C | U7 | U7 | C | D5 | C | D5 | C | C |
| M-H-S>P | D6 | C | C | U7 | U7 | C | D5 | C | D5 | C | C |
| M-H-P>S | D6 | C | C | U7 | U7 | C | U4 | C | C | C | C |
| M-H-P>P | D6 | C | C | U7 | U7 | C | U4 | C | C | C | C |
| M-G-S>S | C | C | C | U7 | U7 | C | D5 | C | D5 | C | C |
| M-G-S>P | D6 | C | C | U7 | U7 | C | D5 | C | D5 | C | C |
| M-G-P>S | D6 | C | C | U7 | U7 | C | U4 | C | C | C | C |
| M-G-P>P | D6 | C | C | U7 | U7 | C | U4 | C | C | C | C |

Evidencia de las celdas C: BYE local DIRECT preempta estado del reducer y termina tras handoff; BYE remoto y LINK_DOWN activo limpian todo [direct_session.c:963-964, 1694-1695, 2153-2164; session.c:75-150]. Spectrum limpia prompts, controles, tablero e historial en app.c:528-542, 2264-2280, 2543-2552 y 2990-2993. PC-MQTT limpia por BYE/F/timeout en main.cpp:4658-4674, 4824-4830 y 6177-6202. Los avisos MQTT de otra sesión se filtran por lado y session id [src/spectrum/session/event.c:240-319; src/pc/client/main.cpp:4658-4683].

## Hallazgos

### 1. desync/atasco entre peers — RESET/DRAW pueden coexistir con MOVE/TAKEBACK

Combinaciones: cualquier rol; DIRECT o MQTT cuando S inicia o responde; MQTT cuando P responde. DIRECT P>P es correcto.

Norma: sólo una operación puede estar pendiente. RESET/DRAW frescos durante MOVE, DRAW o TAKEBACK pendientes deben recibir NACK/BUSY sin sobrescribir correlación ni retry [docs/session-core-contract.md:269-281].

Flujo Spectrum:

1. pending_local_ply o takeback_pending_ply queda pendiente.
2. RESET local no comprueba ninguno; DRAW local no comprueba pending_local_ply [src/spectrum/app/app.c:1490-1504, 1946-1953, 2177-2190].
3. RESET/DRAW remotos tampoco los comprueban y abren prompt [app.c:2800-2808, 2853-2860].
4. Coexisten dos operaciones. El retry prioriza RESIGN, MOVE, START, RESET, DRAW y TAKEBACK; una respuesta perdida puede dejar sin retransmitir la segunda operación [app.c:1650-1669].
5. Aceptar RESET/DRAW borra la operación original al reiniciar o entrar en rematch [app.c:1480-1488, 1507-1526].

Flujo PC-MQTT: los gates DRAW omiten pendingPly_/takebackPending_; RESET omite pendingPly_, drawPending_ y takebackPending_ [src/pc/client/main.cpp:4873-4888, 4914-4951]. Aceptar borra la operación previa por endGameOver() o startGameFromAck() [main.cpp:5080-5111, 5878-5909].

Resultado observable: petición simultánea, retry/correlación divergente y operación previa descartada; según orden de ACK/NACK, un peer puede reiniciar mientras el otro sigue resolviendo la jugada anterior.

Dirección: aplicar el gate de una sola operación en el punto común de entrada RESET/DRAW; no añadir otro estado.

### 2. desync/atasco entre peers — DRAW/RESET heredan el wedge de prompt sin respuesta

Combinaciones: S como iniciador, cualquier rol/transporte y respondedor S o P. El hallazgo se limita a DRAW/RESET; no re-reporta TAKEBACK.

Flujo:

1. S envía DRAW/RESET y arma control_pending.
2. Si no llega decisión, retry_pending_outgoing retransmite sin contador ni stop [src/spectrum/app/app.c:1650-1677, 2994-3009].
3. El respondedor S traga duplicados con el prompt abierto y sólo sale por Y/N [app.c:2004-2132, 2770-2771, 2832-2833]. PC-MQTT también ignora duplicados con modal abierto [src/pc/client/main.cpp:4876-4877, 4929-4933].
4. Las retransmisiones mantienen actividad de enlace; no aparece una frontera que cierre request y prompt.

Resultado observable: iniciador bloqueado esperando ACK/NACK y respondedor bloqueado en el prompt indefinidamente. RESIGN sólo comparte el bloqueo local de confirmación antes de enviar; no deja todavía a un peer esperando.

Dirección: reutilizar un deadline existente para cerrar el prompt con NACK o terminar la sesión; no crear una cola/timer paralelo.

### 3. desync/atasco entre peers — PC-MQTT avanza aunque falle el TX de la respuesta

Combinaciones: MQTT, P respondedor, host o guest, peer S/P; ACK/NACK DRAW/RESET y ACK RESIGN.

Norma: MQTT es fail-hard ante fallo de handoff; RESET/DRAW sólo sueltan el latch después del handoff de la respuesta [docs/session-core-contract.md:249-255, 287-291].

Flujo:

1. writeMqttPacket informa encode/write/partial-write failure [src/pc/client/main.cpp:4266-4288].
2. Los handlers descartan el bool de sendLine y avanzan estado [main.cpp:4834-4841, 4873-4907, 4918-4975].
3. Caso RESET: falla ACK RESET, pero P ejecuta startGameFromAck y borra pending/board [main.cpp:4969-4971, 5878-5909].
4. El peer retransmite RESET; P ya no conserva el request aceptado y vuelve a preguntar. Si ahora se rechaza, los peers quedan en partidas distintas.

DIRECT termina la sesión ante cualquier fallo TX de control [src/common/session/direct_session.c:989-1028].

Dirección: no avanzar el estado tras sendLine=false; cerrar/fallar la sesión o conservar el latch hasta handoff confirmado.

### 4. comportamiento incorrecto recuperable — Spectrum ACKea RESET cruzado en ACTIVE

Combinaciones: cualquier transporte/rol y cualquier cruce que incluya S.

Norma: DRAW cruzado se ACKea y avanza a RESET; RESET cruzado durante partida activa se rechaza BUSY. Sólo el RESET cruzado de rematch/game-over se acepta [docs/session-core-contract.md:222-232].

Spectrum, con game_status_active y control_pending == RESET, envía ACK RESET, borra pending y reinicia [src/spectrum/app/app.c:2792-2799]. El reducer DIRECT y PC-MQTT distinguen ACTIVE de rematch y NACKean el cruce activo [src/common/session/direct_session.c:1434-1457; src/pc/client/main.cpp:4918-4927].

Resultado observable: ambos Spectrum suelen converger al reset, pero el resultado contractual cambia de rechazo recuperable a aceptación automática.

Dirección: ACK sólo si game_over; en ACTIVE emitir el NACK BUSY ya existente.

### 5. aspereza UX — BYE local no preempta ciertos controles Spectrum

Combinaciones: S local con prompt DRAW/RESET entrante o game-over con RESET/rematch pendiente; cualquier transporte/rol.

Norma DIRECT: BYE local puede preemptar handshake o cualquier control pendiente [docs/session-core-contract.md:401-410].

El bloque confirm_action consume todas las teclas antes de alcanzar el menú DISCONNECT [src/spectrum/app/app.c:2004-2132 frente a 2169-2174]. En game-over con control_pending, cualquier tecla muestra espera y tampoco llega al disconnect [app.c:2147-2156].

Resultado observable: el usuario debe contestar el control antes de poder salir. BYE/link-loss remoto sí limpia inmediatamente [app.c:2264-2280, 2543-2552].

Dirección: dar prioridad al comando explícito DISCONNECT sobre confirm/pending y reutilizar disconnect_to_setup().

### 6. nota — PC-MQTT incumple el ownership del reducer canónico

El contrato exige reducers DIRECT/MQTT tras session_step() y política PC sólo en common [docs/session-core-contract.md:9-16, 491-500]. El código committed despacha sólo DIRECT y devuelve cero para MQTT [src/common/session/session.c:141-161]; main.cpp interpreta todos los controles MQTT [src/pc/client/main.cpp:4799-5078].

Consecuencia: toda ruta MQTT con P tiene Arquitectura D6, aunque una celda de comportamiento sea C. No se buscó el reducer no commiteado indicado en el encargo.

Dirección: la futura migración debe sustituir, no duplicar, esta política legacy.

### 7. nota — dos contratos normativos se contradicen en link loss MQTT

session-core ordena terminar, cancelar y descartar juego/historial [docs/session-core-contract.md:327-352, 504-504]. mqtt-session-policy ordena congelar tablero, historial y relojes en suspensión [docs/mqtt-session-policy.md:85-94].

Spectrum descarta y vuelve a espera [src/spectrum/app/app.c:2282-2305]; PC descarta por socket/F/BYE/timeout mediante resetGame [src/pc/client/main.cpp:2511-2555, 3039-3083, 4658-4674, 4824-4830, 6283-6290].

Resultado: el código coincide con session-core y diverge de mqtt-session-policy. TL/LV MQTT quedan U7 hasta declarar precedencia; ejecutar hardware no resolvería una contradicción documental.

Dirección: elegir una sola semántica normativa antes de escribir transcripts.

### 8. nota — RESIGN local durante MOVE difiere entre Spectrum y canónico

El contrato llama RESIGN unilateral, pero no dice si un usuario local puede iniciarlo mientras su MOVE espera ACK [docs/session-core-contract.md:224-232].

Spectrum local_action_ready omite pending_local_ply, por lo que /resign puede enviarse y end_game_over borra el MOVE [src/spectrum/app/app.c:1490-1504, 1936-1943, 2045-2052]. DIRECT P rechaza cualquier nuevo local request mientras pending_control está ocupado [src/common/session/direct_session.c:2166-2169]. PC-MQTT lo bloquea mediante restoreBusy [src/pc/client/main.cpp:3701-3704, 3246-3256].

Resultado observable: S permite abandonar inmediatamente; P obliga a resolver primero la jugada. D8 marca la asimetría, no una severidad funcional mayor.

Dirección: fijar en contrato si RESIGN preempta MOVE local y alinear el gate mínimo.

## Verificación de c8ec143 y latches

c8ec143 es completo en las rutas Spectrum exitosas de RESET:

- RESET remoto aceptado normal limpia last_control_accept [src/spectrum/app/app.c:2036-2043].
- RESET/rematch cruzado limpia el latch [app.c:2773-2782, 2792-2799].
- ACK al RESET propio entra por reset_auto_start, game_start_state y pending_takeback_clear, que limpia last_control_accept [app.c:2675-2679, 1507-1526, 490-497].
- Al compartir app.c, lo anterior cubre ZX y Next, DIRECT y MQTT, host y guest.

El latch DRAW también se limpia en el boundary exitoso de rematch por game_start_state -> pending_takeback_clear. No hay transcript que mande un DRAW fresco después de completar ese RESET.

Quedan dos boundaries anómalos sin prueba suficiente para afirmar un segundo bug observable:

- NACK RESET borra control_pending pero no last_control_accept [app.c:2725-2733].
- El host MQTT que acepta DRAW ignora el fallo de start_draw_rematch y reescribe CONTROL_ACCEPT_DRAW después del cleanup [app.c:2033-2035, 1448-1455, 528-542].

Los guards actuales pueden hacer esos valores inertes hasta el siguiente reset de partida. Se clasifican U2, no hallazgo. La familia adicional demostrada no es un latch Spectrum que vive demasiado: es PC-MQTT soltando el latch RESET demasiado pronto cuando falla el handoff (hallazgo 3).

## Celdas SIN COBERTURA — candidatas a transcripts

### U2 — boundaries DRAW/RESET

- DRAW aceptado -> RESET/rematch completo -> DRAW fresco: no existe. draw_rematch termina tras RESET/linkdown y draw_crossed tampoco vuelve a pedir DRAW [tests/session/direct_reference_runner.c:1535-1570, 1634-1672].
- NACK/fallo TX del RESET de rematch seguido de retransmisión o control fresco.

### U3 — Next liveness real

ZX y Next comparten FSM, pero Next inyecta una cadencia DIRECT distinta [src/spectrum/session/ping.c:5-10]. La suite permitida ejecuta la paridad ZX; no prueba el binario Next ni la selección 50/60 Hz [Makefile:349-356]. No se hizo afirmación que requiera hardware.

### U4 — preemption BYE desde modal PC

El reducer DIRECT acepta BYE durante control, pero no hay test que pruebe si la presentación Qt permite iniciar Disconnect mientras un QMessageBox de control está modal [src/pc/client/main.cpp:2331-2400, 2559-2587].

### U5 — candidato/intruso en Spectrum product

El reducer DIRECT cubre cierre/BUSY de link no activo [src/common/session/direct_session.c:1610-1637]. Las superficies autorizadas no dan certeza completa del ownership del socket candidato en el transporte product Spectrum. Candidato: transcript host con prompt control abierto + segundo link + caída del segundo link.

### U7 — link loss MQTT

No crear transcript esperado hasta resolver la contradicción del hallazgo 7.

### Familias sin cobertura ejecutable

- Ningún test del alcance instancia src/pc/client/main.cpp; la paridad instancia el host runner Spectrum, no pares reales ZX↔ZX, ZX↔PC o PC↔PC [tests/session/test_direct_session_parity.c:1-11].
- MQTT no tiene transcripts DRAW/RESET/RESIGN/BYE. Sólo hay clasificación/presencia/handshake [tests/spectrum/test_session_event.c:252-376; tests/spectrum/test_session_mqtt.c:73-115; tests/spectrum/test_session_spectrum_pair.c:74-124].
- No hay fallo TX de request/reply DRAW, RESET o RESIGN. Sólo BYE local está cubierto; el scratch corto RESET prueba atomicidad, no fallo de transporte [tests/session/direct_reference_runner.c:257-283; tests/session/test_direct_session_core.c:1051-1059].
- Falta Spectrum host local/respondedor para prompts DRAW/RESET, rechazo DRAW, DRAW/RESIGN con MOVE pendiente, RESET local con MOVE pendiente, BYE tras game-over y link loss con DRAW/RESIGN/control MQTT pendiente.

Cobertura positiva relevante:

- RESET-after-RESET está atrapado: la segunda petición abre prompt nuevo [tests/session/direct_reference_runner.c:1585-1631; tests/session/test_direct_session_parity.c:1665-1707].
- DRAW DIRECT cubre rematch, cruce y duplicado durante RESET [tests/session/test_direct_session_core.c:1098-1227].
- RESET DIRECT cubre accept/reject, cruce BUSY, game-over y RESET detrás de MOVE [tests/session/test_direct_session_core.c:452-523, 1144-1158, 1234-1247, 1300-1345].
- RESIGN DIRECT cubre remoto, duplicado, retry y cruce [tests/session/test_direct_session_core.c:525-536, 1426-1445, 1694-1717].
- DISCONNECT DIRECT cubre LINK_DOWN/BYE/liveness; poll cubre detección DIRECT y MQTT [tests/session/test_session_core.c:97-141; tests/session/test_direct_session_core.c:760-788, 1647-1665, 1743-1755, 1803-1833; tests/spectrum/test_session_poll.c:164-263].

## Resumen

- 704 celdas: DRAW 192, RESET 192, RESIGN 160, DISCONNECT 160.
- Hallazgos: 3 desync/atasco entre peers; 1 comportamiento incorrecto recuperable; 1 aspereza UX; 3 notas.
- Los tres riesgos mayores son operación doble MOVE/TAKEBACK+RESET/DRAW, wedge de prompt Spectrum y avance PC-MQTT tras fallo TX de respuesta.
- c8ec143 corrige RESET-after-RESET en todos los boundaries exitosos compartidos por ZX/Next.
- No se demuestra otro latch Spectrum exitoso que sobreviva de más. Sí se demuestra la familia adyacente PC-MQTT: el latch RESET se suelta antes de un handoff fallido.
- DRAW se limpia estáticamente al completar rematch, pero falta el transcript DRAW fresco posterior y faltan sus boundaries NACK/TX-fail.
