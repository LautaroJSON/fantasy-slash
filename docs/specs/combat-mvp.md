# Feature: MVP del core loop de combate

- **Estado:** Implementada (2026-09-25, 73 tests GdUnit4 en verde)
- **Constitución:** `docs/constitution.md` v2.0.0
  - *Revisión (2026-09-25):* crítico 5 % (×19 cartas hasta 100 %), daño crítico como bonus +100 % (×14 hasta 300 %, `max_crit_damage`), robo de vida 0 %, dash 1.5 s / 3.0 m; sin cartas de arco, dash, invencibilidad ni salto. Ver `stats-rework.md`.
  - *Revisión (2026-09-25):* `swing_duration` pasó de `PlayerTuning` a `SwordSwingConfig` (por clase) y se escala con la velocidad de ataque. Ver `class-sweep-timing.md`.
  - *Revisión v3.0.0:* la espada `BoxMesh` negra (`sword_material.tres`) fue reemplazada por el modelo Spartan sword. Ver `weapon-models.md`.
- **Pilares (Principio I):** Combate (ataque, dash, salto), Supervivencia (daño recibido, defensa, robo de vida, game over), Progresión (mejoras por oleada).
- **Plataforma e input:** PC, solo teclado y mouse (Principio VI).
- **Dependencias:** ninguna. GdUnit4 instalado para los tests (paso 0).

## 1. Objetivo

Un loop jugable en una arena cerrada: el jugador se mueve con cámara orbital, ataca automáticamente al enemigo vivo más cercano, esquiva con dash e iframes y salta. Pelea contra oleadas infinitas de 5 enemigos. Al limpiar una oleada elige 1 de 3 mejoras de stats distintos. Al morir, la run se reinicia completa. ESC pausa y muestra un resumen de solo lectura.

Se entrega en 4 bloques jugables (§6). Cada bloque se cierra con aviso al responsable antes de empezar el siguiente.

## 2. Estructura

### 2.1 Carpetas y archivos

```
res://
├── data/                              # instancias .tres (valores de diseño)
│   ├── player/player_stats.tres       # PlayerStats (stats mejorables, valores iniciales)
│   ├── player/player_tuning.tres      # PlayerTuning (sensación de control)
│   ├── player/camera_config.tres      # CameraConfig
│   ├── enemies/grunt_stats.tres       # EnemyStats
│   ├── combat/combat_rules.tres       # CombatRules (topes y pisos)
│   ├── waves/wave_config.tres         # WaveConfig
│   ├── upgrades/                      # 15 × UpgradeData + upgrade_catalog.tres
│   └── ui/stat_display_table.tres     # StatDisplayTable (nombre y formato de cada stat)
├── materials/                         # StandardMaterial3D compartidos
│   ├── player_material.tres           # Color(1, 1, 1)       blanco
│   ├── sword_material.tres            # Color(0, 0, 0)       negro
│   ├── enemy_material.tres            # Color(0.5, 0.5, 0.5) gris
│   ├── floor_material.tres            # Color(0.24, 0.30, 0.22) verde oscuro
│   └── wall_material.tres             # Color(0.45, 0.30, 0.20) marrón
├── resources/                         # scripts de Resource (solo datos)
│   ├── player_stats.gd  player_tuning.gd  camera_config.gd
│   ├── enemy_stats.gd   combat_rules.gd   wave_config.gd
│   ├── upgrade_data.gd  upgrade_catalog.gd
│   └── stat_display.gd  stat_display_table.gd
├── combat/damage_math.gd              # funciones estáticas puras
├── components/                        # nodos reutilizables
│   ├── health_component.gd  stats_component.gd  movement_component.gd
│   ├── dash_component.gd    attack_component.gd
│   └── camera/third_person_camera.tscn + .gd
├── entities/
│   ├── player/player.tscn + player.gd
│   └── enemy/enemy.tscn + enemy.gd
├── systems/
│   ├── enemy_registry.gd  enemy_pool.gd  wave_manager.gd  run_state.gd
│   └── upgrade_offer.gd               # selección pura de 3 cartas
├── ui/ hud.tscn  upgrade_picker.tscn  pause_menu.tscn  game_over_screen.tscn (+ .gd)
├── levels/arena/arena.tscn            # escena principal
└── test/                              # GdUnit4, espejo de lo anterior
```

### 2.2 Resources (datos, Principio III)

Ningún valor de diseño vive en código, ni siquiera como default de un `@export`. Todos salen de estos `.tres`.

**`PlayerStats`: los 15 stats mejorables del jugador, con su valor inicial**

`enum Stat` y `get_base(stat: Stat) -> float`.

| # | `Stat` | Campo | Inicial | Mejora por carta |
|---|---|---|---|---|
| 1 | `DAMAGE` | `damage` | 15 | +4 |
| 2 | `DEFENSE` | `defense` | 3 | +2 |
| 3 | `MAX_HEALTH` | `max_health` | 100 | +20 |
| 4 | `CRIT_CHANCE` | `crit_chance` | 0.15 | +0.05 |
| 5 | `CRIT_DAMAGE` | `crit_damage` | 1.5 | +0.25 |
| 6 | `ATTACK_SPEED` | `attack_speed` (golpes/s) | 1.2 | +0.15 |
| 7 | `ATTACK_RANGE` | `attack_range` (m) | 2.0 | +0.3 |
| 8 | `LIFESTEAL` | `lifesteal` | 0.10 | +0.03 |
| 9 | `DAMAGE_BONUS` | `damage_bonus` | 0.0 | +0.10 |
| 10 | `MOVE_SPEED` | `move_speed` (m/s) | 6.0 | +0.5 |
| 11 | `JUMP_VELOCITY` | `jump_velocity` (m/s) | 4.5 | +0.5 |
| 12 | `DASH_DISTANCE` | `dash_distance` (m) | 3.6 | +0.6 |
| 13 | `IFRAME_DURATION` | `iframe_duration` (s) | 1.0 | +0.1 | *(Reemplazado por `dash-iframes.md`: la invulnerabilidad dura lo que el dash y `IFRAME_DURATION` ya no existe.)*
| 14 | `DASH_COOLDOWN` | `dash_cooldown` (s) | 2.0 | −0.15 (mejora = baja) |
| 15 | `ATTACK_ARC` | `attack_arc_degrees` | 120 | +15 |

**Otros Resources (datos no mejorables)**

| Resource | Campos (`@export`) y valores iniciales |
|---|---|
| `PlayerTuning` | Sensación de control: `acceleration 40` · `deceleration 50` · `turn_speed 12` · ~~`dash_duration 0.2`~~ (reemplazado por el stat `dash_speed`, ver `dash-speed.md`) · `swing_duration 0.25` |
| `CameraConfig` | `follow_offset (0,1.5,0)` · `spring_length 5.0` · `mouse_sensitivity 0.003` · `min_pitch_deg -60` · `max_pitch_deg 30` · `invert_y false` |
| `EnemyStats` | `damage 8` · `defense 0` · `max_health 40` · `attack_interval 1.0` · `attack_range 2.0` · `move_speed 3.5` |
| `CombatRules` | `min_damage_after_defense 1.0` · `max_crit_chance 1.0` · `max_attack_arc_degrees 360` · `min_dash_cooldown_gap 0.5` (el cooldown efectivo nunca baja de `iframe_duration + gap`) |
| `WaveConfig` | `enemies_per_wave 5` · `pool_size 5` · `spawn_half_extent 12.0` · `min_spawn_distance 6.0` · `spawn_attempts 30` (intentos por enemigo para cumplir la distancia mínima) · `cards_per_offer 3` |
| `UpgradeData` | `stat: PlayerStats.Stat` · `amount: float` (puede ser negativo) · `title: String` (nombre del stat en la carta) · `description: String` (cambio con signo, p. ej. "+4 de daño") |
| `UpgradeCatalog` | `upgrades: Array[UpgradeData]` (una por stat, 15 en total) |
| `StatDisplay` | `stat` · `label` · `format` (estilo printf, p. ej. `"%.0f %%"`) · `multiplier` (100 para fracciones que se muestran como %) · `format_value(value) -> String` |
| `StatDisplayTable` | `rows: Array[StatDisplay]` (orden de la pausa; una fila por stat) |

**Regla de runtime:** ningún `.tres` se muta. El estado de la run (mejoras, vida actual, oleada, kills) vive en nodos. Por eso recargar la escena reinicia todo.

### 2.3 Fórmulas (`DamageMath`, funciones estáticas puras)

- `outgoing(damage, bonus, is_crit, crit_mult) -> float` = `damage × (1 + bonus) × (crit_mult si is_crit, si no 1)`
- `mitigate(raw, defense, min_damage) -> float` = `max(raw − defense, min_damage)`
- `roll_crit(chance, roll) -> bool` = `roll < chance` (`roll` se inyecta para poder testearlo)
- Robo de vida: `heal = daño_aplicado × lifesteal`. El daño aplicado es la vida que realmente perdió el enemigo, sin contar overkill.

Chequeo con los valores base: 15 → 3 golpes (15/30/45) contra 40 de vida. Con 1 crítico (22.5) → 2 golpes. El enemigo le hace al jugador 8 − 3 = **5** por golpe, así que el jugador muere en 20 golpes.

### 2.4 Escenas

**`player.tscn`** (capa `player`, máscara `world`)
```
Player (CharacterBody3D) — player.gd
├── CollisionShape3D          CapsuleShape3D r 0.4 h 1.8
├── Visual (Node3D)           frente = −Z; rota hacia el movimiento o hacia el objetivo al atacar
│   ├── Body (MeshInstance3D) CapsuleMesh, player_material (blanco)
│   └── SwordPivot (Node3D)   a la altura del hombro derecho
│       └── Sword (MeshInstance3D)  BoxMesh 0.08×0.08×1.2, sword_material (negro)
├── SwingPlayer (AnimationPlayer)   animación "swing": rotación X de SwordPivot, de arriba hacia abajo
├── StatsComponent            base_stats → player_stats.tres, rules → combat_rules.tres
├── HealthComponent           rules → combat_rules.tres
├── MovementComponent         body, visual, stats, tuning
├── DashComponent             body, visual, health, stats, tuning
├── AttackComponent           visual, stats, registry, swing_player, movement, tuning, rules
└── CameraRig (ThirdPersonCamera)   target → Player, config → camera_config.tres
```

**`enemy.tscn`** (capa `enemies`, máscara `world | enemies`)
```
Enemy (CharacterBody3D) — enemy.gd, stats → grunt_stats.tres
├── CollisionShape3D          CapsuleShape3D r 0.4 h 1.8
├── Body (MeshInstance3D)     CapsuleMesh, enemy_material (gris)
└── HealthComponent
```

**`arena.tscn`** (escena principal)
```
Arena (Node3D)
├── WorldEnvironment + DirectionalLight3D (sin sombras)
├── Floor (StaticBody3D, world)       BoxMesh/BoxShape 30×1×30, floor_material
├── Walls (StaticBody3D, world) ×4    BoxMesh/BoxShape 30×3×1, wall_material
├── Player (instancia)
├── EnemyRegistry
├── EnemyPool          (bloque 3; en bloques 1-2 hay un Enemy colocado a mano)
├── WaveManager        (bloque 3)
├── RunState           (bloque 3)
└── UI (CanvasLayer): Hud · UpgradePicker · GameOverScreen · PauseMenu
```

### 2.5 Configuración del proyecto

- **Capas 3D:** `1 world` · `2 player` · `3 enemies`. El jugador **no colisiona con los enemigos**: puede atravesarlos con el dash y no queda atrapado. Los enemigos chocan entre sí para no apilarse.
- **InputMap (solo teclado y mouse, Principio VI):**

  | Acción | Binding |
  |---|---|
  | `move_forward` / `move_back` / `move_left` / `move_right` | W / S / A / D |
  | `attack` | Click izquierdo |
  | `dash` | Click derecho |
  | `jump` | Espacio |
  | `pause` | Esc |

  La cámara se mueve con el movimiento relativo del mouse (`InputEventMouseMotion`), leído solo dentro de `ThirdPersonCamera`. Es la excepción que prevé el Principio VI.
- **Renderer:** Forward+.
- **Tipado:** `untyped_declaration` = Error; `unsafe_*` = Warning.
- **Escena principal:** `levels/arena/arena.tscn`.

## 3. Interfaz pública

### 3.1 `HealthComponent` (Node, lo usan el jugador y el enemigo)
| Miembro | Firma |
|---|---|
| `@export` | `rules: CombatRules` |
| Propiedades | `max_health: float`, `current_health: float` (solo lectura), `defense: float`, `is_invulnerable: bool` |
| Señales | `health_changed(current: float, maximum: float)` · `died` (se emite una sola vez) |
| Métodos | `setup(max_hp: float, defense: float) -> void` · `receive_hit(raw: float) -> float` (devuelve el daño aplicado; 0 si es invulnerable o está muerto) · `heal(amount: float) -> void` (con tope en el máximo) · `set_max_health(value: float) -> void` (si sube, cura la diferencia) · `is_dead() -> bool` |

### 3.2 `StatsComponent` (Node)
| Miembro | Firma |
|---|---|
| `@export` | `base_stats: PlayerStats` · `rules: CombatRules` |
| Señal | `stats_changed` |
| Métodos | `get_stat(stat: PlayerStats.Stat) -> float` (lee un caché) · `add_upgrade(upgrade: UpgradeData) -> void` (suma al array y recalcula el caché una vez) · `get_upgrades() -> Array[UpgradeData]` |

Valor efectivo = base + suma de las mejoras de ese stat, con estos límites de `CombatRules`:
- `CRIT_CHANCE` ≤ `max_crit_chance`
- `ATTACK_ARC` ≤ `max_attack_arc_degrees`
- `DASH_COOLDOWN` ≥ `IFRAME_DURATION` efectivo + `min_dash_cooldown_gap` *(Reemplazado por `dash-iframes.md`: la invulnerabilidad dura lo que el dash y `IFRAME_DURATION` ya no existe.)*

El último límite garantiza siempre que no se pueda encadenar invencibilidad, aunque se suban los iframes o se baje el cooldown.

### 3.3 `MovementComponent` (Node)
`@export body: CharacterBody3D, visual: Node3D, stats: StatsComponent, tuning: PlayerTuning`
- `move(direction: Vector3, delta: float) -> void`: velocidad máxima = `MOVE_SPEED` efectivo.
- `jump() -> void`: `velocity.y = JUMP_VELOCITY` efectivo, solo si está en el suelo.
- `compute_velocity(current: Vector3, direction: Vector3, delta: float, on_floor: bool, max_speed: float) -> Vector3` es **pura**. Aceleración y desaceleración por `move_toward`; gravedad `ProjectSettings.physics/3d/default_gravity`.
- `face_direction_locked: bool`: mientras está activo, `move()` no rota `visual`. Lo usa el ataque.

### 3.4 `DashComponent` (Node)
`@export body, visual, health: HealthComponent, stats: StatsComponent, tuning: PlayerTuning` · señales `dash_started`, `dash_ready`
- `try_dash(direction: Vector3) -> bool`: falla si está en cooldown. Si la dirección es cero, usa el frente de `visual`.
- `is_dashing() -> bool` · `get_cooldown_remaining() -> float` · `get_cooldown_ratio() -> float` (0 = listo, 1 = recién usado; lo lee el Hud)
- `move_body(delta: float) -> void`: el Player lo llama en lugar de `MovementComponent.move()` mientras `is_dashing()`. El último paso se acorta para recorrer exactamente `DASH_DISTANCE`. Al terminar se anula el impulso horizontal, así el dash no sigue deslizando.
- `advance_timers(delta: float) -> void`: avanza iframes y cooldown. Lo llama `_physics_process` y también los tests.
- Durante `tuning.dash_duration` fija la velocidad horizontal en `dir × (DASH_DISTANCE / dash_duration)`, sin gravedad y sin input de movimiento. *(Reemplazado por `dash-speed.md`: la velocidad es el stat `DASH_SPEED` y la duración `DASH_DISTANCE / DASH_SPEED`.)*
- Desde el inicio del dash, `health.is_invulnerable = true` durante `IFRAME_DURATION` (1 s inicial). El cooldown (`DASH_COOLDOWN`, 2 s inicial) también cuenta desde el inicio. *(Reemplazado por `dash-iframes.md`: la invulnerabilidad dura lo que el dash y `IFRAME_DURATION` ya no existe.)*

### 3.5 `AttackComponent` (Node)
`@export visual, stats: StatsComponent, health: HealthComponent (para el robo de vida), registry: EnemyRegistry, swing_player: AnimationPlayer, movement: MovementComponent, tuning: PlayerTuning` · señal `attacked(hit_count: int, total_damage: float, was_crit: bool)`
- `try_attack() -> bool`: falla si `_cooldown > 0`. El cooldown es `1 / ATTACK_SPEED`. Delega en `try_attack_with_roll(crit_roll: float) -> bool`, que recibe el tiro de crítico inyectado para que los tests sean deterministas.
- `advance_cooldown(delta: float) -> void`: avanza el cooldown y el bloqueo de orientación. Lo llama `_physics_process` y también los tests.
- Al atacar:
  1. Busca el enemigo vivo más cercano con `registry.find_nearest(from)`, sin límite de distancia.
  2. Si existe, rota `visual` hacia él al instante y bloquea la rotación durante `swing_duration`.
  3. Reproduce "swing". Si el intervalo es menor que `swing_duration`, sube `speed_scale`.
     - *Reemplazado (2026-09-25, `sword-sweep.md`):* la animación vertical "swing" se sustituyó por un barrido horizontal procedural (`SwordSwing`) que cubre `ATTACK_ARC`. `AttackComponent` usa `sword_swing` en lugar de `swing_player`.
  4. **Hitbox lógica, sin Area3D (Principio V):** golpea a todos los enemigos vivos a distancia XZ ≤ `ATTACK_RANGE` y dentro de ±`ATTACK_ARC/2` del frente. Un solo tiro de crítico por swing.
  5. A cada uno le aplica `enemy.health.receive_hit(outgoing)` y después cura `Σ aplicado × LIFESTEAL`.
- El jugador se sigue moviendo durante el ataque. Mantener presionado `attack` repite el golpe al ritmo de la cadencia.

### 3.6 `ThirdPersonCamera` (Node3D, `top_level`)
`@export target: Node3D, config: CameraConfig`
- `rotate_camera(yaw_delta: float, pitch_delta: float) -> void` (pitch con límites) · `get_yaw() -> float` · `get_pitch() -> float`
- `to_world_direction(input: Vector2) -> Vector3` (conserva la longitud)
- `capture_mouse() -> void` · `release_mouse() -> void`
- Hijos: `SpringArm3D` (máscara `world`) → `Camera3D`. Mueve solo con el mouse, sin relación con la dirección de movimiento.

### 3.7 `Player` (`player.gd`, CharacterBody3D)
Solo orquesta (Principio IV). Lee las acciones del InputMap y delega:
```gdscript
func _physics_process(delta: float) -> void:
    _handle_jump()
    _handle_dash()
    _handle_movement(delta)
    _handle_attack()
```
`@export enemy_registry: EnemyRegistry` lo asigna el nivel, y el Player se lo pasa a `AttackComponent` en `_ready`. Así la escena del jugador no depende del nivel. En `_ready` también conecta `stats_changed` para actualizar `health.defense` y `health.max_health`. Expone `health: HealthComponent`, `stats: StatsComponent`, `dash: DashComponent` y la señal `died`.

### 3.8 `Enemy` (`enemy.gd`, CharacterBody3D)
`@export stats: EnemyStats, target: Player, registry: EnemyRegistry, start_active: bool` · señal `killed(enemy: Enemy)`
- `start_active`: si es true, el enemigo se activa solo en `_ready` (caso de un enemigo colocado a mano). Si es false, arranca desactivado y espera a que el pool lo active.
- Todos sus valores salen de `EnemyStats.tres`. Las mejoras de las cartas son del jugador y no afectan a los enemigos.
- `activate(at: Vector3, new_target: Player) -> void`: resetea la vida, se hace visible, habilita la colisión y el proceso, y se registra en el registry.
- `deactivate() -> void`: lo inverso y se desregistra. Así funciona el pooling.
- Comportamiento:
  - Si la distancia XZ al objetivo es mayor que `attack_range`, avanza hacia él a `move_speed` (con gravedad). El timer de ataque queda **congelado**, no se reinicia (cambio introducido por `combat-feedback.md`).
  - Si no, se detiene, mira al objetivo y acumula el timer. Cada `attack_interval` llama a `target.health.receive_hit(stats.damage)`. El timer vuelve a 0 solo en `activate()`, así que el primer golpe llega después de acumular un intervalo completo en rango. Si el jugador está invulnerable, el golpe hace 0.
- Al morir emite `killed` y se desactiva.

### 3.9 Sistemas
| Nodo | Interfaz |
|---|---|
| `EnemyRegistry` | `register(e)` (también se conecta a `e.killed`) · `unregister(e)` · `find_nearest(from: Vector3) -> Enemy` (null si no hay) · `get_active() -> Array[Enemy]` (no crea arrays nuevos) · `alive_count() -> int` · señales `enemy_killed(e)` y `all_dead` |
| `EnemyPool` | `@export enemy_scene: PackedScene, config: WaveConfig, registry: EnemyRegistry` · crea `pool_size` enemigos desactivados en `_ready` · `acquire() -> Enemy` (null + `push_error` si se agotó) · `available_count() -> int` · el enemigo vuelve solo al pool en `killed` |
| `UpgradeOffer` (RefCounted, puro) | `static pick(catalog: UpgradeCatalog, count: int, rng: RandomNumberGenerator) -> Array[UpgradeData]`: `count` mejoras de stats **distintos** |
| `RunState` | `wave: int` (empieza en 1) · `kills: int` · `add_kill()` · `next_wave()` · señal `changed` (la escucha el Hud) |
| `WaveManager` | `@export config, pool, registry, player, run_state, picker, catalog` · `start_wave()` · en `all_dead` → `_offer_upgrades()` · `_on_upgrade_chosen(u)` → `player.stats.add_upgrade(u)` → `run_state.next_wave()` → `start_wave()` |

**Spawn:** posición aleatoria dentro de ±`spawn_half_extent` en XZ, a una distancia de al menos `min_spawn_distance` del jugador. Usa un RNG reutilizado y reintenta si la posición no cumple la distancia.

### 3.10 UI (CanvasLayer)
- **Hud:** vida `actual/máx` (barra), oleada, indicador de dash listo o en cooldown.
- **UpgradePicker:** una carta por mejora ofrecida, con `title` y `description`. Cada carta es un duplicado de un botón plantilla de la escena, así el layout no queda en código. Durante la elección pausa el árbol (`process_mode = ALWAYS` en la UI) y libera el mouse. Al elegir despausa y recaptura. API: `show_offer(upgrades)` · `choose(upgrade)` (lo llaman los botones y los tests) · `is_open() -> bool` · `get_offered() -> Array[UpgradeData]` · señal `upgrade_chosen(u)`.
- **GameOverScreen:** "GAME OVER", "Oleada N · K enemigos eliminados" y botón **Reintentar**, que llama a `restart_run()`: despausa y hace `get_tree().reload_current_scene()`.
- **PauseMenu:** `pause` lo abre o cierra, salvo durante UpgradePicker o GameOver. Muestra los **15 stats efectivos**, formateados según `StatDisplayTable`, más la oleada y las kills, en solo lectura. Las filas se construyen una sola vez en `_ready`, duplicando labels plantilla, y los valores se refrescan al abrir. Al cerrar, con Esc o con el botón Reanudar, despausa y recaptura el mouse. API: `toggle()` · `open()` · `close()` · `is_open()` · `get_stat_row_count()` · `get_value_text(stat)` · `get_run_text()`.

## 4. Lógica de estado

```
[Oleada N activa] --all_dead--> [Eligiendo mejora (paused)] --upgrade_chosen--> [Oleada N+1 activa]
       │
       └──player died──> [Game Over (paused)] --Reintentar--> reload_current_scene (oleada 1, stats base, sin mejoras)
[cualquier estado jugable] --Esc--> [Pausa] --Esc/Reanudar--> [mismo estado]
```

## 5. Criterios de aceptación

**Bloque 1: movimiento, cámara y ataque**
- **AC1** `DamageMath.outgoing(15, 0, false, 1.5) == 15`; con crítico `== 22.5`; con bonus 0.1 y crítico `== 24.75`.
- **AC2** `mitigate(15, 0, 1) == 15`; `mitigate(8, 3, 1) == 5`; `mitigate(2, 5, 1) == 1`.
- **AC3** `roll_crit(0.15, 0.10) == true`; `roll_crit(0.15, 0.15) == false`.
- **AC4** `HealthComponent`: `receive_hit` con overkill devuelve solo la vida restante; `died` se emite una vez; `heal` no supera el máximo.
- **AC5** `StatsComponent`: sin mejoras, los 15 `get_stat` coinciden con los valores de `player_stats.tres`. Con 2 mejoras de DAMAGE (+4), da 23. `player_stats.tres` no cambia.
- **AC6** Límites: 20 mejoras de CRIT_CHANCE → `get_stat == max_crit_chance`. 20 mejoras de DASH_COOLDOWN → `get_stat == IFRAME_DURATION + min_dash_cooldown_gap` (1.5). Con +0.1 de IFRAME_DURATION, ese piso pasa a 1.6. *(Reemplazado por `dash-iframes.md`: la invulnerabilidad dura lo que el dash y `IFRAME_DURATION` ya no existe.)*
- **AC7** `EnemyRegistry.find_nearest` devuelve el enemigo activo más cercano y null si no hay ninguno.
- **AC8** `AttackComponent`: con enemigo a 1.5 m frente al jugador y `roll` sin crítico, un ataque le quita 15 de vida y cura al jugador 1.5. Un segundo `try_attack()` antes de `1/1.2` s devuelve false.
- **AC9** Un enemigo a 3 m (fuera de rango) no recibe daño. Un enemigo a 1.5 m a espaldas del objetivo (fuera del arco) tampoco. Con +3 mejoras de ATTACK_RANGE (2.9 m), el enemigo a 2.5 m sí recibe daño.
- **AC10** El enemigo de 40 de vida muere en 3 golpes sin crítico, emite `killed` y queda desactivado y fuera del registry.
- **AC11** `ThirdPersonCamera`: el pitch se mantiene dentro de los límites; con yaw 0, `to_world_direction((0,-1)) ≈ (0,0,-1)`.
- **AC12** `MovementComponent.compute_velocity`: acelera sin pasar `max_speed` y desacelera hasta 0 sin invertir el signo. Con +1 mejora de MOVE_SPEED, la velocidad máxima alcanzada es 6.5.
- *Manual:* WASD relativo a la cámara, mouse orbita, click ataca girando hacia el enemigo, se puede mover mientras ataca.

**Bloque 2: daño recibido, dash y salto**
- **AC13** Enemigo en rango: el jugador pierde 5 de vida después de 1.0 s y otros 5 a los 2.0 s. Fuera de rango, el enemigo avanza hacia él.
- **AC14** Después de `try_dash`, `is_invulnerable` es true durante `IFRAME_DURATION` (1.0 s) y los golpes hacen 0. Después vuelve a false. *(Reemplazado por `dash-iframes.md`: la invulnerabilidad dura lo que el dash y `IFRAME_DURATION` ya no existe.)*
- **AC15** `try_dash` durante el cooldown devuelve false. Después de `DASH_COOLDOWN` (2.0 s) devuelve true.
- **AC16** El dash recorre `DASH_DISTANCE` (3.6 m ± 0.1) en suelo plano sin obstáculos.
- **AC17** En el suelo, `jump()` da `velocity.y == JUMP_VELOCITY`. En el aire, `jump()` no hace nada.
- **AC18** Un jugador que cae desde y = 5 queda `is_on_floor()` en ≤ 2 s. Ni el jugador ni el enemigo atraviesan las paredes.

**Bloque 3: oleadas, mejoras y game over**
- **AC19** `start_wave()` activa exactamente 5 enemigos, todos a ≥ `min_spawn_distance` del jugador y dentro de la arena.
- **AC20** Al morir el 5.º enemigo se emite `all_dead`, el árbol se pausa y el picker muestra 3 cartas.
- **AC21** `UpgradeOffer.pick` devuelve 3 mejoras de stats distintos (de los 15) en 1000 corridas con semillas distintas.
- **AC22** Al elegir +4 Daño: `get_stat(DAMAGE) == 19`, `get_upgrades().size() == 1`, `run_state.wave == 2`, hay 5 enemigos activos y el árbol se despausa.
- **AC23** Al elegir +20 Vida: el máximo sube a 120 y la vida actual sube 20.
- **AC24** `kills` suma 1 por enemigo muerto a lo largo de varias oleadas.
- **AC25** Con vida 0 se muestra el Game Over. Después de Reintentar: oleada 1, kills 0, los 15 stats en su valor base, sin mejoras, vida 100.

**Bloque 4: pausa**
- **AC26** `pause` pausa el árbol, muestra los 15 stats efectivos, la oleada y las kills. Un segundo `pause` reanuda con posiciones y vidas idénticas.
- **AC27** `pause` no hace nada durante el picker o el Game Over.

## 6. Plan de implementación

0. **(Usuario)** Instalar GdUnit4 compatible con Godot 4.7 desde AssetLib y activar el plugin.
1. **Bloque 1**
   1. `project.godot`: capas, InputMap de teclado y mouse, warnings de tipado, escena principal (con el editor cerrado).
   2. Materiales `.tres` y scripts de Resource con sus `.tres` de datos.
   3. `DamageMath`, `HealthComponent`, `StatsComponent` → tests AC1-AC6 → implementar.
   4. `MovementComponent` sin salto y `ThirdPersonCamera` → AC11-AC12.
   5. `EnemyRegistry` y `Enemy` quieto (sin IA) → AC7.
   6. `AttackComponent` + animación de la espada negra → AC8-AC10.
   7. `player.tscn`, `arena.tscn` con un Enemy colocado a mano y Hud (vida). Correr, verificar que no haya errores y **avisar**.
2. **Bloque 2:** IA del enemigo (perseguir y atacar), `DashComponent`, salto, indicador de dash en el Hud. Muerte provisional: `levels/arena/arena.gd` recarga la escena, y el Bloque 3 lo reemplaza por el Game Over. Tests AC13-AC18. **Avisar.**
3. **Bloque 3:** `EnemyPool` (se quita el enemigo manual), `RunState`, `UpgradeData` + 15 `.tres` + catálogo, `UpgradeOffer`, `WaveManager`, `UpgradePicker`, `GameOverScreen`. Se elimina `levels/arena/arena.gd` (la muerte provisional). Tests AC19-AC25. El Reintentar con recarga real se verifica con un smoke test fuera de la suite, porque recargar la escena dentro del runner lo rompe. **Avisar.**
4. **Bloque 4:** `StatDisplay` + tabla `.tres`, `PauseMenu` → AC26-AC27. El ESC real (evento de teclado) se verifica con un smoke test fuera de la suite. Checklist de review de la constitución completo y spec marcada como **Implementada**.

## 7. Fuera de alcance

- Escalado de dificultad de los enemigos por oleada (con enemigos fijos, las oleadas infinitas se vuelven triviales).
- Mando y cualquier input que no sea teclado y mouse.
- Números de daño flotantes, feedback visual de crítico, golpe o invulnerabilidad, telegraph del ataque enemigo.
- Animaciones de muerte, sonido, meta-progresión, navmesh (la arena es abierta y la persecución es en línea recta).
