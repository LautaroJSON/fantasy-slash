# Feature: botón de dash en el HUD

- **Estado:** Implementada (2026-09-27). ACs: AC769–AC777. Constitución enmendada a 4.14.0 (aplicada).
- **Constitución:** `docs/constitution.md` v4.13.1 → **enmienda MINOR a 4.14.0** (Principio VI, ver §6).
- **Pilar (Principio I):** **combate.** El dash es la herramienta defensiva principal. Mostrarlo como un botón igual a los de habilidad, con el reloj de recarga y el pulso al quedar listo, lo pone junto a las demás acciones de combate: se lee de un vistazo cuándo se puede esquivar. El botón también deja preparado el camino para una versión táctil.
- **Dependencias:** `ability-slot-frame.md`, `cooldown-clock.md`, `cooldown-timers.md` (AC321), `player-hud-layout.md` (AC173), `sprint-stamina.md` (AC720), `gamepad-support.md`.

## 1. Estado actual

1. El dash se muestra como una barra (`%DashBar`, abajo a la izquierda) con el texto `DASH` (`HudConfig.dash_ready_text`) o los segundos restantes (`%DashLabel`), que `Hud._process` actualiza.
2. La barra de estamina (`%StaminaBar`) está debajo de la barra de dash.
3. Los botones de habilidad (`AbilitySlotView`) son círculos dibujados: relleno celeste pálido, reloj translúcido de recarga, segundos en el centro durante la recarga, prompt de la tecla cuando está listo, pulso al quedar listo y marco opaco. Solo sirven para `AbilityComponent`.
4. Constitución, Principio VI: "No hay soporte de pantalla táctil".

## 2. Diseño

### 2.1 Qué se ve

- **Desaparecen** `%DashBar` y `%DashLabel`.
- **Botón de dash** `%DashSlot`: un `AbilitySlotView` más, en `AbilitySlots` (abajo a la derecha), **a la izquierda de E**, con el tamaño de E (`basic_radius` = 32). Muestra lo mismo que un botón de habilidad:
  - Listo: círculo celeste pálido con el prompt de la tecla (`Clic D` con teclado y mouse, `B` con mando, desde `InputPromptConfig`).
  - Recarga: reloj translúcido sobre la parte que falta y los segundos restantes en el centro (`S.S` bajo 10 s, redondeo hacia arriba, `CooldownText`), en lugar del prompt.
  - Al quedar listo: el pulso de escala de siempre.
  - Nunca está bloqueado (gris), cargando ni potenciado (dorado): el dash no tiene esos estados.
- **Barra de estamina:** queda abajo a la izquierda, sola, en su lugar actual (150 × 12 px, a 16 px de los bordes). Reemplaza la parte de AC720 que la ubicaba "debajo del dash".

### 2.2 Cómo se usa

- **PC:** sin cambios. El dash sigue en el clic derecho (y en B con mando), vía InputMap. Con el mouse capturado por la cámara no se hace clic en el HUD, y el botón no reacciona al mouse.
- **Táctil:** tocar el círculo equivale a apretar la acción `dash`. Al tocar dentro del círculo se llama `Input.action_press(&"dash")`, y al levantar el dedo (o si el botón se oculta) `Input.action_release(&"dash")`. `Player` no cambia: lee `dash` del InputMap como siempre, a través del `HeldInputGuard`. Sin input de movimiento, el dash sale hacia adelante (regla actual).
- Solo el botón de dash es táctil en esta spec (`touch_action = &"dash"`). E y R quedan con `touch_action` vacío (no táctiles). Hacerlos táctiles será un dato en otra spec.

### 2.3 Estructura de nodos

```
Hud
├── HealthBar
├── StaminaBar            (abajo a la izquierda, sin la barra de dash encima)
├── AbilitySlots (HBoxContainer, abajo a la derecha)
│   ├── DashSlot   (nuevo) AbilitySlotView, prompt_action = &"dash", touch_action = &"dash", mouse_filter = PASS
│   │   └── KeyLabel
│   ├── BasicSlot
│   └── UltimateSlot
└── … (DashBar y DashLabel se eliminan)
```

### 2.4 Resources y datos

- **`SlotSource`** (`ui/slot_source.gd`, `class_name SlotSource extends RefCounted`): qué muestra un botón. Métodos virtuales: `get_cooldown_ratio()`, `get_cooldown_remaining()`, `is_equipped()`, `is_charging()`, `get_charge_ratio()`, `is_empowered()`, `is_ultimate()`. Dos implementaciones:
  - `AbilitySlotSource` (envuelve un `AbilityComponent`, con el comportamiento actual).
  - `DashSlotSource` (envuelve un `DashComponent`): recarga del dash, siempre equipado, nunca carga ni está potenciado, tamaño básico.
  
  No son Resources: son adaptadores de UI sin datos de diseño.
- **`AbilitySlotView`**: lee todo de su `SlotSource`. `setup(ability)` se mantiene (crea un `AbilitySlotSource`), y se suma `setup_dash(dash)`. Se agrega `@export var touch_action: StringName` (vacío = no táctil).
- **`InputPromptConfig`**: `dash` → `"Clic D"` (teclado y mouse) y `"B"` (mando).
- **`HudConfig`** se **elimina** (`resources/hud_config.gd`, `data/ui/hud_config.tres`), igual que el export `Hud.config`. Solo guardaba el texto `DASH` y el formato de los segundos de la barra, y el botón usa el `cooldown_text` de `AbilitySlotViewConfig`.
- Sin colores nuevos: el botón usa la paleta de los botones de habilidad (celeste pálido, color no reservado ya registrado).

### 2.5 Interfaz pública

```gdscript
# AbilitySlotView
@export var touch_action: StringName          # &"" = not touchable
func setup(ability: AbilityComponent) -> void  # unchanged
func setup_dash(dash: DashComponent) -> void
func is_touch_held() -> bool                   # a finger is holding the button

# Hud
# (loses `config: HudConfig`, `_dash_bar`, `_dash_label`, `_process`)
```

### 2.6 Lógica interna

- `AbilitySlotView._refresh_if_changed()`, `_update_time_text()`, `get_radius()` y la fuente de la cuenta leen de `_source`, sin cambiar sus reglas.
- `AbilitySlotView._gui_input(event)`: si `touch_action` no está vacío y el evento es `InputEventScreenTouch`, un toque dentro del círculo (distancia al centro ≤ radio) hace `Input.action_press(touch_action)` y guarda su índice. Al soltar ese índice, `Input.action_release(touch_action)`. `_notification(NOTIFICATION_VISIBILITY_CHANGED / EXIT_TREE)` suelta la acción si seguía apretada. Los eventos de mouse se ignoran.
- `Hud._ready()`: `%DashSlot.setup_dash(player.dash)` y lo suma a `_show_prompts`. Se elimina `Hud._process` (solo actualizaba la barra).
- Sin allocations por cuadro: el botón sigue redibujando solo cuando cambia la recarga, como los de habilidad.

## 3. Criterios de aceptación (AC769–AC777)

- **AC769** El HUD no tiene `%DashBar` ni `%DashLabel`. Tiene `%DashSlot` (`AbilitySlotView`) como primer hijo de `AbilitySlots`, a la izquierda de E, con el radio de E (`basic_radius`). Reemplaza a AC173.
- **AC770** Listo, el botón muestra el prompt de `dash` (`Clic D` con teclado y mouse, `B` con mando), sin reloj (`get_clock_fraction() == 0`).
- **AC771** Tras dashear con 1.5 s de recarga, el centro dice `"1.5"` y el prompt se oculta. A los 0.7 s dice `"0.8"` y el reloj cubre la fracción restante (`get_shown_ratio()` ≈ 0.8 / 1.5). Al terminar vuelve el prompt. Reemplaza a AC321.
- **AC772** Al quedar listo, el botón hace el pulso (`is_pulsing()`), como los de habilidad.
- **AC773** El botón de dash nunca se muestra bloqueado, cargando ni potenciado.
- **AC774** Un `InputEventScreenTouch` presionado dentro del círculo aprieta `dash` (`Input.is_action_pressed(&"dash")`) y el jugador dashea. Al soltarlo, la acción se suelta.
- **AC775** Un toque fuera del círculo, un clic de mouse sobre el botón, o un toque sobre E o R (`touch_action` vacío) no aprietan ninguna acción.
- **AC776** El clic derecho (y B) siguen dasheando como antes (AC65 / AC367 sin cambios).
- **AC777** La barra de estamina queda abajo a la izquierda, sola (sin barra de dash encima), con su estilo amarillo. Reemplaza la ubicación de AC720.

## 4. Tests

- `test/ui/dash_button_test.gd` (nuevo): AC769–AC775 y AC777.
- `test/ui/cooldown_hud_test.gd`: AC321 se reemplaza por AC771, que verifica lo mismo en el botón.
- `test/ui/player_hud_test.gd`: AC173 se reemplaza por AC769 y se quita `_dash_bar`.
- `test/ui/sprint_hud_test.gd`: AC720 pasa a verificar la barra sola abajo a la izquierda (AC777).
- `input_map_test.gd` (AC776): sin cambios.
- Tests de `AbilitySlotView` que ya existen (`cooldown_clock_test`, `tsubame_gaeshi_test`, `ability_run_test`, `samurai_run_test`) sin cambios: `setup(ability)` se mantiene.

## 5. Riesgos

- **Toque sin movimiento táctil:** en táctil, por ahora, el dash solo sale hacia adelante (no hay joystick virtual). Es el comportamiento esperado hasta la spec de controles táctiles.
- **Mouse visible** (pausa, menús): el botón ignora el mouse, así que un clic no dashea.

## 6. Enmienda de la constitución (MINOR 4.13.1 → 4.14.0)

Principio VI:

- "No hay soporte de pantalla táctil" pasa a decir: "**No hay controles táctiles**, salvo los **botones de acción del HUD**".
- Excepción nueva: "**Botones táctiles del HUD:** un botón de acción del HUD puede aceptar toques de pantalla (`InputEventScreenTouch`). Un toque aprieta **su acción del InputMap** (`Input.action_press`/`action_release`) y nada más: la lógica de juego sigue leyendo solo acciones. Qué botones son táctiles es un dato del botón (`touch_action`). Moverse, la cámara y el ataque táctiles necesitan su propia spec."
- Historial: `4.14.0 (2026-09-27): Principio VI: los botones de acción del HUD pueden ser táctiles y disparan su acción del InputMap (ver dash-button.md).`

## 7. Plan

1. Reservar AC769–AC777 en `CLAUDE.md` (próximo libre: AC778) y aplicar la enmienda 4.14.0.
2. `SlotSource`, `AbilitySlotSource` y `DashSlotSource`. `AbilitySlotView` pasa a leer de `_source` (con `setup` igual y `setup_dash` nuevo). Correr los tests existentes de `AbilitySlotView` para confirmar que no cambia nada.
3. Toque: `touch_action` y `_gui_input` en `AbilitySlotView`, y `dash` en `InputPromptConfig`.
4. HUD: `%DashSlot` en `AbilitySlots`, `Hud` sin barra ni `_process`, y eliminar `HudConfig`. La estamina queda donde está.
5. Tests: `dash_button_test.gd` nuevo y los reemplazos de AC321, AC173 y AC720 (anotados en sus specs).
6. Captura del HUD, tests de esta spec y de los que toca, smoke test, checklist, estado **Implementada** y `CLAUDE.md`.

## 8. Checklist de review (constitución)

- [x] Principio I: pilar de combate (el dash se lee como las demás acciones de combate, con su recarga).
- [x] Principio II: primitivas de UI dibujadas (`draw_circle`/`draw_arc`), sin texturas ni colores nuevos (paleta de los botones de habilidad).
- [x] Principio III: tamaño, colores y formato salen de `ability_slot_view_config.tres` y los prompts de `input_prompt_config.tres`. Se eliminó `HudConfig`, que quedó sin uso.
- [x] Principio IV: tipado estricto. `SlotSource` es una clase base tipada, sin duck typing, y `_gui_input` y `_notification` solo orquestan.
- [x] Principio V: sin allocations por cuadro. El botón redibuja solo cuando cambia la recarga y el HUD ya no tiene `_process`.
- [x] Principio VI: enmendado a 4.14.0. El toque aprieta la acción `dash` del InputMap; `Player` no cambia y el dash sigue en clic derecho y B.
- [x] Principio VII: sin cambios.

## 9. Notas de implementación

1. **Tests reemplazados** (describían la barra, que ya no existe): `cooldown_hud_test.gd` AC321 pasó a `dash_button_test.gd` AC771 (mismos segundos, "1.5" y "0.8", más el reloj); `player_hud_test.gd` AC173 pasó a AC769; `sprint_hud_test.gd`, la parte de AC720 que ubicaba la estamina "debajo del dash", pasó a AC777. Anotado en `cooldown-timers.md`, `player-hud-layout.md` y `sprint-stamina.md`.
2. `KeyLabel` del botón de dash usa 14 px (E usa 16) para que "Clic D" entre en el círculo de 64 px.
3. **Resultado:** `dash_button_test` 7/7, `sprint_hud_test` 4/4, `player_hud_test` 4/4, `cooldown_hud_test` 5/5, `cooldown_clock_test` 6/6, `input_prompts_test` 3/3, `ability_run_test` 8/8, `tsubame_gaeshi_test` 10/10 e `input_map_test` 6/6 en verde. Smoke test del proyecto y de la arena sin errores. Captura del HUD revisada: botón listo con "Clic D" y en recarga con el reloj y "0.9".
