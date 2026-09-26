# Tipos de enemigo: Embestidor, Saltador, Hostigador y Escudero

- **Estado:** Implementada (2026-09-26, 482 tests GdUnit4: 474 en verde y los mismos 8 fallos previos ajenos a esta spec, ver `enemy-attack-telegraph.md`; 0 orphans; tests de niveles repetidos 3 veces sin fallos intermitentes; import y smoke test de la arena sin errores; captura revisada)
- **Constitución:** `docs/constitution.md` **v4.2.0**, sin enmienda (ver *Arte*)
- **Pilar (Principio I):** Combate + Supervivencia.
  - **Combate:** cada tipo pide una respuesta distinta. Al Embestidor se lo esquiva hacia el costado, al Saltador se le sale del lugar donde va a caer, al Hostigador se lo encara sin darle la espalda y al Escudero se lo rodea o se le pega cuando baja la guardia.
  - **Supervivencia:** la mezcla de tipos por oleada obliga a priorizar a quién atacar primero.
- **Tipo:** feature. Segunda de la hoja de ruta: `enemy-attack-telegraph` → **`enemy-types`** → `enemy-group-ai` → `boss-verdugo` → `boss-titan` → `boss-colmena`.
- **Dependencias:** `enemy-attack-telegraph.md` (`EnemyBehavior`, `EnemyAttackData`, manos), `enemy-levels.md`, `enemy-rage.md`.

## Objetivo

1. Cuatro tipos nuevos, cada uno con su propio `EnemyBehavior`, sus stats y sus ataques en `.tres`. Todos usan la misma escena `enemy.tscn`: cuerpo gris y dos manos.
2. **Mezcla por oleada:** cada tipo tiene un peso, una primera oleada en la que aparece y un máximo por oleada. Las oleadas normales mezclan tipos; las de boss no cambian.
3. El **Bruto** (grunt, de `enemy-attack-telegraph`) sigue siendo la base y el tipo de respaldo.

## Los cuatro tipos

Los tiempos y distancias son los valores iniciales de los `.tres`, a nivel 1. `Mult.` multiplica el daño escalado del enemigo, como en `enemy-attack-telegraph`.

### Embestidor (`charger`): carga en línea recta

| Vida | Daño | Defensa | Velocidad | Aparece en | Peso | Máx./oleada |
|---|---|---|---|---|---|---|
| 60 | 10 | 2 | 3.0 m/s | oleada 2 | 2 | 2 |

1. **Perseguir** hasta quedar entre `min_trigger_range` (3 m) y `trigger_range` (8 m) del jugador. Si está más cerca, se aleja para tomar distancia.
2. **Preparación** (0.8 s): se frena y gira hacia el jugador a 180°/s. Las dos manos se van atrás y abajo, como tomando impulso. Al terminar, **fija la dirección** de la carga.
3. **Carga:** avanza recto a `charge_speed` (13 m/s) hasta recorrer `charge_distance` (9 m). No gira. La hitbox rodea el cuerpo (radio 1.0 m, arco 360°) y pega una sola vez, con `Mult.` 2.0. Atraviesa al jugador, porque los enemigos no chocan contra el jugador (capas de colisión actuales).
4. **Recuperación:** 0.9 s quieto, o `wall_stun_time` (2.0 s) si chocó contra una pared. Las manos caen, como aturdido. Es la ventana de castigo.
5. Después espera `attack_interval` (1.2 s).
6. No lo interrumpe el empuje en ninguna fase.

### Saltador (`leaper`): cae sobre el jugador

| Vida | Daño | Defensa | Velocidad | Aparece en | Peso | Máx./oleada |
|---|---|---|---|---|---|---|
| 50 | 9 | 1 | 3.2 m/s | oleada 5 | 2 | 2 |

1. **Perseguir** hasta quedar entre `min_trigger_range` (3.5 m) y `trigger_range` (8 m). Si está más cerca, se aleja.
2. **Preparación** (0.7 s): agachado, con las dos manos abajo y atrás. Gira a 120°/s. Al terminar, **fija el punto de caída**: donde está el jugador en ese momento, a `max_leap_distance` (8 m) como máximo.
3. **Salto:** parábola hasta el punto fijado en `leap_time` (0.8 s), con altura máxima `leap_height` (2.0 m). Usa `move_and_slide`, así que una pared lo frena. Mientras vuela, las manos quedan arriba.
4. **Impacto:** al tocar el suelo, un solo chequeo en círculo alrededor de donde cayó (radio 2.0 m, arco 360°), con `Mult.` 2.0. Las manos golpean hacia abajo.
5. **Recuperación:** 1.0 s quieto. Después espera `attack_interval` (1.5 s).
6. Interrumpible solo durante la preparación.

### Hostigador (`harasser`): orbita y castiga descuidos

| Vida | Daño | Defensa | Velocidad | Aparece en | Peso | Máx./oleada |
|---|---|---|---|---|---|---|
| 35 | 7 | 0 | 4.5 m/s | oleada 3 | 2 | 2 |

1. **Orbitar:** se acerca hasta `orbit_radius` (4 m) y lo rodea. Elige sentido horario o antihorario al activarse y lo invierte cada `orbit_flip_time` (2.5 s) o si choca contra algo.
2. **Apertura:** ataca cuando se cumple alguna de estas condiciones, siempre que esté a ≤ `trigger_range` (5 m):
   - el jugador le da la espalda: el ángulo entre hacia dónde mira el jugador y la dirección hacia el Hostigador es mayor que `back_angle` (110°);
   - el jugador atacó hace menos de `opening_window` (0.4 s): ataque básico o habilidad;
   - pasaron `max_patience` (4 s) sin apertura. Así un jugador que lo encara siempre no lo deja orbitando para siempre.
3. **Preparación** (0.3 s, corta): una mano atrás.
4. **Estocada:** sale disparado hacia el jugador a `lunge_speed` (14 m/s), recorriendo como máximo `lunge_distance` (4.5 m) y frenando a 1.0 m del jugador. Hitbox en arco de 60°, alcance 1.6 m, `Mult.` 1.8, una mano adelante.
5. **Recuperación:** 0.6 s quieto. Después espera `attack_interval` (1.2 s) mientras vuelve a orbitar.
6. Interrumpible solo durante la preparación.

### Escudero (`shieldbearer`): se cubre de frente

| Vida | Daño | Defensa | Velocidad | Aparece en | Peso | Máx./oleada |
|---|---|---|---|---|---|---|
| 90 | 12 | 6 | 2.2 m/s | oleada 6 | 1 | 1 |

1. **Guardia:** mientras persigue o espera, las dos manos quedan juntas adelante, a la altura del pecho (`guard_offset`). Gira hacia el jugador como máximo a `guard_turn_speed` (100°/s), así que se lo puede rodear. Si el jugador está dentro del arco frontal `block_arc` (140°):
   - los golpes le hacen `block_reduction` (80 %) menos daño, aplicado con `HealthComponent.damage_reduction`, que ya existe;
   - **el empuje no lo mueve.**
2. **Golpe de escudo:** preparación 0.8 s (manos atrás), golpe 0.2 s (arco de 100°, alcance 2.2 m, `Mult.` 1.5, las dos manos adelante) y recuperación 1.0 s.
3. **Guardia baja:** desde la preparación hasta `guard_down_time` (1.2 s) después de la recuperación, recibe daño completo y el empuje sí lo mueve. Las manos quedan abajo a los costados.
4. Después espera `attack_interval` (1.5 s). No es interrumpible.
5. La defensa (6) y la fricción del empuje (60) son altas.

## Mezcla por oleada

- **`EnemySpawnEntry`** (Resource nuevo): `stats`, `weight`, `first_wave` y `max_per_wave`.
- **`WaveConfig.enemy_types: Array[EnemySpawnEntry]`**: Bruto (peso 4, oleada 1, máx. 5), Embestidor, Hostigador, Saltador y Escudero con los valores de las tablas.
- **Elección:** por cada uno de los `enemies_per_wave`, un sorteo ponderado entre los tipos que ya aparecen en esa oleada (`first_wave` ≤ oleada) y no llegaron a su máximo. Si ninguno califica, sale un Bruto, así la oleada siempre tiene `enemies_per_wave` enemigos.
- La elección es una función pura, `EnemySpawnTable.pick(entries, wave, counts, roll) -> EnemySpawnEntry`, y `WaveManager` le pasa su `_rng`.
- **Pools:** un `EnemyPool` por tipo, con `@export var spawn_entry: EnemySpawnEntry` (tamaño = `max_per_wave`), en el mismo estilo que `challenge`. `WaveManager.pool` pasa a ser `pools: Array[EnemyPool]`. `arena.tscn` gana cuatro pools.

## Arte (sin enmienda)

Todos siguen siendo **cápsula gris + dos esferas grises**. Los tipos se distinguen por:
- **Pose de las manos:**
  - Embestidor: manos bajas y adelante, como cuernos.
  - Saltador: manos altas.
  - Hostigador: una mano adelante, en posición de esgrima.
  - Escudero: las dos juntas al frente.
- **Tamaño:**
  - `body_scale`: Hostigador 0.85, Escudero 1.2, el resto 1.
  - Tamaño de las manos (`EnemyHandsConfig.hand_scale`, nuevo): Escudero 1.4, Embestidor 1.2.

  Todo es escala uniforme; la colisión sigue siendo una cápsula.

Cada tipo tiene su propio `EnemyHandsConfig` (`EnemyStats.hands_config`, nuevo), que `Enemy` asigna a `Hands` en `_ready`.

## Estructura de nodos

No hay nodos nuevos en `enemy.tscn`. Cada tipo trae su comportamiento como escena:

```
components/enemies/
├─ enemy_behavior.gd, melee_behavior.gd/.tscn   (existentes)
├─ charger_behavior.gd/.tscn
├─ leaper_behavior.gd/.tscn
├─ harasser_behavior.gd/.tscn
└─ shieldbearer_behavior.gd/.tscn   (extiende MeleeBehavior: agrega guardia)
```

## Resources y datos

- **`EnemyAttackData`** se reutiliza tal cual para la hitbox de cada ataque (alcance, arco, tiempos, manos). Los datos propios de cada tipo van en subclases:
  - `ChargeAttackData`: `min_trigger_range`, `charge_speed`, `charge_distance` y `wall_stun_time`.
  - `LeapAttackData`: `min_trigger_range`, `max_leap_distance`, `leap_time` y `leap_height`.
  - `LungeAttackData`: `lunge_speed`, `lunge_distance` y `stop_distance`.
  - `HarasserConfig`: `orbit_radius`, `orbit_flip_time`, `back_angle`, `opening_window` y `max_patience`.
  - `GuardConfig`: `block_arc`, `block_reduction`, `guard_turn_speed`, `guard_down_time` y `guard_offset`.
- **`EnemyStats`** suma `hands_config: EnemyHandsConfig` y `behavior_config: Resource` (el `HarasserConfig` o el `GuardConfig` de ese tipo; vacío en los demás).
- **Datos nuevos:**
  - `data/enemies/<tipo>_stats.tres` (con `level_growth` como el Bruto).
  - `data/enemies/attacks/<tipo>_*.tres`.
  - `data/enemies/hands/<tipo>_hands.tres`.
  - `data/enemies/spawn/<tipo>_spawn.tres`.

## Interfaz pública

- `Enemy` suma:
  - `move_with_velocity(horizontal: Vector3, delta)`: para cargas y estocadas.
  - `launch(vertical_speed: float)`: para el salto.
  - `is_airborne()` y `hit_wall()`: esta última envuelve `is_on_wall()`.
  - `apply_knockback()` consulta `behavior.resists_knockback(direction) -> bool` antes de aplicar el empuje (el Escudero de frente devuelve `true`).
- `EnemyBehavior` suma `resists_knockback(direction) -> bool`, que por defecto devuelve `false`.
- **`Player` suma `get_facing() -> Vector3`**, que lee `Visual`, y la señal `attack_performed`, emitida por el ataque básico (`AttackComponent.attacked`) y por el inicio de cada habilidad (`AbilityComponent.cast_started`). El Hostigador se conecta a esa señal al activarse y se desconecta al cambiar de objetivo.
- `EnemySpawnTable.pick(...)`: estática y pura.

## Criterios de aceptación (AC412–AC439, reservados)

**Mezcla** (`test/resources/enemy_spawn_table_test.gd`, `test/levels/arena_waves_test.gd`):
- **AC412:** `pick` solo devuelve tipos con `first_wave` ≤ oleada. En la oleada 1 siempre sale un Bruto.
- **AC413:** `pick` respeta el peso: con `roll` en los extremos y en los cortes de peso, devuelve el tipo esperado.
- **AC414:** un tipo que llegó a su `max_per_wave` no sale. Si ningún tipo califica, sale un Bruto.
- **AC415:** en la arena, toda oleada normal tiene `enemies_per_wave` enemigos vivos y ningún tipo supera su máximo (oleadas 1 a 8 con semilla fija). Las oleadas de boss no cambian.

**Embestidor** (`test/entities/enemy/charger_test.gd`):
- **AC416:** a 5 m del jugador empieza la preparación. A 2 m primero se aleja y no carga.
- **AC417:** si el jugador se corre después de la preparación, la carga sigue en la dirección fijada (no hay daño).
- **AC418:** con el jugador en la línea, pega una sola vez (10 × 2 − 3 = 17) y sigue de largo.
- **AC419:** la carga recorre como máximo `charge_distance`.
- **AC420:** si choca contra una pared, queda `wall_stun_time` quieto. Si no, `recovery_time`.

**Saltador** (`test/entities/enemy/leaper_test.gd`):
- **AC421:** el punto de caída se fija al final de la preparación. Si el jugador se aleja más de 2 m de ese punto durante el salto, no hay daño.
- **AC422:** si el jugador queda dentro del radio del impacto, recibe 9 × 2 − 3 = 15 una sola vez.
- **AC423:** el salto supera la altura del cuerpo (se eleva más de 1.5 m) y cae en ≈ `leap_time`.
- **AC424:** el salto no supera `max_leap_distance` aunque el jugador esté más lejos.
- **AC425:** un empuje durante la preparación la cancela; durante el salto no.

**Hostigador** (`test/entities/enemy/harasser_test.gd`):
- **AC426:** sin apertura, orbita a `orbit_radius` ± 0.5 m y no ataca antes de `max_patience`.
- **AC427:** si el jugador le da la espalda (más de `back_angle`), empieza la preparación.
- **AC428:** después de un ataque básico del jugador, ataca dentro de `opening_window`.
- **AC429:** a los `max_patience` segundos sin apertura, ataca igual.
- **AC430:** la estocada se frena a `stop_distance` del jugador y pega 7 × 1.8 − 3 = 9.6 una vez.
- **AC431:** `Player.get_facing()` coincide con −Z de `Visual` y `attack_performed` se emite con el ataque básico y con el inicio de una habilidad.

**Escudero** (`test/entities/enemy/shieldbearer_test.gd`):
- **AC432:** con el jugador de frente, un golpe hace el 20 % del daño que haría sin guardia.
- **AC433:** con el jugador detrás (fuera de `block_arc`), el golpe hace el daño completo.
- **AC434:** de frente, el empuje no lo mueve; detrás, sí.
- **AC435:** durante el golpe de escudo y `guard_down_time` después, el daño es completo aunque el jugador esté de frente.
- **AC436:** gira a `guard_turn_speed` como máximo: si el jugador se corre rápido detrás de él, queda fuera del arco.

**Comunes:**
- **AC437:** cada tipo escala con el nivel (`level_growth`) y con rage, igual que el Bruto.
- **AC438:** cada tipo aplica su `hands_config` y su `body_scale`: las manos y el cuerpo tienen el tamaño de sus datos.
- **AC439:** reutilizar un enemigo del pool en pleno ataque (`deactivate` + `activate`) lo devuelve al estado inicial, en todos los tipos.

## Plan de implementación

1. Reservar AC412–AC439 en `CLAUDE.md` (próximo libre → AC440).
2. `EnemySpawnEntry`, `EnemySpawnTable.pick` y `WaveConfig.enemy_types`. Tests AC412–AC414.
3. `EnemyPool.spawn_entry`, `WaveManager.pools` y los pools en `arena.tscn` (primero solo con el Bruto, así la arena sigue igual). Test AC415.
4. `Enemy`: `move_with_velocity`, `launch`, `is_airborne`, `hit_wall` y el veto de empuje. `EnemyStats.hands_config`/`behavior_config`. `EnemyHandsConfig.hand_scale`.
5. `Player.get_facing()` y `attack_performed` (releer `player.gd` antes: lo editan otras sesiones). Test AC431.
6. Escudero (`shieldbearer_behavior`, datos). Tests AC432–AC436.
7. Embestidor (`charger_behavior`, datos). Tests AC416–AC420.
8. Saltador (`leaper_behavior`, datos). Tests AC421–AC425.
9. Hostigador (`harasser_behavior`, datos). Tests AC426–AC430.
10. Sumar los 4 tipos a `wave_config.tres`. Tests AC437–AC439.
11. Suite completa, smoke test y captura de cada tipo en plena acción sobre la copia del scratchpad. Checklist, spec **Implementada** y `CLAUDE.md` (próximo AC libre y "Dónde se ajusta").

## Review (checklist de la constitución)

- [x] **I.** Combate y Supervivencia, como se explica arriba.
- [x] **II.** Solo cápsulas y esferas grises con `enemy_material.tres`. Los tipos se distinguen por escala uniforme y pose de las manos.
- [x] **III.** Todos los valores en `.tres`. `EnemySpawnTable.pick` e `is_hit` son puros.
- [x] **IV.** Tipado estático.
- [x] **V.** No se asigna memoria por frame: los pools se crean al cargar y los contadores de la mezcla usan buffers reutilizados.
- [x] **VI.** Sin input nuevo.

## Notas

- Los valores numéricos son un punto de partida para probar jugando y se ajustan en los `.tres` sin tocar código.
- El Hostigador y el Embestidor pueden atravesar al jugador porque los enemigos no chocan contra él (máscara actual). Esto no cambia.

### Implementación: ajustes respecto de lo aprobado

- **Saltador:** `leap_time` y `leap_height` definen juntos la parábola, así que el salto usa su propia gravedad (`LeapAttackData.get_leap_gravity()`, aplicada con `Enemy.launch(speed, gravity_scale)`). Con 0.7 s y 2.5 m la caída era casi vertical, por eso quedó en 0.8 s y 2.0 m. AC423 pide más de 1.5 m de altura.
- **Escudero:** la pose de guardia es el reposo de sus manos (`shieldbearer_hands.tres`), así que `GuardConfig.guard_offset` pasó a ser `guard_down_offset`, la pose con la guardia baja.
- **Poses extra de las manos:** `ChargeAttackData.stun_hand_offset` (aturdido) y `LeapAttackData.air_hand_offset` (en el aire). Se muestran con `EnemyHands.play_pose()`, y el config por tipo se aplica con `EnemyHands.apply_config()`.
- **Empuje:** el Embestidor lo ignora mientras carga y el Saltador mientras está en el aire, con `resists_knockback`. Así el empuje no corta la carga ni el salto, como pide la spec.
- **"Pared" del Embestidor:** es `is_on_wall()`, que también se activa al chocar contra otro enemigo. Chocar contra un aliado también lo aturde. Se deja así porque suma a la lectura del combate.
- **Tests viejos adaptados:**
  - `test_ac151_waves_3_and_5_are_grunts` pasó a llamarse `…_are_regular_waves` y verifica que los enemigos sean de la mezcla y no bosses.
  - AC342 y AC344 calculan el valor esperado con los stats de cada enemigo (`_raged(stats, …)`), porque las oleadas ya no son solo de Brutos.
- **Lectura visual (a revisar jugando):** en la captura cenital los tipos se distinguen poco a la distancia de la cámara. Se ven sobre todo el tamaño y la pose de las manos. Si en juego cuesta distinguirlos, la próxima mejora es una enmienda del Principio II para dar siluetas propias (proporciones del cuerpo o una pieza primitiva por tipo).
