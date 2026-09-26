# Ataques enemigos con aviso: manos y hitbox

- **Estado:** Implementada (2026-09-26, 453 tests GdUnit4: 445 en verde y 8 fallos previos ajenos a esta spec, ver Notas; 0 orphans; import y smoke test de la arena sin errores; captura revisada)
- **Constitución:** `docs/constitution.md` **v4.1.0** → **v4.2.0** (enmienda MINOR, ver abajo)
- **Pilar (Principio I):** Combate. El golpe enemigo pasa a ser algo que se **lee** (las manos se echan atrás antes de pegar), que se **esquiva** (hitbox en arco que se evita con los iframes del dash o saliendo del alcance) y que se **castiga** (recuperación con el enemigo quieto y expuesto).
- **Tipo:** feature. Primera de la hoja de ruta de enemigos: `enemy-attack-telegraph` → `enemy-types` → `enemy-group-ai` → `boss-verdugo` → `boss-titan` → `boss-colmena`.
- **Dependencias:** `enemy-levels.md`, `enemy-rage.md` (el intervalo de ataque sigue siendo un stat escalable).

## Objetivo

Antes, cada enemigo en rango llamaba a `receive_hit()` cada `attack_interval`: era daño directo, sin aviso ni hitbox. Ahora:

1. El enemigo pasa su lógica a un **comportamiento intercambiable** (`EnemyBehavior`), instanciado desde `EnemyStats.behavior`, igual que `AbilityData.behavior` en las habilidades.
2. Cada ataque (`EnemyAttackData`) tiene 3 fases: **preparación → golpe → recuperación**, y después el enemigo espera `attack_interval`.
3. Dos **manos flotantes** (`SphereMesh` grises) muestran el ataque: en reposo flotan, en la preparación retroceden y en el golpe salen disparadas hacia delante.
4. El daño sale de una **hitbox en arco** que se evalúa durante el golpe, con un impacto como máximo por ataque.

Bruto, Gemelo y Coloso pasan todos a `MeleeBehavior` con su propio ataque. Gemelo y Coloso lo usan hasta que los reemplacen `boss-titan` y `boss-colmena`.

## Estructura de nodos

```
Enemy (CharacterBody3D, enemy.gd)
├─ CollisionShape3D, Body (+RageAura), HealthComponent, DebuffComponent, HealthBar   (sin cambios)
├─ Hands (Node3D, components/enemies/enemy_hands.gd, escala = body_scale)
│  ├─ LeftHand  (MeshInstance3D, SphereMesh r = 0.2, enemy_material.tres)
│  └─ RightHand (MeshInstance3D, SphereMesh r = 0.2, enemy_material.tres)
└─ Behavior (instanciado en _ready desde stats.behavior; p. ej. melee_behavior.tscn)
```

## Resources y datos

- **`resources/enemy_attack_data.gd`** (`EnemyAttackData`):
  - `damage_multiplier` (× el `damage` ya escalado).
  - `windup_time`, `active_time` y `recovery_time`.
  - `trigger_range`: distancia a la que empieza la preparación.
  - `hit_range` y `hit_arc_degrees`.
  - `windup_turn_speed` (°/s).
  - `interruptible`.
  - `hands` (`BOTH`/`LEFT`/`RIGHT`/`ALTERNATE`).
  - `hand_windup_offset` y `hand_strike_offset`: offsets de la mano derecha respecto del reposo; la izquierda espeja x.
  - Funciones puras: `is_hit(origin, facing, point, padding)` y `get_total_time()`.
- **`resources/enemy_hands_config.gd`** (`EnemyHandsConfig`): `rest_offset`, `bob_amplitude`, `bob_frequency` y `return_time`. El `.tres` es `data/enemies/enemy_hands_config.tres`.
- **`EnemyStats`** suma `behavior: PackedScene` y `attacks: Array[EnemyAttackData]` (se recorren en orden). `attack_interval` pasa a ser la pausa entre el fin de la recuperación y la próxima preparación. `attack_range` es la distancia a la que el enemigo deja de perseguir.
- **Ataques** en `data/enemies/attacks/`:

  | Ataque | Mult. | Prep. / golpe / recup. | `attack_interval` | Trigger / alcance / arco | Giro | Interrumpible | Manos |
  |---|---|---|---|---|---|---|---|
  | `grunt_punch` | 1.5 | 0.5 / 0.15 / 0.45 s | 0.4 s (antes 1.0) | 2.0 / 2.2 m / 100° | 90°/s | sí | alternadas |
  | `twin_punch` | 1.5 | 0.7 / 0.15 / 0.6 s | 0.6 s (antes 1.3) | 2.5 / 2.9 m / 110° | 75°/s | no | alternadas |
  | `colossus_slam` | 1.5 | 0.9 / 0.2 / 0.8 s | 0.9 s (antes 1.8) | 3.0 / 3.4 m / 120° | 60°/s | no | las dos |

  El DPS queda casi igual que antes: Bruto 8/s, Gemelo ≈ 8.8/s (antes 9.2) y Coloso ≈ 10.7/s (antes 11.1). A cambio, cada golpe pega más fuerte y se ve venir.

## Interfaz pública

- `EnemyBehavior` (`components/enemies/enemy_behavior.gd`): `setup(enemy)`, `reset()`, `physics_update(delta)`, `knocked_back()` y `is_attacking()`.
- `MeleeBehavior` (`components/enemies/melee_behavior.gd`/`.tscn`): fases `CHASE`, `WINDUP`, `ACTIVE` y `RECOVERY`, y `get_phase()`.
- `EnemyHands`: `reset()`, `play_windup(attack, duration)`, `play_strike(attack, duration)`, `return_to_rest()`, `advance(delta)`, `get_left_position()`/`get_right_position()` y `get_left_rest()`/`get_right_rest()`.
- `Enemy`: `get_behavior()`, `get_hands()`, `get_target_padding()` (radio de la cápsula del objetivo), `get_facing()`, `move_towards()`, `stand_still()`, `face()` y `turn_towards()`.

## Lógica interna

1. **Perseguir:** baja el cooldown. Si ya pasó y el objetivo está a ≤ `trigger_range`, empieza la preparación. Si no, persigue hasta `attack_range` y ahí espera mirando al objetivo.
2. **Preparación:** el enemigo queda quieto y gira como máximo a `windup_turn_speed`. Las manos que atacan van a `rest + hand_windup_offset`.
3. **Golpe:** las manos van a `rest + hand_strike_offset`. En cada frame se evalúa `is_hit(pos, facing, pos del objetivo, radio del objetivo)`. El primer acierto aplica `receive_hit(damage × damage_multiplier)` y consume el golpe, aunque los iframes lo dejen en 0.
4. **Recuperación:** el enemigo queda quieto sin girar y las manos vuelven al reposo en `return_time`. Al terminar arranca el cooldown `attack_interval` y se pasa al siguiente ataque de la lista.
5. **Empuje:** mientras dura, el comportamiento está pausado. Si empieza durante la preparación de un ataque `interruptible`, lo cancela: vuelve a perseguir, las manos regresan y no hay cooldown.
6. **Reutilización del pool:** `activate()` reinicia el comportamiento y las manos.

## Enmienda a la constitución (MINOR → 4.2.0)

- **Principio II, tabla de colores:** se agrega "Manos de enemigos | `SphereMesh` | Gris `Color(0.5, 0.5, 0.5)`", con el mismo `enemy_material.tres`. El gris se comparte solo entre el cuerpo del enemigo y sus manos, que forman una misma silueta.

## Criterios de aceptación

**Cálculo puro** (`test/resources/enemy_attack_data_test.gd`):

- **AC409:** `is_hit` respeta el alcance más el padding, el borde del arco, ignora la altura, usa el origen y acierta siempre si el objetivo se superpone. `get_total_time` suma las tres fases.

**Comportamiento** (`test/entities/enemy/enemy_attack_test.gd`, con el Bruto salvo que se indique):

- **AC400:** con el jugador a menos de `trigger_range`, no hay daño antes de `windup_time` y la fase es `WINDUP`.
- **AC401:** si el jugador sigue en el arco, recibe 12 − 3 = 9 una sola vez por ataque.
- **AC402:** si el jugador sale del alcance durante la preparación, no recibe daño.
- **AC403:** si el jugador se corre ~102° hacia el costado durante la preparación (más de lo que el enemigo alcanza a girar a 90°/s), no recibe daño.
- **AC404:** un golpe que llega durante los iframes del dash no hace daño (junto con AC14, en `enemy_behaviour_test.gd`).
- **AC405:** durante la recuperación el enemigo no se mueve ni gira aunque el jugador se aleje.
- **AC406:** entre dos impactos pasan al menos `get_total_time() + attack_interval`.
- **AC407:** un empuje durante la preparación del Bruto la cancela (no hay daño en ese ciclo). La preparación del Coloso (no interrumpible) sigue.
- **AC408:** las manos arrancan en reposo y en reposo flotan alrededor de `rest_offset` (a lo sumo `bob_amplitude`). Al terminar la preparación, la mano que pega está detrás de su reposo y en el pico del golpe, delante.
- **AC410:** las manos escalan con `body_scale` (1 en el Bruto, 2.5 en el Coloso).
- **AC411:** `deactivate()` + `activate()` en pleno ataque devuelven al enemigo a `CHASE` con las manos en reposo.

## Plan de implementación

1. Reservar AC400–AC411 en `CLAUDE.md` (próximo libre → AC412).
2. Enmienda de la constitución (4.2.0).
3. `EnemyAttackData` y `EnemyHandsConfig`. Test AC409.
4. `EnemyStats.behavior`/`attacks`, `.tres` de ataques y configuración de Bruto, Gemelo y Coloso.
5. `EnemyBehavior` y `MeleeBehavior`, con `enemy.gd` delegando en el comportamiento.
6. `EnemyHands` y los nodos `Hands` en `enemy.tscn`.
7. Tests AC400–AC411 y adaptación de los tests viejos (ver Notas).
8. Suite completa, smoke test y captura sobre la copia del scratchpad. Cierre.

## Review (checklist de la constitución)

- [x] **I.** Sirve a Combate: el golpe se ve venir, se esquiva y deja una ventana para castigar.
- [x] **II.** Las manos son `SphereMesh` con el `enemy_material.tres` compartido y no hay shaders. El color se registró en la enmienda 4.2.0.
- [x] **III.** Tiempos, alcances, arcos, giro, multiplicadores y poses viven en `EnemyAttackData`/`EnemyHandsConfig` (`.tres`). `is_hit` y `get_total_time` son puros. El `.tres` compartido de stats no se muta: `attacks` se lee desde `stats`.
- [x] **IV.** Tipado estático en todo el código nuevo.
- [x] **V.** No se asigna memoria por frame. El comportamiento se instancia una vez por enemigo del pool, y las manos interpolan posiciones sin tweens ni nodos nuevos.
- [x] **VI.** Sin input nuevo.

## Notas

- **Tests viejos adaptados** (verifican lo mismo con los tiempos nuevos):
  - AC13 (`test_ac13_enemy_in_range_hits_every_attack_interval`): antes 5 de daño por golpe cada 1 s; ahora 9 por golpe, con el primero a ~0.5 s y un ciclo de 1.5 s.
  - AC14 → `test_ac14_ac404_…`: el dash se hace durante la preparación y el golpe cae dentro de los iframes.
  - AC130: un golpe de nivel 5 ahora hace 11.2 × 1.5 − 3 = 13.8 (antes 8.2).
- **AC37 reemplazado:** "el timer se congela al ser empujado y no se reinicia" deja de aplicar porque no hay timer continuo. Lo reemplaza AC407: el empuje durante la preparación cancela el ataque y un empuje en otra fase solo lo pausa.
- **Desvío menor respecto del plan aprobado:** se agregó `EnemyAttackData.interruptible`. Sin ese campo, cualquier golpe del jugador (todos empujan) cancelaría siempre la preparación de los bosses, y pegándoles sin parar nunca atacarían. El Bruto es interrumpible; Gemelo y Coloso no.
- **Fallos previos, ajenos a esta spec:** la suite base, antes de cualquier cambio, ya tenía 8 tests en rojo porque los valores de los `.tres` cambiaron fuera de sus specs: `dash_speed` 25, Conmoción 0.12, `attack_range` de la katana, stats del Samurái y del barrido del Berserker. Son AC188, AC211, AC221, AC236, AC285/AC298, AC288 y AC395. No se tocaron.
- **Ajuste visual:** las manos pasaron de r = 0.16 a r = 0.2 después de la captura, para que se lean mejor a la distancia de la cámara de juego. El tamaño está en el `SphereMesh_hand` de `enemy.tscn`.
