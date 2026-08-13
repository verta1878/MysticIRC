# Fase 7 paso 0 — cobertura del canon MQTT frente al PC legado

Baseline auditado: `main`, HEAD `6ac6c65112c4824d877e34ad5f5602e1ab4834db`.

Alcance: `handleMqttSessionPayload()` y sus ramas adyacentes de START, liveness y link-loss frente a `src/common/session/mqtt_session.c`, `session.c` y el corpus compartido. Auditoría source-only: no build, no test, no cambio de código. Los dos runners actuales recorren el mismo `mqtt_session_transcripts[]` (`tests/session/test_mqtt_session_core.c:242-307`, `tests/session/test_mqtt_session_parity.c:1775-1794`).

## Resumen

- Cubiertas: 7.
- Parciales: 4.
- Ausentes: 1.
- Los tres cierres críticos pedidos están implementados en el reducer; BUSY y F-sin-id tienen transcript directo. El cierre grupo8 tiene implementación genérica y transcript de expiración TX-guard, pero no un transcript directo `PING -> EV_TX_RESULT(FAILED)`.

## Tabla de cobertura

| Regla PC | Canon | Evidencia actual | Diferencia/gap |
|---|---|---|---|
| `O` presencia del rival + seat | PARCIAL | BUSY exacto: `mqtt_handle_online()` (`mqtt_session.c:837-870`); `mqtt-seat-acquire-exact-retained-busy` (`mqtt_session_transcripts.c:308-326`) | El canon no emite observación para el `O` blando del rival. PC cambia status/connected incluso con O sin id o id coincidente (`main.cpp:4768-4794`). Corpus fija `O` rival como inerte fuera de BUSY (`:486-488`, `:570-572`). |
| `F` rival: live, id obligatorio y sesión exacta termina partida | CUBIERTA | `mqtt_handle_offline()` exige LIVE, no retained, id presente y sesión exacta (`mqtt_session.c:873-915`); corpus ignora retained/idless/stale y termina con exacto live (`mqtt_session_transcripts.c:491-503,575-601`) | Ningún gap semántico. `F` sin id no se honra. |
| `F` propio re-publica `O` propio | PARCIAL | Reparación exacta: `mqtt_handle_offline():897-910`; transcript `live own offline repairs retained online` (`mqtt_session_transcripts.c:580-592`) | PC repara cualquier F propio parseable si side-ready, incluso retained/idless/stale; canon solo live + id exacto y fija retained exacto como inerte (`:575-577`). Hace falta decisión explícita, no copiar el alcance PC por accidente. |
| `H` guest: retained selecciona lado/probe; live adopta sesión y reclama asiento | CUBIERTA | `mqtt_handle_host():761-835`, `MQTT_STATE_PROBING`, `ACT_SIDE_CHANGED`, SEND `O`; corpus `mqtt-seat-acquire-retained-vs-live` (`:240-305`) | La suscripción Qt y orientación son ejecución de `ACT_SIDE_CHANGED`, no política nueva. |
| Reanuncio periódico `H` del host mientras espera | CUBIERTA | `SESSION_TIMER_CONTROL` vuelve a `mqtt_send_host()` solo para HOST/HANDSHAKE/no peer (`mqtt_session.c:2997-3009`); transcript `mqtt-bootstrap-host-reannounce` | El adapter solo programa/cancela el timer pedido. |
| `H` recibido por un PC host / conflicto de otro host | PARCIAL | El reducer aplica guard de rol e ignora H (`mqtt_session.c:779-781`); corpus mantiene el segundo host inerte (`mqtt_session_transcripts.c:430-434`) | Estado seguro cubierto; falta el diagnóstico visible PC `Host conflict - disconnect...` (`main.cpp:4853-4863`). Si se preserva UX, el canon necesita observación tipada; el adapter no debe parsear H. |
| `J` host: retained/mal/stale/ACTIVE se guardan; válido reenvía H y READY tras TX | PARCIAL | `mqtt_handle_join():918-952`; READY tras `MQTT_TX_HOST_LIVE` (`mqtt_session.c:2465-2478`); transcript de join/duplicado (`mqtt_session_transcripts.c:396-475`) | Política/estado cubiertos. Falta solo el status PC `GAME_ALREADY_ACTIVE` para J durante partida (`main.cpp:4915-4920`). |
| Reanuncio periódico `J` del guest pre-start | AUSENTE | PC llama `announceMqttSetup()` cada 5 s para guest side-ready (`main.cpp:6458-6463,6494-6507`) | El reducer acepta J duplicado en host, pero no arma timer ni vuelve a emitir J en guest; el timeout de setup solo reanuncia H del host (`mqtt_session.c:2997-3009`). Si esta recuperación sigue requerida, transcript + reducer antes de borrar. |
| GAME START / ACK/NACK, roles, retained y readiness | CUBIERTA | `mqtt_handle_game_start():955-995`, `mqtt_handle_start_reply():997-1070`, `MQTT_TX_ACK_START:2742-2759`; transcripts `mqtt-start-*` (`mqtt_session_transcripts.c:3013-3047`) | El adapter entrega route/flags y proyecta acciones; no conserva parser/policy Qt. |
| Side/session y orientación | CUBIERTA | `ACT_SIDE_CHANGED` incluye color+session id (`session.h:199-202`); emitido por H retained/live (`mqtt_session.c:788-815`) | Suscripciones, orientación y redraw son proyección PC del action. |
| Liveness/PING/ACK, peer timeout, release y fallo TX | CUBIERTA | `mqtt_handle_ping():1944-1994`; timers/PING/deadline (`mqtt_session.c:2719-2728,2880-2914`); cualquier TX_FAILED posterior a claim envía F propio (`:2778-2820`); corpus `mqtt-liveness-*` (`mqtt_session_transcripts.c:2175-2508`) | El crédito PC a cualquier PUBLISH live de topic peer (`main.cpp:4676-4680`) NO es canon: el contrato lo limita deliberadamente a eventos reconocidos (`session-core-contract.md:441-452`). No portarlo. Falta un transcript directo de PING TX_FAILED; el existente cubre expiración TX-guard. |
| Link-loss, pending state y sesión fresca | CUBIERTA | `session_step()` termina el active link y neutraliza link ajeno (`session.c:141-150`); corpus `mqtt-link-loss-*` (`mqtt_session_transcripts.c:2511-2725`) | El adapter debe conservar broker si ENDED llega sin CLOSE y emitir un LINK_UP explícito para la sesión siguiente; no hay resume/replay. |

## Gaps antes de borrar la política PC

1. Decidir si se conserva la señal UI de presencia `O`. Si sí, añadir observación/transcript común; el adapter no puede reconocer O.
2. Resolver el alcance de reparación de F propio: canon exacto-live frente a PC amplio. La opción mínima es declarar supersedido el alcance PC y conservar el canon actual.
3. Decidir si sobreviven los diagnósticos UI de H-conflict y J-durante-ACTIVE. La seguridad ya está cubierta como evento inerte; conservar textos exige una observación común.
4. El reanuncio periódico J del guest no existe en el reducer. Añadir transcript+timer/reenvío o deprecarlo explícitamente antes de eliminar `announceMqttSetup()`.
5. Blindaje grupo8: añadir transcript directo `PING send -> EV_TX_RESULT(FAILED) -> retained F propio -> END/CLOSE` y un test del adapter que pruebe que `mqttPublish()==false` se traduce inmediatamente a FAILED. El reducer ya hace el cleanup; el riesgo restante es la traducción Qt.

## Obligaciones del adapter, no gaps del canon

- Mapear topic a route y retain/live a flags sin parsear H/J/O/F.
- Ejecutar `ACT_SEND` serialmente y reentrar con el mismo tx-id como OK/FAILED.
- Invalidar timers viejos al SET/CANCEL.
- Ejecutar SIDE_CHANGED antes del SEND dependiente del nuevo lado.
- Diferenciar ENDED con/sin LINK_CLOSE para conservar el broker cuando corresponda.
