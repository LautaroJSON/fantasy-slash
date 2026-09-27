# Feature: modelo humanoide animado para el jugador

- **Estado:** Implementada (2026-09-26). Se corrieron solo los tests de esta spec y los que adapta o toca (no la suite completa, a pedido del responsable): 207 casos, en verde salvo 5 fallos previos y ajenos (ver §7). 0 orphans. Import, smoke test (escena principal y arena) y combate real en el arena con las tres clases sin errores ni warnings en la consola.
- **Constitución:** `docs/constitution.md` v4.8.0 → **v4.9.0** (enmienda MINOR aplicada, ver §6).
- **Decisiones aprobadas:** D1 (humanoide ×1.333, cápsula de 1.8 m) y D2 (multiplicadores 0.35 / 0.35 / 0.62).
- **Pilar (Principio I):** combate.
  - La cápsula se reemplaza por un personaje animado, así que se lee qué hace el jugador: si corre, salta, en qué golpe del combo está o si recibió un golpe.
  - El ataque básico pasa a ser un combo de 3 golpes con ventana de encadenado y buffer de entrada, y el impacto se siente gracias al hitstop y al shake. Pelear queda más expresivo sin cambiar el balance (ver D2).
- **Dependencias:** `weapon-models.md`, `weapon-trail.md`, `class-sweep-timing.md`, `samurai.md` (funda), `sheathe-feel.md` (temblor de carga), todas Implementadas.
- **Fuera de alcance:** los enemigos. Siguen siendo cápsulas grises con sus manos de aviso y tendrán una spec aparte. Tampoco se rehacen las animaciones de las habilidades (ver §2.6).

## 1. Objetivo

- **Hoy:**
  - El jugador es una `CapsuleMesh` blanca de 1.8 m (`Visual/Body`).
  - El ataque básico se repite mientras se mantiene el botón, a la cadencia de `ATTACK_SPEED`. Cada golpe hace un barrido procedural (`SwordSwing.play`) y aplica el daño **en el mismo cuadro** en que se aprieta.
- **Nuevo:**
  1. El cuerpo visible es el humanoide low-poly `LowPolyHumanoid` (cabeza, torso, manos y pies flotantes), blanco, que sostiene el arma de la clase en la mano derecha.
  2. Animaciones de locomoción según el estado: `idle`, `run`, `run_stop`, `jump_start`, `jump_air` y `jump_land`.
  3. Combo `attack_1` → `attack_2` → `attack_3` → `attack_1`… Cada **toque** de ataque hace un golpe (mantener apretado no repite). Un toque dentro de la ventana de combo, o hasta 0.15 s antes (buffer), encadena el golpe siguiente.
  4. El daño se aplica cuando se abre `hit_window` del golpe, una vez por golpe, con el mismo sector lógico de hoy (`ATTACK_RANGE` + `ATTACK_ARC`).
  5. Animación `hit` al recibir daño.
  6. Hitstop corto (0.06 s) y un shake leve de cámara cuando un golpe del combo impacta.

## 2. Diseño

### 2.1 El asset `LowPolyHumanoid`

- **Ubicación:** `low_poly_humanoid.gd` se mueve de la raíz a `assets/models/characters/low_poly_humanoid/low_poly_humanoid.gd` (Principio II, scaffolding), con un `SOURCE.md` que registra origen (aportado por el responsable del proyecto) y licencia (propia). `humanoid_demo.gd` se mueve a la misma carpeta, como escena de prueba del asset.
- **Modificaciones al script (imprescindibles, sin cambiar poses, tiempos ni API):**
  1. **Tipado estático.** Hoy el script **no compila** en este proyecto: `untyped_declaration` es error en `project.godot` y hay 17 errores (variables de `for` sin tipo y la lambda de `_ready`). Se agregan los tipos que faltan (`for side: int in …`, `func(_n: StringName) -> void`, etc.).
  2. **Materiales compartidos (Principio II).** Se agregan `@export var body_material: Material`, `accent_material` y `weapon_material`. Si están asignados, `_build()` los usa en lugar de crear un `StandardMaterial3D` por instancia. Si no, se comporta como hoy (el demo sigue igual).
  3. **`@export var use_hitbox: bool = true`.** Si es `false`, no se crea el `Area3D` de la espada. El juego no lo usa (el daño es el sector lógico, ver §2.4), y así no queda un área con capas por defecto (Principio V).
  4. **`func get_right_hand() -> Node3D`**, que devuelve la muñeca derecha para montar el arma de la clase. Hoy esa articulación solo es accesible por el diccionario privado `_j`.
- **Escena adaptadora:** `entities/player/humanoid.tscn`. La raíz es un `LowPolyHumanoid` con `has_sword = false`, `use_hitbox = false`, `demo_controls = false` y `body_material = materials/player_material.tres` (blanco `Color(1, 1, 1)`). `accent_material` y `weapon_material` quedan vacíos porque solo se usan en la espada propia, que está desactivada.

### 2.2 Escena del jugador (`player.tscn`)

- `Visual/Humanoid`: instancia de `humanoid.tscn`, con escala uniforme `1.8 / 1.35 ≈ 1.333` (ver **D1**). Mira hacia −Z como `Visual`.
- Se **elimina** `Visual/Body` (la `CapsuleMesh`) y su sub-recurso `CapsuleMesh_body`.
- `CollisionShape3D`: sigue siendo una `CapsuleShape3D` con base en los pies (`y = altura / 2`). Con D1 conserva radio 0.4 y alto 1.8.
- `ChargeFeedback.body` pasa de `Visual/Body` a `Visual/Humanoid` (el temblor de carga mueve al humanoide).
- **Rotación:** `MovementComponent` ya rota solo `Visual`, nunca el `CharacterBody3D`, interpolando con `PlayerTuning.turn_speed`. `Humanoid` es hijo de `Visual`, así que mira hacia donde se mueve el jugador sin código nuevo. No se rota `Humanoid` por separado porque el auto-aim, `get_facing()` y las habilidades usan la orientación de `Visual`.

### 2.3 Animación (`PlayerAnimator`, nuevo componente)

- **`components/player_animator.gd`** (`class_name PlayerAnimator extends Node`). Traduce estados en animaciones y es el **único** que llama a `humanoid.play()`.
- **Exports:** `body: CharacterBody3D`, `humanoid: LowPolyHumanoid`, `attack: AttackComponent`, `dash: DashComponent`, `health: HealthComponent`, `config: PlayerAnimationConfig`.
- **La lógica de estados está separada de la animación:**
  - `static func next_locomotion(current: Locomotion, on_floor: bool, horizontal_speed: float, rising: bool, clip_finished: bool, config: PlayerAnimationConfig) -> Locomotion` es pura y testeable.
  - Un mapa constante `Locomotion → StringName` da el nombre de cada clip (las constantes estructurales están permitidas).
- **`enum Locomotion { IDLE, RUN, RUN_STOP, JUMP_START, AIR, LAND }`**, con estas reglas:
  - **En el piso:**
    - Velocidad horizontal mayor que `config.run_speed_threshold` → `RUN`.
    - Si no la supera y veníamos de `RUN` → `RUN_STOP`, que al terminar el clip pasa a `IDLE`.
    - Si no, `IDLE`. El movimiento corta `RUN_STOP` y `LAND` y pasa a `RUN`.
  - **Salto:** al despegar subiendo (`velocity.y > 0` y sin piso) → `JUMP_START`. Al terminar el clip → `AIR`. Si deja el piso sin saltar (cae de un borde) → `AIR` directo.
  - **Aterrizaje:** de `JUMP_START` o `AIR` al tocar el piso → `LAND`. Al terminar el clip → `IDLE` o `RUN`.
  - "Clip terminado" sale de `humanoid.anim.animation_finished`.
- **Prioridad cada cuadro**, de mayor a menor:
  1. **Golpe del combo en curso:** no se piden clips de locomoción (el clip de ataque lo pide `AttackComponent` a través de `play_attack()`).
  2. **`hit`**, mientras dure el clip.
  3. **Dash:** `run`.
  4. **Casteo, carga, tajo aéreo o agarre:** `idle`. Esas acciones tienen sus poses de arma propias (§2.6).
  5. **Locomoción.**
- **`hit`:** con `health.damaged` (el daño absorbido por la invulnerabilidad no lo emite), si no hay un golpe del combo en curso ni un casteo. Es solo visual: no aturde ni corta nada.
- **API:**
  - `play_attack(clip: StringName, speed: float) -> void`: fija `humanoid.anim.speed_scale = speed` y reproduce el clip.
  - Al volver a locomoción, `speed_scale` vuelve a `1`.

### 2.4 Combo del ataque básico (`AttackComponent`, reescrito)

- **Nuevos exports:**
  - `humanoid: LowPolyHumanoid`: solo para escuchar `hit_window`, `combo_window_opened` y `attack_finished`, la fuente de los tiempos.
  - `animator: PlayerAnimator`.
  - `combo: AttackComboConfig`.
  - Se quita `sword_swing` (el ataque básico ya no barre).
- **Estados:** `enum ComboState { READY, STRIKING, CHAIN_OPEN }` más el índice del golpe actual.
- **`request_attack() -> void`:** la llama `Player` con `is_just_pressed(ACTION_ATTACK)`. Carga el buffer con `combo.input_buffer` (0.15 s).
- **Cada cuadro:**
  - Se descuenta el buffer.
  - Si el buffer está activo y el estado es `READY` o `CHAIN_OPEN`, arranca el golpe siguiente: `attack_1` desde `READY`, y `(i + 1) % steps.size()` desde `CHAIN_OPEN`, así que después de `attack_3` vuelve a `attack_1`.
  - En `STRIKING`, el buffer espera hasta vencer.
- **Al empezar un golpe:**
  1. `_face_nearest_enemy()`, como hoy. Bloquea el giro hasta que termine el golpe.
  2. `animator.play_attack(step.animation, ATTACK_SPEED / combo.reference_attack_speed)`. Las mejoras de velocidad aceleran el combo, el Berserker (0.6) es más lento y el Samurái (1.6), más rápido.
  3. Emite `step_started`, al que `Player` conecta `attack_performed` (los enemigos lo leen como apertura, igual que hoy).
- **`hit_window(true)`:** `_strike(roll, step)` **una sola vez por golpe** (el flag `_struck_this_step` evita un doble golpe). Evalúa el sector lógico actual (rango, arco y `get_hit_padding()`) y aplica, igual que hoy, crítico, robo de vida y `enemy_hit` por enemigo, más `attacked(hit_count, total, crit)`. Cada enemigo del sector se golpea como máximo una vez por golpe. El daño se multiplica por `step.damage_multiplier` y el empuje por `step.knockback_multiplier`.
- **Transiciones:**
  - `combo_window_opened` → `CHAIN_OPEN`.
  - `attack_finished` → `READY` e índice 0, salvo que el golpe siguiente ya haya arrancado.
  - Al terminar el golpe se desbloquea el giro.
- **`cancel() -> void`:** vuelve a `READY` con índice 0 y vacía el buffer. Si `hit_window` todavía no se abrió, el golpe no hace daño. La llaman el dash (`Player._handle_dash`), el inicio de un casteo o del tajo aéreo, y `begin_hold()`.
- **Sin `humanoid`** (tests unitarios que arman un `AttackComponent` suelto): el golpe aplica el daño en el mismo cuadro y el estado vuelve a `READY` enseguida. Es el patrón de "sin coordinador, como antes" de `enemy-group-ai`, para que los tests de enemigos que usan `try_attack_with_roll()` sigan valiendo.
- **Movimiento durante el combo:** igual que hoy, no se frena. Solo se bloquea el giro hacia el enemigo.
- **Aire:** el Tajo aéreo del Berserker sigue teniendo prioridad sobre el combo en el aire (`_handle_air_slash` corre antes). Las otras clases pueden encadenar el combo en el aire y, al terminar, `PlayerAnimator` vuelve a `jump_air`.
- **`Player._handle_attack()`:** pasa de `is_pressed` + `try_attack()` a `is_just_pressed` + `attack.request_attack()`.

### 2.5 Arma de la clase en la mano (`WeaponMount`, nuevo componente)

- **`components/weapon_mount.gd`.** Exports: `pivot: Node3D` (`Visual/SwordPivot`), `humanoid: LowPolyHumanoid`, `sword_swing: SwordSwing`, `swing_player: AnimationPlayer`, `abilities: Array[AbilityComponent]`, `air_slash: AirSlashComponent`, `config: PlayerAnimationConfig`.
- **Cuándo manda la mano:** cuando ninguna habilidad castea ni carga, `SwingPlayer` no reproduce nada, `SwordSwing` está en `IDLE` y el tajo aéreo está inactivo. En ese caso, cada cuadro (`_process`, sin allocations) lleva `pivot.global_transform` a `mano.global_transform * grip`, donde el grip sale de `WeaponData.grip_position`/`grip_rotation` (nuevos, por arma).
- **Transición:** al recuperar el arma después de una habilidad, el pivot se mezcla hacia la mano durante `config.weapon_mount_blend` segundos.
- Durante las habilidades, el arma sigue sus animaciones actuales sin cambios.
- **Funda de la katana:** `WeaponData.sheath_position` es relativo a `Visual`. Con D1 la altura de la cadera se parece a la de la cápsula. Se verifica con una captura y se ajusta solo si hace falta, junto con `SheatheConfig.sheathed_*` y la animación `sheathe_slash` (trampa conocida del `CLAUDE.md`).

### 2.6 Qué se borra o queda sin uso

- **`SwingPlayer` no tiene animaciones de espada viejas sin uso.** `thrust`, `swift_strike` y `sheathe_slash` (y sus `_recover`) son de las habilidades y siguen en uso.
- **Lo que queda sin uso y se borra:**
  - la llamada `sword_swing.play()` del ataque básico y `AttackComponent._play_swing()`/`_swing_time()`;
  - el cooldown por `1 / ATTACK_SPEED` (ahora la cadencia la marca el combo);
  - el campo `SwordSwingConfig.swing_duration`, con su línea en los tres `*_swing_config.tres`. `SwordSwing.play()` sigue existiendo porque lo usa el corte del dash del Giro, con su duración propia.
- **Limitación aceptada:** durante las habilidades, la mano del humanoide no coincide con el arma (el humanoide hace `idle` y el arma sigue la animación del pivot). Adaptar cada habilidad al humanoide queda para specs futuras.

### 2.7 Estela del arma

- `WeaponTrail` suma `@export var attack: AttackComponent`. `_is_weapon_attacking()` también es verdadero durante un golpe del combo, y se conecta a `attack.step_started` y `attack.combo_ended`.

### 2.8 Game feel del impacto (`HitstopComponent`, nuevo)

> **Reemplazada** por `bdo-combat-feel.md`: la ralentización global pasa a ser un hit lag local por golpe.

- **`components/hitstop_component.gd`.** Exports: `attack: AttackComponent`, `camera: ThirdPersonCamera`, `config: HitstopConfig`.
- **Con `attack.attacked` y `hit_count > 0`:**
  1. `Engine.time_scale = config.time_scale` durante `config.duration` segundos **reales** (contados con `Time.get_ticks_usec()`, porque el `delta` está escalado). Después vuelve a `1`.
  2. `camera.shake(config.shake_strength)`.
- **Un golpe nuevo durante un hitstop** reinicia la duración, sin acumularla.
- **`time_scale` también vuelve a `1`** en `_exit_tree()` y al morir el jugador.
- **Alcance:** solo el combo básico, no las habilidades.

### 2.9 Resources nuevos (Principio III)

| Resource | Archivo | Campos (valor inicial) |
|---|---|---|
| `AttackComboStep` | sub-recursos de `attack_combo_config.tres` | `animation: StringName`, `damage_multiplier: float`, `knockback_multiplier: float` |
| `AttackComboConfig` | `data/player/attack_combo_config.tres` | `steps` = `attack_1` (0.35, 0.5), `attack_2` (0.35, 0.5), `attack_3` (0.62, 1.5); `reference_attack_speed` = 1.2; `input_buffer` = 0.15 |
| `PlayerAnimationConfig` | `data/player/player_animation_config.tres` | `run_speed_threshold` = 0.5 m/s; `weapon_mount_blend` = 0.1 s |
| `HitstopConfig` | `data/player/hitstop_config.tres` | `duration` = 0.06 s; `time_scale` = 0.05; `shake_strength` = 0.2 |
| `WeaponData` (campos nuevos) | `sword.tres`, `greatsword.tres`, `katana.tres` | `grip_position`, `grip_rotation`: se ajustan con capturas para que la empuñadura quede en la mano |

- Todos son **no mejorables**: son sensación de control, como `PlayerTuning`. El combo sigue escalando con los stats mejorables `DAMAGE`, `ATTACK_SPEED`, `ATTACK_RANGE`, `CRIT_*` y `LIFESTEAL`.
- Las poses y los tiempos de las animaciones (incluidos `hit_on`/`combo`/`end`) son **arte del asset**, como los keyframes de un `.glb` o de las animaciones de `player.tscn`, y viven en su script (ver §6).

### 2.10 Decisiones a confirmar

- **D1. Escala del humanoide (recomendado: ×1.333, cápsula de 1.8 m).** Todo lo que hoy está posicionado para un cuerpo de 1.8 m se diseñó con esa altura: el reposo del arma, las alturas del barrido y de las animaciones de habilidades, la funda, el corte de viento, el seguimiento de la cámara y el alcance y el agarre de los enemigos. Si escalo el modelo, todo eso sigue valiendo y el jugador no queda más bajo que los enemigos (1.8 m).
  - **Alternativa:** humanoide a 1.35 m y cápsula de 1.35 m, como pediste al principio. Obliga a re-posicionar todo lo anterior y a revisar los ataques enemigos contra un cuerpo más bajo. Sería bastante más trabajo y más riesgo de romper algo.
- **D2. Balance del combo (recomendado: multiplicadores 0.35 / 0.35 / 0.62).**
  - A velocidad 1, encadenando en cada ventana de combo, un ciclo completo dura 0.24 + 0.26 + 0.60 = 1.10 s por 3 golpes.
  - Con `speed = ATTACK_SPEED / 1.2`, el daño por segundo vale `ATTACK_SPEED × DAMAGE × Σm / 1.32`. Con `Σm = 1.32`, **iguala el DPS de hoy en las tres clases**.
  - Los golpes individuales muestran números más chicos, pero el golpe final pesa casi el doble que los otros dos.
  - **Alternativa:** 1 / 1 / 1.5 hace unas 2.65× más DPS. Habría que rebalancear la vida de enemigos y bosses.

## 3. Criterios de aceptación (reservados al empezar la implementación)

- **AC590** `assets/models/characters/low_poly_humanoid/` tiene `low_poly_humanoid.gd`, `humanoid_demo.gd` y `SOURCE.md`, y la raíz ya no los tiene. El script compila con la configuración de warnings del proyecto. Sus poses, tiempos de clip y eventos (`hit_on`, `hit_off`, `combo`, `end`) no cambiaron.
- **AC591** `player.tscn` tiene `Visual/Humanoid` (instancia de `entities/player/humanoid.tscn`) y no tiene `Visual/Body`. El humanoide usa `player_material.tres` (blanco `Color(1, 1, 1)`) en todas sus mallas visibles, no tiene espada propia ni `Area3D`, y no crea materiales por instancia.
- **AC592** El `CollisionShape3D` es una `CapsuleShape3D` con base en los pies, y su alto coincide con el del humanoide escalado (±0.1 m). Con D1: radio 0.4, alto 1.8.
- **AC593** En el piso, con velocidad horizontal mayor que `run_speed_threshold`, suena `run`, y sin superarla, `idle`. Al frenar después de correr suena `run_stop` y, al terminar el clip, `idle`. Moverse durante `run_stop` pasa a `run`.
- **AC594** Al saltar suena `jump_start`, después `jump_air` mientras está en el aire y `jump_land` al tocar el piso, y luego locomoción. Al caer de un borde sin saltar suena `jump_air` directamente.
- **AC595** Al moverse, `Visual` gira hacia la dirección de movimiento interpolando con `turn_speed`. `Humanoid` conserva rotación local cero y la rotación del `CharacterBody3D` no cambia.
- **AC596** Un toque de ataque hace `attack_1`. Otro toque en la ventana de combo encadena `attack_2`, después `attack_3` y después `attack_1`. Si no hay toque, al emitirse `attack_finished` vuelve a locomoción y el próximo toque es `attack_1`.
- **AC597** Un toque hasta `input_buffer` (0.15 s) antes de que se abra la ventana de combo encadena el golpe siguiente, y uno 0.2 s antes no. Mantener el botón apretado sin soltarlo hace un solo golpe.
- **AC598** Durante un golpe del combo no suena ningún clip de locomoción, aunque el jugador se mueva, aterrice o deje de moverse.
- **AC599** El daño se aplica cuando se abre `hit_window`, no antes. Cada enemigo dentro del sector (`ATTACK_RANGE` + padding, `ATTACK_ARC`) recibe un solo golpe por golpe del combo, con `DAMAGE × damage_multiplier`, crítico, robo de vida y empuje × `knockback_multiplier`. Un enemigo fuera del sector no recibe daño.
- **AC600** La velocidad de los clips de ataque es `ATTACK_SPEED / reference_attack_speed`: 1.0 con el guerrero, 0.5 con el berserker y 1.33 con el samurái. Una mejora de velocidad de ataque la sube.
- **AC601** A stats base, encadenando el combo completo sin pausas, el daño por segundo de cada clase queda a ±10 % de `ATTACK_SPEED × DAMAGE` (el DPS de hoy).
- **AC602** Un dash, el inicio de un casteo o del tajo aéreo, o un agarre cortan el golpe en curso: si `hit_window` no se abrió, no hay daño, y el próximo toque es `attack_1`.
- **AC603** Fuera de las habilidades, el arma de la clase sigue la mano derecha: la empuñadura queda a ≤ 0.05 m de `mano × grip` en locomoción y durante el combo. Durante una habilidad, el pivot sigue sus animaciones actuales, y al terminar vuelve a la mano en `weapon_mount_blend` segundos.
- **AC604** La estela del arma se emite durante cada golpe del combo y deja de emitirse al terminar.
- **AC605** Al recibir daño, sin un golpe del combo ni un casteo en curso, suena `hit`. Un golpe absorbido por la invulnerabilidad no reproduce `hit`.
- **AC606** *(Reemplazado por AC619–AC623 de `bdo-combat-feel.md`.)* Un golpe del combo que impacta al menos a un enemigo pone `Engine.time_scale = time_scale` durante `duration` segundos reales, lo devuelve a `1` y sacude la cámara con `shake_strength`. Un golpe al aire no hace hitstop. `time_scale` vuelve a `1` si el jugador muere o sale del árbol durante un hitstop.
- **AC607** Los valores de §2.9 están en sus `.tres`, y los scripts nuevos o reescritos no tienen literales de diseño.
- **AC608** Con el Berserker en el aire, el ataque sigue lanzando el Tajo aéreo y no el combo. Con el guerrero en el aire, el combo suena y al terminar vuelve `jump_air`.
- **AC609** `Player.attack_performed` se emite al empezar cada golpe del combo.
- **AC610** Regresión:
  - suite completa en verde (salvo los fallos previos ajenos registrados en `dash-iframes.md`);
  - import sin errores;
  - smoke test del arena con las tres clases sin errores ni warnings nuevos en la consola.

**Próximo libre después de esta spec: AC611.**

## 4. Plan de implementación

Cada paso deja el proyecto abriendo y jugable.

1. **Reserva y enmienda:** reservar AC590–AC610 en `CLAUDE.md` (próximo libre → AC611) y aplicar la enmienda MINOR 4.9.0.
2. **Asset:** mover los dos scripts a `assets/models/characters/low_poly_humanoid/`, tiparlos, agregar `body_material`/`accent_material`/`weapon_material`, `use_hitbox` y `get_right_hand()`, y escribir `SOURCE.md`. Import en la copia: 0 errores. Copiar de vuelta los `.uid`.
3. **Adaptadora y escena:** crear `entities/player/humanoid.tscn`, agregar `Visual/Humanoid` (D1), borrar `Visual/Body` y apuntar `ChargeFeedback.body` al humanoide. El juego ya se ve con el humanoide en `idle`.
4. **Resources:** `AttackComboStep`, `AttackComboConfig`, `PlayerAnimationConfig` y `HitstopConfig`, con sus `.tres`. `WeaponData.grip_*`.
5. **`WeaponMount`:** el arma en la mano, con la katana y la funda verificadas con una captura. Ajustar `grip_*` de las tres armas.
6. **`PlayerAnimator`:** locomoción, salto, dash, casteo y `hit`.
7. **Combo:** reescribir `AttackComponent`, cambiar `Player._handle_attack()`, agregar las llamadas a `cancel()` y conectar `step_started` a `attack_performed`. Estela conectada al combo. Borrar `swing_duration` de `SwordSwingConfig` y de sus `.tres`.
8. **`HitstopComponent`** en `player.tscn`.
9. **Tests:**
   - nuevos, de AC590 a AC609;
   - adaptar `attack_component_test` (la cadencia por cooldown pasa al combo), `sweep_timing_test` (el barrido del ataque básico se borra; lo que sigue vigente del Giro se conserva), `weapon_trail_test` (estela en el combo), `berserker_run_test` y `stats_rework_test` si leen `swing_duration` o mantienen el ataque;
   - revisar los tests de nivel que usan "mantener ataque".
   Cada test adaptado se anota en §7.
10. **Cierre:** import, tests, smoke test del arena con las tres clases, capturas de locomoción, combo, arma en la mano y funda, review de la constitución y estado **Implementada**.

## 5. Tests

- **Unitarios, sin escena completa:**
  - `next_locomotion()` (AC593, AC594);
  - el combo y el buffer con un `LowPolyHumanoid` real avanzando frames (AC596–AC600, AC602);
  - el `HitstopComponent`, que reinicia `Engine.time_scale` en `after_test` (AC606).
- **De nivel (`test/levels/`):** las tres clases en el arena (AC601, AC603, AC604, AC608, AC610).

## 6. Enmienda propuesta: MINOR 4.9.0

- **Principio II, nueva viñeta: personaje procedural (desde 4.9.0).**
  - El cuerpo del jugador puede ser `LowPolyHumanoid`: un asset de script que vive en `assets/models/characters/low_poly_humanoid/` con su `SOURCE.md`.
  - Construye sus mallas (`ArrayMesh` con normales planas) y su `AnimationPlayer` **una vez**, en `_ready`, y se usa solo a través de su escena adaptadora (`entities/player/humanoid.tscn`).
  - Sus materiales vienen de `.tres` compartidos.
  - Las poses y los tiempos de sus animaciones son datos del asset, como los keyframes de un `.glb`. Los valores de gameplay que dependen de ellos (multiplicadores, buffer, velocidad de referencia) viven en Resources.
- **Tabla de colores:** la fila "Jugador (cuerpo)" pasa de `CapsuleMesh` a "Humanoide low-poly (`LowPolyHumanoid`)", sigue en blanco `Color(1, 1, 1)`, y se aclara que las manos y los pies flotantes son parte de la misma silueta. En el párrafo del blanco compartido, "una cápsula opaca" pasa a "un cuerpo opaco".
- **Por qué MINOR:** agrega una excepción acotada a la viñeta "mallas procedurales solo para VFX", igual que la 4.5.0 con las mallas de los avisos. No elimina ni redefine un principio.
- **Alternativa conforme descartada:** exportar el humanoide a `.glb` (formato preferido). Hoy no hay Blender en el flujo y el modelo no tiene esqueleto. Si más adelante se exporta, la escena adaptadora aísla el cambio.

## 7. Notas de implementación

- **Grip de cada arma** (unidades locales de la mano; la mano está escalada ×1.333, así que el desplazamiento real es `1.333 × grip`): espada `(0, -0.04, -0.19)`, mandoble `(0, -0.04, -0.1)`, katana `(0, -0.04, 0.04)`, sin rotación. Se eligieron midiendo el AABB de cada modelo (pomo en +Z, hoja en −Z) y con capturas, para que la mano quede sobre el mango. La funda de la katana no se tocó: con D1 queda a la altura de la cadera, como antes.
- **Eventos de las animaciones:** el `AnimationPlayer` del humanoide llama sus pistas de método en modo diferido (el default de Godot). Por eso `AttackComponent`:
  - ignora eventos de un clip que ya no suena (`_is_current_clip_playing()`);
  - termina el golpe con `animation_finished` en el mismo cuadro;
  - tiene una red de seguridad por si el clip se corta sin su evento `end`.

  `PlayerAnimator` pide el clip siguiente dentro de `animation_finished`, así un clip de un solo uso nunca deja un cuadro sin animación.
- **`SwordSwing.is_active()`** es nuevo: `WeaponMount` no toma el arma mientras el barrido o su recuperación estén activos.
- **`Hitstop`** tiene `process_mode = ALWAYS`, para devolver `time_scale` aunque se abra una pantalla que pausa el juego.
- **Tests nuevos:**
  - `attack_component_test` (AC596–AC602, AC609 y AC227 adaptado);
  - `player_animator_test` (AC593–AC595, AC598, AC605, AC608);
  - `weapon_mount_test` (AC603);
  - `weapon_trail_test` (AC604);
  - `hitstop_test` (AC606);
  - `humanoid_model_test` (AC590–AC592, AC607).

  AC610 son las corridas de abajo. El helper `test/helpers/combo_driver.gd` avanza los clips a mano, con pistas de método inmediatas. `unit_combo()` pone los multiplicadores en 1, para que los tests viejos de daño conserven sus números.
- **Tests adaptados** (verifican lo mismo, salvo donde la regla cambió):
  - **AC8–AC10** (`attack_component_test`): cada ataque es un golpe completo del combo con multiplicador 1. "El segundo ataque durante el cooldown se rechaza" pasa a "durante el golpe en curso".
  - **AC224–AC226** (`sweep_timing_test`, borrado): el ataque básico ya no barre. Los reemplazan AC600 y AC601. AC227 se movió a `attack_component_test`: el bloqueo de giro dura todo el golpe.
  - **AC89–AC93** (`sword_swing_test`): el barrido se lanza con `SwordSwing.play()` directo, que es como lo usa el Giro.
  - **AC215/AC217** (`weapon_trail_test`): la estela se enciende con el golpe del combo, y la punta se mueve porque el clip mueve la mano.
  - **AC187 y AC222** (`berserker_run_test`): golpes a la mitad de velocidad, y el arco de 150° verificado en el hitbox.
  - **AC52 y AC78:** tras el casteo hay que volver a tocar ataque (mantener ya no repite).
  - **AC264:** el temblor de carga mueve `Visual/Humanoid`.
  - **AC32/AC33, AC142/AC143, AC149, AC36 y AC230:** usan `combo_driver` con combo unitario.
- **Fallos previos y ajenos** (fallan igual en `HEAD` sin esta spec; verificado con una corrida en una copia de `HEAD`):
  - AC188 (`spin_test`), AC578 (`air_slash_test`), AC211 (`weapon_reach_test`), AC221 (`berserker_run_test`), AC236 (`samurai_run_test`).
  - Todos por datos cambiados fuera de sus specs.
- **Advertencia de tipado del asset:** el script compila con la configuración del proyecto. El editor puede mostrar avisos `unsafe_*` (nivel warning, no error) en sus accesos a arrays sin tipo; se dejaron así para no reescribir la lógica de poses del asset.

### Review de la constitución (cierre)
- **I:** combate. El combo con ventana y buffer, el hitstop y la silueta animada hacen el pelear más legible y expresivo.
- **II:** el humanoide vive en `assets/models/characters/low_poly_humanoid/` con `SOURCE.md` y escena adaptadora. Usa `player_material.tres` (blanco), sin materiales por instancia ni shaders. Enmienda 4.9.0 aplicada.
- **III:** multiplicadores, buffer, velocidad de referencia, umbral de carrera, mezcla del arma, hitstop y grips están en `.tres`. Las poses y los tiempos de los clips son datos del asset (4.9.0). No se muta ningún Resource compartido: el helper de tests duplica el combo.
- **IV:** tipado estricto en todo lo nuevo y en el asset. `_physics_process` y `_process` delegan en `update()`/`advance()`.
- **V:** sin allocations ni búsquedas de nodos por frame (el `Array` de clips es constante). El humanoide se construye una vez, sin `Area3D` (`use_hitbox = false`). El daño sigue siendo un cálculo de distancia.
- **VI:** solo acciones del InputMap (`attack` con `is_just_pressed`).
- **Calidad:** import y smoke tests sin errores. Tests de la spec en verde; los fallos restantes son previos y ajenos.
