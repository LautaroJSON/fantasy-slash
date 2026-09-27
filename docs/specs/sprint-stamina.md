# Feature: correr (sprint) y estamina

- **Estado:** Implementada (2026-09-27), con la revisión de §11 implementada el mismo día (cortes del sprint) y la de §12 (dash y doble toque en cualquier dirección). ACs: AC698–AC720, AC757–AC764 (AC710, AC711 y AC713 reemplazados) y AC765–AC768. Tests: solo los de esta spec y los que tocan (a pedido del responsable); ver §10.
- **Constitución:** `docs/constitution.md` v4.13.0 → **enmienda PATCH a 4.13.1** (ver §7).
- **Pilar (Principio I):** **combate** y **supervivencia.** Hoy la velocidad es fija: no hay forma de reposicionarse rápido salvo el dash, que tiene recarga. Correr da una herramienta de posicionamiento (alejarse de un grupo, cerrar distancia con un Hostigador, esquivar la onda de un boss), y la estamina la vuelve un recurso con costo: el jugador decide cuándo gastarla. La estamina queda preparada para que otras acciones la consuman en el futuro.
- **Dependencias:** `humanoid-player-model.md` y `samurai-run.md` (máquina de locomoción de `PlayerAnimator`, con el `RUN_START` del caminar), `class-combat-identity.md` (perfiles por clase; **en curso en otra sesión**, ver §8), `dash-speed.md`, `gamepad-support.md`, `player-hud-layout.md`.

## 1. Estado actual

1. `MovementComponent.move()` usa siempre `MOVE_SPEED` (× un `speed_factor` que pasan los casts).
2. El clip de caminar se llama `run` (con `run_stop` al frenar); el dash también usa `run` (`PlayerAnimator.CLIP_DASH`).
3. No existe estamina.

## 2. Diseño

### 2.1 Nombres

Por decisión del responsable, **`run` y `run_stop` siguen siendo caminar**. Lo nuevo se llama **`sprint`** en código (en la documentación y la UI, "correr"):

| Clip | Qué es | Bucle |
|---|---|---|
| `sprint_start` | arranque: se inclina y empuja (≈ 0.25 s) | no |
| `sprint` | carrera (período ≈ 0.45 s, más corto y amplio que `run`) | sí |
| `sprint_stop` | frenada con derrape (≈ 0.45 s) y vuelta a la guardia | no |

Cada perfil de clase (Guerrero, Berserker, Samurái) define los tres con su identidad (el Berserker con el mandoble al hombro y zancada pesada, el Samurái bajo y con la mano en la funda, el Guerrero con escudo y espada al frente). El perfil `legacy` no los define: si un perfil no tiene un clip de sprint, `PlayerAnimator` usa el de caminar equivalente (`run`/`run_stop`), igual que `_busy_clip()` cae en `idle`.

### 2.2 Reglas de correr

**Empezar a correr** (_reglas 1 y 3 ampliadas a cualquier dirección en §12_) (si `stamina ≥ stamina_to_start_sprint` y el jugador está en el piso, sin cast, sin golpe comprometido ni sujeción):

1. **Doble toque de avance:** dos `just_pressed` de `move_forward` separados por ≤ `double_tap_window` s. En teclado es W–W; con el stick, dos empujes hacia adelante (inofensivo).
2. **Acción `sprint`:** clic del stick izquierdo (L3) en mando y `Shift` izquierdo en teclado (la constitución pide binding en los dos esquemas; el doble toque de W sigue siendo el gesto principal en teclado). Solo empieza a correr, no alterna.
3. **Al terminar un dash** (no cancelado por una habilidad), si `move_forward` sigue apretada y hay estamina suficiente: se corre directo en `sprint`, sin `sprint_start` (el dash ya dio el impulso). Vale aunque antes del dash no se estuviera corriendo.

**Mientras corre:** velocidad máxima = `MOVE_SPEED × SPRINT_SPEED_FACTOR`, con la misma aceleración de `player_tuning`. Gasta `SPRINT_STAMINA_COST` por segundo (continuo, por `delta`). La dirección sigue a todo el input (W+A corre en diagonal).

**Deja de correr** (_reemplazado por §11: ver ahí las reglas vigentes_) (sin recuperar el estado: para volver a correr hay que repetir el doble toque, L3/Shift o un dash):

1. Se suelta `move_forward` (aunque siga apretada A o D).
2. La estamina llega a 0.
3. Golpea: empieza un golpe del combo, un cast o carga de habilidad, o el Tajo aéreo.
4. Una sujeción de boss (`begin_hold`).

**Dash y salto** (_el salto ahora corta, §11_): el dash **pausa** la carrera (no gasta estamina durante el dash) y al terminar vuelve a correr por la regla 3. El salto **no** la corta: en el aire se conserva la velocidad y se sigue gastando; al aterrizar sigue corriendo si `move_forward` sigue apretada.

### 2.3 Estamina

- `STAMINA_MAX` (stat), valor actual en `StaminaComponent`, que empieza lleno y se llena al reiniciar la run.
- Se regenera `STAMINA_REGEN` por segundo cuando pasaron `stamina_regen_delay` s desde el último gasto. No se regenera mientras se corre.
- `stamina_to_start_sprint` evita carreras de un cuadro con la estamina casi vacía.
- Si baja `STAMINA_MAX` por quitar una mejora (sandbox), el actual se recorta al nuevo máximo.
- La estamina no se gasta con nada más por ahora (ni dash ni salto).

### 2.4 Animación

`PlayerAnimator.Locomotion` suma `SPRINT_START`, `SPRINT`, `SPRINT_STOP`. `next_locomotion()` recibe `sprinting: bool` y `move_input: bool` (sigue siendo pura; ver nota de implementación 1 en §10):

| Estado actual | Condición | Siguiente |
|---|---|---|
| cualquiera en piso (no sprint) | `sprinting` | `SPRINT_START` |
| saliendo de una acción (dash, golpe, cast) | `sprinting` (`settled_locomotion`) | `SPRINT` |
| `SPRINT_START` | clip terminado | `SPRINT` |
| `SPRINT_START`/`SPRINT`/`SPRINT_STOP` | no `sprinting`, con input de movimiento | `RUN` (caminar, mezcla `sprint_exit_blend`) |
| `SPRINT_START`/`SPRINT` | no `sprinting`, sin input (aunque siga deslizando rápido) | `SPRINT_STOP` |
| `SPRINT_STOP` | clip terminado | `IDLE` |
| en el aire / aterrizaje | igual que hoy; al aterrizar con `sprinting` | `SPRINT` |

El `RUN_START` del caminar (`samurai-run.md`) cuenta como "no sprint": hacer doble toque durante el arranque de caminar pasa a `SPRINT_START`. Al dejar de correr se vuelve a `RUN`, nunca a `RUN_START`.

Si la carrera termina por un golpe o una habilidad, el clip de la acción manda como hoy (`_is_action_owning_body()`). Al salir de la acción se usa `settled_locomotion()`, que devuelve `SPRINT` si sigue corriendo. El dash sigue mostrando `run` (`CLIP_DASH`).

### 2.5 Estructura de nodos

```
Player (CharacterBody3D)
├── StaminaComponent   (nuevo) components/stamina_component.gd
├── SprintComponent    (nuevo) components/sprint_component.gd
└── … (sin cambios)
```

- **`StaminaComponent`**: `stats: StatsComponent`, `config: SprintConfig`. Guarda la estamina actual y el tiempo desde el último gasto.
- **`SprintComponent`**: `stats`, `stamina: StaminaComponent`, `config: SprintConfig`. Guarda si corre, el reloj del doble toque y si la carrera viene de un dash. El detector de doble toque es una función pura.
- `Player` solo orquesta (`_handle_sprint()`), y le pasa a `MovementComponent.move()` el `speed_factor` de la carrera.
- **HUD:** una barra de estamina (`ProgressBar` `%StaminaBar`, amarilla) **debajo de la barra del dash**, abajo a la izquierda: mismo ancho (150 px), más fina (12 px), a 16 px del borde inferior. La barra del dash sube para dejarle lugar (de `offset_top` −36 / `offset_bottom` −16 a −54 / −34, 6 px de separación). Sin texto: solo el relleno.

### 2.6 Resources y datos

**`PlayerStats`** (stats mejorables; sin carta en el catálogo por ahora, fijos por diseño como el dash). Nuevos valores del enum `Stat` al final: `STAMINA_MAX`, `STAMINA_REGEN`, `SPRINT_STAMINA_COST`, `SPRINT_SPEED_FACTOR`.

| Campo | Guerrero | Berserker | Samurái |
|---|---|---|---|
| `stamina_max` | 100 | 100 | 100 |
| `stamina_regen` (por s) | 25 | 25 | 25 |
| `sprint_stamina_cost` (por s) | 20 | 20 | 20 |
| `sprint_speed_factor` | 1.6 | 1.6 | 1.6 |

(5 s de carrera con la estamina llena; el Samurái pasa de 6.5 a 10.4 m/s.)

**`SprintConfig`** (`resources/sprint_config.gd`, `data/player/sprint_config.tres`; sensación de control, no mejorable):

| Campo | Valor | Qué es |
|---|---|---|
| `double_tap_window` | 0.3 | s máximos entre los dos toques de avance |
| `stamina_to_start_sprint` | 20 | estamina mínima para empezar a correr |
| `stamina_regen_delay` | 1.0 | s sin gastar antes de regenerar |

**`PlayerAnimationConfig`** suma `sprint_exit_blend = 0.2` (s de mezcla de `sprint` a caminar; vive con las demás mezclas del animador).

**`PlayerHealthBarStyle`** se reutiliza para la barra de estamina con `data/ui/player_stamina_bar_style.tres` (amarillo `Color(1.0, 0.9, 0.2)`, el mismo fondo oscuro que la vida). Posición y tamaño viven en `hud.tscn`, como las demás barras.

**`StatDisplayTable`**: fila "Estamina máxima" (entero) en la pausa. Costo, regeneración y factor de velocidad no se muestran (internos, como `dash_speed`).

**InputMap:** acción `sprint` (L3 = `JOY_BUTTON_LEFT_STICK`, `Shift` izquierdo). `InputPromptConfig` suma su prompt.

### 2.7 Interfaz pública

```gdscript
# StaminaComponent
signal stamina_changed(current: float, maximum: float)
signal depleted
func get_current() -> float
func get_max() -> float
func has_at_least(amount: float) -> bool
func spend(amount: float) -> void          # clamps at 0; restarts the regen delay
func refill() -> void                      # run reset
func advance(delta: float) -> void         # regen (called from _physics_process)

# SprintComponent
signal sprint_started(from_dash: bool)
signal sprint_ended
func is_sprinting() -> bool
func started_from_dash() -> bool
func register_forward_tap(now: float) -> bool   # true = double tap completed
static func is_double_tap(last_tap: float, now: float, window: float) -> bool
func try_start(from_dash: bool) -> bool
func stop() -> void
func drain(delta: float) -> void            # spends cost × delta; stops at 0
func get_speed_factor() -> float            # SPRINT_SPEED_FACTOR while sprinting, else 1

# Player
func is_sprinting() -> bool
func has_move_input() -> bool              # the animator's sprint stop

# DashComponent
signal dash_ended(cancelled: bool)
```

### 2.8 Lógica interna

`Player._physics_process` suma `_handle_sprint(delta)` después de `_handle_dash()` y antes de `_handle_movement()`:

```gdscript
func _handle_sprint(delta: float) -> void:
	_start_sprint_if_requested()
	_stop_sprint_if_released()
	if sprint.is_sprinting() and not dash.is_dashing():
		sprint.drain(delta)
```

- `_start_sprint_if_requested()`: doble toque o acción `sprint` → `sprint.try_start(false)`, solo con `_can_start_sprint()` (piso, sin cast, sin golpe comprometido).
- Fin del dash → `sprint.try_start(true)` si `move_forward` está apretada (señal nueva `DashComponent.dash_ended(cancelled: bool)`; no se arranca si `cancelled`).
- `_stop_sprint_if_released()`: `move_forward` sin apretar → `sprint.stop()`.
- `sprint.stop()` en: `attack.step_started`, `cast_started`/`charge_started` de las habilidades, `air_slash` al empezar, `begin_hold()`, y `stamina.depleted`.
- `_handle_movement()`: `_movement.move(wish_direction, delta, sprint.get_speed_factor())`.
- `HeldInputGuard` suma `sprint` a sus acciones. El doble toque lee `move_forward` a través del guard (un W apretado al cerrar la pausa no cuenta como toque).
- Sin allocations por frame: tiempos como `float` miembro; el reloj del doble toque es un `float` que `SprintComponent` suma en `_physics_process` (determinista en los tests).

## 3. Criterios de aceptación (AC698–AC720)

**Estamina**
- **AC698** `PlayerStats` tiene `STAMINA_MAX`, `STAMINA_REGEN`, `SPRINT_STAMINA_COST`, `SPRINT_SPEED_FACTOR`; los `.tres` de las tres clases valen 100 / 25 / 20 / 1.6 y `get_base()` los devuelve.
- **AC699** `StaminaComponent` empieza lleno (`get_current() == STAMINA_MAX`) y `refill()` lo vuelve a llenar.
- **AC700** `spend(30)` con 100 deja 70 y emite `stamina_changed(70, 100)`; `spend` nunca baja de 0 y al llegar a 0 emite `depleted` una vez.
- **AC701** Tras gastar, no regenera durante `stamina_regen_delay` (1.0 s); después sube 25/s hasta el máximo sin pasarlo.
- **AC702** Si `STAMINA_MAX` baja (quitar una mejora), el actual se recorta al nuevo máximo.

**Empezar a correr**
- **AC703** `is_double_tap()`: 0.25 s entre toques → true; 0.35 s → false (ventana 0.3).
- **AC704** Dos toques de `move_forward` dentro de la ventana, en el piso y con estamina ≥ 20 → `is_sprinting()` y `sprint_started(false)`.
- **AC705** Con estamina < 20, en el aire, durante un cast, una carga o un golpe comprometido, el doble toque no hace correr.
- **AC706** La acción `sprint` hace correr con las mismas condiciones; no apaga una carrera en curso.
- **AC707** Un dash que termina solo con `move_forward` apretada y estamina ≥ 20 deja al jugador corriendo (`sprint_started(true)`), aunque antes no corriera. Sin `move_forward`, o si el dash lo cortó una habilidad, no corre.

**Mientras corre y al terminar**
- **AC708** Corriendo, la velocidad horizontal máxima es `MOVE_SPEED × 1.6` (10.4 m/s en el Samurái); sin correr, `MOVE_SPEED`.
- **AC709** Correr gasta 20 por segundo (1 s → 80 ± 0.5); durante el dash no gasta.
- **AC710** Soltar `move_forward` corta la carrera aunque siga apretada `move_left`/`move_right`.
- **AC711** Llegar a 0 de estamina corta la carrera y el jugador sigue caminando si mantiene W.
- **AC712** Empezar un golpe del combo, un cast, una carga, el Tajo aéreo o una sujeción corta la carrera; terminarlos no la retoma.
- **AC713** Saltar corriendo no corta la carrera: en el aire sigue gastando; al aterrizar con W apretada sigue corriendo.
- **AC714** Al reiniciar la run la estamina está llena y el jugador no corre.

**Animación**
- **AC715** Los perfiles Guerrero, Berserker y Samurái tienen `sprint_start` (no bucle), `sprint` (bucle) y `sprint_stop` (no bucle), con largos en los rangos 0.15–0.35 s, 0.35–0.55 s y 0.3–0.6 s; `sprint` es más corto que `run` del mismo perfil.
- **AC716** `next_locomotion()`: empezar a correr desde caminar o quieto → `SPRINT_START` → al terminar el clip `SPRINT`; desde un dash → `SPRINT` directo; aterrizar corriendo → `SPRINT`.
- **AC717** Dejar de correr con input de movimiento → `RUN`; sin input → `SPRINT_STOP` aunque el cuerpo siga deslizando rápido → al terminar `IDLE`; con input durante `SPRINT_STOP` → `RUN`.
- **AC718** Con un perfil sin clips de sprint (`legacy`), el animador pide `run`/`run_stop` y no falla.

**Input y HUD**
- **AC719** `sprint` tiene L3 y `Shift` izquierdo, no comparte binding con otra acción (AC65) y está en el `HeldInputGuard`; `InputPromptConfig` tiene su prompt.
- **AC720** (_ubicación reemplazada por AC777 de `dash-button.md`: la barra queda sola abajo a la izquierda_) El HUD muestra la barra de estamina amarilla debajo de la barra del dash (mismo ancho, su borde superior por debajo del inferior del dash y sin solaparse), con el estilo de `player_stamina_bar_style.tres`, y se actualiza con `stamina_changed`; la pausa muestra "Estamina máxima: 100".

**Rango ya anotado como propuesto en `CLAUDE.md`. Próximo libre global: AC757.**

## 4. Tests

- `test/components/stamina_component_test.gd` (AC699–AC702).
- `test/components/sprint_component_test.gd` (AC703, AC709).
- `test/entities/player/sprint_test.gd` (AC704–AC714, con el jugador real y `Input.action_press`).
- `test/components/player_animator_test.gd` (AC716–AC718, casos nuevos de `next_locomotion`).
- `test/entities/player/class_combat_identity_test.gd` (AC715, en un test propio del archivo).
- `test/entities/player/input_map_test.gd` (AC719) y `test/ui/hud_test.gd` / `pause_menu_test.gd` (AC720).
- Tests con valores fijos que cambian: el número de filas de la pausa y la lista de acciones del InputMap (se anotan al cerrar).

## 5. Riesgos

- **Correr + dash = mucha movilidad.** El dash encadena en carrera y la carrera no tiene recarga, solo estamina. Si se vuelve demasiado fácil escapar, se ajusta `sprint_speed_factor` o se agrega costo de estamina al dash (otra spec).
- **Doble toque con el stick:** empujar el stick dos veces rápido hace correr. Es el mismo gesto, así que se acepta.
- **Arranque del dash como carrera:** si se siente brusco pasar del dash a `sprint` sin `sprint_start`, se ajusta la mezcla en la captura.

## 6. Visual

Hojas de captura por clase (arranque, carrera en 4 cuadros, frenada) para aprobar las poses antes de cerrar, con torso inclinado, brazos amplios y zancada larga (pedido del responsable: animaciones expresivas).

## 7. Enmienda de la constitución (PATCH 4.13.0 → 4.13.1)

Principio II, registro de colores no reservados: "amarillo `Color(1.0, 0.9, 0.2)` para la barra de estamina del HUD (no se confunde con el dorado de las cartas ni con la miel de la Colmena: es una barra del HUD, abajo a la izquierda)". No cambia ninguna regla: los stats nuevos siguen el Principio III (valores en `.tres`, mejorables, sin carta por diseño) y `sprint` tiene binding en los dos esquemas (Principio VI).

## 8. Coordinación

`class-combat-identity.md` sigue abierta en otra sesión y edita los perfiles (`berserker_profile.gd` tiene cambios sin commitear). Los clips de sprint se agregan como funciones nuevas (`_add_sprint()`) al final de cada perfil, sin tocar las existentes, y se implementan cuando esa spec cierre o con su visto bueno.

## 9. Checklist de review (constitución)

- [x] Principio I: pilares de combate (reposicionarse rápido, encadenar dash → carrera) y supervivencia (la estamina es un recurso con costo).
- [x] Principio II: sin mallas ni materiales nuevos en 3D. Los clips de sprint son datos del asset `LowPolyHumanoid` (una función `_add_sprint()` por perfil, construidos una vez al cargar). La barra de estamina es UI; su amarillo quedó registrado como color no reservado (4.13.1).
- [x] Principio III: estamina, regeneración, costo y factor de velocidad son stats mejorables en `<clase>_stats.tres` (sin carta por diseño); ventana del doble toque, umbral para arrancar y demora de regeneración en `sprint_config.tres`; la mezcla de salida en `player_animation_config.tres`. Sin literales de diseño en el código.
- [x] Principio IV: tipado estricto, callbacks delgados (`_handle_sprint` orquesta; la lógica está en `SprintComponent`/`StaminaComponent`), código y comentarios en inglés.
- [x] Principio V: sin allocations por cuadro (el reloj y la estamina son `float` miembro; el HUD escribe dos floats por cambio; las señales solo se emiten al cambiar la estamina).
- [x] Principio VI: acción `sprint` con Shift izquierdo y L3; el doble toque lee `move_forward` del InputMap a través del `HeldInputGuard`; prompt en `InputPromptConfig`.
- [x] Principio VII: correr no cambia el compromiso del golpe; golpear corta la carrera.

## 10. Notas de implementación

1. **La salida del sprint depende del input, no de la velocidad.** Al soltar W el cuerpo sigue deslizando a ~10 m/s mientras frena, así que con la regla por velocidad de la spec original `sprint_stop` nunca sonaba (pasaba a caminar y después a `run_stop`). Se agregó `move_input` a `next_locomotion()` y `Player.has_move_input()`; AC717 se reescribió en consecuencia. `from_dash` no hizo falta: el dash es una acción del cuerpo y `settled_locomotion(sprinting = true)` ya deja el estado en `SPRINT`.
2. `sprint_exit_blend` quedó en `PlayerAnimationConfig` (junto a `attack_exit_blend`) en vez de `SprintConfig`, para que el animador no dependa de otro Resource.
3. Las mezclas que faltan en un perfil (`sprint_start` → `sprint` → `run`, `sprint_stop` → `run_stop`, y el `run_start` de `samurai-run.md` → `run`) se resuelven con una tabla (`CLIP_FALLBACKS`) en vez del caso especial que tenía `run_start`.
4. Poses: el Guerrero carga con el torso volcado y el escudo al pecho (`SHIELD_COVER`), la espada baja al frente (`SPRINT_WRIST`, más levantada que al caminar para que la punta no toque el piso); el Berserker embiste con el mandoble al hombro y el puño izquierdo bombeando; el Samurái corre bajo con la katana horizontal detrás y la funda paralela (brazos de `RUN_ARMS` con el hombro 18° más atrás). Hojas de captura revisadas antes de cerrar.
5. **Tests adaptados** (sin cambiar lo que verifican): `dash_component_test.gd` AC395 (`DASH_SPEED` ya no es el último stat: ahora se verifica que conserve su índice, justo antes de `STAMINA_MAX`); `pause_menu_test.gd` AC233 (la columna derecha suma "Estamina máxima" y los stats internos nuevos van a `HIDDEN_STATS`); `input_map_test.gd` (`sprint` en `GAME_ACTIONS`, así AC65 verifica que no comparta binding).
6. **Resultado:** `stamina_component_test` 4/4, `sprint_component_test` 5/5, `sprint_test` 17/17, `sprint_anim_test` 6/6, `sprint_hud_test` 4/4, más `input_map_test`, `player_animator_test`, `dash_component_test`, `player_hud_test`, `pause_menu_test` y `samurai_run_anim_test` en verde. `dash_cancel_test.gd` AC363 (pose de reposo de la katana después del corte de Envainar) falla sin tocar correr ni el input de avance; coincide con los cambios en curso de otras sesiones en `weapon_mount.gd` y Envainar (`sheathe-release-animation.md`). No se corrió la suite completa (pedido del responsable). Smoke test del proyecto y de la arena sin errores.

## 11. Revisión (2026-09-27): cuándo se deja de correr

Pedido del responsable: el sprint se corta **si y solo si** el jugador golpea, usa una habilidad, salta, se queda quieto o recibe un golpe (y, por decisión suya, también con el agarre de un boss). Quedarse sin estamina ya no lo corta.

### 11.1 Reglas nuevas (reemplazan "Deja de correr" de §2.2)

El sprint termina solo con:

1. **Golpear:** un golpe del combo, un cast o carga de habilidad, o el Tajo aéreo (sin cambios).
2. **Saltar:** el salto ahora **corta** la carrera. Reemplaza la regla "el salto no la corta" de §2.2 y AC713.
3. **Quedarse quieto:** no hay ningún input de movimiento (`move_forward`, `move_back`, `move_left`, `move_right`). Soltar W ya no corta: con A o D apretadas se sigue corriendo en esa dirección. Reemplaza AC710.
4. **Recibir daño de un enemigo:** `HealthComponent.damaged`. Durante el dash el jugador es invulnerable, así que no hay daño ni corte.
5. **Agarre de un boss** (`begin_hold`, sin cambios).

**El dash** sigue pausando la carrera sin cortarla. Cómo se empieza a correr no cambia (doble toque de W, Shift/L3, o fin de un dash con W apretada).

### 11.2 Estamina en 0: "sin aliento"

Llegar a 0 **no** corta el sprint (reemplaza AC711). El jugador queda **sin aliento** (`SprintComponent.is_winded()`):

- Se mueve a velocidad de caminar (`get_speed_factor()` = 1) y se ve caminar (el animador recibe "no corre").
- No gasta estamina. La estamina se regenera normalmente (después de `stamina_regen_delay`).
- Cuando la estamina vuelve a `stamina_to_start_sprint` (20), vuelve solo a correr (`sprint_start` → `sprint`) si el sprint no se cortó mientras tanto.
- El umbral de 20 evita que se alterne entre caminar y correr en cada cuadro apenas se regenera algo de estamina. No hay datos nuevos.

### 11.3 Interfaz y lógica

```gdscript
# SprintComponent
func is_winded() -> bool            # sprinting but out of breath: walks, spends nothing
func is_running() -> bool           # sprinting and not winded: sprint speed and clips
# Player
func is_running() -> bool           # what the PlayerAnimator reads (was is_sprinting())
```

- `SprintComponent`: `stamina.depleted` → `_winded = true` (ya no `stop`). En `drain()`, si está sin aliento no gasta, y sale de ese estado cuando `stamina.has_at_least(stamina_to_start_sprint)`. `stop()` y `try_start()` limpian `_winded`.
- `Player._handle_sprint()`: `sprint.stop()` si `not has_move_input()` (antes: si no había `move_forward`). `_handle_jump()` llama `sprint.stop()` al saltar. `health.damaged` se conecta a `sprint.stop`.
- `PlayerAnimator` lee `player.is_running()` en lugar de `player.is_sprinting()`. Sin aliento, el animador ve "no corre" con input, así que pasa a caminar (`RUN`). Al recuperarse vuelve a `SPRINT_START`.

### 11.4 Criterios de aceptación (AC757–AC764)

Reemplazan a AC710, AC711 y AC713, y amplían AC712:

- **AC757** Soltar `move_forward` con `move_right` apretada **no** corta la carrera: sigue a `MOVE_SPEED × 1.6` hacia la derecha.
- **AC758** Soltar todo el input de movimiento corta la carrera. Al volver a moverse, camina.
- **AC759** Saltar corta la carrera; al aterrizar con W apretada camina.
- **AC760** Recibir daño corta la carrera. Un golpe que llega durante el dash (invulnerable) no la corta.
- **AC761** Con la estamina en 0 el sprint sigue activo (`is_sprinting()`) pero sin aliento (`is_winded()`): velocidad de caminar, clip `run`, no gasta.
- **AC762** Sin aliento, la estamina se regenera después de `stamina_regen_delay`. Al llegar a 20 vuelve a correr solo (`is_running()`, velocidad de sprint, `sprint_start`).
- **AC763** Sin aliento, golpear, saltar, quedarse quieto o recibir daño cortan el sprint igual. Al cortarse ya no vuelve a correr al recuperar estamina.
- **AC764** `SprintComponent`: `drain()` con 0 de estamina no emite `stamina_changed` ni reinicia la demora de regeneración.

### 11.5 Plan

1. Reservar AC757–AC764 en `CLAUDE.md`.
2. `SprintComponent`: estado "sin aliento" (`is_winded`, `is_running`) y `drain` sin gasto en ese estado. Tests AC761, AC762 y AC764 en `sprint_component_test.gd`.
3. `Player`: corte al quedarse quieto (cualquier input), al saltar y al recibir daño; `is_running()`. `PlayerAnimator` lee `is_running()`.
4. `sprint_test.gd`: se reemplazan los tests de AC710, AC711 y AC713 por AC757–AC760 y AC763. Se reescriben, no se adaptan, porque la regla cambió: se anota en §10.
5. Correr los tests de esta spec y los que toca (`player_animator_test`, `sprint_anim_test`), smoke test, checklist y cerrar la revisión.

### 11.6 Cierre de la revisión

- **Checklist de la constitución:** sin cambios respecto de §9. No hay datos nuevos: el estado "sin aliento" usa `stamina_to_start_sprint` como umbral de vuelta. Tampoco hay allocations nuevas por cuadro (`_winded` es un `bool` miembro). El corte por daño se conecta una vez en `_ready`.
- **Tests reescritos (no adaptados), porque la regla cambió:** en `sprint_test.gd` se quitaron `test_ac710_letting_go_of_forward_stops_it`, `test_ac711_an_empty_bar_stops_it_and_the_player_walks` y `test_ac713_jumping_keeps_it_and_spends_in_the_air`, y se agregaron AC757–AC763. En `sprint_component_test.gd`, `test_ac711_an_empty_bar_stops_the_sprint` pasó a ser AC761–AC764.
- **Resultado:** `stamina_component_test` 4/4, `sprint_component_test` 8/8, `sprint_test` 21/21, `sprint_anim_test` 6/6, `sprint_hud_test` 4/4 y `player_animator_test` 13/13 en verde. Smoke test del proyecto y de la arena sin errores.

## 12. Revisión (2026-09-27): correr en cualquier dirección

Pedido del responsable: el dash hace correr si el jugador se está moviendo **en cualquier dirección** (W, A, S o D), no solo con W. Además, el doble toque vale en cualquier dirección (W W, A A, S S o D D), no solo con W. Shift y L3 no cambian.

### 12.1 Regla (reemplaza la regla 3 de "Empezar a correr" en §2.2)

Un dash que termina solo (no cortado por una habilidad), con **cualquier** input de movimiento apretado al terminar (`Player.has_move_input()`) y estamina ≥ `stamina_to_start_sprint`, sigue como carrera en `sprint` (sin `sprint_start`). La dirección de la carrera es la del input, como cualquier movimiento. Sin input al terminar, no corre.

### 12.1b Doble toque en cualquier dirección (reemplaza la regla 1 de "Empezar a correr" en §2.2)

Dos `just_pressed` de **la misma** acción de movimiento (`move_forward`, `move_back`, `move_left` o `move_right`) separados por ≤ `double_tap_window` s hacen correr, con las mismas condiciones de siempre (piso, estamina ≥ 20, sin cast ni golpe comprometido). Dos toques de direcciones distintas (A y después D) **no** cuentan: un cambio rápido de dirección no dispara la carrera. Con el stick vale igual para cualquier dirección.

### 12.2 Lógica

- `Player._on_dash_ended()`: la condición `Input.is_action_pressed(ACTION_FORWARD)` pasa a `has_move_input()`.
- `SprintComponent.register_forward_tap()` pasa a `register_tap(action: StringName) -> bool`: guarda la acción del último toque y solo completa el doble toque si la acción se repite.
- `Player._start_sprint_if_requested()` revisa las cuatro acciones de movimiento a través del `HeldInputGuard`, que suma `move_back`, `move_left` y `move_right`. `_can_start_sprint()` pide `has_move_input()` en vez de `move_forward`.
- No hay datos nuevos.

### 12.3 Criterios de aceptación (AC765–AC768)

Amplían AC704 y AC707:

- **AC765** Un dash que termina con `move_back`, `move_left` o `move_right` apretada (sin `move_forward`) y estamina ≥ 20 deja al jugador corriendo (`sprint_started(true)`) a `MOVE_SPEED × 1.6` en esa dirección.
- **AC766** Un dash que termina sin input de movimiento, o cortado por una habilidad, no hace correr (sin cambios respecto de AC707).
- **AC767** Doble toque de `move_left` (y de `move_back` o `move_right`) dentro de la ventana hace correr en esa dirección, a `MOVE_SPEED × 1.6`.
- **AC768** `move_left` y después `move_right` dentro de la ventana no hace correr; `register_tap()` con dos acciones distintas devuelve `false`.

### 12.4 Plan

1. Reservar AC765–AC768 en `CLAUDE.md` (próximo libre: AC769).
2. `Player._on_dash_ended()`: usar `has_move_input()`.
3. `SprintComponent.register_tap(action)`, el guard con las cuatro direcciones y `_start_sprint_if_requested()` revisando las cuatro. `sprint_component_test.gd`: AC703 pasa a `register_tap` (se adapta sin cambiar lo que verifica) y se agrega AC768.
4. `sprint_test.gd`: AC765 (tres direcciones), AC766 y AC767. Los tests de AC704 y AC707 siguen valiendo.
5. Correr `sprint_test`, `sprint_component_test`, `sprint_anim_test` y `sprint_hud_test`, hacer el smoke test y cerrar: estado, notas y `CLAUDE.md`.

### 12.5 Cierre de la revisión

- **Checklist de la constitución:** sin cambios respecto de §9. El doble toque sigue leyendo acciones del InputMap a través del `HeldInputGuard` (Principio VI); `MOVE_ACTIONS` es una constante estructural y no aloca por cuadro (Principio V). No hay datos nuevos.
- **Test adaptado:** `sprint_component_test.gd` AC703 (`register_forward_tap()` → `register_tap(&"move_forward")`, verifica lo mismo).
- **Resultado:** `stamina_component_test` 4/4, `sprint_component_test` 9/9, `sprint_test` 25/25, `sprint_anim_test` 6/6, `sprint_hud_test` 4/4 y `player_animator_test` 13/13 en verde. Smoke test del proyecto y de la arena sin errores.
