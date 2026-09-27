# Feature: Controles táctiles y versión Android

- **Estado:** Aprobada (2026-09-27), en implementación
- **Constitución:** `docs/constitution.md` v4.12.1 → **v5.0.0** (enmienda MAJOR del Principio VI, del Principio I y del Technology Stack, sección 8).
- **Criterios de aceptación:** AC698–AC727 (reservados en `CLAUDE.md`).
- **Pilares (Principio I):**
  - **Combate:** el esquema de control define cómo se ataca, se esquiva, se salta y se encadenan habilidades. En el teléfono el pulgar izquierdo mueve con intensidad analógica (joystick flotante), el derecho gira la cámara arrastrando y tiene el ataque, el salto, el dash y las dos habilidades en un solo racimo alrededor del ataque (distribución de *Wuthering Waves* móvil), sin perder el mantener-para-repetir del ataque ni la carga de Envainar.
- **Dependencias:** `gamepad-support.md` (Aprobada, en implementación). Esta spec reutiliza lo que ya está hecho de ella (`InputDeviceMonitor`, `HeldInputGuard`, prompts por dispositivo, foco en los menús) y no la cierra.

## 1. Objetivo

El juego completo (menú → clase → habilidad → oleadas → cartas → pausa → Game Over → reintentar) se puede jugar **en un teléfono Android con pantalla táctil, en horizontal**, sin romper teclado y mouse ni mando, que siguen funcionando igual.

Decisiones del usuario (2026-09-27):

| Tema | Decisión |
|---|---|
| Joystick de movimiento | **Flotante**: aparece donde apoyás el pulgar en la mitad izquierda y persigue al pulgar si se pasa del radio. En reposo se ve tenue en su posición por defecto. |
| Cámara | **Arrastre en la mitad derecha**, fuera de los botones. Un dedo que empieza en un botón no mueve la cámara. |
| Botones de acción | Racimo tipo WuWa abajo a la derecha: **ataque grande en el centro**, **salto arriba a la derecha**, **dash abajo a la derecha**, **habilidad básica abajo a la izquierda** y **ultimate (R) arriba a la izquierda** (esta última según la imagen de referencia; ver pregunta al final). El HUD táctil reemplaza al de PC: los slots de habilidad y el dash (hoy `AbilitySlots` y `DashBar`) se muestran como botones del racimo. |
| Paquete Android | `com.fantasyslash.game` |

Distribución (base 1152 × 648, `canvas_items` + `expand`; los números concretos viven en `touch_controls_config.tres`):

```
┌──────────────────────────────────────────────────────────────┐
│ Vida / Oleada / Bosses / Buffs (como en PC)             [II] │  ← pausa, esquina sup. der.
│                                                              │
│                                                              │
│     mitad izquierda:                mitad derecha:           │
│     joystick flotante               arrastre = cámara        │
│                                                              │
│                                          (R)       (Salto)   │
│        ( o )  ← reposo tenue                  (ATAQUE)       │
│                                          (E)       (Dash)    │
└──────────────────────────────────────────────────────────────┘
```

Fuera de alcance: remapeo de controles táctiles por el usuario, vibración, íconos con textura (los botones dibujan círculos y texto, Principio II), íconos de launcher propios (se usa `icon.svg`), publicación en Play Store (firma de release), iOS.

## 2. Historia: por qué la v2.0.0 quitó Android

La constitución 1.0.0 apuntaba a Android y su Principio V era de performance móvil. La 2.0.0 (2026-09-24) quitó el target para enfocar el prototipo en PC con teclado y mouse, redefinió el V como performance general y pasó a Forward+. Nada de eso fue por un bloqueo técnico: el costo era validar el combate en dos plataformas a la vez. Hoy el combate ya tiene forma, el toolchain está instalado y un APK de debug exporta y firma, así que se reincorpora Android **sin** volver a subordinar el diseño al móvil: PC sigue siendo la plataforma principal y Android se agrega como segundo target con su propio esquema de control.

## 3. Estructura

### 3.1 Proyecto (`project.godot`) y exportación

| Setting | Valor | Por qué |
|---|---|---|
| `display/window/handheld/orientation` | `4` (sensor landscape) | Horizontal, girable 180°. |
| `input_devices/pointing/emulate_mouse_from_touch` | `true` (default, explícito) | Los `Button` de los menús responden a toques vía el mouse emulado. |
| `input_devices/pointing/emulate_touch_from_mouse` | `false` en PC (default) | Solo se activa a mano para probar en PC; no se versiona en `true`. |
| `application/config/quit_on_go_back` | `false` | El gesto "atrás" de Android no cierra el juego (sección 5.7). |
| `rendering/renderer/rendering_method.mobile` | `"mobile"` (explícito) | Ya es el default de Godot para Android; se escribe para que quede documentado. PC sigue en Forward+. |
| Bindings de mouse de `attack` y `dash` | `device = 32` (`InputEvent.DEVICE_ID_MOUSE`) en vez de `-1` | Un toque genera un clic emulado con `device = -1` (`InputEvent.DEVICE_ID_EMULATION`), que es también el valor de "todos los dispositivos" del binding: **cualquier toque en la pantalla atacaría**. En Godot 4.7 el mouse real llega con `DEVICE_ID_MOUSE` (32; el teclado con `DEVICE_ID_KEYBOARD`, 16), así que con ese device solo el mouse real dispara la acción (AC701). |

Preset "Android" (`export_presets.cfg`):

- `package/unique_name="com.fantasyslash.game"`, `package/name="Fantasy Slash"`, `version/name="0.1.0"`, `version/code=1`.
- `exclude_filter="test/*, addons/gdUnit4/*"` (en la copia de este worktree está vacío).
- Se mantiene Gradle build y solo `arm64-v8a`.
- **Se versiona `export_presets.cfg`** (se quita de `.gitignore`): en Godot 4 las contraseñas del keystore viven en `.godot/export_credentials.cfg`, no en el preset, así que no tiene secretos y así el preset deja de ser configuración local de cada máquina.

### 3.2 Datos (Principio III)

**`TouchControlsConfig`** (`resources/touch_controls_config.gd`, instancia `data/ui/touch_controls_config.tres`). Todas las medidas en píxeles de la resolución base.

| Campo | Tipo | Valor inicial | Qué es |
|---|---|---|---|
| `stick_zone_width_ratio` | `float` | 0.5 | Fracción izquierda de la pantalla donde un toque crea el joystick. |
| `stick_radius` | `float` | 90 | Radio del aro; el pulgar a esa distancia = intensidad 1. |
| `stick_knob_radius` | `float` | 38 | Radio de la perilla. |
| `stick_dead_zone` | `float` | 0.15 | Intensidad por debajo de la cual no se mueve (fracción del radio). |
| `stick_rest_position` | `Vector2` | (200, −170) | Centro en reposo, desde la esquina inferior izquierda del área segura. |
| `stick_follows_thumb` | `bool` | true | Flotante: si el pulgar pasa el radio, el centro lo sigue. |
| `cluster_anchor` | `Vector2` | (−190, −170) | Centro del botón de ataque, desde la esquina inferior derecha del área segura. |
| `attack_radius` | `float` | 72 | Botón de ataque. |
| `side_button_radius` | `float` | 44 | Salto, dash, habilidad básica y ultimate. |
| `jump_offset` / `dash_offset` / `basic_offset` / `ultimate_offset` | `Vector2` | (105, −105) / (105, 105) / (−105, 105) / (−105, −105) | Centro de cada botón respecto del centro del ataque (diagonales). |
| `pause_radius` | `float` | 30 | Botón de pausa. |
| `pause_anchor` | `Vector2` | (−50, 50) | Desde la esquina superior derecha del área segura. |
| `touch_slop` | `float` | 8 | Radio extra de acierto de todo botón (un toque apenas afuera cuenta). |
| `idle_color` / `pressed_color` / `stick_color` / `knob_color` | `Color` | blanco translúcido α 0.25 / α 0.5 / α 0.2 / α 0.45 | Colores de UI 2D (no reservados: la tabla de colores reserva elementos 3D; se registran en la enmienda). |
| `label_color` | `Color` | blanco α 0.9 | Texto de los botones. |
| `label_font_size` | `int` | 18 | Texto de los botones sin slot (ataque, salto, dash, pausa). |
| `ring_width` | `float` | 3 | Borde de los círculos. |
| `arc_point_count` | `int` | 48 | Puntos por círculo dibujado. |

**`CameraConfig`**: nuevo `touch_look_sensitivity: float` (radianes por píxel base de arrastre; inicial 0.006) e `invert_y` se respeta también en táctil.

**`InputPromptConfig`**: nuevo `touch_prompts: Dictionary[StringName, String]` con el texto de cada botón: `attack` "Atacar", `jump` "Saltar", `dash` "Dash", `pause` "II", `ability_basic` "" y `ability_ultimate` "" (los slots de habilidad no muestran tecla en táctil).

**`AbilitySlotViewConfig`**: sin cambios. En táctil el slot se dibuja con el radio `side_button_radius` (se pasa por `setup`, sección 4).

### 3.3 Clases y nodos nuevos

```
ui/touch/touch_controls.tscn        TouchControls (Control, full rect, mouse_filter IGNORE, process_mode ALWAYS)
├── MoveStick (VirtualStick)         dibuja aro y perilla
├── Cluster (Control)                se posiciona en cluster_anchor + área segura
│   ├── AttackButton  (TouchActionButton, action = attack)
│   ├── JumpButton    (TouchActionButton, action = jump)
│   ├── DashButton    (TouchActionButton, action = dash, con reloj del dash)
│   ├── BasicButton   (TouchActionButton, action = ability_basic)  └── BasicSlot (AbilitySlotView)
│   └── UltimateButton(TouchActionButton, action = ability_ultimate) └── UltimateSlot (AbilitySlotView)
└── PauseButton (TouchActionButton, action = pause)
```

- `TouchControls` se instancia dentro de `hud.tscn`. Es **el único nodo** que lee `InputEventScreenTouch`/`InputEventScreenDrag` (excepción del Principio VI): hace el ruteo multitoque por índice de dedo y traduce a acciones del InputMap y a un delta de cámara.
- `TouchActionButton` (`ui/touch/touch_action_button.gd`): círculo dibujado con `draw_circle`/`draw_arc`, texto desde `touch_prompts`, estado apretado. **No lee eventos**: `TouchControls` le dice `press(finger)`/`release()`. El dash dibuja además el reloj de recarga (`CooldownClock.build_sector`) y los segundos restantes (`CooldownText`), igual que hoy la `DashBar`.
- `VirtualStick` (`ui/touch/virtual_stick.gd`): estado del joystick (centro, perilla, dedo) y su dibujo. Cálculo puro de la intensidad en `get_vector()`.
- `PointerMode` (`components/input/pointer_mode.gd`, `class_name PointerMode extends RefCounted`, estático): `capture_for_gameplay()` y `release_for_ui()` reemplazan los `Input.mouse_mode = ...` de la cámara y los menús; en plataformas con la feature `mobile` no capturan nunca.
- En los slots de habilidad del racimo se reutiliza `AbilitySlotView` tal cual (reloj, carga, marco dorado, pulso). Visualmente son "los mismos slots" reubicados: el HUD oculta `AbilitySlots` y `DashBar` en táctil y muestra el racimo; en teclado o mando es al revés.

## 4. Interfaz pública

```gdscript
# components/input/input_device_monitor.gd
enum Device { KEYBOARD_MOUSE, GAMEPAD, TOUCH }
## Initial device: TOUCH on platforms with the "mobile" feature, KEYBOARD_MOUSE elsewhere.
func get_device() -> Device

# components/input/pointer_mode.gd
static func capture_for_gameplay() -> void
static func release_for_ui() -> void
static func is_capture_allowed() -> bool   # false with the "mobile" feature

# ui/touch/touch_controls.gd
class_name TouchControls extends Control
@export var config: TouchControlsConfig
@export var prompts: InputPromptConfig
@export var camera: ThirdPersonCamera
func setup(player: Player) -> void          # binds the dash clock and the two ability slots
func handle_event(event: InputEvent) -> void # called by _input and by tests
func release_all() -> void                   # releases every action this node pressed
func set_active(active: bool) -> void        # visible + accepts new touches; false also releases all
func get_stick_vector() -> Vector2           # last vector sent as move_* strengths

# ui/touch/touch_action_button.gd
class_name TouchActionButton extends Control
@export var action: StringName
func contains_point(global_point: Vector2, slop: float) -> bool
func press(finger: int) -> void
func release() -> void
func is_pressed() -> bool
func get_finger() -> int                     # -1 when not pressed

# ui/touch/virtual_stick.gd
class_name VirtualStick extends Control
func begin(finger: int, local_point: Vector2) -> void
func drag(local_point: Vector2) -> void
func end() -> void
func get_vector() -> Vector2                 # length 0..1, 0 inside the dead zone
func get_finger() -> int

# ThirdPersonCamera
func apply_touch_look(relative: Vector2) -> void

# AbilitySlotView
func setup(ability: AbilityComponent, radius_override: float = -1.0) -> void
```

## 5. Lógica interna

### 5.1 Ruteo multitoque (`TouchControls.handle_event`)

- **Toque nuevo** (`InputEventScreenTouch.pressed`), solo si está activo y el árbol no está en pausa:
  1. Si cae en un botón libre (`contains_point` con `touch_slop`, se prueban de más chico a más grande para que la pausa gane a la mitad derecha), ese dedo queda asignado al botón → `press(finger)`.
  2. Si no, si cae en la zona del joystick (`x < ancho × stick_zone_width_ratio`) y el joystick está libre → `begin`: el centro del joystick salta al punto del toque.
  3. Si no, y ningún dedo está mirando → ese dedo pasa a ser el de la cámara.
  4. Si no, se ignora.
- **Arrastre** (`InputEventScreenDrag`): el dedo del joystick → `drag`; el dedo de la cámara → `camera.apply_touch_look(event.relative)` (con `relative` en píxeles base, ya escalado por el stretch). Un dedo asignado a un botón no hace nada al arrastrar (no se "desliza" a otro botón ni mueve la cámara).
- **Soltar** (`InputEventScreenTouch` no apretado): libera lo que tenga ese dedo. Las liberaciones se procesan **siempre**, aunque el árbol esté pausado (`process_mode ALWAYS`), para que ninguna acción quede trabada.
- Todo evento de toque procesado se marca como manejado (`set_input_as_handled`) para que no llegue a `_unhandled_input` de otros nodos.

### 5.2 Acciones

- Cada botón, al apretar, envía `InputEventAction` (`action`, `pressed = true`, `strength = 1`) con `Input.parse_input_event`; al soltar, el mismo evento con `pressed = false`. Así el estado de la acción (`is_action_pressed`, `is_action_just_pressed`), `HeldInputGuard` y los nodos que leen eventos (la pausa con `_unhandled_input`) se comportan igual que con una tecla. Nada del `Player` cambia:
  - **Ataque**: mantener repite (ya lo hace el `Player` con `is_pressed`).
  - **Habilidades de carga** (Envainar): mantener carga y levantar el dedo suelta (el `Player` ya llama `release_charge()` cuando la acción deja de estar apretada).
- **Joystick**: en cada cambio del vector `v`, envía `move_right` con fuerza `max(v.x, 0)`, `move_left` con `max(−v.x, 0)`, `move_back` con `max(v.y, 0)` y `move_forward` con `max(−v.y, 0)`; `pressed = fuerza > 0`. `Player._read_move_input()` sigue con `Input.get_vector`. Solo se envían las fuerzas que cambiaron (sin eventos redundantes por frame).
- `get_vector()`: `(perilla − centro) / stick_radius`, limitado a longitud 1; 0 si la longitud es menor que `stick_dead_zone`. Si `stick_follows_thumb` y el pulgar pasa el radio, el centro se corre hacia el pulgar para que quede justo a `stick_radius`.
- `release_all()` suelta los botones, pone el joystick en reposo (fuerzas 0) y libera el dedo de cámara. Se llama al desactivarse, en `NOTIFICATION_APPLICATION_FOCUS_OUT` / `NOTIFICATION_APPLICATION_PAUSED` y cuando el árbol entra en pausa (se detecta al comparar `get_tree().paused` con el valor anterior en `_process`, sin allocations).

### 5.3 Dispositivo activo y HUD

- `InputDeviceMonitor`: `InputEventScreenTouch`/`InputEventScreenDrag` → `TOUCH`. Los eventos de mouse con `device == InputEvent.DEVICE_ID_EMULATION` (los que Godot genera a partir de un toque) **no** cambian el dispositivo; los `InputEventAction` tampoco. Estado inicial: `TOUCH` con `OS.has_feature("mobile")`, si no `KEYBOARD_MOUSE` (el nombre de la feature es una constante estructural).
- `Hud._show_prompts(device)` pasa a `_apply_device(device)`: en `TOUCH` activa `TouchControls` (`set_active(true)`) y oculta `AbilitySlots` y `DashBar`; en los otros dos los muestra y desactiva `TouchControls`. Los prompts de teclado y mando siguen como hoy. Los slots ocultos siguen actualizándose (son baratos y así vuelven al día al cambiar de dispositivo).
- Una PC con pantalla táctil cambia de esquema según el último input, como ya pasa entre teclado y mando.

### 5.4 Cámara

- `apply_touch_look(relative)`: `rotate_camera(−relative.x × touch_look_sensitivity, −relative.y × touch_look_sensitivity × _y_sign())`.
- `_handle_mouse_motion` ignora los eventos con `device == DEVICE_ID_EMULATION` (en una PC táctil con el mouse capturado, el arrastre de un dedo giraría la cámara dos veces).
- `capture_mouse()`/`release_mouse()` pasan por `PointerMode`.

### 5.5 Área segura

`TouchControls` y el `Hud` leen `DisplayServer.get_display_safe_area()` al estar listos y al cambiar el tamaño del viewport (`size_changed`), la convierten a coordenadas del canvas (dividiendo por el factor de stretch) y la usan como márgenes: el joystick en reposo, el racimo y la pausa se anclan a sus esquinas, y los elementos anclados del HUD (vida, oleada, buffs) se corren lo necesario. En PC el área segura es la ventana entera y no cambia nada.

### 5.6 Menús al tacto

- Todos los botones de UI tienen al menos **44 px base de alto** (≈ 70 px físicos en un teléfono de 1080 p de alto, por encima de los 48 dp recomendados). Hoy cumplen la pausa (44), el menú principal (56) y las cartas. No cumplen los del panel sandbox: `ButtonTemplate` pasa de 32 × 28 a 44 × 44 y `ResetButton` de 200 × 36 a 200 × 44 (también en PC). El test AC718 recorre las escenas de UI y lo verifica.
- El scroll del panel sandbox funciona con arrastre (`ScrollContainer` ya lo soporta con el mouse emulado).
- El foco visible de mando no se fuerza en táctil; los menús no cambian de comportamiento.

### 5.7 Gesto "atrás" de Android

`Session` (autoload) atiende `NOTIFICATION_WM_GO_BACK_REQUEST`:
- Con el árbol en pausa (pausa, cartas, bloqueo, Game Over) envía `ui_cancel` (cierra la pausa, "Volver" del bloqueo, etc., igual que B en el mando).
- Sin pausa envía `ui_cancel` y después `pause`: en el menú principal `ui_cancel` vuelve un panel y `pause` no hace nada; en juego `ui_cancel` no hace nada (pausa cerrada) y `pause` la abre. El orden importa: al revés, la pausa se abriría y se cerraría en el mismo gesto.
- En el panel principal del menú el gesto no hace nada (el juego se cierra desde el sistema).

### 5.8 Render en Android

- Renderer **Mobile** (Vulkan). Lo que usa el juego está soportado: `ImmediateMesh` (estela), `CPUParticles3D`, `OmniLight3D` breves (el Mobile limita a 8 luces omni por malla; el juego enciende a lo sumo una o dos a la vez), `DirectionalLight3D` con sombras.
- Sin ajustes de calidad en esta spec. Si la medición en el dispositivo (paso 9 del plan) da menos de 30 FPS estables con la oleada más poblada, se abre una spec aparte de ajustes móviles (sombras, cantidad de partículas, tamaño del pool) con los números medidos. No se cambian valores "por las dudas".

## 6. Criterios de aceptación

- **AC698** `project.godot`: orientación `4` (sensor landscape), `quit_on_go_back = false`, `emulate_mouse_from_touch = true`, `rendering_method.mobile = "mobile"`.
- **AC699** `touch_controls_config.tres` existe con todos los campos de la tabla 3.2 distintos de 0 (salvo los `Vector2` de posición, que no son `ZERO`), `attack_radius > side_button_radius`, y los cinco botones del racimo no se superponen entre sí (distancia entre centros ≥ suma de radios). `camera_config.tres` tiene `touch_look_sensitivity > 0`.
- **AC700** `input_prompt_config.tres` devuelve con `TOUCH`: "Atacar", "Saltar", "Dash", "II" para `attack`, `jump`, `dash`, `pause`, y "" para las dos habilidades.
- **AC701** Un `InputEventMouseButton` izquierdo con `device = DEVICE_ID_EMULATION` no activa `attack` (`InputMap.event_is_action` es `false`) y uno con `device = DEVICE_ID_MOUSE` sí. Lo mismo para el derecho y `dash`.
- **AC702** `InputDeviceMonitor`: `InputEventScreenTouch` y `InputEventScreenDrag` pasan a `TOUCH` y emiten `device_changed` una vez. Un `InputEventMouseButton`/`InputEventMouseMotion` con `device = DEVICE_ID_EMULATION` no cambia el dispositivo; con `device = DEVICE_ID_MOUSE` vuelve a `KEYBOARD_MOUSE`. Un `InputEventAction` no cambia nada. Las reglas de AC371 siguen valiendo.
- **AC703** `PointerMode.is_capture_allowed()` es `true` en PC (tests). Ningún script fuera de `pointer_mode.gd` escribe `Input.mouse_mode` (test que recorre `components/`, `entities/`, `ui/`, `levels/` y `systems/`).
- **AC704** Tocar el botón de ataque deja `attack` apretada (`is_action_pressed` y `is_action_just_pressed` ese frame); soltar el dedo la suelta. Igual para salto, dash, habilidad básica, ultimate y pausa.
- **AC705** Un toque a menos de `touch_slop` px fuera del círculo de un botón lo aprieta; uno a más no.
- **AC706** Multitoque: con el dedo 0 en el joystick y el dedo 1 en el ataque, soltar el dedo 0 no suelta `attack` y soltar el dedo 1 no toca el movimiento. Dos dedos sobre el mismo botón: el segundo se ignora y el botón se suelta solo con el primero.
- **AC707** Joystick flotante: un toque en la mitad izquierda (fuera de botones) mueve el centro del joystick a ese punto; arrastrar `stick_radius` a la derecha da `get_stick_vector() = (1, 0)` y `move_right` con fuerza 1 (`Input.get_action_strength`), `move_left` 0. Arrastrar media distancia hacia arriba da `move_forward` ≈ 0.5.
- **AC708** Zona muerta: un arrastre menor que `stick_dead_zone × stick_radius` deja el vector en `ZERO` y las cuatro acciones sueltas.
- **AC709** Con `stick_follows_thumb`, arrastrar a 2 × `stick_radius` deja el vector de longitud 1 y el centro a `stick_radius` del pulgar. Soltar vuelve el joystick a `stick_rest_position` y suelta las cuatro acciones.
- **AC710** Un toque en la mitad derecha, fuera de los botones, y su arrastre llaman a la cámara: el yaw cambia en `−relative.x × touch_look_sensitivity` (pitch análogo, respetando `invert_y` y los límites). Un toque en la mitad izquierda nunca mueve la cámara. Un dedo que empezó en un botón y se arrastra no mueve la cámara.
- **AC711** Solo un dedo a la vez controla la cámara: un segundo dedo en la mitad derecha (fuera de botones) mientras el primero mira se ignora.
- **AC712** `release_all()` suelta todas las acciones que había apretado `TouchControls` (botones y las cuatro de movimiento). Se llama al desactivar (`set_active(false)`) y al pausarse el árbol: con `attack` y `move_forward` apretadas, pausar el árbol deja ambas sueltas.
- **AC713** Con el árbol en pausa, un toque nuevo no aprieta ninguna acción, pero soltar un dedo que se apretó antes de la pausa sí la suelta.
- **AC714** Player (con `ComboDriver`): mantener el botón de ataque encadena golpes como mantener el clic (regresión de "mantener repite"). Mantener el botón de la habilidad básica con Envainar equipada carga, y levantar el dedo llama a `release_charge()`.
- **AC715** Player: tras una pausa simulada con el botón de dash apretado (`HeldInputGuard`), no hay dash al volver hasta soltar y volver a tocar (misma regla que AC379).
- **AC716** HUD: con `TOUCH`, `TouchControls` es visible y `AbilitySlots` y `DashBar` no; con `KEYBOARD_MOUSE` o `GAMEPAD`, al revés. Cambiar de `TOUCH` a otro dispositivo con un botón apretado lo suelta.
- **AC717** Los slots del racimo son `AbilitySlotView` enlazados a las habilidades del jugador, con radio `side_button_radius`: tras usar la habilidad básica muestran el mismo `get_clock_fraction()` y `get_time_text()` que el slot de PC. El botón de dash muestra la fracción de recarga y el texto de `CooldownText` del dash.
- **AC718** Tamaño de toque: todo `Button` de `main_menu.tscn`, `pause_menu.tscn`, `sandbox_upgrade_panel.tscn`, `upgrade_picker.tscn`, `upgrade_ban_picker.tscn`, `ability_picker.tscn` y `game_over_screen.tscn` (incluidos los que se instancian desde plantillas) tiene alto mínimo efectivo ≥ 44.
- **AC719** Posiciones: con viewport base y área segura igual a la ventana, el centro del ataque está en `esquina inferior derecha + cluster_anchor`, cada botón lateral en `centro del ataque + su offset`, la pausa en `esquina superior derecha + pause_anchor` y el joystick en reposo en `esquina inferior izquierda + stick_rest_position`.
- **AC720** Área segura: con un área segura simulada (margen izquierdo de 60 px y derecho de 40 px), el racimo y la pausa se corren 40 px a la izquierda, el joystick en reposo 60 px a la derecha, y ningún botón queda fuera del área segura.
- **AC721** `ThirdPersonCamera` ignora un `InputEventMouseMotion` con `device = DEVICE_ID_EMULATION` aunque el mouse esté capturado; con `device = DEVICE_ID_MOUSE` gira como antes.
- **AC722** Gesto atrás (`Session` con el evento simulado): con el árbol en pausa y la pausa abierta, la cierra. En juego sin pausa, la abre y queda abierta. En el panel de clases del menú principal vuelve al de modos.
- **AC723** Tocar el botón táctil de pausa (evento de acción vía `parse_input_event`) abre la pausa y pausa el árbol. Con el árbol pausado el racimo no acepta toques nuevos (AC713), así que la pausa se cierra con "Reanudar" o con el gesto atrás.
- **AC724** Sin allocations por frame en `TouchControls`, `VirtualStick` y `TouchActionButton`: `_process` no crea objetos (revisión de código) y el dibujo solo se pide cuando cambia el estado (`queue_redraw` condicionado, como `AbilitySlotView`).
- **AC725** El preset "Android" tiene `package/unique_name="com.fantasyslash.game"`, `package/name="Fantasy Slash"`, `version/name="0.1.0"`, `exclude_filter` con `test/*` y `addons/gdUnit4/*`, solo `arm64-v8a` y Gradle build; `export_presets.cfg` está versionado.
- **AC726** Exportación: `--export-debug "Android"` sobre la copia del scratchpad genera un APK firmado sin errores (paso manual del cierre, se anota el tamaño).
- **AC727** Smoke test en PC con `emulate_touch_from_mouse` activado a mano en la copia: arena 300 frames sin errores. Si el usuario conecta un teléfono: instalar con `adb install`, jugar una run hasta la oleada 3 y anotar FPS con la oleada más poblada alcanzada (paso manual; se registra en la sección 11).

## 7. Tests que pueden necesitar adaptación

- `test/components/input/*`: AC371 sigue igual; se agregan casos de `TOUCH`.
- `test/ui/input_prompts_test.gd`: `Hud._show_prompts` pasa a `_apply_device`; si un test lo llama por nombre se adapta sin cambiar lo que verifica.
- Tests que leen `Input.mouse_mode` después de abrir y cerrar menús: siguen valiendo en PC porque `PointerMode` captura igual que antes.

## 8. Enmienda a la constitución (MAJOR → 5.0.0)

**Principio I**, primera oración: "…en tercera persona **para PC y Android**, jugado con teclado y mouse, mando **o pantalla táctil**."

**Principio VI** (redefinido), título "Input: teclado y mouse, mando o pantalla táctil":

- El juego se controla con **teclado y mouse**, con **mando** (layout Xbox; otros vía SDL) o con **pantalla táctil** (Android, horizontal).
- Todo input pasa por el **InputMap**. Toda acción de juego tiene binding de teclado/mouse y de mando, y un **control táctil** que la dispara como `InputEventAction` (salvo `camera_*`, que en táctil es el arrastre). Prohibido leer teclas o botones físicos en la lógica de juego.
- Toda pantalla de UI se puede usar con mando (foco inicial, foco visible, `ui_accept`, `ui_cancel`) **y al tacto (controles de al menos 44 px base de alto)**.
- Los prompts salen de datos (`InputPromptConfig`, también los textos de los botones táctiles).
- Los bindings de mouse de acciones de juego se limitan al mouse real (`device = DEVICE_ID_MOUSE`), para que un toque no dispare acciones por el mouse emulado.
- Excepciones:
  - El movimiento relativo del mouse para la cámara (`InputEventMouseMotion`), solo en el nodo de cámara, que ignora el mouse emulado desde un toque.
  - `InputDeviceMonitor` clasifica eventos por tipo (teclado/mouse, mando o táctil) solo para elegir prompts y el HUD.
  - `TouchControls` lee `InputEventScreenTouch`/`InputEventScreenDrag` por **posición** (no hay botones físicos que mapear) y los traduce a acciones del InputMap y a un delta de cámara. Es el único nodo que los lee.
  - La captura del mouse pasa por `PointerMode`, que no captura en móvil.

**Principio V**: se agrega "El render de Android usa el renderer Mobile; un ajuste de calidad para móvil se decide con mediciones en el dispositivo, no por las dudas."

**Principio II**: al registro de colores no reservados se suma "blanco translúcido (alpha ≤ 0.5) para los controles táctiles 2D (joystick y botones)". No choca con el blanco reservado, que es de elementos 3D del mundo.

**Technology Stack**: Renderer "Forward+ (PC), Mobile (Android)"; Plataforma "PC (Windows) y Android (arm64-v8a, horizontal)"; Input "Teclado y mouse, mando o pantalla táctil, vía InputMap (Principio VI)".

**Checklist de review, Input (VI)**: "…con bindings de teclado/mouse y de mando **y control táctil**. Pantallas nuevas navegables con mando **y usables al tacto**. Prompts desde datos. **Los bindings de mouse de juego usan `device = DEVICE_ID_MOUSE`, nunca `-1`.**"

**Historial**: "5.0.0 (fecha de cierre): se reincorpora Android como segundo target con controles táctiles. Principio VI redefinido (tercer esquema de control, excepción de `TouchControls`, bindings de mouse limitados al mouse real, `PointerMode`). Principios I, II y V y Technology Stack actualizados (ver `mobile-touch-controls.md`)."

**Revisión de specs tras la MAJOR:** `gamepad-support.md` (sus reglas siguen valiendo; se le suma una nota de que el Principio VI ahora tiene un tercer esquema). Las demás specs no dependen del esquema de control; se revisan por búsqueda de `mouse_mode`, `InputEventMouse` e `is_action` y se anota el resultado en la sección 10.

## 9. Riesgos y alternativas

- **Mouse emulado vs acciones (AC701):** resuelto en el spike (paso 1): el binding con `device = 0` no coincidía con el mouse real, porque Godot 4.7 identifica al mouse con `DEVICE_ID_MOUSE` (32) y migra el `0` a ese valor al cargar. Se escribe 32 explícito (sección 3.1). Si no hubiera funcionado, la alternativa conforme era que el `Player` ignorara `attack`/`dash` en `TOUCH` sin el botón táctil apretado (quitar los bindings de mouse violaría "binding en los dos esquemas").
- **Buffer de input en Android:** `Input.parse_input_event` puede quedar en buffer hasta el próximo frame; los tests llaman `Input.flush_buffered_events()` después de cada evento.
- **Performance:** sin dispositivo no se puede medir; queda como paso manual (AC727).

## 10. Plan

1. **Spike de input (sin tocar gameplay):** test AC701 sobre los bindings actuales cambiados a `device = DEVICE_ID_MOUSE`, y un test mínimo de `parse_input_event` + `flush_buffered_events` con `InputEventAction` con fuerza. Si AC701 falla, se para y se corrige la spec (sección 9).
2. **Reservar ACs** (ya hecho al escribir la spec) y **datos:** `TouchControlsConfig` + `.tres`, `touch_look_sensitivity`, `touch_prompts`, settings de `project.godot` (AC698–AC701).
3. **`InputDeviceMonitor.TOUCH`** y **`PointerMode`**, reemplazando los `Input.mouse_mode` de cámara y menús (AC702, AC703, AC721). Suite de input en verde.
4. **`VirtualStick` y `TouchActionButton`** (dibujo y estado puro) con sus tests (AC705, AC707–AC709).
5. **`TouchControls`**: ruteo multitoque, acciones, cámara, `release_all`, pausa (AC704, AC706, AC710–AC713, AC724).
6. **HUD:** instanciar `touch_controls.tscn`, `_apply_device`, slots del racimo, reloj del dash, área segura (AC716, AC717, AC719, AC720). Re-leer `hud.tscn`/`hud.gd` y `player.gd` antes de editar (sesiones paralelas).
7. **Player y regresiones de combate** con el táctil (AC714, AC715).
8. **Menús y gesto atrás:** tamaños mínimos (sandbox), `Session` con go-back (AC718, AC722, AC723).
9. **Exportación:** preset (quitar `export_presets.cfg` de `.gitignore`), export de debug en la copia; si hay teléfono, `adb install` y medición (AC725–AC727).
10. **Cierre:** tests de esta spec en verde (y la suite completa para el cierre, según el flujo), copiar `.uid` nuevos, smoke test, enmienda 5.0.0 aplicada a la constitución, checklist de review, `CLAUDE.md` (mapa: `ui/touch/`, "Dónde se ajusta": controles táctiles; próximo AC libre), estado **Implementada**.

## 11. Notas de implementación

_(se completa al implementar)_

## 12. Review de la constitución (cierre)

_(se completa al cerrar)_
