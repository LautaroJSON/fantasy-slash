# Feature: re-work de las habilidades del Guerrero (Carga de escudo y Parada)

- **Estado:** Propuesta (2026-09-27). ACs reservados: **AC801–AC850** (se usan AC801–AC846).
- **Constitución:** `docs/constitution.md` v4.16.0 → **enmienda MINOR** (Principios II, III y VII, ver §9). Toma la 4.17.0 si cierra antes que `affliction.md`; si no, la siguiente libre.
- **Pilar (Principio I):** **combate.**
  - Carga de escudo: una apertura que reposiciona. Llevarse enemigos contra una pared o contra otros enemigos premia leer el terreno y el grupo.
  - Parada: un riesgo con recompensa. Levantar el escudo a tiempo contra un golpe telegrafiado lo convierte en un contraataque. Las dos le dan al Guerrero una identidad de "tanque con escudo" que las habilidades viejas (una estocada y un golpe veloz) no tenían.
- **Dependencias:** `warrior-sword-and-shield.md` (escudo en `wrist_l`, AC751), `sheath-socket-hand-grip.md` y `sheathe-release-animation.md` (clip del cuerpo por habilidad, `holds_weapon_in_hand()`, cola libre de `PlayerAnimator`), `bdo-combat-feel.md` (hit lag local), `status-icons.md` (íconos), `unique-ability-upgrades.md` (mejoras únicas), `sprint-stamina.md` (estamina), `enemy-attack-telegraph.md` (preparaciones).
- **En paralelo:** `affliction.md` (rama `claude/affliction-spec`, AC851–AC900). Toca los mismos archivos (`DebuffData`, `DebuffComponent`, `Enemy`). Ver §8.

## 1. Decisiones del responsable (2026-09-27)

1. **Habilidades:** Carga de escudo y Parada, las dos **BASIC** (se elige una al empezar la run, como hoy).
2. **Ultimate:** por ahora **no hay**. El slot R sigue vacío; Caída del león queda fuera de esta spec.
3. **Aturdimiento en bosses: reducido.** Se aturden, pero la duración se multiplica por un factor de datos (`EnemyStats.stun_duration_scale`; bosses 0.3). En un boss, el aturdimiento **pausa** su comportamiento (la preparación sigue donde estaba al terminar) y no la cancela.
4. **Sin sistema de VFX por estado.** No se hacen `StatusVisuals`, ni la migración de Rage y Escudo, ni hooks de animación por tipo de enemigo. El aturdimiento se ve solo por su ícono y porque el enemigo se queda quieto. Entran solo las dos habilidades, **sus VFX** y un **feedback de impacto estándar** para las habilidades, igual al de los básicos: hit lag, sacudida de cámara y empuje.

## 2. Relevamiento (verificado sobre `main`, f2c7167)

| Pieza | Hoy | En esta spec |
|---|---|---|
| `data/classes/warrior/warrior_abilities.tres` | Estocada y Swift Strike (BASIC) | Carga de escudo y Parada |
| Estocada | `data/abilities/thrust/` (6 cartas y "Lacerante"), `components/abilities/thrust_ability.gd/.tscn` | **Se borra** |
| Swift Strike | `data/abilities/swift_strike/` (6 cartas, "Asesinato" y "Reset"), `components/abilities/swift_strike_ability.gd/.tscn` | **Se borra** |
| Clips `thrust`, `thrust_recover`, `swift_strike`, `swift_strike_recover` | `AnimationLibrary_sword` del `SwingPlayer` en `player.tscn` | **Se borran** (el Giro conserva los suyos) |
| `data/debuffs/bleed.tres` | Solo lo aplica Lacerante; varios tests lo usan como debuff genérico | **Se conserva** (lo usará Aflicción) |
| `PlayerAnimator.CLIP_BUSY = &"idle"` | Una habilidad sin clip deja el cuerpo en `idle` | Las dos habilidades tienen clips en `warrior_profile.gd` |
| `WeaponMount` | Deja de seguir la mano si hay `SwordSwing`/`SwingPlayer` activos; `holds_weapon_in_hand()` solo se consulta durante el lanzamiento | Las dos habilidades dibujan el golpe con el cuerpo. `holds_weapon_in_hand()` también vale durante la carga (la Parada se sostiene) |
| `HitstopComponent` | Solo escucha a `AttackComponent` | También escucha los golpes de habilidad (§4.4) |
| `WeaponTrail` | Emite durante todo el lanzamiento de una habilidad | Emite solo mientras la hoja barre (§4.5) |
| Daño al jugador | 9 llamadas `target.health.receive_hit(x)` en `melee`, `charger`, `harasser`, `leaper`, `boss` (×3) y `titan` (×2); sin dirección | `receive_hit_from(x, origen)` y un `ShieldGuard` en el jugador (§4.3) |
| Aturdimiento | No existe (hay empuje, hit lag y `EnemyAttackData.interruptible`) | `DebuffData.Effect.STUN`, `data/debuffs/stun.tres` y `Enemy.stun()` (§4.2) |
| Colisiones | Enemigos: capa 3 (valor 4), máscara mundo + enemigos (5). Jugador: capa 2, máscara solo mundo (1): **atraviesa a los enemigos** | La Carga arrastra empujando (knockback continuo), no con el cuerpo del jugador |
| `UltimateAbility` | Existe (R y botón en el HUD); nada la equipa | Sin cambios |

## 3. Qué se ve y cómo se juega

### 3.1 Carga de escudo (BASIC, tecla E)

1. Al apretar E, el Guerrero gira hacia el enemigo más cercano (Principio VII), marca en el piso el recorrido (rectángulo de `HIT_RANGE` × `HIT_WIDTH`, que se desvanece) y **avanza 5 m en 0.4 s** con el escudo adelante y levantando polvo.
2. Mientras avanza, **reduce 50 % el daño que viene de frente** (arco de 120°).
3. Los enemigos que toca el frente del escudo (una franja de 1.2 m delante) quedan **arrastrados**: van delante de él a la misma velocidad.
4. Al terminar el recorrido, o antes si choca contra una pared o alcanza a un enemigo que no se deja arrastrar (un Escudero en guardia, un boss), da un **golpe de escudo**: **12 + 10 % del daño** del jugador (sin crítico) a todos los que tiene delante (2 m × `HIT_WIDTH`), con un **empuje fuerte**. El golpe tiene hit lag, sacudida de cámara, destello de impacto y un anillo de polvo.
5. Durante los 0.6 s siguientes, cada enemigo empujado que **choca contra una pared** queda **aturdido 1 s**. Si **choca contra otro enemigo**, quedan aturdidos los dos. Lo mismo vale para un arrastrado que choca durante el avance.
6. Enfriamiento: **7 s**, desde que se aprieta la tecla. El dash corta la Carga en cualquier momento, y al cortarla suelta a los arrastrados.

**Mejoras únicas** (se ofrecen solo con la Carga equipada):

| Id | Nombre | Niveles | Efecto |
|---|---|---|---|
| `hammer_anvil` | **Martillo y yunque** | 1 | Cuando dos enemigos chocan, cada uno recibe el 50 % del daño de la Carga (con número de daño). |
| `momentum` | **Impulso** | 1 | Si el golpe de escudo alcanza a 3 o más enemigos, el enfriamiento que queda se reduce a la mitad. |
| `concussive` | **Contundencia** | 2 | El aturdimiento pasa de 1 s a 1.5 s (nivel 1) y a 2 s (nivel 2). |

*"Contundencia" reemplaza al nombre propuesto "Conmoción del escudo", porque "Conmoción" ya es un buff del Giro (ícono verde lima) y los dos se confundirían en la pausa y en las cartas.*

**Cartas de stats** (`AbilityUpgradeData`): daño (+4, ×5), escalado (+5 %, ×4), enfriamiento (−0.75 s, ×4; piso 3 s) y distancia (+1 m, ×3; el tiempo del avance no cambia, así que va más rápido).

### 3.2 Parada (BASIC, se mantiene E)

1. **Mantener E** levanta el escudo: bloquea el **100 % del daño frontal** (arco de 120°). Los golpes de atrás o de los costados pegan completos. Solo se puede levantar con al menos 10 de estamina.
2. Mientras sostiene, camina al 40 % de su velocidad mirando al enemigo más cercano y **gasta 25 de estamina por segundo**. Con la estamina en 0, el escudo baja solo, como si se soltara la tecla.
3. Cada golpe bloqueado da una chispa en el escudo y una sacudida leve. El jugador no recibe daño ni reproduce `hit`.
4. **Parada perfecta:** si un golpe frontal llega en los **primeros 0.25 s** desde que se levantó el escudo, se dispara una **estocada automática** hacia el atacante: **20 + 30 % del daño** (con crítico según los stats del jugador), en un rectángulo de 3 m × 1.2 m, que **aturde 1 s** y empuja. Tiene hit lag fuerte, sacudida, destello y estela de la espada solo mientras la hoja avanza. El jugador es invulnerable durante la estocada (0.5 s).
5. **Soltar E** baja el escudo (0.2 s). El enfriamiento de **4 s** arranca al soltar. Tras una parada perfecta queda en **1 s**. El dash durante el bloqueo cuenta como soltar.

**Mejoras únicas:**

| Id | Nombre | Niveles | Efecto |
|---|---|---|---|
| `retaliation` | **Represalia** | 1 | La estocada suma el 100 % del daño que tenía el golpe parado (antes de la defensa). |
| `bulwark` | **Muralla** | 1 | El primer segundo del bloqueo no gasta estamina. |
| `disarm` | **Desarme** | 3 | La estocada aplica Debilitar (`weaken.tres`): 5 / 7 / 10 % de defensa ignorada por stack, como "Rompe-armadura" del Giro. |

**Cartas de stats:** daño (+5, ×5), escalado (+10 %, ×4) y enfriamiento (−0.5 s, ×4; piso 1.5 s).

### 3.3 Aturdido

- Un enemigo aturdido **se queda quieto**: no camina, no gira y no ataca. Si estaba en una **preparación**, se cancela: se apaga su aviso en el piso y devuelve su turno de ataque. Un empuje que ya tenía **sigue deslizándolo**.
- Muestra el ícono **Aturdido** (`knocked_out_stars.svg`, `delapouite/knocked-out-stars`), con su reloj, en su fila de estados (`EnemyStatusOverlay`, o la barra del boss).
- Reaplicarlo mientras dura no suma: queda la duración más larga entre la que le quedaba y la nueva.
- **Bosses:** duración × `stun_duration_scale` (0.3: 1 s → 0.3 s). No se cancela su ataque; su comportamiento se pausa y sigue donde estaba.

## 4. Diseño

### 4.1 Estructura de nodos

```
Player (player.tscn)
├── HealthComponent                     guard = ShieldGuard (nuevo export, opcional)
├── ShieldGuard (ShieldGuard)           ← nuevo: bloqueo frontal (arco, reducción), señal blocked
├── BasicAbility / UltimateAbility      + exports stamina y guard
├── Hitstop (HitstopComponent)          + abilities: [BasicAbility, UltimateAbility]
├── AbilityImpactVfx (AbilityImpactVfx) ← nuevo: pool de destellos y chispas de impacto (tamaño fijo, creado al cargar)
└── (SwingPlayer › AnimationLibrary_sword pierde thrust*, swift_strike*)

components/abilities/shield_charge_ability.tscn   (ShieldChargeAbility)
├── Indicator (AbilityRectIndicator)
└── BashVfx (ShieldBashVfx)             ← polvo del avance y anillo del golpe

components/abilities/parry_ability.tscn            (ParryAbility)
└── BlockVfx (BlockSparkVfx)            ← chispas y destello en el escudo (pool)
```

Todos los VFX se crean una vez al cargar (Principio V) y se reposicionan.

### 4.2 Aturdimiento

**`DebuffData.Effect.STUN = 5`**, con **valor explícito**. `affliction.md` fija `SLOW = 4` (AC894), así el `effect = 5` guardado en `stun.tres` no cambia sea cual sea el orden de merge.

**`data/debuffs/stun.tres`:** `id = &"stun"`, `effect = 5`, `duration = 1.0` (la real la pasa quien lo aplica), `max_stacks = 1`, `icon = knocked_out_stars.svg`, `icon_color = Color(1.0, 0.95, 0.55)` (amarillo estrella, se registra en el Principio II), `is_beneficial = false`.

**`DebuffComponent`:**
- `apply(data, potency, duration: float = 0.0)`: con `duration > 0` usa esa duración en lugar de `data.duration`. Al refrescar un estado con duración propia, queda `max(le_quedaba, duration)`. Sin el parámetro, el comportamiento no cambia.
- `ActiveDebuff.duration`: la duración con la que se aplicó. `get_remaining_ratio()` la usa para que el reloj del ícono sea correcto con duraciones propias.
- `is_stunned() -> bool`: hay un estado `STUN` activo. Un `STUN` es temporizado (`_is_timed`) y no toca la defensa.

**`EnemyStats`:**
- `@export var stun_duration_scale: float = 1.0`. El default va en el script: un `.tres` que no lo escribe vale 1. Verdugo, Titán y Colmena: 0.3. Con 0, el enemigo es inmune (no recibe el estado).
- `@export var stun_cancels_attack: bool = true`. Los tres bosses: `false`.

**`Enemy`:**
- `stun(status: DebuffData, seconds: float)`: aplica `status` con `seconds × stun_duration_scale`. Si `stun_cancels_attack`, llama a `_behavior.stunned()`. No hace nada si el enemigo está muerto, apareciendo o si la duración escalada es ≤ 0.
- `is_stunned() -> bool` (delegado en `debuffs`).
- `_update_behaviour`: si está empujado, desliza (como hoy). Si no, y está aturdido, `stand_still()` y no actualiza el comportamiento. El hit lag sigue teniendo prioridad.
- `get_push_speed() -> float`: el largo de `_knockback`, para detectar choques (§5).

**`EnemyBehavior.stunned()`** (hook nuevo, vacío por defecto): los cinco comunes (`melee`, `charger`, `leaper`, `harasser`, `shieldbearer`) cancelan el ataque en curso como `_end_attack(false)`, sin importar `interruptible`: se apaga el aviso, se devuelve el turno y vuelven las manos al reposo. Los bosses no lo implementan (su `stun_cancels_attack` es `false`).

### 4.3 Bloqueo frontal: `ShieldGuard` y `receive_hit_from`

**`HealthComponent`:**
- `@export var guard: ShieldGuard` (opcional; los enemigos no lo tienen).
- `receive_hit_from(raw: float, source: Vector3) -> float`: si es invulnerable o está muerto, devuelve 0 sin avisar al guard. Si no, `raw = guard.absorb(raw, source)` cuando hay guard, y sigue como `receive_hit(raw)`. Un golpe bloqueado al 100 % no emite `damaged` (no hay flicker, `hit` ni sacudida de daño).
- `receive_hit(raw)` no cambia: lo siguen usando los golpes del jugador sobre los enemigos.

**Las 9 llamadas de los enemigos** pasan a `target.health.receive_hit_from(x, enemy.global_position)`. En la onda expansiva del Verdugo y en los golpes del Titán, el origen es la posición del boss. Los agarres (`begin_hold`) no pasan por aquí: **el escudo no bloquea un agarre**.

**`ShieldGuard extends Node`** (`components/shield_guard.gd`):
- `@export var visual: Node3D`: su −Z es el frente.
- `signal blocked(amount: float, source: Vector3)`: la parte absorbida, antes de la defensa.
- `raise(reduction: float, arc_degrees: float)`, `lower()`, `is_raised() -> bool`.
- `absorb(raw, source) -> float`: si está levantado y `is_in_front(...)`, emite `blocked(raw × reduction, source)` y devuelve `raw × (1 − reduction)`. Si no, devuelve `raw`.
- `static is_in_front(facing: Vector3, origin: Vector3, source: Vector3, arc_degrees: float) -> bool`: ángulo plano (XZ) entre `facing` y `source − origin` ≤ `arc/2`. Un origen en el mismo punto cuenta como de frente.

### 4.4 Feedback de impacto de las habilidades

**`StrikeFeel`** (`resources/strike_feel.gd`), uno por golpe de habilidad, dentro del config de cada habilidad:
- `hitlag: float`: segundos de pausa del clip del jugador y de congelamiento con temblor de los golpeados (`Enemy.apply_hitlag`; los bosses solo tiemblan, como hoy).
- `shake_strength: float`: sacudida de cámara.
- `impact_scale: float`: tamaño del destello de impacto sobre cada golpeado (0 = sin destello).

**`AbilityComponent`:**
- `signal struck(feel: StrikeFeel, enemies: Array[Enemy])`, emitida por `report_strike(feel, enemies)`, que los behaviors llaman **una vez por golpe** que alcanzó a alguien, después de sus `report_hit()`. El array es el buffer del behavior (sin copias).
- `report_hit()` no cambia: sigue dando números de daño, robo de vida si corresponde, y la carga de Aflicción de `affliction.md`.

**`HitstopComponent`** (generalizado, sigue siendo el único que pausa el clip):
- `@export var abilities: Array[AbilityComponent]`. En `struck`: `start(feel.hitlag)`, `camera.shake(feel.shake_strength)` si es > 0, y `apply_hitlag(feel.hitlag, config)` en cada enemigo.
- `start()` guarda la velocidad del clip al pausarlo, y `_resume()` la restaura. Para los básicos es la misma `get_clip_speed()` de hoy.
- Si el lanzamiento termina o se corta (`cast_released`) durante un hit lag de habilidad, este termina y el clip se reanuda.

**`AbilityImpactVfx`** (`components/abilities/ability_impact_vfx.gd`, en `player.tscn`): un pool de `impact_pool_size` destellos, cada uno una esfera blanca aditiva que crece y se apaga, más chispas `CPUParticles3D` *one-shot*. Escucha `struck` de las dos ranuras y dispara uno por enemigo, en su centro, con `feel.impact_scale`. Si el pool está lleno, reutiliza el más viejo. Config: `data/player/ability_impact_vfx_config.tres` (`AbilityImpactVfxConfig`: tamaño del pool, radio, duración, alpha ≤ 0.5, cantidad y velocidad de chispas). Material compartido: `materials/vfx/ability_impact_material.tres`. Sirve para cualquier clase: el Giro y Envainar pueden sumarse después poniendo su `StrikeFeel` (fuera de alcance).

**Empuje:** cada golpe de habilidad sigue empujando con `Enemy.apply_knockback` y la velocidad de su config (`bash_knockback_speed`, `counter_knockback_speed`).

### 4.5 Estela solo mientras la hoja barre

- `AbilityBehavior.is_blade_sweeping(ability) -> bool`: por defecto `true` durante todo el lanzamiento (el Giro y Envainar quedan igual).
- `AbilityComponent.is_blade_sweeping()`: `is_casting() and _behavior.is_blade_sweeping(self)`. Además `signal sweep_changed`, que el behavior emite con `ability.notify_sweep_changed()` al entrar y al salir de la ventana.
- `WeaponTrail._is_weapon_attacking()` usa `is_blade_sweeping()` y se refresca también con `sweep_changed`.
- La Carga devuelve siempre `false` (golpea con el escudo). La Parada devuelve `true` solo en `[counter_trail_start, counter_trail_end]` de la estocada.

### 4.6 Otros cambios genéricos en `AbilityBehavior`/`AbilityComponent`

- `AbilityBehavior.cast_duration(ability) -> float`: por defecto `ability.get_stat(CAST_DURATION)`. `_start_cast()` la usa. La Parada devuelve `counter_duration` tras una parada perfecta.
- `AbilityBehavior.has_charge_feedback() -> bool`: por defecto `true`. Con `false` no hay hitos de carga (sin sacudida ni temblor de `ChargeFeedbackComponent`) y `get_charge_ratio()` devuelve 0, así el HUD no llena el anillo de carga. La Parada devuelve `false`.
- `AbilityComponent.holds_weapon_in_hand()`: se consulta mientras carga **o** lanza. Envainar devuelve `not _charging` y queda igual.
- `AbilityComponent` gana `@export var stamina: StaminaComponent` y `@export var guard: ShieldGuard`.

### 4.7 Clips del cuerpo (`warrior_profile.gd`)

Poses nuevas del brazo izquierdo (el escudo cuelga de `wrist_l`): `SHIELD_BASH` (escudo al frente, a la altura del pecho, empujando) y `SHIELD_BLOCK` (escudo alto, cubriendo torso y cabeza). La espada va en la mano derecha en todos los clips (`holds_weapon_in_hand()`).

| Clip | Tipo | Largo | Qué hace | Tiempos atados a datos |
|---|---|---|---|---|
| `shield_charge` | loop | 0.4 s por ciclo | Torso inclinado, escudo en `SHIELD_BASH`, zancadas cortas | — |
| `shield_bash` | one-shot | 0.35 s | Empujón del escudo hacia delante y vuelta a la guardia | pico del empujón = `bash_hit_time` (0.08 s) |
| `shield_block` | loop | 1.2 s | Guardia baja, escudo en `SHIELD_BLOCK`, espada atrás lista | — |
| `shield_lower` | one-shot | 0.2 s | De `shield_block` a la guardia de reposo | — |
| `shield_counter` | one-shot | 0.5 s | Desde `shield_block`: estocada horizontal que sale por el costado del escudo y recupera | extensión máxima = `counter_hit_time` (0.15 s); la hoja barre en `[counter_trail_start, counter_trail_end]` = [0.08, 0.25] |

Los clips llevan un evento (*method track* vacío, como los del combo) en los tiempos de la tabla, y un test los compara con el config (como AC641). Todos cumplen AC751: el escudo no atraviesa el torso ni pasa detrás de la espalda, y la punta de la espada no toca el piso.

`get_body_clip()`:
- Carga: `shield_charge` mientras avanza, `shield_bash` desde el golpe (termina como cola libre de `PlayerAnimator`).
- Parada: `shield_block` mientras sostiene, `shield_lower` al soltar y `shield_counter` en la estocada.

## 5. Lógica interna

### 5.1 `ShieldChargeAbility extends AbilityBehavior`

Fases dentro del lanzamiento (`CAST_DURATION` = 0.7 s), según el tiempo transcurrido en `channel()`:

1. **TRAVEL** `[0, travel_time)`:
   - `begin()`: `face_nearest_enemy`, mostrar el indicador, `guard.raise(guard_reduction, guard_arc_degrees)` y arrancar el polvo.
   - `move_body()` (`controls_motion()` es `true` en TRAVEL): velocidad `HIT_RANGE / travel_time` hacia el frente, con las reglas de `MovementComponent` contra paredes. Si en un paso el jugador avanzó menos de `stall_ratio` × lo esperado (una pared), pasa a BASH.
   - En cada paso: los enemigos activos cuyo centro está en la franja `capture_depth` × `HIT_WIDTH` delante del jugador (con `get_hit_padding()`) entran a `_dragged`. A cada arrastrado se le aplica `apply_knockback(frente, velocidad × drag_speed_factor)`. Si después de aplicarlo `is_knocked_back()` es falso (lo resistió: un Escudero en guardia o un boss), pasa a BASH.
2. **BASH** (instante `travel_time`, o antes):
   - `guard.lower()`, fin del arrastre y del polvo.
   - Se juntan los enemigos en el rectángulo `bash_range` × `HIT_WIDTH`. Cada uno recibe `hit_damage()` (sin crítico) con `report_hit`, y `apply_knockback(desde el jugador, bash_knockback_speed)`.
   - `report_strike(bash_feel, golpeados)`, anillo de polvo y destello del escudo.
   - "Impulso": con `golpeados ≥ momentum_min_hits`, `reduce_cooldown(restante × (1 − valor))`.
   - Los golpeados y los que seguían arrastrados pasan a la vigilancia de choques por `impact_window` segundos.
3. **RECOVERY** hasta el final: sin movimiento libre (el jugador queda quieto, como hoy durante un lanzamiento). El dash la corta (`dash_cancels_cast = true`).

**Vigilancia de choques** (en el `_physics_process` del behavior, solo mientras la lista no está vacía; también durante TRAVEL para los arrastrados):
- Un vigilado choca si `enemy.hit_wall()` y todavía se desliza (`get_push_speed() > impact_min_speed`).
- `static find_contact(position, push_direction, others, contact_distance) -> int`: índice del enemigo activo más cercano delante de él, en el sentido del empuje (a ≤ `contact_distance` + paddings), o −1 si fue una pared. Sin allocations: recorre `registry.get_active()`.
- **Pared:** `stun(stun, duración)` al vigilado. **Enemigo:** `stun` a los dos y, con "Martillo y yunque", `receive_hit(daño × valor)` y `report_hit` a cada uno, más `report_strike(impact_feel, par)`.
- Cada vigilado choca una sola vez y sale de la lista. La duración es `stun_duration`, o el valor de "Contundencia".

**Corte** (`cancel_cast`, p. ej. el dash): `guard.lower()`, se vacía `_dragged`, se apaga el polvo y el indicador se desvanece. La vigilancia de los ya empujados sigue.

### 5.2 `ParryAbility extends AbilityBehavior`

- `is_charged() = true`, `has_charge_feedback() = false` y `controls_motion()` es `true` mientras bloquea.
- **Poder levantar:** `can_cast()` depende de `AbilityComponent` (enfriamiento). Además, `begin_charge()` verifica `stamina.has_at_least(min_stamina_to_block)`. Si no alcanza, cancela la carga en el acto (`ability.cancel_charge()`, sin enfriamiento) y no pasa nada.
- `begin_charge()`: `_block_time = 0`, `guard.raise(block_reduction, block_arc_degrees)`, conecta `guard.blocked` y hace `face_nearest_enemy`.
- `charge(step)`: `_block_time += step`. Gasta `stamina_per_second × step` salvo durante el primer `valor` s con "Muralla". Si `stamina.get_current() <= 0`, llama a `ability.release_charge()`.
- `move_body()`: `movement.move(wish, delta, move_speed_factor)` y encara al enemigo más cercano (sin enemigos, mantiene el último giro, como Envainar).
- `_on_blocked(amount, source)`:
  - `report_strike(block_feel, [])` (solo la cámara) y la chispa en el escudo.
  - Si `_block_time <= perfect_window`: guarda `_parried = true`, `_parried_amount = amount` y `_counter_target = source`, y llama a `ability.release_charge()`.
- `dash_during_charge()`: `ability.release_charge()`. El dash corta el bajado del escudo (`dash_cancels_cast = true`).
- `cancel_charge()` (p. ej. un agarre o la muerte): `guard.lower()`.
- `begin()` (al soltar, o por la parada):
  - `guard.lower()`.
  - **Sin parada:** clip `shield_lower`; el lanzamiento dura `CAST_DURATION`.
  - **Con parada:** gira hacia `_counter_target`, `health.is_invulnerable = true` por el lanzamiento y `reduce_cooldown(max(restante − perfect_cooldown, 0))`. El lanzamiento dura `counter_duration` (vía `cast_duration()`), y chispa grande con `report_strike(perfect_feel, [])`.
- `channel()` de la estocada:
  - Al cruzar `counter_hit_time`, golpe: rectángulo `HIT_RANGE` × `HIT_WIDTH`. Daño `hit_damage() + parried_amount × valor` (con "Represalia"), con tirada de crítico (`DamageMath.roll_crit`/`apply_crit`, como Envainar).
  - A cada golpeado: `report_hit`, `apply_knockback(counter_knockback_speed)` y `stun(stun, stun_duration)`. Con "Desarme", `debuffs.apply(weaken, valor)`.
  - Después, `report_strike(counter_feel, golpeados)`.
  - Al cruzar `counter_trail_start` y `counter_trail_end`: `notify_sweep_changed()`.
- `release()` / `cancel_cast()`: `health.is_invulnerable = false`, `_parried = false`.

## 6. Resources y datos

| Archivo | Tipo | Contenido |
|---|---|---|
| `resources/strike_feel.gd` | `StrikeFeel` | `hitlag`, `shake_strength`, `impact_scale` |
| `resources/shield_charge_config.gd` → `data/abilities/shield_charge/shield_charge_config.tres` | `ShieldChargeConfig` | `travel_time` 0.4, `capture_depth` 1.2, `drag_speed_factor` 1.1, `stall_ratio` 0.2, `guard_reduction` 0.5, `guard_arc_degrees` 120, `bash_range` 2.0, `bash_hit_time` 0.08, `bash_knockback_speed` 14, `impact_window` 0.6, `impact_min_speed` 2.0, `contact_distance` 1.0, `stun` (`stun.tres`), `stun_duration` 1.0, `momentum_min_hits` 3, `bash_feel` (0.1 s, 0.45, 1.3), `impact_feel` (0.06 s, 0.25, 0.8), `charge_body_clip`, `bash_body_clip`, dust (`dust_amount`, `ring_radius`, `ring_duration`) |
| `data/abilities/shield_charge/shield_charge.tres` | `AbilityData` | "Carga de escudo", BASIC, `base_damage` 12, `attack_scaling` 0.10, `cooldown` 7, `hit_range` 5, `hit_width` 1.8, `cast_duration` 0.7, `min_cooldown` 3, `min_cast_duration` 0.7, `interrupts_dash` false, `dash_cancels_cast` true; 4 cartas y 3 únicas |
| `data/abilities/shield_charge/shield_charge_indicator_config.tres` | `AbilityIndicatorConfig` | como el de la Estocada |
| `resources/parry_config.gd` → `data/abilities/parry/parry_config.tres` | `ParryConfig` | `block_reduction` 1.0, `block_arc_degrees` 120, `stamina_per_second` 25, `min_stamina_to_block` 10, `move_speed_factor` 0.4, `perfect_window` 0.25, `perfect_cooldown` 1.0, `counter_duration` 0.5, `counter_hit_time` 0.15, `counter_trail_start` 0.08, `counter_trail_end` 0.25, `counter_knockback_speed` 10, `stun`, `stun_duration` 1.0, `block_feel` (0, 0.15, 0), `perfect_feel` (0, 0.4, 0), `counter_feel` (0.12 s, 0.5, 1.2), `block_body_clip`, `lower_body_clip`, `counter_body_clip`, chispa (`spark_amount`, `perfect_spark_scale` 1.8) |
| `data/abilities/parry/parry.tres` | `AbilityData` | "Parada", BASIC, `base_damage` 20, `attack_scaling` 0.30, `cooldown` 4, `hit_range` 3.0, `hit_width` 1.2, `cast_duration` 0.2, `min_cooldown` 1.5, `min_cast_duration` 0.2, `dash_cancels_cast` true; 3 cartas y 3 únicas |
| `data/abilities/<habilidad>/upgrades/*.tres`, `unique/*.tres` | `AbilityUpgradeData`, `AbilityUniqueUpgradeData` | §3.1 y §3.2. "Desarme" lleva `debuff = weaken.tres`; los valores por nivel van en `level_values` (Principio III) |
| `data/debuffs/stun.tres` | `DebuffData` | §4.2 |
| `assets/icons/status/knocked_out_stars.svg` | SVG | game-icons.net `delapouite/knocked-out-stars`, CC BY 3.0, preparado como pide `status-icons.md` §2.3, con su fila en `SOURCE.md` |
| `resources/ability_impact_vfx_config.gd` → `data/player/ability_impact_vfx_config.tres` | `AbilityImpactVfxConfig` | pool 8, radio 0.35, duración 0.18 s, alpha 0.5, chispas 10 a 6 m/s |
| `materials/vfx/ability_impact_material.tres` | `StandardMaterial3D` | blanco, unshaded, aditivo, alpha ≤ 0.5 |
| `materials/vfx/shield_dust_material.tres` | `StandardMaterial3D` | tierra `Color(0.62, 0.52, 0.4)`, unshaded, alpha ≤ 0.6 |
| `data/enemies/{verdugo,titan,colmena}_stats.tres` | `EnemyStats` | `stun_duration_scale = 0.3`, `stun_cancels_attack = false` |
| `data/classes/warrior/warrior_abilities.tres` | `AbilityCatalog` | `[shield_charge, parry]` |

Ningún Resource compartido se muta en runtime. Los valores de las mejoras se leen con `get_unique_value()`.

## 7. Interfaz pública (resumen)

```gdscript
# HealthComponent
@export var guard: ShieldGuard
func receive_hit_from(raw: float, source: Vector3) -> float

# ShieldGuard
signal blocked(amount: float, source: Vector3)
func raise(reduction: float, arc_degrees: float) -> void
func lower() -> void
func is_raised() -> bool
func absorb(raw: float, source: Vector3) -> float
static func is_in_front(facing: Vector3, origin: Vector3, source: Vector3, arc_degrees: float) -> bool

# DebuffComponent
func apply(data: DebuffData, potency: float, duration: float = 0.0) -> void
func is_stunned() -> bool

# Enemy
func stun(status: DebuffData, seconds: float) -> void
func is_stunned() -> bool
func get_push_speed() -> float

# EnemyBehavior
func stunned() -> void

# AbilityBehavior
func cast_duration(ability: AbilityComponent) -> float
func has_charge_feedback() -> bool
func is_blade_sweeping(ability: AbilityComponent) -> bool

# AbilityComponent
signal struck(feel: StrikeFeel, enemies: Array[Enemy])
signal sweep_changed
@export var stamina: StaminaComponent
@export var guard: ShieldGuard
func report_strike(feel: StrikeFeel, enemies: Array[Enemy]) -> void
func notify_sweep_changed() -> void
func is_blade_sweeping() -> bool

# ShieldChargeAbility
static func find_contact(position: Vector3, push_direction: Vector3, others: Array[Enemy], self_index: int, contact_distance: float) -> int
```

## 8. Coordinación con `affliction.md`

- **`DebuffData.Effect`:** Aflicción agrega `SLOW = 4`; esta spec, `STUN = 5` con valor explícito. Cualquiera de las dos puede mergearse primero sin tocar los `.tres`. Si esta entra antes, el enum queda con un hueco en 4 hasta que llegue `SLOW`, y AC894 ("`SLOW` vale 4") sigue valiendo.
- **`DebuffComponent.apply`:** Aflicción cambia cómo se refresca y apila (`stack_mode`). Esta spec solo agrega el parámetro opcional `duration` y `ActiveDebuff.duration`. Al resolver el conflicto: `duration > 0` manda sobre `data.duration` en los tres modos, y el reloj usa `ActiveDebuff.duration`.
- **`Enemy._update_behaviour`:** Aflicción aplica ahí la escala de `SLOW`. El aturdimiento se evalúa **antes** (un aturdido no se mueve, lento o no). Es el enganche que su §8 prevé para una futura "Aflicción que aturde", que solo necesita un `AfflictionData` con `debuff = stun.tres`. Ojo: para que respete `stun_duration_scale` y cancele la preparación, Aflicción tendría que aplicarlo con `Enemy.stun()` y no con `debuffs.apply()`. Queda anotado para esa spec.
- **`enemy.tscn`:** esta spec no le agrega nodos. Solo cambian scripts y los `.tres` de los bosses.
- **Fuente "habilidad":** los golpes de la Carga, de "Martillo y yunque" y de la estocada pasan por `report_hit()`, así que cargan las Aflicciones de habilidad. Aflicción necesita su `AbilityData.affliction_scale` (su tabla nombra "Estocada 1.0, Golpe veloz 1.0", que dejan de existir). Propuesta: **Carga 1.5** (un golpe cada 7 s a varios enemigos) y **Parada 2.0** (un golpe raro y difícil). Lo decide Aflicción al rebasar.
- **Constitución:** las dos specs enmiendan el Principio III. La que cierre segunda toma el número siguiente y rebasa el texto.

## 9. Enmienda de la constitución (MINOR 4.16.0 → 4.17.0, o la siguiente libre)

**Principio II**, lista de blancos compartidos: se agregan **el destello y las chispas de impacto de las habilidades, del bloqueo y de la parada** (esfera y partículas, blanco unshaded aditivo, alpha ≤ 0.5, duran décimas de segundo). Registro de colores no reservados: el tierra `Color(0.62, 0.52, 0.4)` también colorea el polvo y el anillo de la Carga de escudo, y el amarillo estrella `Color(1.0, 0.95, 0.55)` es el `icon_color` del estado Aturdido.

**Principio III**, viñeta "Estados de entidades": se agrega el efecto **aturdido** (`STUN`): el enemigo se queda quieto y, si su tipo lo permite (`stun_cancels_attack`), cancela su preparación. La duración la pasa quien lo aplica y la escala el enemigo (`stun_duration_scale`; los bosses se aturden menos y no cancelan su ataque). Nueva viñeta: **bloqueo frontal**, donde el daño que recibe el jugador puede traer su origen y un `ShieldGuard` reduce el que llega dentro de un arco al frente. Arco y reducción son datos de quien lo levanta.

**Principio VII**, "Hit lag local": los golpes de **habilidad** también pausan el clip del jugador, congelan y sacuden a los golpeados y sacuden la cámara, con valores por golpe en su config (`StrikeFeel`). "Estela": solo mientras la hoja barre, no durante todo el lanzamiento.

**Historial:** `4.17.0 (fecha de cierre): Principio II: destellos y chispas de impacto blancos, polvo de la Carga y color del ícono Aturdido. Principio III: estado aturdido (STUN) y bloqueo frontal con origen del golpe. Principio VII: hit lag y estela de las habilidades (ver warrior-abilities-rework.md).`

## 10. Tests existentes que cambian

31 archivos mencionan `THRUST`, `SWIFT_STRIKE` o sus datos. Criterio: **lo que verifican no cambia**; cambia qué habilidad usan.

| Tipo | Archivos | Cambio |
|---|---|---|
| Solo usan una habilidad del Guerrero para arrancar la run o equipar algo | `cooldown_hud_test` (`_start_titan()`), `cooldown_clock_test`, `cooldown_timers_test`, `boss_hud_bar_test`, `input_prompts_test`, `pause_menu_test`, `harasser_test`, `boss_body_test`, `arena_waves_test`, `boss_challenge_run_test`, `berserker_run_test`, `character_class_run_test`, `upgrade_ban_run_test`, `card_ban_test`, `sheathe_test`, `sheathe_feel_test`, `weapon_mount_test`, `sword_swing_test`, `class_combat_identity_test`, `character_class_test` | `THRUST` → `SHIELD_CHARGE` y `SWIFT_STRIKE` → `PARRY` (constantes con la ruta nueva). Donde se contaba el catálogo del Guerrero (2), sigue siendo 2 |
| Mecánicas genéricas probadas con la Estocada o el Golpe veloz | `ability_component_test` (lanzamiento, enfriamiento, cartas, pisos), `upgrade_offer_test`, `upgrade_caps_test`, `ability_run_test`, `sandbox_run_test`, `unique_upgrade_run_test`, `dash_cancel_test`, `weapon_trail_test` | Pasan a la Carga (no cargada) o a la Parada (cargada, donde hoy se usa Envainar no hace falta). Los valores fijos (enfriamiento 4 → 7, daño 10 → 12, piso…) se reescriben desde los `.tres`, no a mano, y se anotan en §13. `weapon_trail_test`: el caso "la estela emite en un lanzamiento" pasa a verificar que emite solo en la ventana de la hoja (AC830) y que el Giro sigue igual (AC831) |
| Verifican el comportamiento de lo que se borra | `thrust_indicator_test`, `swift_strike_test`; los casos de Lacerante, Asesinato y Reset en `unique_upgrades_test` | **Se borran con la feature**. Lo genérico que cubrían (niveles de una única, `reset_cooldown`, `health.execute`) ya lo cubren Envainar, el Giro y `health_component_test`. Si algún caso genérico queda sin cobertura, se reescribe con la Carga y se anota |

La línea base de `main` tiene 15 fallas previas (Giro, alcance y estela del arma, oleadas, datos de clases, escudo del Guerrero). La meta es cero fallas nuevas.

## 11. Criterios de aceptación

**Limpieza y catálogo**
- **AC801** `warrior_abilities.tres` lista exactamente `shield_charge.tres` y `parry.tres`, las dos `slot = BASIC`, y `WaveManager.offer_abilities()` ofrece esas dos al Guerrero.
- **AC802** No existen `data/abilities/thrust/`, `data/abilities/swift_strike/`, `thrust_ability.*` ni `swift_strike_ability.*`, y el `AnimationLibrary_sword` de `player.tscn` no tiene `thrust`, `thrust_recover`, `swift_strike` ni `swift_strike_recover`. Ningún `.gd`, `.tscn` ni `.tres` los referencia. `bleed.tres` sigue existiendo.
- **AC803** Ningún Guerrero, con ninguna de las dos habilidades, deja el cuerpo en `idle` durante una carga o un lanzamiento: `PlayerAnimator` pide un clip del perfil del Guerrero en cada fase (§4.7).

**Aturdimiento**
- **AC804** `DebuffData.Effect.STUN == 5`, y `stun.tres` tiene `effect = 5`, `icon` = `knocked_out_stars.svg`, `icon_color = Color(1.0, 0.95, 0.55)` e `is_beneficial = false`. El SVG tiene su fila en `SOURCE.md`.
- **AC805** `DebuffComponent.apply(data, p, 2.5)` deja `get_remaining_seconds() == 2.5` aunque `data.duration` sea 1. Reaplicar con 1.0 cuando quedan 2 deja 2, y con 3.0 deja 3. `get_remaining_ratio()` usa la duración aplicada. Sin el tercer parámetro, todo como antes (los tests viejos de debuffs no cambian).
- **AC806** Un común aturdido no se mueve ni gira durante el estado (posición y `rotation.y` constantes, sin empuje), y vuelve a actuar al terminar.
- **AC807** Un común aturdido en `WINDUP` cancela el ataque, aunque sea `interruptible = false`: `is_attacking()` es falso, el aviso del piso está limpio y el coordinador ya no le cuenta el turno. Vale para `grunt`, `charger`, `leaper`, `harasser` y `shieldbearer`.
- **AC808** Un aturdido que estaba siendo empujado sigue deslizándose hasta frenar.
- **AC809** Un boss (Verdugo, Titán, Colmena) aturdido 1 s queda aturdido 0.3 s (`stun_duration_scale`), no cancela su ataque en curso y lo retoma en la misma fase y tiempo al terminar.
- **AC810** `stun_duration_scale = 0` no aplica el estado. Un enemigo muerto, desactivado o apareciendo no se aturde.
- **AC811** El ícono de Aturdido aparece en `EnemyStatusOverlay` (comunes) y en la fila de la barra del boss mientras dura, con su reloj.

**Bloqueo frontal**
- **AC812** `ShieldGuard.is_in_front`: con arco de 120°, un origen a 59° del frente cuenta, uno a 61° no, y uno detrás no. Un origen en el mismo punto cuenta.
- **AC813** `receive_hit_from` con el guard levantado al 100 %, de frente: 0 de daño, sin `damaged` y `blocked` emitido con el golpe entero. De espaldas: daño completo y sin `blocked`. Con 50 %: la mitad antes de la defensa.
- **AC814** Con iframes (dash), `receive_hit_from` devuelve 0 y **no** emite `blocked`.
- **AC815** Las 9 llamadas de daño de los enemigos al jugador usan `receive_hit_from` con la posición del enemigo. Ningún comportamiento enemigo llama `target.health.receive_hit(`.

**Carga de escudo**
- **AC816** Sin obstáculos, la Carga desplaza al jugador `HIT_RANGE` (5 m ± 0.1) en `travel_time` (0.4 s) hacia el enemigo más cercano, y el golpe de escudo cae en ese instante.
- **AC817** Durante el avance, un golpe frontal hace el 50 % y uno de atrás el 100 %. Terminado el avance, el guard está bajo.
- **AC818** Un enemigo en la franja de captura avanza con el jugador (sigue delante, a menos de `capture_depth` + su padding) y no recibe daño hasta el golpe de escudo.
- **AC819** El golpe de escudo hace `12 + 0.10 × DAMAGE` (sin crítico, con defensa) a cada enemigo en `bash_range` × `HIT_WIDTH`, los empuja a `bash_knockback_speed` y emite un `enemy_hit` por cada uno.
- **AC820** Contra una pared, la Carga pasa al golpe de escudo apenas se frena. Contra un Escudero en guardia de frente o un boss, pasa al golpe al alcanzarlo.
- **AC821** Un enemigo empujado por el golpe que choca contra una pared dentro de `impact_window` queda aturdido `stun_duration`. Uno que no choca, no.
- **AC822** Un empujado que choca contra otro enemigo deja aturdidos a los dos. `find_contact` distingue pared (−1) de enemigo (índice) en casos puros.
- **AC823** Cada vigilado choca una sola vez y la lista se vacía al pasar `impact_window`.
- **AC824** "Martillo y yunque": en un choque entre enemigos, cada uno recibe `0.5 × daño de la Carga`, con `enemy_hit`. Sin la mejora, el choque no hace daño.
- **AC825** "Impulso": con 3 golpeados, el enfriamiento restante queda a la mitad justo después del golpe. Con 2, no cambia.
- **AC826** "Contundencia": niveles 1 y 2 dan 1.5 s y 2 s de aturdimiento. `max_level = 2`.
- **AC827** Un dash durante la Carga la corta: el guard baja, los arrastrados dejan de recibir empuje y no hay golpe de escudo. El enfriamiento sigue corriendo.
- **AC828** El enfriamiento es 7 s desde la tecla. Las cartas de stats de la Carga respetan su `max_stacks` y los pisos (`min_cooldown` 3).

**Estela**
- **AC829** La estela del arma no emite en ningún momento de la Carga.
- **AC830** En la estocada de la Parada, la estela emite solo con el tiempo del lanzamiento en `[counter_trail_start, counter_trail_end]`.
- **AC831** El Giro y Envainar siguen emitiendo como hoy (todo el lanzamiento).

**Parada**
- **AC832** Mantener E con ≥ 10 de estamina levanta el guard al 100 % con arco de 120° y gasta 25/s: tras 1 s quedan 75 ± 1 de 100. Con menos de 10, no se levanta y no hay enfriamiento.
- **AC833** Con la estamina en 0, el escudo baja solo, como al soltar: enfriamiento de 4 s.
- **AC834** Soltar E baja el guard, reproduce `shield_lower` durante `CAST_DURATION` y arranca el enfriamiento de 4 s. Mientras sostiene, el jugador camina a `move_speed_factor` de su velocidad.
- **AC835** Un golpe frontal a los 0.2 s dispara la estocada, que gira hacia el atacante. A los 0.3 s, no: se bloquea y el escudo sigue arriba.
- **AC836** La estocada hace `20 + 0.30 × DAMAGE` (con crítico según `CRIT_CHANCE`/`CRIT_DAMAGE`) en `HIT_RANGE` × `HIT_WIDTH` al cruzar `counter_hit_time`, aturde `stun_duration` y empuja.
- **AC837** Durante la estocada el jugador es invulnerable, y al terminarla o cortarla deja de serlo. Tras una parada perfecta, el enfriamiento restante es 1 s.
- **AC838** "Represalia": la estocada suma el daño bloqueado por la parada. "Muralla": durante el primer segundo no se gasta estamina y después sí. "Desarme": la estocada aplica `weaken` con el valor de su nivel.
- **AC839** Un dash durante el bloqueo baja el escudo y arranca el enfriamiento. `ChargeFeedbackComponent` no recibe hitos durante el bloqueo y `get_charge_ratio()` es 0.
- **AC840** Un agarre (`begin_hold`) durante el bloqueo cancela la carga, baja el guard y no bloquea el agarre.

**Feedback de impacto y VFX**
- **AC841** Un `struck` con `hitlag > 0` pausa el clip del jugador (`speed_scale == 0`) ese tiempo y luego restaura la velocidad previa. Aplica `apply_hitlag` a cada golpeado y sacude la cámara con `shake_strength`. Un golpe del combo sigue igual (los tests de `bdo-combat-feel.md` no cambian).
- **AC842** Si el lanzamiento termina o se corta durante el hit lag de una habilidad, el clip se reanuda.
- **AC843** `AbilityImpactVfx` crea su pool al cargar (`impact_pool_size` nodos) y no crea nodos en runtime. Un `struck` con 3 enemigos e `impact_scale > 0` activa 3 destellos en sus posiciones. Con `impact_scale = 0`, ninguno.
- **AC844** La Carga muestra polvo durante el avance y el anillo al golpear, y la Parada da una chispa por golpe bloqueado (más grande en la perfecta). Todos usan nodos creados al cargar.

**Cuerpo y armas**
- **AC845** Los clips `shield_charge`, `shield_bash`, `shield_block`, `shield_lower` y `shield_counter` existen en el perfil del Guerrero, y sus eventos coinciden con `bash_hit_time`, `counter_hit_time`, `counter_trail_start` y `counter_trail_end`. Durante las dos habilidades `holds_weapon_in_hand()` es `true` y `WeaponMount` sigue la mano.
- **AC846** AC751 vale en cada cuadro muestreado de los cinco clips nuevos: el escudo no atraviesa el torso ni pasa detrás de la espalda, y la punta de la espada no toca el piso.

## 12. Plan

Cada paso deja el proyecto abriendo y la suite sin fallas nuevas respecto de la línea base (15).

1. **Entorno:** Godot 4.7.2 Linux y gdUnit4 v6.2.0 en el scratchpad; correr la línea base de `main` y guardar la lista de fallas.
2. **Aturdimiento:** `Effect.STUN`, `duration` en `apply`/`ActiveDebuff`, `is_stunned()`, `EnemyStats.stun_*`, `Enemy.stun()`/`is_stunned()`/`get_push_speed()`, el hook `stunned()` en los cinco comunes, los `.tres` de los bosses, `stun.tres` y el SVG (bajado, preparado, `.import` desde la copia y fila en `SOURCE.md`). Tests AC804–AC811.
3. **Bloqueo frontal:** `ShieldGuard`, `receive_hit_from` y las 9 llamadas; el nodo en `player.tscn`. Tests AC812–AC815.
4. **Feedback genérico:** `StrikeFeel`, `struck`/`report_strike`, `HitstopComponent` generalizado, `AbilityImpactVfx` con su config y material, `is_blade_sweeping`/`sweep_changed` en `WeaponTrail`, `cast_duration()`, `has_charge_feedback()`, `holds_weapon_in_hand()` durante la carga, y exports `stamina`/`guard`. Tests AC829 (preparado), AC831, AC841–AC843.
5. **Clips:** poses `SHIELD_BASH`/`SHIELD_BLOCK` y los cinco clips en `warrior_profile.gd`, con captura visual de cada uno. Tests AC845–AC846.
6. **Carga de escudo:** config, behavior, escena, VFX, `.tres`, cartas y únicas. Tests AC816–AC829, AC844 (parte).
7. **Parada:** config, behavior, escena, VFX, `.tres`, cartas y únicas. Tests AC830, AC832–AC840, AC844 (parte).
8. **Cambio de catálogo y borrado:** `warrior_abilities.tres` pasa a las nuevas. Se adaptan los tests de §10 y se borran Estocada, Swift Strike, sus clips y sus tests. Tests AC801–AC803.
9. **Cierre:** enmienda de la constitución (§9) y `CLAUDE.md` (lo que se ajusta: Carga, Parada, aturdimiento, `ShieldGuard`, `StrikeFeel`/`AbilityImpactVfx`; specs recientes). Suite completa, import, smoke test (`--quit-after 300` y la arena), capturas de las dos habilidades en la arena, checklist §14 y estado **Implementada**.

## 13. Notas de implementación

(Se completa al implementar: tests viejos adaptados y sus valores, desvíos aprobados.)

## 14. Checklist de review (constitución)

- [ ] **Identidad (I):** combate (apertura con posicionamiento; riesgo y recompensa de la parada).
- [ ] **Arte (II):** primitivas y partículas; el blanco solo en destellos translúcidos y breves (enmienda); el SVG con `SOURCE.md`; materiales `.tres` compartidos.
- [ ] **Datos (III):** tiempos, distancias, arcos, reducciones, estamina, hit lag y VFX en configs `.tres`; las únicas con `max_level` y valores por nivel; sin mutar Resources compartidos.
- [ ] **GDScript (IV):** tipado estricto; `_physics_process` delgados.
- [ ] **Performance (V):** pools de VFX creados al cargar; la vigilancia de choques recorre el registro sin allocations; buffers reutilizados.
- [ ] **Input (VI):** solo `ability_basic` (mantener y soltar), sin acciones nuevas.
- [ ] **Combate (VII):** hit lag local sin `Engine.time_scale`; auto-apuntado al más cercano; estela solo mientras la hoja barre; los bosses se aturden menos y no cancelan su ataque.
- [ ] **Calidad:** sin fallas nuevas respecto de la línea base; sin warnings de tipado nuevos.
