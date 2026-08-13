# Prompt para la sesión nueva — Session Core Refactor

Copia y pega íntegramente este prompt al abrir la sesión nueva. Sustituye
EXPECTED_HEAD por el SHA del commit documental que contiene estos dos ficheros,
si Ignacio te lo proporciona en el mismo mensaje.

~~~text
Continúa el refactor Session Core de NetChessZX desde el checkpoint existente.
No reconstruyas el contexto desde fase 0, no preguntes de qué va el proyecto y
no hagas una lectura exploratoria general del repositorio.

Repositorio:
C:\Users\ignac\Dropbox\Retro\Software\Para divMMC\NetChessZX

Rama obligatoria:
refactor/session-core

Checkpoint funcional inmutable:
b47074347e05816056110b14414da3bb2b6668fb

HEAD documental esperado:
EXPECTED_HEAD

Tu primera acción debe ser exactamente:

git status --short --branch
git rev-parse HEAD
git log --oneline -5

Debe salir rama refactor/session-core, árbol limpio y HEAD documental cuyo padre
funcional es b470743. Si no coincide, informa y detente: no hagas reset, restore,
clean ni ninguna reparación automática.

Después lee COMPLETO:

docs/session-core-refactor-handoff.md

Luego lee las secciones relevantes, no el repositorio entero:

1. docs/session-core-contract.md:
   - Input Events;
   - Output Actions;
   - DIRECT Normalization Decisions;
   - RESTORE, TAKEBACK, RESIGN y liveness.
2. docs/session-core-refactor-plan.md:
   - estado y tabla de fases;
   - Phase 4;
   - Phase 5;
   - acceptance, rollback y stop conditions.
3. docs/session-core-size-ledger.md:
   - baseline;
   - parity judge desde HELLO/MOVE;
   - liveness;
   - seams;
   - DRAW;
   - RESIGN cerrado.

No me devuelvas una introducción larga. En un máximo de diez líneas confirma:

- rama/HEAD/árbol;
- arquitectura “una semántica, dos implementaciones, un juez”;
- fase 4 en curso;
- HELLO, MOVE, liveness, DRAW y RESIGN cerrados;
- TAKEBACK como único bloque abierto;
- ZX 34347/BSS398/guard1607/SP1951;
- Next TAP 34394/BSS398/guard1559/SP1903;
- Next NEX 35357/BSS497/guard497/SP841;
- primer transcript TAKEBACK que vas a añadir.

Gates de aceptación por target, medidos en el mismo build:

- ZX: residente <= 34363 y SP_GAP >= 1935;
- Next TAP: residente <= 34398 y SP_GAP >= 1902.

Empieza inmediatamente TAKEBACK. No abras RESTORE, BUSY ni MQTT en paralelo.

Cobertura TAKEBACK obligatoria:

1. local request + ACK correlacionado + apply + accepted result + ply retrocede;
2. remoto: decisión y apply antes de ACK;
3. duplicado aceptado: re-ACK sin reaplicar;
4. rechazo/fallo de apply: NACK y nuevo intento permitido;
5. resultado stale/wrong-ply ignorado;
6. TAKEBACK cruzado con MOVE en vuelo;
7. TAKEBACK después de TAKEBACK;
8. latch takeback_pending_ply conservado hasta MOVE/RESET; otro ply es operación
   nueva.

La lista de cobertura describe escenarios. Donde el contrato aún no fije el
resultado, decide el método de nueve pasos, no esta lista.

Método obligatorio para cada divergencia:

1. transcript neutral;
2. rojo archivado en ledger antes de tocar producto;
3. decidir si falla producto o instrumento;
4. si es producto, PC v1.0 como árbitro de campo;
5. decisión escrita en contrato;
6. parche mínimo en el motor incorrecto;
7. verde en ambos runners con expectativas idénticas;
8. bytes/BSS/stack enlazados del mismo build;
9. cierre en ledger antes del siguiente bloque.

Una divergencia no demuestra que el reducer tenga razón. DRAW produjo un falso
rojo porque un shim host interpretó /draw como MOVE. La lista de stubs es la
lista de puntos ciegos: no inventes semántica. Enlaza C real de producto cuando
exista; si solo hay ASM, transcripción fiel y vectores dorados derivados de sus
ramas.

Restricciones:

- Spectrum conserva su FSM compacta;
- PC conserva el reducer común canónico;
- no enlazar core/ejecutor genérico en ZX/Next;
- no expectativas específicas por target;
- seam nuevo en fuentes de producto: TAP byte-idéntico con la macro host off y
  hash archivado en el ledger; cero bytes se demuestra, no se estima;
- no relajar baseline, BSS, pila u overlays;
- no mover reducer a overlay, banking o 128K;
- link loss termina y descarta la partida; no resume/replay;
- no investigar client-msvc salvo bloqueo directo del trabajo;
- no afirmar hardware desde host;
- MQTT queda bloqueado hasta hardware fase 5;
- un solo bloque abierto;
- no commits salvo petición expresa de Ignacio;
- reporta progreso al menos cada 60 segundos;
- comunicación Caveman full, densa y técnica.

Entorno:

- PowerShell 7;
- Python C:/Program Files/Python311/python.exe;
- para make: PYTHON=C:/Progra~1/Python311/python.exe;
- nunca bare python;
- TEMP/TMP autorizado:
  C:\Users\ignac\AppData\Local\Temp\netchesszx-zcc;
- builds ZX/Next seriales porque comparten objetos;
- make test incluye tap-next;
- make next puede tardar unos cinco minutos;
- errores rojos posteriores intentando restaurar TEMP son ruido ambiental si el
  exit code, mapa y artefacto son verdes.

Gates del checkpoint ya ejecutados con exit 0:

make NO_COLOR=1 PYTHON=C:/Progra~1/Python311/python.exe test
make NO_COLOR=1 PYTHON=C:/Progra~1/Python311/python.exe abi-check size-check
make NO_COLOR=1 PYTHON=C:/Progra~1/Python311/python.exe next

No los repitas al inicio. Ejecuta primero el test focused de TAKEBACK; enlaza y
mide solo cuando exista un bloque semántico que medir.

Después de TAKEBACK, y solo después:

1. RESTORE completo;
2. intrusos/BUSY/close;
3. cierre formal fase 4;
4. checklist y hardware fase 5;
5. MQTT fases 6-9.

Sigue hasta completar el bloque TAKEBACK o encontrar un bloqueo real. No pares
para pedirme contexto que ya está en el handoff.
~~~
