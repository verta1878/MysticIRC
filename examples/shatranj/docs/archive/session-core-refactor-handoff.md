# Session Core Refactor — Handoff operativo

Fecha: 2026-07-11

Este documento transfiere el trabajo de la rama refactor/session-core a una
sesión nueva. Es un estado operativo, no una introducción al proyecto. La nueva
sesión no debe reconstruir las fases 0-4 desde cero: debe verificar el
checkpoint, leer las fuentes normativas indicadas y continuar directamente por
TAKEBACK.

## 1. Autoridad y punto de partida

- Repositorio:
  C:\Users\ignac\Dropbox\Retro\Software\Para divMMC\NetChessZX
- Rama obligatoria: refactor/session-core
- Tag baseline: baseline-pre-refactor
- Commit baseline:
  76d4c135dc7dcbe0b316d1362f1476f0d46edad7
- Checkpoint del intento genérico rechazado:
  66e2f7c
- Commit que restauró la ruta compacta Spectrum:
  9da6fc1
- Checkpoint funcional cerrado hasta RESIGN:
  b47074347e05816056110b14414da3bb2b6668fb
- El commit documental que contiene este fichero debe ser hijo directo de
  b470743.
- Ignacio confirmó expresamente que todos los cambios del checkpoint eran de
  Codex. El árbol quedó limpio antes de crear este handoff.

Primeras comprobaciones de la sesión receptora:

~~~powershell
git status --short --branch
git rev-parse HEAD
git log --oneline -5
~~~

Resultado requerido:

- Rama refactor/session-core.
- Árbol limpio.
- HEAD contiene este handoff.
- b470743 es el padre funcional inmutable.

Si rama, limpieza o historia no coinciden: informar antes de editar. No
restaurar, resetear, limpiar ni asumir que la suciedad es prescindible.

## 2. Decisión arquitectónica vigente

Frase normativa:

> Una semántica, dos implementaciones, un juez.

- PC: reducer común canónico en src/common/session/.
- ZX y Next: FSM compacta de producción ya existente.
- Juez host: ejecuta los mismos transcripts y compara exactamente las mismas
  observaciones semánticas contra ambos motores.
- ZX/Next no enlazan el reducer común ni el ejecutor genérico de acciones.
- No puede haber expectativas específicas por target.
- La equivalencia se garantiza por contrato y transcripts, no por identidad de
  object code.

Motivo físico del pivote:

- El adapter genérico Spectrum llevó el residente a aproximadamente 65 KiB:
  +31.077 bytes.
- Aun eliminando todo el reducer común, el plumbing genérico ya superaba el
  presupuesto 48K.
- No existe una optimización del mismo ABI capaz de reducir ese coste a +128
  bytes.
- Abandonar 48K o mover el problema a banking/overlays cambia el producto y no
  está autorizado.

Conservar:

- Core común y reducer DIRECT como referencia canónica.
- Adapter PC.
- Harness nativo y transcripts.
- Guardas de módulos, ABI y política DIRECT.
- Conocimiento contractual descubierto por la auditoría.
- Runtime Spectrum compacto.

No reabrir el adapter genérico Spectrum, no mover el reducer a overlay y no
proponer 128K/banking salvo autorización expresa de Ignacio.

## 3. Fuentes normativas

Leer completamente antes del primer cambio de producto:

1. docs/session-core-refactor-handoff.md — este estado.
2. docs/session-core-contract.md — semántica normativa.
3. docs/session-core-refactor-plan.md — alcance, fases, gates y stop conditions.
4. docs/session-core-size-ledger.md — opciones, rojos, decisiones y medidas.
5. docs/baseline-pre-refactor.md — síntomas heredados y reglas de comparación.

Prioridad ante contradicción:

1. Petición actual de Ignacio.
2. Contrato y plan actuales.
3. Este handoff.
4. Ledger.
5. Notas históricas o memoria.

La semántica vigente de pérdida de enlace es inequívoca: termina y descarta la
partida; un enlace posterior inicia handshake, sesión y partida nuevos. No hay
resume, replay ni sesión suspendida. Cualquier memoria antigua que diga lo
contrario está superada por el contrato y el plan actuales.

## 4. Estado de fases

| Fase | Estado | Evidencia |
|---|---|---|
| 0 | Cerrada | Tag baseline, artefactos y ledger |
| 1 | Cerrada | ABI host congelada y harness nativo |
| 2 | Cerrada | Reducer DIRECT canónico y transcripts nativos |
| 3 | Cerrada en checkpoint | Adapter PC y guard de política |
| 4 | En curso tras pivote | Juez compartido operativo; cerrado hasta RESIGN |
| 5 | No iniciada | Checkpoint hardware DIRECT obligatorio |
| 6-9 | Replanificadas | MQTT con el mismo patrón, solo tras fase 5 |

El wrapper make client-msvc conserva un bloqueo ambiental heredado
(Constrained Language Mode/proceso de compilador y CMake). La compilación y el
enlace MSVC directos con las mismas opciones ya sirvieron como evidencia. No
convertirlo en una excursión del refactor.

## 5. Bloques de fase 4 cerrados

- Rollback de la integración Spectrum genérica físicamente inviable.
- Juez diferencial real alrededor del game_message_loop de producción.
- Link id 0.
- HELLO inicial perdido, roles, lado, ready y start.
- HELLO duplicado consumido sin echo loop.
- MOVE local y remoto.
- ACK/NACK correlacionados por ply.
- Resultados stale/wrong-ply ignorados.
- MOVE remoto duplicado aplicado una vez.
- Forma normativa NACK <ply> SYNC.
- Interoperabilidad mixta de SYNC comprobada:
  - PC v1.0 ya emitía SYNC.
  - Spectrum antiguo toleraba el sufijo.
- Kernel ASM normal-ABI de 45 bytes para ACK/NACK numéricos.
- Vectores dorados ACK/NACK para ply 0 y 65535.
- Color de host RESTORE inmutable.
- Liveness DIRECT PAL/Next 50/60 Hz.
- PING, ACK PING y rearme por tráfico válido.
- Pérdida silenciosa de guest y host.
- Fallos asimétricos de handoff PING/ACK PING.
- DRAW aceptado hasta RESET automático y segundo STARTED.
- DRAW cruzado, re-ACK de duplicado y RESET cruzado.
- Auditoría completa de seams host.
- RESIGN remoto duplicado.
- RESIGN cruzado y eliminación del retry zombi.

## 6. Juez compartido

Ficheros:

- tests/session/direct_parity.h
- tests/session/direct_reference_runner.c
- tests/session/test_direct_session_parity.c

Diseño:

- test_direct_session_parity.c incluye app.c completo bajo
  NETCHESSZX_HOST_SESSION_TEST.
- Se ejecutan handlers, polling y game_message_loop reales del Spectrum.
- Los stubs de transporte capturan cada envío con type, link_id, code, value,
  length y payload byte a byte.
- El runner canónico ejecuta session_step().
- Ambos comparan la misma traza exacta contra una sola expectativa neutral.
- Un escenario debe consumir todos sus pasos, dejar peer_ready limpio y no
  desbordar la traza.

Escenarios actuales, por nombre exacto:

1. host-link-hello-down
2. guest-link-hello-down
3. host-link-zero
4. host-duplicate-hello
5. start-host
6. start-guest
7. move-local-ack
8. move-local-stale-results
9. move-remote-duplicate
10. move-ply-sync
11. draw-rematch-guest
12. draw-crossed
13. resign-remote-duplicate
14. resign-crossed
15. liveness-ack
16. liveness-pending-window
17. liveness-guest-loss
18. liveness-host-loss
19. liveness-ping-send-fail
20. liveness-ack-ping-send-fail

Comando focused:

~~~powershell
& .\build\netchesszx_direct_session_parity_test.exe
~~~

Salida actual:

~~~text
DIRECT semantic parity scenarios ok
~~~

## 7. Seams del juez y puntos ciegos ya eliminados

La lista de stubs es la lista de puntos ciegos. La tercera categoría
“inventa semántica” debe permanecer vacía.

- Parser MOVE:
  - El falso rojo de /draw demostró que el shim permisivo era inválido.
  - La implementación real es ASM en
    asm/overlay/gui_log/entry_gui_log.asm:58-160.
  - El host usa una transcripción fiel con matriz independiente de 20 ramas:
    espacios, límites a-h/1-8, fold ASCII, separadores, promoción y basura.
  - En fallo solo se aserta retorno falso; el buffer queda indefinido y puede
    contener escrituras parciales.
- Local MOVE result:
  - Se captura en el hecho semántico post-apply ACK, no en una sombra GUI.
  - Un solo macro HOST_SESSION_OBSERVE_MOVE_RESULT() centraliza el seam de
    producto.
  - Con macros host desactivadas, TAP y mapa fueron byte-idénticos antes/después
    del seam.
- strlen8/append text/append u16:
  - Vectores dorados comprueban texto, NUL, puntero devuelto y límites hasta
    65535.
- RESTORE codec:
  - Se compila la implementación C real de restore_ovl.c en host.
  - Roundtrip, base64 inválido y frame exacto de 60 bytes en chunks 30+30.
  - Los trampolines ASM solo hacen ex de,hl y jp; no añaden semántica.
- GUI:
  - Connected, orientación, paneles, piezas, notify y timers son capturas cuando
    constituyen hechos asertables.
  - Llamadas puramente visuales pueden quedar inert.
- Rutas MQTT/setup/file fuera de DIRECT:
  - Fail-fast si el transcript DIRECT entra accidentalmente en ellas.

Antes de MQTT, volver a auditar cualquier callsite que comparta scratch de
low-RAM con el parser MOVE: un parse fallido puede escribir parcialmente.

## 8. Expediente RESIGN cerrado

Rojo archivado antes del parche:

~~~text
FAIL: resign-crossed Spectrum observation count 12 != 11
trace 6: SEND RESIGN
trace 7: CONTROL RESIGN accepted
trace 8: SEND ACK RESIGN
trace 9: SEND PING
trace 10: SEND RESIGN          <- unexpected stale retry
trace 11: ENDED
~~~

Causa:

- RESIGN entrante se ACKeaba.
- resign_pending permanecía a 1.
- retry_pending_outgoing() emitía un RESIGN fantasma.
- Si ya había empezado una revancha, el mensaje zombi podía terminarla minutos
  después.

Árbitro PC v1.0:

- RESIGN local terminaba sin conservar retry.
- RESIGN remoto era unilateral, idempotente y sin RESET automático.
- El reducer canónico añade ACK y limpia el crossed retry tras el handoff.

Contrato:

- ACK a todo RESIGN recibido.
- Aplicar como máximo una vez.
- RESIGN cruzado limpia el retry local tras entregar ACK.
- Termina seco; no encadena RESET.

Parche Spectrum:

~~~c
if (!tcp_required(netchesszx_session_send_ack_resign())) {
    return SESSION_DISPATCH_EXIT;
}
resign_pending = 0u;
~~~

El clear va después del ACK exitoso. Si falla el handoff, tcp_required() sale de
la sesión y teardown elimina todo pending; no existe continuación sana con el
retry vivo.

Coste:

- Clear directo: +4 bytes ZX/Next.
- Recuperación Next-only fuera del handler:
  - no limpiar _rx_byte mientras _is_recv=0: -3 bytes;
  - reutilizar B con inc b entre UART_SEL=$153B y UART_FRAME=$163B: -2 bytes.
- Neto Next del bloque: -1 residente y +1 de margen SP.
- Se rechazó compartir el tail RESIGN/ACK_RESIGN para conservar legibilidad.

Disassembly enlazado Next:

~~~text
d628 xor a
d629 ld ($f7b9),a       ; solo _is_recv
d62c ld bc,$153b
...
d631 out (c),a
d633 inc b              ; pasa a $163b
~~~

No aparece clear de _rx_byte.

## 9. Liveness normativa y riesgo hardware

El contrato común usa ticks de 20 ms. El adapter compacto DIRECT entrega un
timeout cada dos frames:

- src/spectrum/overlay/direct_ovl.c define WAIT_POLL=2.
- Cada iteración llama net_wait_frame().
- Un SPECTRUM_LINK_READ_TIMEOUT equivale a dos ticks de protocolo.

Política compacta:

- DIRECT_IDLE_PING_TICKS=75 quanta a 50 Hz.
- Next usa 90 a 60 Hz, seleccionado por nextreg de timing.
- DIRECT_WAIT_WINDOWS=5.
- DIRECT_MISSES_MAX=2.
- MQTT mantiene sus constantes 120/4; no fue contaminado.

Tiempos hardware que fase 5 debe cronometrar:

- Guest: primer PING a 3 s.
- Guest: segundo PING a 18 s.
- Guest: cierre a 33 s.
- Host silencioso: cierre a 30 s.

Handoff de envío:

- Fallo de PING saliente DIRECT: fail-hard y cierre.
- Fallo de ACK PING: no cierra inmediatamente; el PING entrante ya probó al
  peer vivo.
- MQTT conserva fail-hard.

Esto está validado en software, pero el cronómetro y un ESP lento/saturado son
gates hardware, no afirmaciones host.

## 10. Métricas físicas

Baseline inmutable:

| Target | Resident | BSS | Guard | SP gap | Full |
|---|---:|---:|---:|---:|---:|
| ZX TAP | 34363 | 398 | 1591 | 1935 | 34761 |
| Next TAP | 34398 | 398 | 1556 | 1900 | 34796 |
| Next NEX | 35361 | 497 | 494 | 838 | 35858 |

Checkpoint funcional b470743:

| Target | Resident | BSS | Guard | SP gap | Full | Artefacto |
|---|---:|---:|---:|---:|---:|---:|
| ZX TAP | 34347 | 398 | 1607 | 1951 | 34745 | TAP 34427 |
| Next TAP | 34394 | 398 | 1559 | 1903 | 34793 | TAP 34474 |
| Next NEX | 35357 | 497 | 497 | 841 | 35855 | NEX 82432 |

Deltas contra baseline:

- ZX: residente -16; guard/SP +16.
- Next TAP: residente -4; guard/SP +3.
- Next NEX: residente -4; guard/SP +3.
- BSS sin crecimiento.
- Todos los overlays conservan sus tamaños aceptados.

Overlays relevantes:

- DIRECT: 2041/2048.
- RESTORE: 1882/2048.
- GUI_LOG: 2031/2048.
- BOARD: 2018/2048.
- Total ZX: 25275.
- Total Next TAP: 25515.
- Total NEX: 25058.

El hard floor de 512 aplica al SP gap medido. El stack-guard NEX se registra
separadamente y puede estar por debajo de 512.

## 11. Hashes del checkpoint

| Artefacto | SHA-256 |
|---|---|
| ZX TAP | EBAF5B2E29070BA24E211E852BCF5B8144867915BDC6AF246862F3B9B0989EFE |
| ZX OVL | 780D3A32BB246C6C209D389A261043B84629994C4E554B4F6D8243911F160AFD |
| ZX DAT | 7EAE7B02C62582AD8B2C727B2434A621FC078C3938C10748EA2FB4836ED18A3B |
| Next TAP | 18821C28D536944A6951CDC8D747816D5BB657480AFDE0835A1076B90FAD5A52 |
| Next OVL | 0DB92C7609F5CD76F95A21A77D272CDCDE35D8848B4D309F55857C94A3A595E1 |
| Next DAT | 1C2E79E51449C7ED0F1CC5EB3326FF97E39220AD34275403DEE432BAF0706F89 |
| Next NEX | 99D8535CF9B7FC97737712B45F8FAF31D4063221632DF18500ADE8051CE7A78E |

## 12. Gates ejecutados antes del checkpoint

Todos salieron con exit code 0:

~~~powershell
make NO_COLOR=1 PYTHON=C:/Progra~1/Python311/python.exe test
make NO_COLOR=1 PYTHON=C:/Progra~1/Python311/python.exe abi-check size-check
make NO_COLOR=1 PYTHON=C:/Progra~1/Python311/python.exe next
git diff --check
~~~

Resultados:

- Suite host completa verde.
- 20 escenarios DIRECT parity verdes.
- tap-next verde: 34394/BSS398/guard1559/SP1903.
- ZX ABI idéntica al baseline.
- ZX size-check verde: 34347/BSS398/guard1607/SP1951.
- Next NEX, codec, low-RAM, ABI y overlays verdes:
  35357/BSS497/guard497/SP841.

## 13. Entorno de build

- Windows 11.
- Shell: PowerShell 7.
- Python obligatorio:
  C:/Program Files/Python311/python.exe
- Para make/zcc usar:
  PYTHON=C:/Progra~1/Python311/python.exe
- No usar bare python.
- Carpeta temporal autorizada:
  C:\Users\ignac\AppData\Local\Temp\netchesszx-zcc

Preparación:

~~~powershell
$env:TEMP='C:\Users\ignac\AppData\Local\Temp\netchesszx-zcc'
$env:TMP=$env:TEMP
~~~

Notas:

- Los builds ZX/Next comparten objetos: ejecutar targets serialmente.
- make test incluye tap-next.
- make next tarda alrededor de cinco minutos porque el atlas puede forzar un
  segundo enlace.
- Tras un build exitoso pueden aparecer errores rojos de PowerShell intentando
  ejecutar la restauración de TEMP como si fuera un comando. Son ruido
  ambiental posterior al éxito. Mandan exit code, mapa y artefactos.
- Si un wrapper expira pero el artefacto aparece, no declararlo verde: repetir
  con timeout suficiente y obtener exit 0.

## 14. Mapa del checkpoint funcional

- Makefile:
  integra el parity judge, ping Next 50/60 y dependencias reales.
- asm/spectrum/shrink_kernels.asm:
  formatter ACK/NACK compacto normal-ABI.
- asm/uart/next_uart.asm:
  timing 75/90 y recuperación Next-only de 5 bytes.
- docs/session-core-contract.md:
  SYNC, RESTORE, liveness, fallos de envío y RESIGN.
- docs/session-core-refactor-plan.md:
  pivote, progreso y gates.
- docs/session-core-size-ledger.md:
  expedientes rojo-verde, seams, opciones y medidas.
- src/common/session/direct_session.c:
  ACK-PING fallido tratado como ACK perdido.
- src/spectrum/app/app.c:
  seam único, HELLO, SYNC y RESIGN.
- src/spectrum/overlay/restore_ovl.c:
  algoritmo real compilable en host.
- src/spectrum/session/outgoing.c:
  fallback C host; target usa kernel ASM.
- src/spectrum/session/ping.c/.h:
  política DIRECT separada de MQTT y timing 50/60.
- src/spectrum/session/poll.c:
  PING DIRECT fallido es fail-hard.
- tests/session/:
  contrato neutral, runner canónico y juez Spectrum.
- tests/spectrum/:
  formatter, liveness, send-fail y timing.

## 15. Siguiente bloque: TAKEBACK

TAKEBACK es el único bloque abierto al iniciar la nueva sesión. No empezar
RESTORE, BUSY ni MQTT en paralelo.

Cobertura mínima requerida:

1. TAKEBACK local:
   - request con ply;
   - ACK correlacionado;
   - aplicación de dominio;
   - resultado accepted;
   - ply retrocede.
2. TAKEBACK remoto:
   - decisión local;
   - aplicación de dominio antes del ACK.
3. Duplicado aceptado:
   - re-ACK;
   - no reaplicar.
4. Rechazo o fallo de aplicación:
   - NACK;
   - permitir nuevo intento.
5. Resultado stale o wrong-ply:
   - ignorar sin observaciones extra.
6. TAKEBACK cruzado con MOVE en vuelo:
   - determinar qué ply se deshace.
7. TAKEBACK después de TAKEBACK.
8. Latch por ply:
   - conservar hasta MOVE/RESET;
   - una petición de otro ply es una operación nueva.

Procedimiento obligatorio:

1. Añadir transcript neutral al corpus.
2. Archivar rojo antes de tocar producto.
3. Determinar si el rojo pertenece al producto o al instrumento.
4. Si es producto, consultar PC v1.0 como árbitro de campo.
5. Escribir la decisión en el contrato.
6. Parche mínimo en el motor incorrecto.
7. Verde en ambos runners.
8. Medir bytes, BSS y pila en el mismo build enlazado.
9. Cerrar TAKEBACK en ledger antes de abrir RESTORE.

No asumir que el reducer tiene razón solo porque diverge. DRAW demostró que el
instrumento también puede fabricar rojos.

## 16. Cola después de TAKEBACK

### RESTORE completo

Ya cubierto:

- color de host inmutable;
- codec C real;
- roundtrip;
- base64 inválido;
- frame exacto 60 bytes en chunks 30+30.

Falta parity de producto:

- adoptar phase y ply restaurados;
- READY/ACTIVE/OVER;
- cancelación temprana durante WAIT_RY;
- cancelación tardía durante WAIT_RA ignorada;
- RN limpia prompt, estado y timer;
- aislamiento de timeout stale;
- dos chunks frescos obligatorios;
- duplicado exacto re-ACK;
- chunk conflictivo no muta workspace;
- RQ posterior a restore completo no se confunde con duplicado.

### Intrusos, BUSY y close

- Candidate link recibe BUSY dirigido y solo ese link se cierra.
- Link-down del intruso no toca sesión activa.
- Link-down activo termina y limpia.
- BYE local espera handoff antes de cerrar.
- BYE remoto termina.
- BYE durante handshake o control pendiente.
- Candidate en vuelo durante teardown.
- No resume/replay tras reconexión.

### Cierre formal de fase 4

- Corpus completo verde en ambos motores.
- make test.
- make abi-check size-check.
- make next.
- Mapas, hashes y overlays archivados.
- Checklist hardware fase 5 preparada como entregable.

### Fase 5 hardware obligatoria

- PC↔ZX en ambos roles.
- PC↔Next en ambos roles y a 50/60 Hz.
- ZX↔Next solo si la ruta está soportada.
- HELLO, side/ready, start, MOVE/ACK, liveness y close.
- Cronómetro 3/18/33 s guest y 30 s host.
- ESP lento/saturado:
  - fallo PING saliente termina;
  - fallo ACK PING no termina inmediatamente.
- UART Next:
  - init repetido;
  - modos 0-7;
  - cache RX válida sin clear inicial;
  - transición $153B->$163B mediante inc b.
- Registrar hash, hardware, modo, resultado, wire y transcript id.

MQTT fases 6-9 no empieza hasta superar fase 5.

## 17. Reglas de método no negociables

- Un solo bloque abierto.
- No parche de producto sin transcript rojo archivado.
- Rojo prueba divergencia; no prueba qué motor tiene razón.
- Primero aislar producto frente a instrumento.
- PC v1.0 es árbitro de interop cuando existe comportamiento desplegado.
- Contrato antes del parche.
- Parche mínimo en el motor incorrecto.
- Mismas expectativas para ambos targets.
- Verde ambos motores.
- Medir bytes enlazados; no estimaciones ASM.
- Medir BSS, stack-guard y SP gap del mismo artefacto.
- No relajar baseline, BSS, pila ni overlay.
- No añadir seams semánticos inventados.
- Preferir C real de producto; si solo hay ASM, transcripción fiel y vectores
  dorados derivados de ramas.
- Cada seam host-only en app.c debe demostrar cero bytes target.
- No afirmar hardware desde tests host.
- No mezclar el bloqueo client-msvc con el refactor.
- No iniciar MQTT antes del hardware DIRECT.
- No hacer commits futuros salvo petición expresa de Ignacio.
- Informar a Ignacio durante el trabajo al menos cada 60 segundos.
- Comunicación Caveman full: breve, densa, técnica, sin relleno.

## 18. Acción inmediata de la sesión receptora

Tras verificar rama/HEAD/limpieza:

1. Leer este handoff completo.
2. Leer contrato, plan y ledger por las secciones indicadas.
3. Reportar en no más de diez líneas:
   - checkpoint reconocido;
   - fase 4;
   - RESIGN cerrado;
   - TAKEBACK como único bloque abierto;
   - métricas actuales;
   - primer transcript que va a escribir.
4. Empezar inmediatamente el transcript rojo de TAKEBACK.
5. No volver a explicar el proyecto desde fase 0.
