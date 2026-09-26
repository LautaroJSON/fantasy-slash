# Feature: Stacks visibles en los íconos de debuff

- **Estado:** Implementada (2026-09-26). Suite: 467 tests en verde con los valores de balance anteriores; con el ajuste nuevo del Giro y de Conmoción fallan 4 tests viejos ajenos a esta spec (ver §8). Import y smoke test sin errores.
- **Constitución:** `docs/constitution.md` v4.1.0 (enmienda MINOR aplicada, §6; la constitución estaba en v4.0.1 al cerrar).
- **Pilares (Principio I):**
  - **Combate:** el Berserker necesita saber si ya tiene a un enemigo en 3 stacks de Debilitar para decidir si sigue girando sobre ese grupo o cambia de objetivo.
  - **Progresión:** Rompecorazas (carta dorada de 3 niveles) se vuelve legible: se ve su efecto acumulándose.
- **Dependencias:** `spin-golden-upgrades.md`, `cooldown-timers.md` y `cooldown-clock.md` (Implementadas).
- **ACs reservados:** AC382–AC386 (reservados en `CLAUDE.md` al escribir la spec).

## 1. Diagnóstico

Lo verifiqué en una captura y con un log en la arena: Berserker con Giro + Rompecorazas contra un enemigo a 1.2 m.

| Tiempo | Distancia | Stacks | Vida |
|---|---|---|---|
| 0.0–0.9 s | 1.20 m | 0 | 40 |
| 1.0 s (1ª vuelta) | 1.28 m | **1** | 28 |
| 2.0 s (2ª vuelta) | 1.46 m | **2** | 17 |
| 3.0 s (3ª vuelta) | — | 3 | — |

- **La mecánica funciona:** cada vuelta del Giro (1 s a velocidad base, 3 s de duración) suma 1 stack, así que se llega a 3 al final de un Giro completo. El knockback aleja al enemigo unos 0.1 m por golpe, lejos del radio de 3 m.
- **El problema es visual:**
  1. **Los stacks no se muestran en ningún lado.** `DebuffIconRow` (3D) y `BossHealthBar` (jefe) solo muestran el color del debuff y su tiempo. `ActiveDebuff.stacks` nunca llega a la UI.
  2. **El ícono 3D es muy chico:** 0.12 m, unos 5 px en pantalla a distancia de juego. El violeta de Debilitar casi no se distingue.

## 2. Objetivo

- **Enemigos comunes (3D):**
  - El ícono crece de 0.12 a **0.2 m**.
  - Para los debuffs que acumulan (`get_stack_cap() > 1`, como Debilitar), se muestra el **número de stacks** en blanco en la esquina inferior derecha del ícono, siempre, incluso con 1 stack.
  - Los debuffs que no acumulan (Sangrado) no muestran número.
  - El tiempo sigue encima.
- **Barra del jefe (2D):** el mismo número en la esquina inferior derecha del ícono, igual que en los buffs, y con la misma regla (solo si el debuff acumula).
- El número se reescribe solo cuando cambian los stacks (con la señal `changed`, no por frame).

## 3. Estructura

| Archivo | Cambio |
|---|---|
| `resources/debuff_icon_config.gd` | `+ stack_font_size: int`, `+ stack_pixel_size: float`, `+ stack_offset: Vector2` (desde el centro del ícono, en metros). |
| `data/ui/debuff_icon_config.tres` | `icon_size 0.2`, `spacing` ajustado para que no se superpongan (≈ 0.14), `stack_font_size 28`, `stack_pixel_size 0.005`, `stack_offset (0.1, −0.08)`. `time_height_above_icon` sube con el ícono. Valores finales con captura. |
| `components/debuff_icon_row.gd` | Cada slot crea una vez un segundo `MeshInstance3D` hijo con su `TextMesh` (material compartido `time_material`, alineado abajo a la derecha). `refresh()` escribe `str(stacks)` y lo muestra solo si `get_stack_cap() > 1`. `+ get_stack_text(index) -> String`, `+ is_stack_visible(index) -> bool`. |
| `resources/boss_bar_config.gd` / `.tres` | `+ debuff_stack_font_size: int` (9). |
| `ui/boss_health_bar.gd` | Un `Label` más por ícono (abajo a la derecha, con contorno) que se escribe en `_refresh_debuffs()`. `+ get_debuff_stack_text(index) -> String`. |

`str(stacks)` crea un string solo cuando cambian los stacks (evento, no frame), igual que `BuffBar` con sus stacks (Principio V).

## 4. Criterios de aceptación

- **AC382** Enemigo común: tras aplicar Debilitar 1, 2 y 3 veces, el ícono muestra `"1"`, `"2"` y `"3"`. Una 4ª aplicación sigue en `"3"`. El texto de stacks es un `TextMesh` propio del slot, creado una vez, con el material `enemy_level_material.tres`.
- **AC383** Sangrado (no acumula) no muestra número de stacks. Con Sangrado y Debilitar a la vez, solo el ícono de Debilitar tiene número visible.
- **AC384** Barra del jefe: con 2 stacks de Debilitar el ícono muestra `"2"`; con Sangrado, vacío.
- **AC385** Con Rompecorazas, después de 3 vueltas del Giro (simuladas), el enemigo tiene 3 stacks y su ícono muestra `"3"`.
- **AC386** Regresión: suite completa en verde, import y smoke test sin errores. En la captura, el ícono de Debilitar y su número se leen a distancia de juego.

## 5. Tests que pueden necesitar adaptación

- AC324 (`cooldown_timers_test`) verifica que el primer hijo del ícono 3D es el texto de tiempo. Sigue siendo así: el de stacks se agrega como segundo hijo.
- AC350 (`cooldown_hud_test`) verifica que cada ícono 3D tiene **un** hijo y que no es un reloj. Pasa a verificar que ningún hijo es un `CooldownClock` (lo que verifica no cambia).

## 6. Enmienda: constitución v4.1.0 (MINOR, aplicada)

- **Principio II, tabla de colores:** la fila "Tiempo restante de debuff" pasa a ser **"Tiempo restante y stacks de debuff (sobre su ícono, en el enemigo) | `TextMesh` | Blanco"**. La frase del blanco compartido se actualiza igual.

## 7. Plan

1. Datos: campos nuevos en `DebuffIconConfig` y `BossBarConfig`, y sus `.tres`.
2. `DebuffIconRow`: texto de stacks y el ícono más grande. Tests AC382, AC383 y AC385.
3. `BossHealthBar`: label de stacks. Test AC384.
4. Adaptar AC350 (§5).
5. Captura de la arena con el Giro y Rompecorazas; ajustar tamaños y offsets.
6. Cierre: enmienda v4.1.0, suite completa, smoke test, `.uid` al proyecto, review de la constitución, estado **Implementada** y `CLAUDE.md` (specs recientes).

## 8. Notas de implementación

- **Valores finales** (con captura): `icon_size 0.2`, `spacing 0.14`, `height_above_bar 0.16` (antes 0.12; subió con el ícono para no tapar la barra), `time_height_above_icon 0.2`, `stack_font_size 28`, `stack_pixel_size 0.005`, `stack_offset (0.1, −0.08)`. Barra del jefe: `debuff_stack_font_size 9`.
- **Captura** (Berserker, Giro con Rompecorazas, 3 s): los enemigos muestran el cuadrado violeta con `1`, `2` y `3` según las vueltas que recibieron, legibles a distancia de juego. Con Sangrado agregado, su ícono no muestra número.
- **AC350** se adaptó como estaba previsto (§5): ahora verifica que ningún hijo del ícono 3D es un `CooldownClock`.
- **AC385** sube la vida del enemigo a 10 golpes (`set_max_health`), para no depender del daño del Giro.
- **Ajuste de balance ajeno a esta spec:** durante la implementación, `spin.tres` pasó de `base_damage 8 / attack_scaling 0.15` a `100 / 0.25`, y `concussion.tres` de `MOVE_SPEED 0.07` a `0.12` por stack (guardados desde el editor). Con esos valores fallan AC188 (`spin_test`), AC288, AC291 (`spin_golden_upgrades_test`) y AC298 (`spin_tornado_test`, `buff_component_test`): el Giro mata de un golpe al enemigo de prueba de 40 de vida, y el dato de Conmoción cambió. Con los valores anteriores la suite completa (467) pasa en verde. Quedan pendientes de la decisión del responsable (adaptar los tests o revertir el ajuste).

## 9. Review de la constitución (cierre)

- [x] **I:** Combate (saber si un enemigo ya está en 3 stacks) y Progresión (Rompecorazas legible), como declara la spec.
- [x] **II:** números como `TextMesh` con el material compartido `enemy_level_material.tres`; el blanco se registró con la enmienda v4.1.0. Ícono sigue siendo el `BoxMesh` con su material compartido.
- [x] **III:** tamaños y offsets en `debuff_icon_config.tres` y `boss_bar_config.tres`. La regla de mostrar stacks sale de `DebuffData.get_stack_cap()`.
- [x] **IV:** tipado completo; `refresh()` delega en `_show_stacks()`.
- [x] **V:** `TextMesh` y labels creados una vez por slot; el número se escribe solo cuando cambia la lista (señal `changed`), nunca por frame.
- [x] **VI:** sin input nuevo.
- [ ] **Calidad:** los tests de esta spec están en verde; la suite completa queda en verde solo con los valores de balance anteriores (§8).
