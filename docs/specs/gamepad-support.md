# Feature: Soporte de mando

- **Estado:** Aprobada (2026-09-25), en implementación
- **Constitución:** `docs/constitution.md` v3.7.0 → **v4.0.0** (enmienda MAJOR del Principio VI, sección 7).
- **Pilares (Principio I):**
  - **Combate:** el esquema de control define cómo se ataca, se esquiva y se encadenan habilidades. Con mando el stick analógico da movimiento de 360° con intensidad, la cámara se maneja con el otro pulgar, y atacar, esquivar y lanzar habilidades quedan en los gatillos y los botones (layout estilo souls).
- **Dependencias:** ninguna. Se toca input, cámara, HUD y las pantallas de UI.
- **Nota (constitución 5.0.0, `mobile-touch-controls.md`):** el Principio VI suma la pantalla táctil como tercer esquema. Las reglas de esta spec siguen valiendo; `InputDeviceMonitor` tiene un tercer dispositivo (`TOUCH`) y los bindings de mouse de `attack`/`dash` pasaron a `device = DEVICE_ID_MOUSE`.

## 1. Objetivo

El juego completo (menú → clase → habilidad → oleadas → cartas → pausa → Game Over → reintentar) se puede jugar **solo con mando**, sin romper el teclado y mouse, que siguen funcionando igual.

**Layout (nombres Xbox; Godot mapea los demás mandos con SDL):**

| Acción | Teclado/mouse (sin cambios) | Mando |
|---|---|---|
| `move_*` | WASD | Stick izquierdo (ejes 0/1) |
| `camera_*` (nuevas) | Movimiento del mouse (sin cambios) | Stick derecho (ejes 2/3) |
| `attack` | Click izquierdo | **RB** (botón 10). Mantener = repetir, igual que el click |
| `jump` | Espacio | **A** (botón 0) |
| `dash` | Click derecho | **B** (botón 1) |
| `ability_basic` | E | **LB** (botón 9) |
| `ability_ultimate` | R | **RT** (eje 5, umbral 0.5) |
| `pause` | Esc | **Start** (botón 6) |
| Menús | Mouse / flechas + Enter | D-pad o stick izquierdo para navegar, **A** confirma, **B** vuelve |

- Los menús usan las acciones incorporadas de Godot (`ui_up/down/left/right`, `ui_accept`, `ui_cancel`). Por defecto ya tienen bindings de mando (d-pad, stick izquierdo, A, B), así que no se modifican.
- **Prompts del HUD:** los slots de habilidad muestran "E"/"R" o "LB"/"RT" según el **último dispositivo usado**, y cambian en el momento.
- **Fuera de alcance:** pantalla táctil, Android, remapeo de controles, vibración, íconos gráficos de botones (los prompts son texto) y ocultar el cursor al usar el mando.

## 2. Estructura

### 2.1 InputMap (`project.godot`)

- A cada acción existente se le **agrega** el evento de mando de la tabla y se conserva el de teclado/mouse. `InputEventJoypadButton` y `InputEventJoypadMotion` usan `device = -1` (todos los mandos).
- Acciones nuevas: `camera_left` (eje 2, −1), `camera_right` (eje 2, +1), `camera_up` (eje 3, −1) y `camera_down` (eje 3, +1), con deadzone 0.2 y solo eventos de mando. El mouse sigue entrando por `InputEventMouseMotion` (excepción ya existente del Principio VI).
- `ability_ultimate`: deadzone 0.5, así el gatillo RT se cuenta como apretado a mitad de recorrido. Esto no cambia nada para la tecla R.

### 2.2 Datos (Principio III)

| Archivo | Cambio |
|---|---|
| `resources/camera_config.gd` | `+ stick_yaw_speed: float` (rad/s con el stick a fondo), `+ stick_pitch_speed: float` (rad/s). `invert_y` se aplica también al stick. |
| `data/player/camera_config.tres` | `stick_yaw_speed = 3.0`, `stick_pitch_speed = 2.0` (valores iniciales, se tunean jugando). |
| `resources/input_prompt_config.gd` (nuevo) | `keyboard_prompts: Dictionary[StringName, String]`, `gamepad_prompts: Dictionary[StringName, String]`, `gamepad_motion_threshold: float` (valor absoluto mínimo de un eje para que cuente como uso del mando; filtra el ruido de los sticks). Función pura `get_prompt(action: StringName, device: InputDeviceMonitor.Device) -> String`. |
| `data/ui/input_prompt_config.tres` (nuevo) | Teclado: `ability_basic → "E"`, `ability_ultimate → "R"`. Mando: `ability_basic → "LB"`, `ability_ultimate → "RT"`. `gamepad_motion_threshold = 0.5`. |
| `resources/upgrade_picker_config.gd` | `+ focus_border_color: Color`, `+ focus_border_width: int` (marco de la carta con foco). |
| `data/ui/upgrade_picker_config.tres` | `focus_border_color = Color(1, 1, 1)`, `focus_border_width = 4`. El blanco es UI 2D, fuera de la tabla de colores reservados del Principio II, que cubre elementos 3D. |

### 2.3 Clases y nodos

| Archivo | Cambio |
|---|---|
| `components/input/input_device_monitor.gd` (nuevo) | `class_name InputDeviceMonitor extends Node`. Clasifica cada evento **por tipo** (no por botón) en `Device.KEYBOARD_MOUSE` o `Device.GAMEPAD`, y emite `device_changed` cuando cambia. `process_mode = ALWAYS`, para funcionar también en pausa. |
| `components/input/held_input_guard.gd` (nuevo) | `class_name HeldInputGuard extends RefCounted`. Después de una pausa, ignora las acciones de juego que ya venían apretadas hasta que se sueltan (sección 4.3). |
| `components/camera/third_person_camera.gd` | Lee el stick derecho en `_process` y lo aplica con `apply_stick_look()`. |
| `entities/player/player.gd` | Las lecturas de `attack`, `dash`, `jump`, `ability_basic` y `ability_ultimate` pasan por `HeldInputGuard`. `_release_charge_if_key_up` sigue leyendo `Input` directo. |
| `ui/ability_slot_view.gd` | `+ @export var prompt_action: StringName` y `+ set_prompt(text: String)`, que escribe `key_label.text` sin tocar su visibilidad. |
| `ui/hud.gd` / `ui/hud.tscn` | Nodo hijo `InputDeviceMonitor`; `@export var prompts: InputPromptConfig`. Escribe el prompt de cada slot al arrancar y en cada `device_changed`. Se quitan los textos fijos "E"/"R" de la escena. |
| `ui/card_style.gd` | El stylebox `focus` pasa a ser un marco (`draw_center = false`, borde de color y ancho de `UpgradePickerConfig`), en lugar de repetir `normal`. `CardStyle._init` recibe el config. |
| `ui/main_menu.gd` | Foco inicial en cada panel. `ui_cancel` vuelve un panel atrás. |
| `ui/ability_picker.gd`, `ui/upgrade_picker.gd`, `ui/upgrade_ban_picker.gd` | Foco en la primera carta al abrir (y en `reopen`). El de bloqueo: `ui_cancel` = `cancel()`. |
| `ui/pause_menu.gd` | Foco en "Reanudar" al abrir. `ui_cancel` = `close()`. |
| `ui/game_over_screen.gd` | Foco en "Reintentar" al mostrarse. |

## 3. Interfaz pública

```gdscript
# components/input/input_device_monitor.gd
enum Device { KEYBOARD_MOUSE, GAMEPAD }
signal device_changed(device: Device)
@export var config: InputPromptConfig          # gamepad_motion_threshold
func handle_event(event: InputEvent) -> void   # called by _input and by tests
func get_device() -> Device                    # starts at KEYBOARD_MOUSE

# components/input/held_input_guard.gd
func _init(actions: Array[StringName]) -> void
func update(physics_frame: int) -> void        # first thing in Player._physics_process
func is_just_pressed(action: StringName) -> bool
func is_pressed(action: StringName) -> bool
func is_blocked(action: StringName) -> bool

# ThirdPersonCamera
func apply_stick_look(look: Vector2, delta: float) -> void

# InputPromptConfig
func get_prompt(action: StringName, device: InputDeviceMonitor.Device) -> String

# AbilitySlotView
@export var prompt_action: StringName
func set_prompt(text: String) -> void
func get_prompt_text() -> String
```

## 4. Lógica interna

### 4.1 Cámara

- `_process(delta)` llama a `_update_stick_look(delta)`, que lee `Input.get_vector(camera_left, camera_right, camera_up, camera_down)` y llama a `apply_stick_look(look, delta)`.
- `apply_stick_look` hace `rotate_camera(-look.x * stick_yaw_speed * delta, -look.y * stick_pitch_speed * delta * y_sign)`, con el mismo `y_sign` que el mouse. Así, empujar el stick hacia abajo mira hacia abajo, igual que mover el mouse hacia abajo. El pitch queda limitado por `rotate_camera`, como hoy.
- El stick funciona aunque el mouse no esté capturado. La cámara está en el árbol del jugador, así que en pausa no procesa.

### 4.2 Dispositivo activo y prompts

- `_input(event)` → `handle_event(event)`. Clasificación:
  - `InputEventJoypadButton` → `GAMEPAD`.
  - `InputEventJoypadMotion` con `absf(axis_value) >= gamepad_motion_threshold` → `GAMEPAD`. Si no llega al umbral, se ignora.
  - `InputEventKey`, `InputEventMouseButton` o `InputEventMouseMotion` → `KEYBOARD_MOUSE`.
  - Cualquier otro evento se ignora.
- Solo se emite `device_changed` si el dispositivo es distinto del actual. El monitor no lee ningún botón concreto, solo el **tipo** de evento (excepción registrada en el Principio VI).
- El HUD, en `_ready` y en cada `device_changed`, hace `slot.set_prompt(prompts.get_prompt(slot.prompt_action, device))` para los dos slots. La visibilidad de `key_label` (oculta durante la recarga) no cambia.

### 4.3 Guardia de input tras una pausa

**Problema:** B cierra la pausa (`ui_cancel`) y también es `dash`. Sin guardia, el primer frame de física después de cerrar ve `is_action_just_pressed(dash)` y el jugador hace un dash. Pasa lo mismo con A (`ui_accept` y `jump`) si un botón se activa al apretar.

**Regla:** si el jugador no procesó física durante al menos un frame (el árbol estuvo en pausa), toda acción de juego que al volver esté apretada, o se haya apretado en ese frame, queda **bloqueada** hasta que se suelte. Mientras está bloqueada, `is_just_pressed` e `is_pressed` devuelven `false`.

- `update(frame)`: si `_last_frame >= 0` y `frame != _last_frame + 1`, hubo pausa y se bloquean esas acciones, anotando el frame del bloqueo. Después se desbloquean las acciones que no están apretadas y fueron bloqueadas en un frame anterior. Por último, `_last_frame = frame`.
- Sin allocations por frame: `_blocked` es un `Dictionary[StringName, int]` miembro y la lista de acciones es constante (Principio V).
- `Player` la construye con `[attack, dash, jump, ability_basic, ability_ultimate]`. Movimiento y cámara no pasan por la guardia, porque son continuos y no disparan acciones.
- **Soltar una carga no pasa por la guardia:** si el jugador mantiene E durante la pausa, la carga sigue. Si la suelta en la pausa, se libera al volver. Es el comportamiento de hoy.
- Efecto aceptado: si se mantiene RB (ataque) mientras se elige una carta, hay que soltarlo y volver a apretarlo para seguir atacando.

### 4.4 Menús

- **Foco inicial** (`grab_focus()`), cada vez que la pantalla o el panel se muestra:

  | Pantalla | Foco |
  |---|---|
  | Menú principal, panel principal | "Jugar" |
  | Menú principal, panel de modos | "Normal" |
  | Menú principal, panel de clases | Primera carta de clase |
  | Elección de habilidad | Primera carta |
  | Cartas de mejora (`show_offer` y `reopen`) | Primera carta de mejora |
  | Bloqueo | Primera carta, o "Volver" si no hay cartas |
  | Pausa | "Reanudar" |
  | Game Over | "Reintentar" |

  Las cartas nuevas se crean después de `queue_free` de las viejas. El foco va a la primera carta **nueva** (la de `get_card_buttons()[0]` o equivalente).
- **Navegación:** la resuelve Godot con los vecinos de foco automáticos por geometría (filas de cartas en `HBoxContainer`, botones en `VBoxContainer`, grilla del sandbox). No se configuran vecinos a mano, salvo que el smoke test muestre un salto roto. En ese caso se anota en la sección 9.
- **`ui_cancel`**, manejado en `_unhandled_input` de cada pantalla visible:
  - Menú principal: panel de modos → principal; panel de clases → modos; panel principal → nada.
  - Bloqueo → `cancel()`.
  - Pausa → `close()`. En `_handle_pause_input` se evalúa primero `pause` (Esc también es `ui_cancel`), después `ui_cancel` solo si el menú está visible. Así Esc hace un solo toggle.
  - Cartas de mejora, elección de habilidad y Game Over: nada, porque no tienen "volver".
- Los `Button` conservan `action_mode` por defecto (se activan al soltar).
- **Foco visible:** los botones comunes y las cartas de clase y habilidad usan el `focus` del tema por defecto de Godot (ya visible). Las cartas coloreadas (`CardStyle`) usan el marco de la sección 2.2.

## 5. Criterios de aceptación

- **AC367** InputMap: `move_forward/back/left/right`, `attack`, `dash`, `jump`, `ability_basic`, `ability_ultimate` y `pause` conservan su evento de teclado/mouse y tienen además el evento de mando de la tabla de la sección 1 (botón o eje y dirección). `ability_ultimate` tiene deadzone 0.5.
- **AC368** Existen `camera_left/right/up/down` con un único evento cada una: `InputEventJoypadMotion` en el eje 2 (−1/+1) y en el eje 3 (−1/+1), con deadzone 0.2.
- **AC369** `apply_stick_look(Vector2(1, 0), 0.5)` cambia el yaw en `−stick_yaw_speed × 0.5` (con wrap). `apply_stick_look(Vector2(0, 1), 0.1)` cambia el pitch en `−stick_pitch_speed × 0.1`, y con `invert_y` en el sentido contrario. El pitch nunca sale de `[min_pitch_deg, max_pitch_deg]`. `Vector2.ZERO` no rota.
- **AC370** `camera_config.tres` tiene `stick_yaw_speed` y `stick_pitch_speed` mayores que 0.
- **AC371** `InputDeviceMonitor` arranca en `KEYBOARD_MOUSE`. Un `InputEventJoypadButton` lo pasa a `GAMEPAD` y emite `device_changed` una vez. Un segundo evento de mando no vuelve a emitir. Un `InputEventJoypadMotion` con `|valor|` menor que el umbral no cambia nada, y uno mayor o igual pasa a `GAMEPAD`. `InputEventKey`, `InputEventMouseButton` e `InputEventMouseMotion` vuelven a `KEYBOARD_MOUSE`.
- **AC372** `input_prompt_config.tres` devuelve "E"/"R" con teclado y "LB"/"RT" con mando para `ability_basic`/`ability_ultimate`.
- **AC373** HUD: al arrancar los slots muestran "E" y "R". Cuando el monitor pasa a `GAMEPAD` muestran "LB" y "RT", y al volver a `KEYBOARD_MOUSE` otra vez "E" y "R". Durante una recarga el prompt sigue oculto (regla de `cooldown-timers.md`) y al terminar reaparece con el texto del dispositivo actual.
- **AC374** Foco inicial: cada pantalla de la tabla de la sección 4.4, al mostrarse, deja con foco (`has_focus()`) el control indicado. Incluye `reopen()` de las cartas de mejora y el bloqueo sin cartas.
- **AC375** `ui_cancel`: en el menú principal, el panel de clases vuelve a modos y el de modos al principal. En el bloqueo emite `ban_cancelled`. En la pausa la cierra y despausa el árbol. En las cartas de mejora, la elección de habilidad y Game Over no cambia nada (siguen visibles).
- **AC376** En la pausa, un evento que es a la vez `pause` y `ui_cancel` (Esc) abre y cierra con un solo toggle por evento: estando abierta la cierra, y estando cerrada la abre (no queda abierta y cerrada en el mismo evento).
- **AC377** `CardStyle` aplica en `focus` un `StyleBoxFlat` con `draw_center = false`, color de borde `focus_border_color` y ancho `focus_border_width` en los cuatro lados. Es distinto del stylebox `normal`.
- **AC378** `HeldInputGuard`: con frames consecutivos, la guardia no bloquea nada y `is_just_pressed`/`is_pressed` coinciden con `Input`. Tras un salto de frames, una acción apretada queda bloqueada (`false` en ambas) mientras siga apretada. Al soltarla se desbloquea y el siguiente press cuenta normal. Una acción que no estaba apretada al volver no se bloquea.
- **AC379** Player: cerrar la pausa con B no hace dash y elegir una carta con A no hace saltar. Test: pausa simulada (salto de frames en la guardia) con `dash`/`jump` apretados, y después `_physics_process` sin dash ni salto. Si durante la pausa se soltó la tecla de una habilidad cargada, la carga se libera al volver (regresión de Envainar).
- **AC380** Constitución en v4.0.0 con el Principio VI redefinido (sección 7). Las specs aprobadas antes se revisan: ninguna contradice el nuevo principio (solo agregan bindings de teclado/mouse, que siguen válidos) y queda anotado en la sección 9.
- **AC381** Regresión y smoke: suite completa en verde; import, menú y arena headless sin errores ni warnings nuevos. **Prueba manual con mando real** (a cargo del usuario, porque no tengo acceso a un mando): una run completa solo con mando, la cámara con el stick derecho, el panel sandbox alcanzable con el d-pad desde la pausa, y los prompts del HUD cambiando al tocar el teclado o el mando.

## 6. Tests que pueden necesitar adaptación

- Tests de `CardStyle` o de las cartas que comparen el stylebox `focus` con `normal`.
- `test/ui/pause_menu_test.gd`: si simula Esc con un evento que ahora también es `ui_cancel`.
- Tests que construyen `CardStyle.new(...)` directamente (cambia la firma).
- Tests del HUD que lean `key_label.text` esperando el texto fijo de la escena.

Si algún test tenía valores fijos, se adapta sin cambiar lo que verifica y se anota acá.

## 7. Enmienda a la constitución (MAJOR → 4.0.0)

Se **redefine el Principio VI**, por eso es MAJOR:

> ### VI. Input: teclado y mouse, o mando
>
> - El juego se controla con **teclado y mouse** o con **mando** (layout Xbox; otros mandos vía el mapeo SDL de Godot). No hay soporte de pantalla táctil.
> - Todo input pasa por el **InputMap** con acciones nombradas. **Toda acción de juego tiene binding en los dos esquemas.** Prohibido leer teclas o botones físicos directamente en la lógica de juego.
> - **Toda pantalla de UI se puede usar con mando:** foco inicial al mostrarse, foco visible, `ui_accept` para confirmar y `ui_cancel` para volver donde haya "volver".
> - Los textos de teclas y botones que muestra la UI (prompts) salen de datos (`InputPromptConfig`), nunca de literales en escenas o scripts.
> - Excepciones:
>   - El movimiento relativo del mouse para la cámara (`InputEventMouseMotion`), que el InputMap no puede representar. Se lee solo dentro del nodo de cámara.
>   - `InputDeviceMonitor` clasifica los eventos **por tipo** (teclado/mouse o mando) solo para elegir qué prompts mostrar. No lee botones concretos ni decide gameplay.
>
> **Rationale:** el combate de un hack and slash se juega cómodo con mando. Mantener todo en el InputMap y los prompts en datos hace que sumar el mando no duplique la lógica de juego.

Otros cambios del documento:

- **Principio I:** "para PC, jugado con teclado y mouse" pasa a "para PC, jugado con teclado y mouse o mando".
- **Technology Stack:** Input → "Teclado y mouse, o mando, vía InputMap (Principio VI)".
- **Checklist de review:** "Input (VI): solo acciones del InputMap, con bindings de teclado/mouse y de mando. Pantallas nuevas navegables con mando. Prompts desde datos."
- **Historial:** entrada 4.0.0 (fecha de cierre).

## 8. Plan

1. Reservar AC367–AC381 en `CLAUDE.md` (próximo libre → AC382).
2. Enmendar la constitución a 4.0.0 (sección 7).
3. **InputMap:** agregar los bindings de mando y las acciones `camera_*` en `project.godot`. Tests AC367–AC368.
4. **Cámara:** campos en `CameraConfig` y `.tres`, `apply_stick_look` y lectura en `_process`. Tests AC369–AC370.
5. **Guardia:** `HeldInputGuard` y su uso en `Player`. Tests AC378–AC379.
6. **Dispositivo y prompts:** `InputPromptConfig`, `.tres`, `InputDeviceMonitor`, `AbilitySlotView.set_prompt` y el cableado en el HUD (se quitan "E"/"R" de `hud.tscn`). Tests AC371–AC373.
7. **Menús:** foco inicial y `ui_cancel` en las seis pantallas, y marco de foco en `CardStyle` con los campos nuevos de `UpgradePickerConfig`. Tests AC374–AC377.
8. Copiar de vuelta los `.uid` generados. Suite completa, import y smoke headless del menú y la arena. Actualizar `CLAUDE.md` (mapa: `components/input/`; "Dónde se ajusta": sensibilidad del stick y prompts). Review de la constitución, estado **Implementada** (pendiente de la prueba manual con mando de AC381).

Cada paso deja el proyecto funcionando: los bindings nuevos no cambian nada hasta que se conecta un mando.

## 9. Notas de implementación

(se completa al implementar)

## 10. Review de la constitución (cierre)

(se completa al cerrar)
