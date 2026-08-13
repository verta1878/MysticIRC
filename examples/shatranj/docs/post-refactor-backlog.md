# Backlog post-refactor

Estado depurado el 2026-07-22, con session-core cerrado. Las entradas cerradas
se conservan tachadas para trazabilidad; solo `PENDIENTE`, `DECISION` y
`OPCIONAL` representan trabajo futuro. Añadir entradas nuevas al final con
fecha y no reabrir las cerradas sin una reproducción actual.

| # | Fecha | Petición | Contexto / evidencia | Severidad |
|---|-------|----------|----------------------|-----------|
| 1 | 2026-07-14 | ~~**TAKEBACK wedge**: rechazo/expiración atasca ambos peers~~ — **CUBIERTO EN SOFTWARE; REVALIDAR EN HW** | Los runners actuales cubren rechazo, nuevo prompt y expiración sin conservar el wedge. No abrir otro fix sin reproducir el deadlock original. | 🟡 validación |
| 2 | 2026-07-14 | ~~**Tabla MOVES del PC: números >=10 recortados**~~ — **CERRADO** | `9b1cabf`; validado visualmente por Ignacio. | ✅ |
| 3 | 2026-07-14 | ~~**Documentar el idiom de intervalo** en `direct_ovl.c` (`(uint16_t)(len-1u) >= 2048u`)~~ — **CERRADO** | El comentario explicita el wraparound de `len == 0` y que una sola comparación rechaza cero y valores mayores de 2048. Solo legibilidad; cero impacto binario. | ✅ |

| 4 | 2026-07-14 | ~~**Feedback audible** en PC/ZX/Next para chat y movimientos~~ — **DESCARTADO** | No se añadirá configuración ni código de sonido en esta release; reabrir solo ante una nueva decisión explícita. | ✅ decisión |
| 5 | 2026-07-14 | ~~**Marca GAME RESTORED en MOVES**~~ — **CERRADO** | `7cba4e7`; validado en el batch visual. | ✅ |
| 6 | 2026-07-14 | ~~**Chat PC: distinguir PLAYER y OPPONENT**~~ — **CERRADO** | `f8143ee`; formato bold del oponente. | ✅ |
| 7 | 2026-07-14 | ~~**TAKEBACK local expira en 2,5 s y termina DIRECT**~~ — **CERRADO POR DISEÑO** | El remoto dispone del envío inicial más cinco reintentos (≈15 s). El timer de 2,5 s señalado empieza tras `ACK <ply>` y espera la aplicación local del rollback; el remoto ya lo aplicó, por lo que `direct_finish()` evita continuar con tableros divergentes. El contrato está fijado por `test_direct_session_core.c` ("local takeback apply timeout ends inconsistent session"). Nota HW no bloqueante: revalidar TAKEBACK end-to-end en Spectrum, incluido swap de overlay/redibujado, para confirmar que la aplicación local completa holgadamente dentro de la ventana. | ✅ diseño; 🟡 HW |
| 8 | 2026-07-14 | ~~**Historial de últimos 5 comandos/mensajes PC**~~ — **CERRADO** | `7cba4e7`. | ✅ |
| 9 | 2026-07-14 | ~~**Reintentos PC tras BYE**~~ — **CERRADO EN SOFTWARE; CALIBRAR EN HW** | El guest PC/DIRECT hace el intento inicial y cinco reintentos a 2/4/6/8/10 s, solo ante `ConnectionRefusedError`; éxito, Cancel o cambio de destino/modo detienen la secuencia. El test levanta un listener real tras el primer rechazo y verifica la recuperación. Ajustar los 2 s únicamente si el re-arm ZX/Next medido en HW lo exige. | ✅; 🟡 HW |
| 10 | 2026-07-14 | ~~**Next: contraste de coordenadas del tablero por tema**~~ — **CERRADO** | `039357c`; usa el atributo oscuro del tema. | ✅ |
| 11 | 2026-07-14 | **PENDIENTE — estilizar el círculo de conexión Next** | Petición cosmética sin implementación localizada. | 🔵 cosmético |
| 12 | 2026-07-14 | ~~**Registrar eventos de control en el chat**~~ — **CERRADO** | `7cba4e7`; RESET/DRAW/RESIGN/TAKEBACK/RESTORE. | ✅ |
| 13 | 2026-07-14 | ~~**Preservar chat ZX/Next durante RESET con el mismo peer**~~ — **CERRADO** | `game_start_state()` limpia solo MOVES mediante `spectrum_gui_reset_moves()`; desconexión y carga completa conservan el borrado de MOVES+CHAT. | ✅ |

| 14 | 2026-07-14 | ~~**Purgar código diagnóstico M03**~~ — **CERRADO** | `2762c56`; cero referencias de producto a `NETCHESSZX_DIRECT_DIAG`. | ✅ |

| 15 | 2026-07-14 | ~~**PC: mejorar visibilidad de coordenadas del tablero**~~ — **CERRADO** | `bd38b29`; bold, brillo y mayúsculas; validado visualmente. | ✅ |
| 16 | 2026-07-14 | ~~**Ampliar el chat más allá de 42 caracteres**~~ — **CERRADO POR DISEÑO** | 42 caracteres llenan exactamente un frame Spectrum: `"CHAT " + 42 + NUL = 48 = SPECTRUM_LINK_PAYLOAD_MAX`, y coinciden con las dos líneas visibles del panel (18+24). No existe truncado en la cadena; el aparente corte es word-wrap y el límite silencioso del input Qt. Única acción derivada: el cliente Qt muestra un contador vivo `n/42` junto a SEND, calculado con `kChatTextMax`. | ✅ diseño |

| 17 | 2026-07-14 | ~~**Compatibilidad automática con ESP AT 1.6.2** mediante `AT+GMR` y recuperación legacy~~ — **DESCARTADO** | M03 quedó atribuido al firmware 1.6.2 y se resuelve actualizando a 1.7.6; no se mantendrá una ruta legacy automática. | ✅ decisión |

| 18 | 2026-07-14 | ~~**Reducir desconexión sucia de 33 s a ~21 s en todos los targets**~~ — **CERRADO EN SOFTWARE; REVALIDAR EN HW** | `SESSION_DIRECT_PING_TICKS=450` y `DIRECT_PING_WAIT_WINDOWS=3`: guest 3/12/21 s, host 18 s. Conserva dos misses, no toca MQTT y mantiene paridad PC/ZX/Next. Los oráculos cubren timeline y H2 con keepalive menor que la nueva ventana. | ✅; 🟡 HW |

| 19 | 2026-07-14 | ~~**Reseleccionar otra pieza propia debe mover el origen, no dar BAD MOVE**~~ — **CERRADO** | `cursor_select_or_move()` sustituye la selección al pulsar otra pieza propia, sin construir ni enviar MOVE. La paridad DIRECT incluye una comprobación que falla con el comportamiento anterior. | ✅ |

| 20 | 2026-07-14 | ~~**PC: confirmar DISCONNECT explícito**~~ — **CERRADO** | `28b5636`; diálogo seguro con No por defecto, validado visualmente. | ✅ |

<!-- añadir nuevas peticiones debajo -->

| 21 | 2026-07-15 | ~~**H1 — RESET/DRAW coexistían con MOVE/TAKEBACK pendiente**~~ — **CERRADO** | `06a2477`; runners comunes y gate HW de control-logic verdes. | ✅ |
| 22 | 2026-07-15 | ~~**H3 — PC-MQTT avanzaba tras fallo TX obligatorio**~~ — **CERRADO** | `35bd048`; fail-hard antes de mutar estado. | ✅ |
| 23 | 2026-07-15 | ~~**H4 — Spectrum ACKeaba crossed RESET en ACTIVE**~~ — **CERRADO** | `6e9cfcd`; NACK BUSY, paridad y HW verdes. | ✅ |
| 24 | 2026-07-15 | ~~**H7 — contradicción link-loss MQTT**~~ — **CERRADO POR DECISION** | `666669e`; prevalece session-core: link-loss termina y descarta sesión, partida e historial. | ✅ |
| 25 | 2026-07-15 | ~~**H2 — DRAW/RESET sin respuesta cerraban la sesión**~~ — **CERRADO**; ~~**H8 — RESIGN local durante MOVE pendiente**~~ — **CERRADO**; H5 cerrado | H2: `d8c9a3f`; tras los reintentos de transporte espera cinco minutos, envía CANCEL correlacionado y solo reanuda tras confirmación. H8: RESIGN, por ser terminal y unilateral, preempta únicamente un MOVE local ya entregado al transporte que espera ACK; cancela su timer y ningún ACK/NACK tardío puede aplicarlo ni reactivarlo. La paridad cubre DIRECT/MQTT, host/guest y PC/ZX/Next. H5 quedó cerrado en `83e3798`; H6 fue absorbido por fase 7. | ✅ H2/H5/H8 |
| 26 | 2026-07-17 | ~~**R2-B — bloquear MOVE MQTT fuera de GAME**~~ — **CERRADO** | `1a08517`; +189B NEX, margen final 181B, paridad/guards/ABI/size verdes. | ✅ |
