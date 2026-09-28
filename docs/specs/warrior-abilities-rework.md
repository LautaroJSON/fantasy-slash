# Feature: re-work de las habilidades del Guerrero (Carga de escudo y Parada)

- **Estado:** **Implementada** (2026-09-27). Revisión 2 aprobada por el responsable ("apruebo, implementá"). ACs reservados: **AC801–AC850** (se usan AC801–AC849).
- **Constitución:** `docs/constitution.md` v4.21.0 → **enmienda MINOR a 4.22.0** (Principios II, III y VII, ver §9), **aplicada**.
- **Pilar (Principio I):** **combate.**
  - **Carga de escudo** (ofensiva): una apertura que reposiciona. Llevarse enemigos contra una pared o contra otros premia leer el terreno. Si recibe un golpe de frente mientras avanza, el golpe final sale potenciado: cargar *contra* un ataque es una decisión con recompensa.
  - **Parada** (defensiva): una parada de toque. Levantar el escudo justo cuando llega un golpe telegrafiado lo anula. Fallar deja al Guerrero expuesto y con un enfriamiento largo. Las mejoras doradas convierten la parada en daño (Represalia, Contragolpe) o en impulso para la run (Duelo).
- **Dependencias:** `warrior-sword-and-shield.md` (escudo en `wrist_l`, AC751), `sheath-socket-hand-grip.md` y `sheathe-release-animation.md` (clip del cuerpo por habilidad, `holds_weapon_in_hand()`), `bdo-combat-feel.md` (hit lag local), `status-icons.md` (íconos), `unique-ability-upgrades.md` y `spin-golden-upgrades.md` (mejoras únicas doradas), `affliction.md` y `frost-freeze.md` (`SLOW`, `resists_control`, congelado), `hit-impact-vfx.md` (impacto de golpe), `spin-visual-rework.md` (`is_trailing`), `enemy-attack-telegraph.md` (preparaciones).

## 1. Decisiones del responsable (2026-09-27)

1. **Habilidades BASIC:** **Carga de escudo** (ofensiva, variante "con absorción") y **Parada** (defensiva, parada de toque). Se elige una al empezar la run, como hoy.
2. **La Parada solo anula el daño.** No aturde ni contraataca por sí sola. Las recompensas llegan con tres **mejoras únicas doradas**: devolver el daño (**Represalia**), renovar el enfriamiento con una estocada automática (**Contragolpe**, un golpe nuevo que no reutiliza la Estocada borrada) y la cadena marca → buff (**Duelo**).
3. **Palanca contra el abuso del bloqueo:** **solo frontal** (arco de 120°). Además, la Parada castiga el fallo con su diseño (recuperación y enfriamiento largo). **No** se agregan ataques imbloqueables (`unblockable`). Los agarres ya no pasan por el daño normal, así que el escudo no los bloquea.
4. **Bastión descartado.**
5. **Ofensiva:** sin preferencia del responsable; se toma la recomendada, **Carga con absorción** (§3.1).
6. **Se mantienen (revisión 1):** se borran Estocada y Swift Strike (con Lacerante, Asesinato y Reset); `bleed.tres` se conserva. Sin ultimate: el slot R queda vacío. Aturdimiento con `stun.tres` (`delapouite/knocked-out-stars`); en bosses, duración × `stun_duration_scale` = 0.3 y el comportamiento se pausa sin cancelar el ataque. Sin sistema de VFX por estado: solo las habilidades, sus VFX y el feedback de impacto estándar (hit lag, sacudida, empuje).

**Propuestas de esta revisión (a confirmar en la aprobación):**
- Nombres: habilidad **Parada**; mejoras **Represalia**, **Contragolpe** y **Duelo**; debuff **Retado**; buff **Triunfo**.
- Retado dura **6 s**. Triunfo: **+10 % de velocidad de movimiento y +10 % de daño por stack**, hasta **3 stacks**, **8 s**. Cada muerte de un Retado suma un stack y reinicia los 8 s. Al vencer, **se pierden todos los stacks juntos** (no de a uno como Conmoción).
- "Matar a un Retado" cuenta cualquier muerte mientras lleva la marca: básicos, habilidades o daño de una Aflicción.

## 2. Relevamiento (verificado sobre `main`, 9c05ff3)

| Pieza | Hoy | En esta spec |
|---|---|---|
| `data/classes/warrior/warrior_abilities.tres` | Estocada y Swift Strike (BASIC) | Carga de escudo y Parada |
| Estocada | `data/abilities/thrust/` (6 cartas y "Lacerante"), `components/abilities/thrust_ability.gd/.tscn` | **Se borra** |
| Swift Strike | `data/abilities/swift_strike/` (6 cartas, "Asesinato" y "Reset"), `components/abilities/swift_strike_ability.gd/.tscn` | **Se borra** |
| Clips `thrust`, `thrust_recover`, `swift_strike`, `swift_strike_recover` | `AnimationLibrary_sword` del `SwingPlayer` en `player.tscn` | **Se borran** (el Giro conserva los suyos) |
| `data/debuffs/bleed.tres` | Solo lo aplica Lacerante; varios tests lo usan como debuff genérico | **Se conserva** |
| `affliction_scale` | Estocada 1.0 y Swift Strike 1.0 (`affliction.md`) | Carga 1.5 y Parada 2.0 (§8) |
| `PlayerAnimator.CLIP_BUSY = &"idle"` | Una habilidad sin clip deja el cuerpo en `idle` | Las dos habilidades tienen clips en `warrior_profile.gd` |
| `HitstopComponent` | Solo escucha a `AttackComponent`; `_resume()` usa `attack.get_clip_speed()` | También escucha los golpes de habilidad (§4.4) |
| `HitImpactVfxHost` | Ya escucha `enemy_hit` de las dos ranuras; dibuja si `AbilityData.shows_hit_impact` | Las dos habilidades nuevas ponen `shows_hit_impact = true`. No hace falta un VFX de impacto propio |
| `AbilityComponent.is_trailing()` | `is_casting() or behavior.extends_trail()` | La estela puede limitarse a una ventana del lanzamiento (§4.5) |
| Daño al jugador | 9 llamadas `target.health.receive_hit(x)` en `melee`, `charger`, `harasser`, `leaper`, `boss` (×3) y `titan` (×2); sin dirección | `receive_hit_from(x, enemy)` y un `ShieldGuard` en el jugador (§4.3) |
| Control de enemigos | `EnemyStats.resists_control` (bosses); `DebuffComponent.get_speed_scale()` en 0 deja al enemigo quieto y con el comportamiento en pausa (Escarcha) | El aturdimiento reutiliza ese camino (§4.2) |
| Buffs | `BuffData` + `BuffComponent`, stacks que se pierden de a uno; modificadores `MOVE_SPEED`, `ABILITY_SPEED`, `CRIT_CHANCE`, que solo lee quien otorga el buff (el Giro) | Buffs **globales** que `StatsComponent` suma a los stats, modificador `DAMAGE` y vencimiento de todos los stacks juntos (§4.6) |
| Colisiones | Enemigos: capa 3 (valor 4), máscara mundo + enemigos (5). Jugador: capa 2, máscara solo mundo (1): **atraviesa a los enemigos** | La Carga arrastra empujando (knockback continuo), no con el cuerpo del jugador |
| `UltimateAbility` | Existe (R y botón en el HUD); nada la equipa | Sin cambios |

## 3. Qué se ve y cómo se juega

### 3.1 Carga de escudo (BASIC, tecla E)

1. Al apretar E, el Guerrero gira hacia el enemigo más cercano (Principio VII), marca en el piso el recorrido (rectángulo de `HIT_RANGE` × `HIT_WIDTH`, que se desvanece) y **avanza 5 m en 0.4 s** con el escudo adelante, levantando polvo.
2. Mientras avanza, **reduce 50 % el daño que viene de frente** (arco de 120°).
3. **Absorción:** si durante el avance lo alcanza un golpe de frente, el escudo destella (chispa) y el golpe final queda **potenciado**. Un golpe de atrás no cuenta.
4. Los enemigos que toca el frente del escudo (una franja de 1.2 m delante) quedan **arrastrados**: van delante de él a la misma velocidad.
5. Al terminar el recorrido, o antes si choca contra una pared o alcanza a un enemigo que no se deja arrastrar (un Escudero en guardia, un boss), da un **golpe de escudo**: **12 + 10 % del daño** del jugador (sin crítico) a todos los que tiene delante (2 m × `HIT_WIDTH`), con un **empuje fuerte**. Tiene hit lag, sacudida de cámara, el impacto de golpe de `hit-impact-vfx.md` y un anillo de polvo.
6. **Potenciado:** el golpe hace **×2 de daño** y **aturde 1 s a todos los golpeados**, con más hit lag, más sacudida y un anillo más grande.
7. Durante los 0.6 s siguientes, cada enemigo empujado que **choca contra una pared** queda **aturdido 1 s**. Si **choca contra otro enemigo**, quedan aturdidos los dos. Lo mismo vale para un arrastrado que choca durante el avance.
8. Enfriamiento: **7 s**, desde que se aprieta la tecla. El dash corta la Carga en cualquier momento y, al cortarla, suelta a los arrastrados.

**Mejoras únicas** (doradas; se ofrecen solo con la Carga equipada):

| Id | Nombre | Niveles | Efecto |
|---|---|---|---|
| `hammer_anvil` | **Martillo y yunque** | 1 | Cuando dos enemigos chocan, cada uno recibe el 50 % del daño de la Carga (con número de daño). |
| `momentum` | **Impulso** | 1 | Si el golpe de escudo alcanza a 3 o más enemigos, el enfriamiento que queda se reduce a la mitad. |
| `concussive` | **Contundencia** | 2 | Todos los aturdimientos de la Carga (choques y golpe potenciado) pasan de 1 s a 1.5 s (nivel 1) y a 2 s (nivel 2). |

*"Contundencia" y no "Conmoción del escudo", porque "Conmoción" ya es un buff del Giro.*

**Cartas de stats** (`AbilityUpgradeData`): daño (+4, ×5), escalado (+5 %, ×4), enfriamiento (−1 s, ×4; piso 3 s; ver §13) y distancia (+1 m, ×3; el tiempo del avance no cambia, así que va más rápido).

### 3.2 Parada (BASIC, tecla E)

> **Revisada** por `parry-riposte-rework.md` (2026-09-28): la habilidad se llama Parry, toda parada exitosa responde con la estocada (sin empujón), Contragolpe pasa a la Estocada mejorada de 360°, Represalia se eliminó, y Triunfo tiene 5 stacks de 15 s.

1. **Tocar E** levanta el escudo durante **0.35 s** (la ventana). El Guerrero gira hacia el enemigo más cercano y se queda quieto. El enfriamiento de **6 s** arranca al apretar.
2. Durante la ventana, **todo golpe de frente (arco de 120°) se anula**: 0 de daño, sin parpadeo ni clip `hit`. Cada uno da una **chispa en el escudo** y una sacudida leve. Los golpes de atrás o de los costados pegan completos. Un agarre no se bloquea.
3. **Parada exitosa** (al menos un golpe anulado): el escudo sigue arriba hasta el final de la ventana (anula los que lleguen), hace un empujón corto de **0.15 s** y el enfriamiento que queda baja a **1.5 s**.
4. **Parada fallida** (no llegó nada): el escudo baja con una **recuperación de 0.4 s** (el Guerrero queda expuesto) y el enfriamiento sigue siendo el completo.
5. El dash corta la Parada en cualquier momento (ventana o recuperación).

**Mejoras únicas doradas** (solo con la Parada equipada):

| Id | Nombre | Niveles | Efecto |
|---|---|---|---|
| `retribution` | **Represalia** | 3 | Cada golpe anulado devuelve al atacante el **100 / 150 / 200 %** del daño que traía (antes de la defensa del jugador), aplicado con la defensa del enemigo, sin crítico y con número de daño. |
| `riposte` | **Contragolpe** | 1 | La **primera** parada exitosa de cada uso **renueva el enfriamiento** (queda en 0) y dispara una **estocada automática** hacia el atacante: **20 + 30 % del daño** (con crítico), en un rectángulo de 3 m × 1.2 m, con empuje. Dura 0.5 s, es invulnerable y deja estela solo mientras la hoja avanza. Reemplaza el resto de la ventana y el empujón. |
| `duel` | **Duelo** | 1 | Cada atacante cuyo golpe se anula queda **Retado** durante **6 s** (no hace nada por sí mismo). Si un Retado muere, el Guerrero gana 1 stack de **Triunfo** (+10 % de velocidad de movimiento y +10 % de daño por stack, máximo 3, **8 s**). Cada muerte de otro Retado suma un stack y reinicia los 8 s. Al vencer, se pierden todos los stacks. |

*Represalia es mejorable porque su efecto es un número que crece bien. Contragolpe es binario. Duelo es binario: su fuerza está en los datos del buff.*

**Cartas de stats:** enfriamiento (−0.75 s, ×4; piso 3 s: afecta al enfriamiento completo, no al de 1.5 s tras el éxito) y ventana (+0.05 s, ×2). Las cartas de daño y escalado no existen: el único golpe propio es el de Contragolpe, que usa los valores base de `parry.tres`.

**Por qué no se abusa:** la ventana es corta y solo frontal; fallar cuesta 0.4 s expuesto y 6 s de espera; con varios enemigos, los de los costados siguen pegando. Con Contragolpe el enfriamiento se renueva, pero la estocada compromete 0.5 s y el siguiente éxito exige volver a leer un golpe.

### 3.3 Aturdido

- Un enemigo aturdido **se queda quieto**: no camina, no gira y no ataca. Si es un enemigo común y estaba en una **preparación**, se cancela: se apaga su aviso en el piso, devuelve su turno de ataque y las manos vuelven al reposo. Un empuje que ya tenía **sigue deslizándolo**.
- Muestra el ícono **Aturdido** (`knocked_out_stars.svg`), con su reloj, en su fila de estados (`EnemyStatusOverlay`, o la barra del boss).
- Reaplicarlo mientras dura no suma: queda la duración más larga entre la que le quedaba y la nueva.
- **Bosses** (`resists_control`): duración × `stun_duration_scale` (0.3: 1 s → 0.3 s). No se cancela su ataque: el comportamiento se pausa, como con el congelado de Escarcha, y sigue donde estaba.

## 4. Diseño

### 4.1 Estructura de nodos

```
Player (player.tscn)
├── HealthComponent                     guard = ShieldGuard (nuevo export, opcional)
├── ShieldGuard (ShieldGuard)           ← nuevo: bloqueo frontal (arco, reducción), señal blocked
├── BasicAbility / UltimateAbility      + export guard
├── Hitstop (HitstopComponent)          + abilities: [BasicAbility, UltimateAbility]
├── Stats (StatsComponent)              + buffs = BuffComponent
└── (SwingPlayer › AnimationLibrary_sword pierde thrust*, swift_strike*)

components/abilities/shield_charge_ability.tscn   (ShieldChargeAbility)
├── Indicator (AbilityRectIndicator)
├── BashVfx (ShieldBashVfx)             ← polvo del avance y anillo del golpe
└── BlockVfx (BlockSparkVfx)            ← chispa de la absorción (misma escena que la Parada)

components/abilities/parry_ability.tscn            (ParryAbility)
├── Indicator (AbilityRectIndicator)    ← solo para la estocada de Contragolpe
└── BlockVfx (BlockSparkVfx)            ← chispas en el escudo (pool)
```

Todos los VFX se crean una vez al cargar (Principio V) y se reposicionan. El impacto sobre los enemigos lo dibuja el `HitImpactVfx` existente.

### 4.2 Aturdimiento

**`DebuffData.Effect.STUN`**, agregado **al final** del enum (después de `SLOW`, así que vale 5; los `.tres` guardan el entero).

**`data/debuffs/stun.tres`:** `id = &"stun"`, `effect = STUN`, `duration = 1.0` (la real la pasa quien lo aplica), `max_stacks = 1`, `icon = knocked_out_stars.svg`, `icon_color = Color(1.0, 0.95, 0.55)` (amarillo estrella, se registra en el Principio II).

**`DebuffComponent`:**
- `apply(data, potency, duration: float = 0.0)`: con `duration > 0` usa esa duración en lugar de `data.duration`. Al refrescar un estado con duración propia, queda `max(le_quedaba, duration)`. Sin el parámetro, nada cambia (tampoco `stack_mode`).
- `ActiveDebuff.duration`: la duración con la que se aplicó. `get_remaining_ratio()` la usa, así el reloj del ícono es correcto con duraciones propias.
- `is_stunned() -> bool`: hay un `STUN` activo. Es temporizado y no toca la defensa.
- `get_speed_scale()` devuelve **0** mientras hay un `STUN`. Así `Enemy._update_behaviour` ya lo deja quieto y pausa su comportamiento (el mismo camino que el congelado de Escarcha), y el empuje sigue teniendo prioridad.

**`EnemyStats`:** `@export var stun_duration_scale: float = 1.0`. El default va en el script: un `.tres` que no lo escribe vale 1. Verdugo, Titán y Colmena: 0.3. Con 0, el enemigo es inmune (no recibe el estado).

**`Enemy`:**
- `stun(status: DebuffData, seconds: float)`: aplica `status` con `seconds × stun_duration_scale`. Si **no** `resists_control`, llama a `_behavior.stunned()`. No hace nada si está muerto, desactivado, apareciendo o si la duración escalada es ≤ 0.
- `is_stunned() -> bool` (delegado en `debuffs`).
- `get_push_speed() -> float`: el largo de `_knockback`, para detectar choques (§5.1).

**`EnemyBehavior.stunned()`** (hook nuevo, vacío por defecto): los cinco comunes (`melee`, `charger`, `leaper`, `harasser`, `shieldbearer`) cancelan el ataque en curso como `_end_attack(false)`, sin importar `interruptible`. Los bosses no lo implementan.

### 4.3 Bloqueo frontal: `ShieldGuard` y `receive_hit_from`

**`HealthComponent`:**
- `@export var guard: ShieldGuard` (opcional; los enemigos no lo tienen).
- `receive_hit_from(raw: float, attacker: Enemy) -> float`: si es invulnerable o está muerto, devuelve 0 sin avisar al guard. Si no, `raw = guard.absorb(raw, attacker)` cuando hay guard, y sigue como `receive_hit(raw)`. Un golpe anulado al 100 % no emite `damaged` (sin parpadeo, `hit` ni sacudida de daño).
- `receive_hit(raw)` no cambia: lo siguen usando los golpes del jugador sobre los enemigos.

**Las 9 llamadas de los enemigos** pasan a `target.health.receive_hit_from(x, enemy)`. En la onda expansiva del Verdugo y en los golpes del Titán, el atacante es el boss (su posición es el origen). Los agarres (`begin_hold`) no pasan por aquí: **el escudo no bloquea un agarre**.

**`ShieldGuard extends Node`** (`components/shield_guard.gd`):
- `@export var visual: Node3D`: su −Z es el frente.
- `signal blocked(amount: float, attacker: Enemy)`: la parte absorbida, antes de la defensa.
- `raise(reduction: float, arc_degrees: float)`, `lower()`, `is_raised() -> bool`.
- `absorb(raw, attacker) -> float`: si está levantado y `is_in_front(...)` con la posición del atacante, emite `blocked(raw × reduction, attacker)` y devuelve `raw × (1 − reduction)`. Si no, devuelve `raw`.
- `static is_in_front(facing: Vector3, origin: Vector3, source: Vector3, arc_degrees: float) -> bool`: ángulo plano (XZ) entre `facing` y `source − origin` ≤ `arc/2`. Un origen en el mismo punto cuenta como de frente.

### 4.4 Feedback de impacto de las habilidades

**`StrikeFeel`** (`resources/strike_feel.gd`), uno por golpe de habilidad, dentro del config de cada habilidad:
- `hitlag: float`: segundos de pausa del clip del jugador y de congelamiento con temblor de los golpeados (`Enemy.apply_hitlag`; los bosses solo tiemblan, como hoy).
- `shake_strength: float`: sacudida de cámara.

**`AbilityComponent`:** `signal struck(feel: StrikeFeel, enemies: Array[Enemy])`, emitida por `report_strike(feel, enemies)`. Los behaviors la llaman **una vez por golpe**, después de sus `report_hit()`. El array es el buffer del behavior (sin copias). Con un array vacío solo sacude la cámara (la chispa de un bloqueo). `report_hit()` no cambia: números de daño, impacto de golpe (`shows_hit_impact`) y carga de Aflicción.

**`HitstopComponent`** (generalizado, sigue siendo el único que pausa el clip):
- `@export var abilities: Array[AbilityComponent]`. En `struck`: `start(feel.hitlag)`, `camera.shake(feel.shake_strength)` si es > 0, y `apply_hitlag(feel.hitlag, config)` en cada enemigo.
- `start()` guarda la velocidad del clip al pausarlo y `_resume()` la restaura. Para los básicos es la misma `get_clip_speed()` de hoy.
- Si el lanzamiento termina o se corta (`cast_released`) durante un hit lag de habilidad, este termina y el clip se reanuda.
- Las habilidades canalizadas (el Giro) no emiten `struck`: el Principio VII no cambia para ellas.

**Empuje:** cada golpe sigue empujando con `Enemy.apply_knockback` y la velocidad de su config.

### 4.5 Estela solo mientras la hoja barre

- `AbilityBehavior.trails_while_casting(ability) -> bool`: por defecto `true` (el Giro y Envainar quedan igual).
- `AbilityComponent.is_trailing()` pasa a `(is_casting() and behavior.trails_while_casting(self)) or behavior.extends_trail(self)`. El behavior avisa los cambios con el `notify_trail_changed()` existente, y `WeaponTrail` ya se refresca con `trail_changed`.
- La Carga devuelve siempre `false` (golpea con el escudo). La Parada devuelve `true` solo durante la estocada de Contragolpe, en `[riposte_trail_start, riposte_trail_end]`.

### 4.6 Buffs globales (para Triunfo)

- **`BuffModifier.Stat.DAMAGE`**, agregado al final del enum: fracción sumada al daño.
- **`BuffData.global: bool`**: sus modificadores `MOVE_SPEED` y `DAMAGE` se aplican siempre, a través de `StatsComponent`. Con `false` (Conmoción), nada cambia: los lee solo quien los otorga.
- **`BuffData.expires_all_stacks: bool`**: al vencer `stack_duration` se pierden todos los stacks juntos. Cada `add_stack` reinicia el tiempo (como hoy).
- **`StatsComponent`:** `@export var buffs: BuffComponent` (opcional). `get_stat(MOVE_SPEED)` y `get_stat(DAMAGE)` devuelven `cache × (1 + Σ modificadores de los buffs globales activos)`. El caché de las mejoras no cambia: la suma se hace en la lectura, recorriendo los buffs activos (pocos, sin allocations). `BuffComponent.changed` reemite `stats_changed`, así la pausa y el movimiento ven el valor con el buff.

### 4.7 Otros cambios genéricos

- `AbilityBehavior.cast_duration(ability) -> float`: por defecto `ability.get_stat(CAST_DURATION)`. `_start_cast()` la usa. La Parada devuelve ventana + recuperación fallida.
- `AbilityComponent.set_cast_remaining(seconds)`: acorta o alarga el lanzamiento en curso (la Parada tras un éxito o para la estocada).
- `AbilityComponent` gana `@export var guard: ShieldGuard`.

### 4.8 Clips del cuerpo (`warrior_profile.gd`)

Poses nuevas del brazo izquierdo (el escudo cuelga de `wrist_l`): `SHIELD_BASH` (escudo al frente, a la altura del pecho, empujando) y `SHIELD_BLOCK` (escudo alto, cubriendo torso y cabeza). La espada va en la mano derecha en todos los clips (`holds_weapon_in_hand()`).

| Clip | Tipo | Largo | Qué hace | Tiempos atados a datos |
|---|---|---|---|---|
| `shield_charge` | loop | 0.4 s por ciclo | Torso inclinado, escudo en `SHIELD_BASH`, zancadas cortas | — |
| `shield_bash` | one-shot | 0.35 s | Empujón del escudo hacia delante y vuelta a la guardia | pico = `bash_hit_time` (0.08 s) |
| `shield_parry` | one-shot | 0.35 s (el último cuadro se sostiene si la ventana crece) | Escudo arriba de golpe, en `SHIELD_BLOCK`, peso adelante | escudo arriba = `raise_time` (0.06 s) |
| `shield_parry_success` | one-shot | 0.15 s | Empujón corto del escudo y vuelta a la guardia | — |
| `shield_parry_whiff` | one-shot | 0.4 s | El escudo baja pesado, el torso cae un poco (expuesto) | — |
| `shield_riposte` | one-shot | 0.5 s | Desde `SHIELD_BLOCK`: estocada horizontal que sale por el costado del escudo y recupera | extensión = `riposte_hit_time` (0.15 s); la hoja barre en [0.08, 0.25] |

Los clips llevan un evento (*method track* vacío, como los del combo) en los tiempos de la tabla, y un test los compara con el config (como AC641). Todos cumplen AC751: el escudo no atraviesa el torso ni pasa detrás de la espalda, y la punta de la espada no toca el piso.

`get_body_clip()`:
- Carga: `shield_charge` mientras avanza y `shield_bash` desde el golpe.
- Parada: `shield_parry` en la ventana, `shield_parry_success` o `shield_parry_whiff` después, y `shield_riposte` en la estocada.

## 5. Lógica interna

### 5.1 `ShieldChargeAbility extends AbilityBehavior`

Fases dentro del lanzamiento (`CAST_DURATION` = 0.7 s), según el tiempo transcurrido en `channel()`:

1. **TRAVEL** `[0, travel_time)`:
   - `begin()`: `face_nearest_enemy`, mostrar el indicador, `guard.raise(guard_reduction, guard_arc_degrees)`, conectar `guard.blocked`, `_absorbed = false` y arrancar el polvo.
   - `move_body()` (`controls_motion()` es `true` en TRAVEL): velocidad `HIT_RANGE / travel_time` hacia el frente, con las reglas de `MovementComponent` contra paredes. Si en un paso avanzó menos de `stall_ratio` × lo esperado (una pared), pasa a BASH.
   - En cada paso: los enemigos activos cuyo centro está en la franja `capture_depth` × `HIT_WIDTH` delante (con `get_hit_padding()`) entran a `_dragged`, y reciben `apply_knockback(frente, velocidad × drag_speed_factor)`. Si después `is_knocked_back()` es falso (lo resistió), pasa a BASH.
   - `_on_blocked()`: `_absorbed = true`, chispa en el escudo y `report_strike(absorb_feel, [])`.
2. **BASH** (instante `travel_time`, o antes):
   - `guard.lower()`, desconectar `blocked`, fin del arrastre y del polvo.
   - Enemigos en el rectángulo `bash_range` × `HIT_WIDTH`: cada uno recibe `hit_damage()` (× `absorb_damage_multiplier` si `_absorbed`), sin crítico, con `report_hit`, y `apply_knockback(desde el jugador, bash_knockback_speed)`. Si `_absorbed`, además `stun(stun, duración)`.
   - `report_strike(bash_feel o empowered_feel, golpeados)` y el anillo (× `empowered_ring_scale` si potenciado).
   - "Impulso": con `golpeados ≥ momentum_min_hits`, `reduce_cooldown(restante × (1 − valor))`.
   - Los golpeados y los que seguían arrastrados pasan a la vigilancia de choques por `impact_window` segundos.
3. **RECOVERY** hasta el final: el jugador queda quieto. El dash la corta (`dash_cancels_cast = true`).

**Vigilancia de choques** (en `_physics_process` del behavior, solo con la lista no vacía; también durante TRAVEL para los arrastrados):
- Un vigilado choca si `enemy.hit_wall()` y todavía se desliza (`get_push_speed() > impact_min_speed`).
- `static find_contact(position, push_direction, others, self_index, contact_distance) -> int`: índice del enemigo activo más cercano delante de él, en el sentido del empuje (a ≤ `contact_distance` + paddings), o −1 si fue una pared. Sin allocations: recorre `registry.get_active()`.
- **Pared:** `stun` al vigilado. **Enemigo:** `stun` a los dos y, con "Martillo y yunque", `receive_hit(daño × valor)` y `report_hit` a cada uno, más `report_strike(impact_feel, par)`.
- Cada vigilado choca una sola vez y sale de la lista. La duración de todo aturdimiento de la Carga es `stun_duration`, o el valor de "Contundencia".

**Corte** (`cancel_cast`, p. ej. el dash): `guard.lower()`, se desconecta `blocked`, se vacía `_dragged`, se apaga el polvo y el indicador se desvanece. La vigilancia de los ya empujados sigue.

### 5.2 `ParryAbility extends AbilityBehavior`

Estados: `WINDOW`, `SUCCESS`, `WHIFF`, `RIPOSTE`.

- `cast_duration()` = `CAST_DURATION` (la ventana) + `whiff_recovery`.
- `begin()`: `face_nearest_enemy`, `guard.raise(block_reduction, guard_arc_degrees)`, conectar `guard.blocked`, `_state = WINDOW`, `_blocked_any = false`.
- `channel()`:
  - En `WINDOW`, al pasar `CAST_DURATION`: `guard.lower()`. Si `_blocked_any`, `_state = SUCCESS` y `set_cast_remaining(success_recovery)`. Si no, `_state = WHIFF` (el lanzamiento ya incluye la recuperación).
  - En `RIPOSTE`: al cruzar `riposte_hit_time`, el golpe (abajo). Al cruzar `riposte_trail_start` y `riposte_trail_end`, `notify_trail_changed()`.
- `_on_blocked(amount, attacker)` (solo en `WINDOW`):
  - Chispa en el escudo, del lado del atacante, y `report_strike(block_feel, [])`.
  - La primera vez: `_blocked_any = true` y `reduce_cooldown(max(restante − success_cooldown, 0))`.
  - **Represalia:** si el atacante sigue activo, `attacker.health.receive_hit(amount × valor)` y `report_hit(attacker, aplicado)`.
  - **Duelo:** `attacker.debuffs.apply(challenged, 1.0)` y, si no estaba conectado, `attacker.killed.connect(_on_challenged_killed, CONNECT_ONE_SHOT)`.
  - **Contragolpe** (solo la primera vez): `reset_cooldown()`, `guard.lower()`, `_state = RIPOSTE`, `_riposte_target = attacker`, gira hacia él, `health.is_invulnerable = true`, `set_cast_remaining(riposte_duration)` y reinicia el reloj de fase.
- Golpe de la estocada: rectángulo `HIT_RANGE` × `HIT_WIDTH` desde el jugador. Daño `hit_damage()` con tirada de crítico (`DamageMath.roll_crit`/`apply_crit`, como Envainar). A cada golpeado: `report_hit` y `apply_knockback(riposte_knockback_speed)`. Después, `report_strike(riposte_feel, golpeados)`.
- `_on_challenged_killed(enemy)`: si `enemy.debuffs` todavía tiene `challenged`, `buffs.add_stack(triumph)`. Si la marca venció antes de la muerte, nada.
- `trails_while_casting()`: `true` solo en `RIPOSTE` dentro de `[riposte_trail_start, riposte_trail_end]`.
- `release()` / `cancel_cast()` (fin, dash, agarre, muerte): `guard.lower()`, desconectar `blocked`, `health.is_invulnerable = false` si la había puesto.

`Retado` usa `DebuffData.Effect.STATUS` (solo se lista). `Triunfo` es un `BuffData` con `global = true` y `expires_all_stacks = true`.

## 6. Resources y datos

| Archivo | Tipo | Contenido |
|---|---|---|
| `resources/strike_feel.gd` | `StrikeFeel` | `hitlag`, `shake_strength` |
| `resources/shield_charge_config.gd` → `data/abilities/shield_charge/shield_charge_config.tres` | `ShieldChargeConfig` | `travel_time` 0.4, `capture_depth` 1.2, `drag_speed_factor` 1.1, `stall_ratio` 0.2, `guard_reduction` 0.5, `guard_arc_degrees` 120, `bash_range` 2.0, `bash_hit_time` 0.08, `bash_knockback_speed` 14, `absorb_damage_multiplier` 2.0, `empowered_ring_scale` 1.6, `impact_window` 0.6, `impact_min_speed` 2.0, `contact_distance` 1.0, `stun` (`stun.tres`), `stun_duration` 1.0, `momentum_min_hits` 3, `bash_feel` (0.1 s, 0.45), `empowered_feel` (0.14 s, 0.7), `absorb_feel` (0, 0.2), `impact_feel` (0.06 s, 0.25), clips, polvo (`dust_amount`, `ring_radius`, `ring_duration`) |
| `data/abilities/shield_charge/shield_charge.tres` | `AbilityData` | "Carga de escudo", BASIC, `base_damage` 12, `attack_scaling` 0.10, `cooldown` 7, `hit_range` 5, `hit_width` 1.8, `cast_duration` 0.7, `min_cooldown` 3, `min_cast_duration` 0.7, `interrupts_dash` false, `dash_cancels_cast` true, `affliction_scale` 1.5, `shows_hit_impact` true; 4 cartas y 3 únicas |
| `data/abilities/shield_charge/shield_charge_indicator_config.tres` | `AbilityIndicatorConfig` | como el de la Estocada (opacidades del Principio II) |
| `resources/parry_config.gd` → `data/abilities/parry/parry_config.tres` | `ParryConfig` | `block_reduction` 1.0, `guard_arc_degrees` 120, `raise_time` 0.06, `success_cooldown` 1.5, `success_recovery` 0.15, `whiff_recovery` 0.4, `riposte_duration` 0.5, `riposte_hit_time` 0.15, `riposte_trail_start` 0.08, `riposte_trail_end` 0.25, `riposte_knockback_speed` 10, `challenged` (`challenged.tres`), `triumph` (`triumph.tres`), `block_feel` (0, 0.2), `riposte_feel` (0.12 s, 0.5), clips, chispa (`spark_amount`, `spark_pool_size`) |
| `data/abilities/parry/parry.tres` | `AbilityData` | "Parada", BASIC, `base_damage` 20, `attack_scaling` 0.30, `cooldown` 6, `hit_range` 3.0, `hit_width` 1.2, `cast_duration` 0.35, `min_cooldown` 3, `min_cast_duration` 0.35, `dash_cancels_cast` true, `affliction_scale` 2.0, `shows_hit_impact` true; 2 cartas y 3 únicas |
| `data/abilities/<habilidad>/upgrades/*.tres`, `unique/*.tres` | `AbilityUpgradeData`, `AbilityUniqueUpgradeData` | §3.1 y §3.2. Represalia `level_values = [1.0, 1.5, 2.0]`; Contundencia `[1.5, 2.0]`; Martillo `[0.5]`; Impulso `[0.5]`. Duelo lleva `debuff = challenged.tres` y `buff = triumph.tres` |
| `data/debuffs/stun.tres` | `DebuffData` | §4.2 |
| `data/debuffs/challenged.tres` | `DebuffData` | "Retado", `id = &"challenged"`, `effect = STATUS`, `duration = 6.0`, `max_stacks = 1`, `icon = crossed_swords.svg`, `icon_color = Color(0.85, 0.3, 0.6)` (magenta) |
| `data/buffs/triumph.tres` | `BuffData` | "Triunfo", `max_stacks = 3`, `stack_duration = 8.0`, `global = true`, `expires_all_stacks = true`, `MOVE_SPEED` 0.10 y `DAMAGE` 0.10 por stack, `icon = laurels.svg`, `icon_color = Color(0.35, 0.6, 1.0)` (azul) |
| `assets/icons/status/{knocked_out_stars,crossed_swords,laurels}.svg` | SVG | game-icons.net `delapouite/knocked-out-stars`, `lorc/crossed-swords` y `lorc/laurels`, CC BY 3.0, preparados como pide `status-icons.md` §2.3, con su fila en `SOURCE.md`. Si alguno no existe con ese nombre, se elige otro del sitio y se anota en §13 |
| `materials/vfx/wind_dust_material.tres` y `shockwave_material.tres` (existentes) | `StandardMaterial3D` | polvo y anillo de la Carga con el tierra registrado (ver §13) |
| `materials/vfx/block_spark_material.tres` | `StandardMaterial3D` | blanco, unshaded, aditivo, alpha ≤ 0.5 |
| `data/enemies/{verdugo,titan,colmena}_stats.tres` | `EnemyStats` | `stun_duration_scale = 0.3` |
| `data/classes/warrior/warrior_abilities.tres` | `AbilityCatalog` | `[shield_charge, parry]` |

Ningún Resource compartido se muta en runtime. Los valores de las mejoras se leen con `get_unique_value()`.

## 7. Interfaz pública (resumen)

```gdscript
# HealthComponent
@export var guard: ShieldGuard
func receive_hit_from(raw: float, attacker: Enemy) -> float

# ShieldGuard
signal blocked(amount: float, attacker: Enemy)
func raise(reduction: float, arc_degrees: float) -> void
func lower() -> void
func is_raised() -> bool
func absorb(raw: float, attacker: Enemy) -> float
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
func trails_while_casting(ability: AbilityComponent) -> bool

# AbilityComponent
signal struck(feel: StrikeFeel, enemies: Array[Enemy])
@export var guard: ShieldGuard
func report_strike(feel: StrikeFeel, enemies: Array[Enemy]) -> void
func set_cast_remaining(seconds: float) -> void

# StatsComponent
@export var buffs: BuffComponent

# BuffData
@export var global: bool
@export var expires_all_stacks: bool

# ShieldChargeAbility
static func find_contact(position: Vector3, push_direction: Vector3, others: Array[Enemy], self_index: int, contact_distance: float) -> int
```

## 8. Coordinación con Aflicción (ya en `main`)

- **`DebuffData.Effect`:** `SLOW` quedó último con valor 4; `STUN` se agrega detrás (5). AC894 ("`SLOW` vale 4") sigue valiendo.
- **`DebuffComponent.apply`:** el parámetro `duration` manda sobre `data.duration` en los dos `stack_mode`, y el reloj usa `ActiveDebuff.duration`. Sin el parámetro, Aflicción no cambia.
- **Congelado:** el aturdimiento reutiliza `get_speed_scale() == 0` (`frost-freeze.md`), así que un aturdido y un congelado se comportan igual en lo que no es cancelar la preparación.
- **Fuente "habilidad":** la Carga, "Martillo y yunque", la estocada de Contragolpe y el daño de Represalia pasan por `report_hit()`, así que cargan las Aflicciones de habilidad. `affliction_scale`: **Carga 1.5** (un golpe cada 7 s a varios enemigos) y **Parada 2.0** (golpes raros que exigen leer al enemigo). `affliction.md` y los tests que nombran "Estocada 1.0, Golpe veloz 1.0" se actualizan (§10).
- Una futura "Aflicción que aturde" debe aplicarlo con `Enemy.stun()` (respeta `stun_duration_scale` y cancela la preparación), no con `debuffs.apply()`.

## 9. Enmienda de la constitución (MINOR 4.21.0 → 4.22.0)

**Principio II:**
- Lista de blancos compartidos: se agregan **las chispas del bloqueo del escudo** (partículas blancas, unshaded, aditivas, alpha ≤ 0.5, duran décimas de segundo).
- Registro de colores no reservados: el tierra `Color(0.62, 0.52, 0.4)` también colorea el polvo y el anillo de la Carga de escudo; amarillo estrella `Color(1.0, 0.95, 0.55)` para el ícono de Aturdido; magenta `Color(0.85, 0.3, 0.6)` para el ícono de Retado; azul `Color(0.35, 0.6, 1.0)` para el ícono de Triunfo.

**Principio III:**
- Viñeta "Estados de entidades": se agrega el efecto **aturdido** (`STUN`): el enemigo se queda quieto y, si no resiste el control, cancela su preparación. La duración la pasa quien lo aplica y la escala el enemigo (`stun_duration_scale`; los bosses se aturden menos y no cancelan su ataque).
- Nueva viñeta **bloqueo frontal**: el daño que recibe el jugador de un enemigo trae a su atacante, y un `ShieldGuard` reduce el que llega dentro de un arco al frente. Arco y reducción son datos de quien lo levanta. Los agarres no se bloquean.
- Viñeta "Buffs": un buff puede ser **global** (sus modificadores de movimiento y daño se suman a los stats del jugador) y puede **vencer con todos sus stacks juntos**.

**Principio VII:**
- "Hit lag local": los golpes de **habilidad** no canalizados también pausan el clip del jugador, congelan y sacuden a los golpeados y sacuden la cámara, con valores por golpe en su config (`StrikeFeel`).
- Nueva viñeta "Estela": durante una habilidad, la estela del arma se ve solo mientras la hoja barre, si el behavior lo declara.

**Historial:** `4.22.0 (fecha de cierre): Principio II: chispas del bloqueo, polvo de la Carga y colores de Aturdido, Retado y Triunfo. Principio III: estado aturdido (STUN), bloqueo frontal con atacante del golpe y buffs globales. Principio VII: hit lag de los golpes de habilidad y estela solo mientras la hoja barre (ver warrior-abilities-rework.md).`

## 10. Tests existentes que cambian

35 archivos mencionan `THRUST`, `SWIFT_STRIKE` o sus datos. Criterio: **lo que verifican no cambia**; cambia qué habilidad usan.

| Tipo | Archivos | Cambio |
|---|---|---|
| Solo usan una habilidad del Guerrero para arrancar la run o equipar algo | `cooldown_hud_test`, `cooldown_clock_test`, `cooldown_timers_test`, `boss_hud_bar_test`, `input_prompts_test`, `pause_menu_test`, `harasser_test`, `boss_body_test`, `arena_waves_test`, `boss_challenge_run_test`, `berserker_run_test`, `character_class_run_test`, `upgrade_ban_run_test`, `card_ban_test`, `sheathe_test`, `sheathe_feel_test`, `weapon_mount_test`, `sword_swing_test`, `class_combat_identity_test`, `character_class_test`, `affliction_run_test` | `THRUST` → `SHIELD_CHARGE` y `SWIFT_STRIKE` → `PARRY` (constantes con la ruta nueva). Donde se contaba el catálogo del Guerrero (2), sigue siendo 2 |
| Mecánicas genéricas probadas con la Estocada o el Golpe veloz | `ability_component_test`, `upgrade_offer_test`, `upgrade_caps_test`, `ability_run_test`, `sandbox_run_test`, `unique_upgrade_run_test`, `dash_cancel_test`, `weapon_trail_test`, `hit_impact_abilities_test`, `affliction_loadout_test`, `affliction_data_test` | Pasan a la Carga o a la Parada (las dos son de toque). Los valores fijos (enfriamiento 4 → 7, daño 10 → 12, `affliction_scale` 1.0 → 1.5/2.0…) se leen de los `.tres`, no a mano, y se anotan en §13. `weapon_trail_test`: el caso "la estela emite en un lanzamiento" pasa a verificar la ventana (AC841) y que el Giro sigue igual (AC842). `hit_impact_abilities_test`: el caso "la Estocada no dibuja impacto" pasa a una habilidad con `shows_hit_impact = false` (el Tajo aéreo o un `AbilityData` de test) |
| Verifican el comportamiento de lo que se borra | `thrust_indicator_test`, `swift_strike_test`; los casos de Lacerante, Asesinato y Reset en `unique_upgrades_test` | **Se borran con la feature**. Lo genérico que cubrían (niveles de una única, `reset_cooldown`, `health.execute`) ya lo cubren Envainar, el Giro y `health_component_test`. Si algún caso queda sin cobertura, se reescribe con la Carga o la Parada y se anota |

La línea base de `main` tiene 15 fallas previas (Giro, alcance y estela del arma, oleadas, datos de clases, escudo del Guerrero); se vuelve a medir en el paso 1 del plan, porque `main` avanzó. La meta es cero fallas nuevas.

## 11. Criterios de aceptación

**Limpieza y catálogo**
- **AC801** `warrior_abilities.tres` lista exactamente `shield_charge.tres` y `parry.tres`, las dos `slot = BASIC`, y `WaveManager.offer_abilities()` ofrece esas dos al Guerrero.
- **AC802** No existen `data/abilities/thrust/`, `data/abilities/swift_strike/`, `thrust_ability.*` ni `swift_strike_ability.*`, y el `AnimationLibrary_sword` de `player.tscn` no tiene `thrust`, `thrust_recover`, `swift_strike` ni `swift_strike_recover`. Ningún `.gd`, `.tscn` ni `.tres` los referencia. `bleed.tres` sigue existiendo.
- **AC803** Durante cualquier fase de las dos habilidades, `PlayerAnimator` pide un clip del perfil del Guerrero (§4.8), nunca `idle`.

**Aturdimiento**
- **AC804** `DebuffData.Effect.STUN == 5` (y `SLOW` sigue en 4). `stun.tres` tiene `effect = 5`, `icon` = `knocked_out_stars.svg`, `icon_color = Color(1.0, 0.95, 0.55)`. El SVG tiene su fila en `SOURCE.md`.
- **AC805** `DebuffComponent.apply(data, p, 2.5)` deja 2.5 s aunque `data.duration` sea 1. Reaplicar con 1.0 cuando quedan 2 deja 2, y con 3.0 deja 3. `get_remaining_ratio()` usa la duración aplicada. Sin el tercer parámetro, todo como antes (los tests de debuffs y de Aflicción no cambian).
- **AC806** Un común aturdido tiene `get_speed_scale() == 0`, no se mueve ni gira (posición y `rotation.y` constantes, sin empuje), y vuelve a actuar al terminar.
- **AC807** Un común aturdido en `WINDUP` cancela el ataque, aunque sea `interruptible = false`: `is_attacking()` es falso, el aviso del piso está limpio y el coordinador ya no le cuenta el turno. Vale para `grunt`, `charger`, `leaper`, `harasser` y `shieldbearer`.
- **AC808** Un aturdido que estaba siendo empujado sigue deslizándose hasta frenar.
- **AC809** Un boss (Verdugo, Titán, Colmena) aturdido 1 s queda aturdido 0.3 s, no cancela su ataque y lo retoma en la misma fase y tiempo al terminar.
- **AC810** `stun_duration_scale = 0` no aplica el estado. Un enemigo muerto, desactivado o apareciendo no se aturde.
- **AC811** El ícono de Aturdido aparece en `EnemyStatusOverlay` (comunes) y en la fila de la barra del boss mientras dura, con su reloj.

**Bloqueo frontal**
- **AC812** `ShieldGuard.is_in_front`: con arco de 120°, un origen a 59° del frente cuenta, uno a 61° no y uno detrás no. Un origen en el mismo punto cuenta.
- **AC813** `receive_hit_from` con el guard levantado al 100 %, de frente: 0 de daño, sin `damaged` y `blocked` emitido con el golpe entero y el atacante. De espaldas: daño completo y sin `blocked`. Con 50 %: la mitad antes de la defensa.
- **AC814** Con iframes (dash), `receive_hit_from` devuelve 0 y **no** emite `blocked`.
- **AC815** Las 9 llamadas de daño de los enemigos al jugador usan `receive_hit_from` con el enemigo. Ningún comportamiento enemigo llama `target.health.receive_hit(`. Un agarre con el guard levantado sujeta al jugador igual.

**Carga de escudo**
- **AC816** Sin obstáculos, la Carga desplaza al jugador `HIT_RANGE` (5 m ± 0.1) en `travel_time` (0.4 s) hacia el enemigo más cercano, y el golpe de escudo cae en ese instante.
- **AC817** Durante el avance, un golpe frontal hace el 50 % y uno de atrás el 100 %. Terminado el avance, el guard está bajo.
- **AC818** Un enemigo en la franja de captura avanza con el jugador (sigue delante, a menos de `capture_depth` + su padding) y no recibe daño hasta el golpe de escudo.
- **AC819** Sin absorción, el golpe de escudo hace `12 + 0.10 × DAMAGE` (sin crítico, con defensa) a cada enemigo en `bash_range` × `HIT_WIDTH`, los empuja a `bash_knockback_speed`, emite un `enemy_hit` por cada uno y no aturde.
- **AC820** Absorción: tras un golpe frontal durante el avance, el golpe de escudo hace `absorb_damage_multiplier` × el daño de AC819 y aturde `stun_duration` a cada golpeado, con `empowered_feel`. Un golpe de atrás durante el avance no lo potencia.
- **AC821** Contra una pared, la Carga pasa al golpe de escudo apenas se frena. Contra un Escudero en guardia de frente o un boss, pasa al golpe al alcanzarlo.
- **AC822** Un empujado que choca contra una pared dentro de `impact_window` queda aturdido `stun_duration`. Uno que no choca, no. Uno que choca contra otro enemigo deja aturdidos a los dos. `find_contact` distingue pared (−1) de enemigo (índice) en casos puros.
- **AC823** Cada vigilado choca una sola vez y la lista se vacía al pasar `impact_window`.
- **AC824** "Martillo y yunque": en un choque entre enemigos, cada uno recibe `0.5 × daño de la Carga`, con `enemy_hit`. Sin la mejora, el choque no hace daño.
- **AC825** "Impulso": con 3 golpeados, el enfriamiento restante queda a la mitad justo después del golpe. Con 2, no cambia.
- **AC826** "Contundencia": niveles 1 y 2 dan 1.5 s y 2 s, tanto en los choques como en el golpe potenciado. `max_level = 2`.
- **AC827** Un dash durante la Carga la corta: el guard baja, los arrastrados dejan de recibir empuje y no hay golpe de escudo. El enfriamiento sigue corriendo.
- **AC828** El enfriamiento es 7 s desde la tecla. Las cartas de stats de la Carga respetan su `max_stacks` y el piso (`min_cooldown` 3).

**Parada**
- **AC829** Tocar E levanta el guard al 100 % con arco de 120° durante `CAST_DURATION` (0.35 s) y arranca el enfriamiento de 6 s. Durante la ventana el jugador no se mueve.
- **AC830** Fallida: sin golpes en la ventana, el guard baja a los 0.35 s, el lanzamiento dura 0.35 + `whiff_recovery` (0.75 s) con `shield_parry_whiff`, y el enfriamiento no se reduce.
- **AC831** Exitosa: un golpe frontal en la ventana hace 0 de daño, sin `damaged`, y deja el enfriamiento restante en `success_cooldown` (1.5 s). Un segundo golpe frontal en la misma ventana también se anula. El lanzamiento termina `success_recovery` después del final de la ventana, con `shield_parry_success`.
- **AC832** Un golpe de atrás en la ventana pega completo y no cuenta como éxito. Un golpe frontal después de la ventana pega completo.
- **AC833** Un dash corta la Parada en la ventana o en la recuperación: el guard baja y el enfriamiento sigue corriendo. Un agarre en la ventana sujeta al jugador y baja el guard.
- **AC834** Las cartas de la Parada: enfriamiento (−0.75 s, ×4, piso 3 s) y ventana (+0.05 s, ×2). Con 2 cartas de ventana, un golpe a los 0.42 s se anula.

**Mejoras de la Parada**
- **AC835** "Represalia": cada golpe anulado hace al atacante `valor × golpe` (niveles 1.0 / 1.5 / 2.0; con su defensa, sin crítico) con `enemy_hit`. Un atacante muerto o desactivado no recibe nada. `max_level = 3`.
- **AC836** "Contragolpe": el primer éxito deja el enfriamiento en 0, gira al jugador hacia el atacante y dispara la estocada: al cruzar `riposte_hit_time` hace `20 + 0.30 × DAMAGE` (con crítico según `CRIT_CHANCE`/`CRIT_DAMAGE`) en `HIT_RANGE` × `HIT_WIDTH` y empuja a `riposte_knockback_speed`. El lanzamiento dura `riposte_duration` desde el éxito. Un segundo golpe no dispara otra.
- **AC837** Durante la estocada el jugador es invulnerable, y al terminarla o cortarla (dash) deja de serlo.
- **AC838** "Duelo": el atacante de un golpe anulado queda Retado 6 s (ícono y reloj). Si muere Retado, el jugador gana 1 stack de Triunfo. Otra muerte de un Retado dentro de los 8 s suma un stack y reinicia el tiempo, hasta 3. A los 8 s sin muertes se pierden todos. Matar a un enemigo sin marca, o después de que la marca venció, no da nada.
- **AC839** Con Triunfo en N stacks, `StatsComponent.get_stat(MOVE_SPEED)` y `get_stat(DAMAGE)` valen la base × (1 + 0.1 × N), y vuelven a la base al vencer. Conmoción (no global) no cambia `get_stat`.

**Estela**
- **AC840** La estela del arma no emite en ningún momento de la Carga, ni en la Parada sin Contragolpe.
- **AC841** En la estocada de Contragolpe, la estela emite solo con el tiempo de la estocada en `[riposte_trail_start, riposte_trail_end]`.
- **AC842** El Giro (con su corte del dash) y Envainar siguen emitiendo como hoy.

**Feedback de impacto y VFX**
- **AC843** Un `struck` con `hitlag > 0` pausa el clip del jugador (`speed_scale == 0`) ese tiempo y después restaura la velocidad previa. Aplica `apply_hitlag` a cada golpeado y sacude la cámara con `shake_strength`. Un golpe del combo sigue igual (los tests de `bdo-combat-feel.md` no cambian).
- **AC844** Si el lanzamiento termina o se corta durante el hit lag de una habilidad, el clip se reanuda.
- **AC845** El golpe de escudo y la estocada de Contragolpe disparan el impacto de golpe de `HitImpactVfx` (`shows_hit_impact = true`).
- **AC846** La Carga muestra polvo durante el avance y el anillo al golpear (más grande si está potenciada). La Parada y la absorción dan una chispa por golpe bloqueado. Todos usan nodos creados al cargar, sin crear nodos en runtime.

**Cuerpo, armas y Aflicción**
- **AC847** Los clips `shield_charge`, `shield_bash`, `shield_parry`, `shield_parry_success`, `shield_parry_whiff` y `shield_riposte` existen en el perfil del Guerrero, y sus eventos coinciden con `bash_hit_time`, `raise_time`, `riposte_hit_time`, `riposte_trail_start` y `riposte_trail_end`. Durante las dos habilidades `holds_weapon_in_hand()` es `true` y `WeaponMount` sigue la mano.
- **AC848** AC751 vale en cada cuadro muestreado de los seis clips nuevos: el escudo no atraviesa el torso ni pasa detrás de la espalda, y la punta de la espada no toca el piso.
- **AC849** `affliction_scale` es 1.5 en `shield_charge.tres` y 2.0 en `parry.tres`, y un golpe de escudo carga una Aflicción de habilidad `base × 1.5 × (1 + ACUMULACIÓN)`.

## 12. Plan

Cada paso deja el proyecto abriendo y la suite sin fallas nuevas respecto de la línea base.

1. **Entorno:** copia en el scratchpad, import, y correr la línea base de esta rama (ya con `main`) para guardar la lista de fallas.
2. **Aturdimiento:** `Effect.STUN`, `duration` en `apply`/`ActiveDebuff`, `is_stunned()`, `get_speed_scale()` en 0, `EnemyStats.stun_duration_scale`, `Enemy.stun()`/`is_stunned()`/`get_push_speed()`, el hook `stunned()` en los cinco comunes, los `.tres` de los bosses, `stun.tres` y el SVG (bajado, preparado, `.import` desde la copia y fila en `SOURCE.md`). Tests AC804–AC811.
3. **Bloqueo frontal:** `ShieldGuard`, `receive_hit_from` y las 9 llamadas; el nodo en `player.tscn`. Tests AC812–AC815.
4. **Genéricos:** `StrikeFeel`, `struck`/`report_strike`, `HitstopComponent` generalizado, `trails_while_casting()`, `cast_duration()`, `set_cast_remaining()`, export `guard`; buffs globales (`DAMAGE`, `global`, `expires_all_stacks`, `StatsComponent.buffs`). Tests AC839 (con un buff de test), AC842–AC844.
5. **Clips:** poses `SHIELD_BASH`/`SHIELD_BLOCK` y los seis clips en `warrior_profile.gd`, con una hoja de capturas de cada uno para revisarlas. Tests AC847–AC848.
6. **Carga de escudo:** config, behavior, escena, VFX, `.tres`, cartas y únicas. Tests AC816–AC828, AC840 (parte), AC845–AC846 (parte), AC849 (parte).
7. **Parada:** config, behavior, escena, VFX, `.tres`, cartas, únicas, Retado, Triunfo y sus SVG. Tests AC829–AC838, AC840–AC841, AC845–AC846 (parte), AC849 (parte).
8. **Cambio de catálogo y borrado:** `warrior_abilities.tres` pasa a las nuevas. Se adaptan los tests de §10 y `affliction.md`, y se borran Estocada, Swift Strike, sus clips y sus tests. Tests AC801–AC803.
9. **Cierre:** enmienda de la constitución (§9) y `CLAUDE.md` (dónde se ajustan la Carga, la Parada, el aturdimiento, `ShieldGuard`, `StrikeFeel` y los buffs globales; specs recientes). Suite completa, import, smoke test (`--quit-after 300` y la arena), capturas de las dos habilidades en la arena, checklist §14 y estado **Implementada**. Sin merge a `main` hasta que lo pida el responsable.

## 13. Notas de implementación

**Desvíos menores respecto del texto aprobado:**

1. **Carta de enfriamiento de la Carga: −1 s × 4** (no −0.75 s). Con −0.75 × 4 desde 7 s quedaba en 4 s y no llegaba al piso de 3 s; AC119 exige que el tope caiga justo en el piso (Principio III: no desperdiciar copias).
2. **Materiales:** el polvo de la Carga usa `wind_dust_material.tres` y el anillo, `shockwave_material.tres` (el tierra registrado, ya existentes) en lugar de un `shield_dust_material.tres` nuevo. Las chispas usan un material nuevo, `materials/vfx/block_spark_material.tres` (blanco aditivo, alpha 0.5).
3. **Recuperación de la Carga:** el golpe de escudo deja siempre `CAST_DURATION − travel_time` (0.3 s) de lanzamiento, aunque llegue antes por una pared o un boss (antes el resto del lanzamiento dependía de cuándo chocaba).
4. **Arrastre:** los arrastrados se recalculan en cada paso (los que están en la franja). Uno que se adelanta frena por su fricción hasta que el escudo lo alcanza de nuevo, así no se aleja del jugador.
5. **`shield_parry_success` dura 0.4 s** (no 0.15 s): el lanzamiento sigue terminando a los 0.15 s de la ventana y el resto del clip es la cola libre de `PlayerAnimator` (volver al reposo en 0.15 s se veía brusco).
6. **Brazo de la espada en la Carga:** `CHARGE_BLADE` (la hoja adelante y a la derecha, alta). Con el brazo de reposo y el torso volcado, la punta tocaba el piso (AC848).
7. **`AbilityComponent.advance()`:** si el behavior llama a `set_cast_remaining()` dentro de `channel()`, ese paso ya no se descuenta del nuevo resto.
8. **Eventos de los clips:** nombres propios (`bash`, `raise`, `riposte`, `trail_on`, `trail_off`) que `_anim_event` ignora, para no disparar los eventos del combo.

**Tests viejos adaptados** (lo que verifican no cambia):

- Constantes `THRUST` → `SHIELD_CHARGE` y `SWIFT_STRIKE` → `PARRY` en 20 suites (§10). Valores que salen de los `.tres` nuevos: `ability_component_test` (golpe base 10.75 → 13.5, con mejoras 16.5 → 19.25, con +4 de DAÑO 10.95 → 13.9; enemigos a 1.5 m porque el rectángulo del golpe es de 2 m; AC50 con las distancias del golpe de escudo; AC52 con la Parada, que no mueve al jugador, y 40 cuadros de espera porque dura 0.75 s), `ability_run_test` (+5 → la carta de daño de la Carga), `affliction_loadout_test` AC865 (55 → 72.5: escala 1.5), `affliction_data_test` AC857 (escalas 1.5 y 2.0), `sandbox_run_test` (Lacerante → Contundencia: "(10 → 35)" → "(12 → 32)", "(2 %/s)" → "(2.0 s)", "Nv 3" → "Nv 2"), `unique_upgrade_run_test` (Reset → Contragolpe, Asesinato → Represalia: "(20 %)" → "(150 %)"), `boss_challenge_run_test` AC154/AC155 (tres cartas doradas en lugar de dos), `boss_body_test` AC149 (el golpe de escudo, enemigos a 1.5 m), `status_icons_test` AC908 (8 → 11 SVG).
- Reescritos porque su mecanismo ya no lo usa ninguna habilidad: `weapon_mount_test` AC603 (un barrido del `SwordSwing` toma el pivote; las habilidades del Guerrero dejan la espada en la mano, AC847), `dash_cancel_test` AC366 (copia en memoria de la Carga con `dash_cancels_cast = false`), `hit_impact_abilities_test` AC938 (copia en memoria de la Parada sin `shows_hit_impact`), `upgrade_offer_test` AC54 (cada carta de la Carga mejora un stat distinto), `weapon_trail_test` AC216 (los casos de Estocada y Golpe veloz pasan a `warrior_abilities_trail_test.gd`).
- Borrados con lo que verificaban: `thrust_indicator_test.gd`, `swift_strike_test.gd`, AC95–AC99 de `unique_upgrades_test` (Reset, Asesinato, Lacerante; AC105 pasa a las mejoras de la Parada), AC125 de `upgrade_caps_test` (tope del Golpe veloz) y AC93 de `sword_swing_test` (la Estocada tomaba la espada con el `SwingPlayer`).
- `test/effects/readable_damage_numbers_test.gd` (de `readable-damage-numbers.md`, otra sesión en paralelo): su AC997 usaba la Estocada como habilidad sin impacto; ahora usa una copia en memoria de la Parada sin `shows_hit_impact`.

**Tests nuevos:** `components/stun_test.gd` (AC804–AC811), `components/shield_guard_test.gd` (AC812–AC815), `components/abilities/shield_charge_test.gd` (AC816–AC828, AC846, AC849), `components/abilities/parry_test.gd` (AC829–AC838, AC846), `components/abilities/warrior_abilities_trail_test.gd` (AC840–AC842), `components/ability_strike_feel_test.gd` (AC839, AC843–AC845), `resources/warrior_abilities_test.gd` (AC801–AC803, AC847) y AC848 en `entities/player/warrior_sword_and_shield_test.gd`.

**Íconos:** los tres propuestos existen en game-icons.net (`delapouite/knocked-out-stars`, `lorc/crossed-swords`, `lorc/laurels`).

**Cierre (2026-09-27):** import sin errores; smoke test del menú y de la arena (`--quit-after 300`) sin errores; capturas de los seis clips revisadas (lateral y de tres cuartos). Suite completa: 1074 casos, 34 fallas, todas de la línea base de esta rama medida antes de empezar (33, no 15: `main` avanzó; Giro, Tajo aéreo, alcance y estela del arma, dash, oleadas, datos de clases y escudo del Guerrero), más `spin_golden_upgrades_test` AC294, que falló una vez en la corrida completa y pasa sola (2 de 2 en la copia base y en la de trabajo) y en la corrida de `components/abilities`: es intermitente y no toca código de esta spec. AC751 sigue fallando solo por los cuadros previos de `dash` y `sprint`; ninguno de los clips nuevos.

## 14. Checklist de review (constitución)

- [x] **Identidad (I):** combate (apertura con posicionamiento y absorción; parada de riesgo y recompensa).
- [x] **Arte (II):** primitivas y partículas; el blanco solo en chispas translúcidas y breves (enmienda); los SVG con `SOURCE.md`; materiales `.tres` compartidos.
- [x] **Datos (III):** tiempos, distancias, arcos, reducciones, hit lag, buffs y VFX en configs `.tres`; las únicas con `max_level` y valores por nivel; sin mutar Resources compartidos.
- [x] **GDScript (IV):** tipado estricto; `_physics_process` delgados.
- [x] **Performance (V):** pools de VFX creados al cargar; la vigilancia de choques recorre el registro sin allocations; los buffs globales se suman sin allocations.
- [x] **Input (VI):** solo `ability_basic` (toque), sin acciones nuevas.
- [x] **Combate (VII):** hit lag local sin `Engine.time_scale`; auto-apuntado al más cercano; estela solo mientras la hoja barre; los bosses se aturden menos y no cancelan su ataque.
- [x] **Calidad:** sin fallas nuevas respecto de la línea base; sin warnings de tipado nuevos.
