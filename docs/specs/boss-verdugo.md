# Boss: el Verdugo

- **Estado:** Implementada (2026-09-26, 526 tests GdUnit4: 518 en verde y los mismos 8 fallos previos ajenos a esta spec, ver `enemy-attack-telegraph.md`; 0 orphans; tests de niveles y entidades repetidos 3 veces sin fallos intermitentes; smoke test de la arena sin errores; capturas del tajo, la onda y el agarre revisadas)
- **Constitución:** `docs/constitution.md` **v4.3.0** → **v4.4.0** (enmienda MINOR, ver abajo)
- **Pilar (Principio I):** Combate + Progresión.
  - **Combate:** un duelo que se gana leyendo avisos. Cada ataque pide una respuesta distinta: salir del arco del combo, saltar la onda o esquivarla con el dash, y esquivar el agarre para castigar la recuperación larga. En la fase 2, el mismo repertorio exige más.
  - **Progresión:** es un desafío de boss más que entrega las cartas doradas al vencerlo.
- **Tipo:** feature. Cuarta de la hoja de ruta: `enemy-attack-telegraph` → `enemy-types` → `enemy-group-ai` → **`boss-verdugo`** → `boss-titan` → `boss-colmena`.
- **Dependencias:** `enemy-attack-telegraph.md`, `enemy-group-ai.md` (aparición; no pide turno), `enemy-levels.md`, `enemy-rage.md`.

## Objetivo

Un boss nuevo que se **suma** al sorteo de las oleadas de boss (`WaveConfig.boss_challenges`), junto al Coloso y los Gemelos. A esos dos los reemplazan `boss-titan` y `boss-colmena`.

- **Cuerpo:** cápsula gris con `body_scale` 2.0 y manos grandes (`hand_scale` 1.6), en pose de guardia alta.
- **Barra:** la del HUD, con el nombre "Verdugo".
- **Turnos y aparición:** no pide turno de ataque (`ignores_attack_tokens`) y aparece desde el piso como todos.

## Repertorio

Elige un movimiento según la distancia al jugador, sin repetir el anterior salvo que sea el único posible. Entre movimientos espera `attack_interval` (0.8 s) acercándose. Si ningún movimiento alcanza, camina hacia el jugador.

| Movimiento | Distancia | Peso | Qué hace | Respuesta |
|---|---|---|---|---|
| **Tajo triple** | 0 – 4.5 m | 3 | 3 golpes seguidos en arco de 120° y alcance 3.2 m. Avanza 0.8 m antes de cada golpe; alterna manos y el último es con las dos. Preparación 0.6 / 0.35 / 0.35 s, golpe 0.15 s, recuperación 0.2 / 0.2 / 0.9 s. `Mult.` 1.0 / 1.0 / 1.6. | Salir del arco o esquivar con el dash cada golpe. Cada golpe se evalúa por separado. |
| **Onda de choque** | 3 – 12 m (peso 1 a menos de 3 m) | 3 | Levanta las dos manos (1.0 s) y golpea el piso. Un anillo crece desde 0.5 m hasta 12 m a 9 m/s, con 0.8 m de ancho. Pega una vez, con `Mult.` 1.2, si el anillo pasa por el jugador y este está a menos de 0.3 m del piso. Recuperación 0.8 s. | **Saltar** cuando llega el anillo o esquivarlo con el dash (iframes). |
| **Agarre** | 0 – 5 m | 2 | Preparación 0.7 s con las manos abiertas adelante. Después se lanza hasta 4 m a 10 m/s, frenando a 1.2 m del jugador. Si lo alcanza (arco de 60°, alcance 1.8 m) lo **sujeta** 1.2 s: el jugador no puede moverse, atacar, saltar, esquivar ni usar habilidades. Al final lo golpea con `Mult.` 2.5. Si falla, queda 1.4 s en recuperación. | Esquivar con el dash o salir del arco. Si falla, es la mejor ventana para castigarlo. |

Todos los tiempos de preparación, golpe y recuperación, alcances y arcos son `EnemyAttackData`. El avance, la onda y el agarre tienen datos propios (ver *Resources*).

## Fase 2 (vida ≤ 50 %)

- **Transición, una sola vez por vida:** cuando la vida baja al 50 % o menos y termina el movimiento en curso, pasa 1.2 s quieto con las manos arriba. En ese tiempo es **invulnerable** y no ataca.
- **Más rápido:** las preparaciones y recuperaciones se multiplican por `time_scale` (0.75).
- **Tajo cuádruple:** el tajo pasa a 4 golpes. El cuarto repite el primero.
- **Doble onda:** la onda lanza 2 anillos separados por 0.6 s.
- **Las manos crecen** un 20 % (`phase_two_hand_scale`), para que se note el cambio de fase.

## Enmienda a la constitución (MINOR → 4.4.0)

- **Principio II, colores no reservados:** el tierra `Color(0.62, 0.52, 0.4)` del polvo del corte de viento también se usa para el **anillo de la onda de choque**: un `TorusMesh` plano sobre el piso, unshaded, alpha ≤ 0.6, que se agranda hasta desaparecer. Se registra el `TorusMesh` como malla primitiva en uso.

## Estructura de nodos

`enemy.tscn` suma dos anillos reutilizables (dos por la doble onda de la fase 2):

```
Enemy
├─ Shockwave  (MeshInstance3D, TorusMesh, materials/vfx/shockwave_material.tres; oculto)   ← nuevo
└─ Shockwave2 (ídem)                                                                         ← nuevo
```

Los usa `BossBehavior`; los otros tipos los dejan ocultos. Los anillos se ubican en coordenadas del mundo (`top_level`), para que no giren ni se muevan con el boss mientras se expanden.

## Resources y datos

- **`BossMoveData`** (base, `resources/boss_move_data.gd`): `min_range`, `max_range`, `weight`, `close_weight` (peso a menos de `min_range`; 0 = no se elige) y `phases` (en qué fases está: 1, 2 o ambas).
  - **`ComboMoveData`:** `steps: Array[EnemyAttackData]`, `advance_distance` y `phase_two_extra_steps: Array[EnemyAttackData]`.
  - **`ShockwaveMoveData`:** `attack: EnemyAttackData` (preparación, recuperación y `Mult.`), `start_radius`, `max_radius`, `speed`, `width`, `clear_height`, `rings_phase_one`, `rings_phase_two` y `ring_delay`. Función pura: `is_hit(center, radius, point) -> bool`.
  - **`GrabMoveData`:** `attack: EnemyAttackData` (preparación, arco y alcance), `lunge_speed`, `lunge_distance`, `stop_distance`, `hold_time`, `slam_multiplier` y `miss_recovery_time`.
- **`BossPhaseData`:** `health_threshold` (0.5), `transition_time` (1.2), `time_scale` (0.75) y `phase_two_hand_scale` (1.2).
- **`BossConfig`** (`EnemyStats.behavior_config` del boss): `moves: Array[BossMoveData]` y `phase_two: BossPhaseData`.
- **`BossMoveTable.pick(moves, distance, phase, last_move, roll) -> int`:** estática y pura. Devuelve −1 si ninguno alcanza.
- **Datos:**
  - `data/enemies/verdugo_stats.tres`: vida 900, daño 18, defensa 6, velocidad 3.0, `body_scale` 2.0, `health_bar_scale` 1.6, `display_name` "Verdugo", barra en el HUD, `ignores_attack_tokens`, crecimiento por nivel como el Coloso.
  - `data/enemies/hands/verdugo_hands.tres`, `data/enemies/configs/verdugo_boss.tres`.
  - `data/enemies/attacks/verdugo_*.tres`.
  - `data/enemies/boss_challenges/verdugo.tres` (1 enemigo).
- `materials/vfx/shockwave_material.tres`: tierra, alpha 0.6, unshaded.

## Interfaz pública

- **`BossBehavior`** (`components/enemies/boss_behavior.gd`/`.tscn`): fases `CHASE`, `COMBO`, `SHOCKWAVE`, `GRAB`, `HOLD`, `TRANSITION` y `RECOVERY`. Expone `get_phase()`, `get_boss_phase() -> int` (1 o 2) y `get_last_move()`.
- **`Player`** (archivo compartido: se relee antes de editarlo):
  - `begin_hold(duration)`: mientras dura, se ignoran movimiento, ataque, salto, dash y habilidades, y la velocidad horizontal es 0.
  - `end_hold()` e `is_held()`.
  - Si el jugador muere o el boss se desactiva, la sujeción se suelta.
- **`Enemy`:** `get_shockwave(index)`. `HealthComponent.is_invulnerable` se usa durante la transición.

## Criterios de aceptación (AC458–AC477, reservados)

**Datos puros** (`test/resources/boss_moves_test.gd`):
- **AC458:** `BossMoveTable.pick` respeta distancia, `close_weight` y fase. No repite el movimiento anterior salvo que sea el único posible, y devuelve −1 si ninguno alcanza.
- **AC459:** `ShockwaveMoveData.is_hit`: pega dentro de la banda (radio ± ancho/2) con el jugador a menos de `clear_height`, y no pega fuera de la banda ni con el jugador en el aire.
- **AC460:** `BossPhaseData` y `ComboMoveData`: en la fase 2, el tajo tiene 4 pasos y los tiempos escalados por `time_scale`.

**Tajo** (`test/entities/enemy/verdugo_test.gd`):
- **AC461:** a 3 m, el tajo pega 3 veces (18 − 3 = 15, 15 y 18 × 1.6 − 3 = 25.8), cada golpe después de su preparación.
- **AC462:** avanza `advance_distance` antes de cada golpe.
- **AC463:** si el jugador sale del arco después del primer golpe, los otros dos no pegan.

**Onda:**
- **AC464:** el anillo crece a `speed`. Un jugador en el piso a 6 m recibe 18 × 1.2 − 3 = 18.6 cuando la banda llega, una sola vez.
- **AC465:** un jugador a más de `clear_height` del piso, o con iframes del dash, no recibe daño.
- **AC466:** el `TorusMesh` se ve con el radio actual del anillo y se oculta al llegar a `max_radius`.

**Agarre:**
- **AC467:** si alcanza al jugador, este queda `is_held()` durante `hold_time`: los intentos de moverse, atacar y esquivar no hacen nada. Al final recibe 18 × 2.5 − 3 = 42 y se suelta.
- **AC468:** si el jugador esquiva con el dash o está fuera del arco, no hay sujeción y el Verdugo queda `miss_recovery_time` en recuperación.
- **AC469:** `Player.begin_hold`/`end_hold`/`is_held`. Si el boss se desactiva durante una sujeción, el jugador se suelta.

**Fase 2:**
- **AC470:** al bajar al 50 % entra en `TRANSITION`: durante `transition_time` es invulnerable y no ataca. Pasa una sola vez aunque se cure.
- **AC471:** en la fase 2, el tajo pega 4 veces, las preparaciones duran `time_scale` × las de la fase 1, la onda lanza 2 anillos separados por `ring_delay` y las manos crecen `phase_two_hand_scale`.

**Selección e integración:**
- **AC472:** en 8 movimientos seguidos nunca repite el mismo dos veces.
- **AC473:** con el jugador a 10 m usa la onda. A 2 m, en 30 elecciones con semilla fija, el tajo y el agarre salen más del doble de veces que la onda (que de cerca tiene `close_weight` 1).
- **AC474:** `verdugo.tres` está en `WaveConfig.boss_challenges` y tiene su pool en la arena. Forzar ese desafío genera 1 Verdugo que aparece desde el piso, no usa turnos y muestra "Verdugo" en la barra del HUD.
- **AC475:** escala con nivel y rage como el resto.
- **AC476:** `activate()` lo devuelve a la fase 1, con manos normales y sin anillos visibles.
- **AC477:** si el jugador muere durante una sujeción, `is_held()` queda en `false`.

## Plan de implementación

1. Reservar AC458–AC477 en `CLAUDE.md` (próximo libre → AC478).
2. Resources (`BossMoveData` y subclases, `BossPhaseData`, `BossConfig`) y `BossMoveTable`. Tests AC458–AC460.
3. `Player.begin_hold`/`end_hold`/`is_held` (releer `player.gd`). Test AC469.
4. Nodos `Shockwave`/`Shockwave2`, su material y `Enemy.get_shockwave`. Enmienda de la constitución (4.4.0).
5. `BossBehavior`: selección, tajo, onda, agarre y fase 2. Datos del Verdugo. Tests AC461–AC468 y AC470–AC473, AC475–AC477.
6. `verdugo.tres`, su pool en `arena.tscn` y `WaveConfig.boss_challenges`. Test AC474.
7. Suite completa (niveles 3 veces), smoke test y capturas (tajo, onda, agarre, fase 2). Checklist, spec **Implementada** y `CLAUDE.md`.

## Review (checklist de la constitución)

- [x] **I.** Combate y Progresión, como se explica arriba.
- [x] **II.** Solo primitivas: cápsula, esferas y `TorusMesh`, con materiales `.tres` compartidos y sin shaders. El anillo queda registrado en 4.4.0.
- [x] **III.** Todos los números en `.tres`. `BossMoveTable.pick` e `is_hit` son puros.
- [x] **IV.** Tipado estático.
- [x] **V.** No se asigna memoria por frame: los anillos existen en la escena y solo se muestran, y la selección no crea arrays.
- [x] **VI.** Sin input nuevo. La sujeción bloquea el input existente.

## Notas

- Los números son un punto de partida para ajustar jugando, en los `.tres`.
- `BossBehavior` y `BossMoveData` están pensados para que el Titán y la Colmena sumen sus propios tipos de movimiento sin reescribir la selección ni las fases.

### Implementación: ajustes respecto de lo aprobado

- **Fases de un movimiento:** en vez de `phases`, `BossMoveData` usa dos flags, `in_phase_one` e `in_phase_two`. La pose de las manos durante la transición es `BossPhaseData.transition_hand_offset`.
- **El boss no se deja empujar durante un movimiento** (`resists_knockback` mientras ataca), porque el empuje rompería la estocada del agarre y la sujeción. Entre movimientos sí se lo empuja.
- **`EnemyBehavior.deactivated()`:** es un hook nuevo. `Enemy.deactivate()` lo llama para que el boss suelte al jugador si muere o se desactiva durante una sujeción.
- **`EnemyHands.set_size_multiplier()`:** agranda las manos en la fase 2. `reset()` lo vuelve a 1.
- **Anillo:** el `TorusMesh` escala con el radio, así que el grosor visual del anillo crece un poco al expandirse. La banda que pega (`width`) es constante.
- **Error corregido en la implementación:** durante la transición la vida sigue bajo el umbral, así que el boss volvía a pedir la fase 2 y repetía la pausa invulnerable. Ahora el umbral no se evalúa durante la transición (lo cubre AC470).
- **AC473 reformulado:** a 2 m la onda también puede salir (`close_weight` 1). El AC verifica la proporción con semillas fijas.
- **Test viejo adaptado:** `test_ac151_wave_4_spawns_only_level_2_bosses` acepta cualquier desafío de `WaveConfig.boss_challenges`, con su propia cantidad.
