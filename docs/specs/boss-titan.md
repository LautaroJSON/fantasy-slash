# Boss: el Titán (reemplaza al Coloso)

- **Estado:** Implementada (2026-09-26). A pedido del usuario se corrieron solo los suites de esta spec y los que toca: `titan_moves_test`, `boss_moves_test`, `test/entities/enemy` completo (102 tests), `attack_coordinator_test`, `boss_challenge_run_test`, `boss_hud_bar_test` y `cooldown_hud_test`. Todos en verde, 0 orphans; smoke test de la arena sin errores; capturas del aplastamiento, la mano apoyada y la mano rota revisadas. La suite completa no se corrió.
- **Constitución:** `docs/constitution.md` **v4.4.0**, sin enmienda (ver *Arte*)
- **Pilar (Principio I):** Combate + Progresión.
  - **Combate:** contra un gigante lento, lo que cuenta es el posicionamiento y elegir **a qué** pegarle. El cuerpo tiene mucha armadura, las manos son puntos débiles y romperlas le quita ataques y lo deja aturdido.
  - **Progresión:** es un desafío de boss que entrega las cartas doradas al vencerlo.
- **Tipo:** feature. Quinta de la hoja de ruta: … → `boss-verdugo` → **`boss-titan`** → `boss-colmena`.
- **Dependencias:** `boss-verdugo.md` (`BossBehavior`, `BossMoveData`, onda de choque, fase 2), `enemy-group-ai.md` (aparición).

## Objetivo

- **Quién es:** un boss gigante (`body_scale` 3.5, cápsula gris de ~6 m) con manos enormes. Es lento, sus golpes cubren zonas grandes y sus avisos son largos.
- **Reemplaza al Coloso:** se borran `colossus_stats.tres`, `colossus_slam.tres` y el desafío `colossus.tres`. En su lugar entran `titan.tres` y `BossPoolTitan`.
- **Barra:** la del HUD, con el nombre "Titán".
- **Turnos y aparición:** no pide turno de ataque y aparece desde el piso.

## Armadura y manos rompibles

- **Armadura:** el cuerpo recibe `body_armor` (70 %) menos daño con `HealthComponent.damage_reduction`, salvo en dos casos.
- **Mano apoyada = punto débil:** después de un aplastamiento, la mano queda apoyada en el piso `hand_rest_time` (2.0 s). Si el jugador está a menos de `weak_point_radius` (radio de la mano + 1.5 m) de una mano apoyada, sus golpes le hacen **daño completo** al Titán y **el mismo daño a esa mano**.
- **Vida de cada mano:** `hand_health_fraction` (30 %) de la vida máxima del Titán, escalada por nivel y rage.
- **Cómo se ve el daño a la mano:** tiembla con cada golpe y se achica hasta el 70 % de su tamaño a medida que pierde vida.
- **Mano rota:**
  - desaparece;
  - el Titán queda **aturdido** `break_stun_time` (3.0 s), con el cuerpo 0.5 m más abajo, sin armadura y sin atacar;
  - pierde los movimientos que usan esa mano. Con una sola mano, el aplastamiento y el barrido usan la que queda. Sin manos, solo le queda el pisotón.

## Repertorio

Se elige como el del Verdugo: `BossMoveTable` por distancia y fase, sin repetir. Además, un movimiento con `needs_hand` no se elige si no le quedan manos.

| Movimiento | Distancia | Peso | Qué hace | Respuesta |
|---|---|---|---|---|
| **Aplastamiento** | 0 – 14 m | 3 | Levanta una mano (alterna entre las que le quedan) durante 1.4 s. Al 60 % de la preparación **fija el punto de impacto** donde está el jugador. La mano cae ahí: círculo de 3.0 m, `Mult.` 2.0. Después queda apoyada `hand_rest_time`. | Salir del círculo después de que fija el punto. Después, pegarle cerca de la mano apoyada. |
| **Barrido** | 0 – 8 m | 2 | Lleva una mano hacia atrás, a un costado (1.2 s), y barre un arco de 200° frente a él, con alcance de 8 m y 0.4 s de golpe, `Mult.` 1.5. Es un golpe bajo: solo pega si el jugador está a menos de 0.4 m del piso. | **Saltarlo** o esquivarlo con el dash. |
| **Pisotón** | 0 – 20 m | 1 (2 sin manos) | Levanta el cuerpo y pisa (1.6 s). Lanza una onda de choque (`ShockwaveMoveData`) que crece hasta 16 m a 7 m/s, `Mult.` 1.2. | Saltar el anillo o esquivarlo con el dash. |

## Fase 2 (vida ≤ 40 %)

Usa la fase 2 de `BossBehavior`:
- **Transición:** una pausa invulnerable de 1.5 s.
- **Más rápido:** preparaciones y recuperaciones × 0.8.
- **Pisotón:** lanza 3 anillos, separados 0.7 s.
- **Manos:** crecen un 10 %. Si alguna ya estaba rota, sigue rota.

## Arte (sin enmienda)

Todo sigue siendo cápsula y esferas grises del `enemy_material.tres`, con el anillo tierra que registró la versión 4.4.0. La escala más grande, el temblor, el achique y la mano rota que desaparece también son primitivas.

## Estructura de nodos

No hay nodos nuevos en `enemy.tscn`. El Titán usa `components/enemies/titan_behavior.tscn`, que extiende `BossBehavior`.

## Resources y datos

- **`BossMoveData`** suma `needs_hand: bool`. Si es `true` y no quedan manos, su peso es 0. `BossMoveTable.pick(...)` suma el parámetro `hands_left: int`, con 2 por defecto, así que el Verdugo no cambia.
- **`HandSlamMoveData`** (`BossMoveData`): `attack: EnemyAttackData` (preparación, recuperación, `Mult.`), `lock_fraction` (0.6), `impact_radius` (3.0), `hand_rest_time` (2.0), `raise_offset` (pose de la mano arriba).
- **`SweepMoveData`** (`BossMoveData`): `attack: EnemyAttackData` (alcance 8, arco 200°) y `clear_height` (0.4).
- **`TitanConfig`** (`BossConfig`): `body_armor` (0.7), `hand_health_fraction` (0.3), `weak_point_margin` (1.5), `break_stun_time` (3.0), `stun_body_drop` (0.5), `damaged_hand_min_scale` (0.7), `hit_shake_time` (0.15) y `hit_shake_amount` (0.1).
- **Datos:**
  - `data/enemies/titan_stats.tres`: vida 1400, daño 22, defensa 8, velocidad 1.8, `body_scale` 3.5, `health_bar_scale` 2.2, "Titán", barra en el HUD, `ignores_attack_tokens`, crecimiento por nivel como el Coloso.
  - `data/enemies/hands/titan_hands.tres` (`hand_scale` 1.3).
  - `data/enemies/configs/titan_boss.tres`.
  - `data/enemies/attacks/titan_*.tres`.
  - `data/enemies/boss_challenges/titan.tres` (1 enemigo).

## Interfaz pública

- **`BossBehavior`** suma hooks para que las subclases agreguen tipos de movimiento: `_begin_other_move(move)` y `_update_other_move(delta)` (fase `OTHER`), y `_hands_left()` (2 por defecto).
- **`TitanBehavior`** agrega:
  - `get_hand_health(left: bool)`, `is_hand_broken(left)`, `is_hand_resting(left)` y `is_stunned()`;
  - los movimientos de aplastamiento y barrido;
  - la armadura, que se recalcula cada frame en `HealthComponent.damage_reduction`, y el reparto del daño a la mano apoyada, que escucha `HealthComponent.damaged`.
- **`EnemyHands`** suma:
  - `move_hand(left, local_position, duration)`: mueve una sola mano;
  - `set_hand_visible(left, visible)`;
  - `set_hand_size(left, multiplier)`;
  - `shake_hand(left, time, amount)`.

## Criterios de aceptación (AC478–AC499, reservados)

**Datos** (`test/resources/titan_moves_test.gd`):
- **AC478:** `BossMoveTable.pick` con `hands_left` 0 nunca devuelve un movimiento con `needs_hand`. Sin el parámetro, se comporta como antes (los tests del Verdugo no cambian).

**Armadura y manos** (`test/entities/enemy/titan_test.gd`):
- **AC479:** lejos de una mano apoyada, un golpe al cuerpo hace 30 % del daño (después de defensa).
- **AC480:** cerca de una mano apoyada, el golpe hace daño completo al Titán y resta lo mismo a la vida de esa mano. Si la mano no está apoyada, no hay daño a la mano.
- **AC481:** la vida de cada mano es `hand_health_fraction` × la vida máxima escalada.
- **AC482:** una mano dañada se achica en proporción a su vida (hasta `damaged_hand_min_scale`) y tiembla al recibir el golpe.
- **AC483:** al romperse, la mano se oculta y el Titán queda aturdido `break_stun_time`: sin armadura, sin atacar, con el cuerpo más abajo. Después vuelve a actuar.
- **AC484:** con una mano rota, los aplastamientos y barridos usan la otra. Con las dos rotas, solo pisa.

**Movimientos:**
- **AC485:** el aplastamiento fija el punto de impacto al `lock_fraction` de la preparación. Si el jugador sale del círculo después, no hay daño; si se queda, recibe 22 × 2 − 3 = 41 una vez.
- **AC486:** después del impacto, la mano queda apoyada `hand_rest_time` en el punto de impacto y después vuelve.
- **AC487:** el barrido pega 22 × 1.5 − 3 = 30 una vez a un jugador en el piso dentro del arco de 200° y 8 m. Con el jugador a más de `clear_height` del piso, o fuera del arco, no pega.
- **AC488:** el pisotón lanza un anillo en la fase 1 y 3 en la fase 2 (usa el `ShockwaveMoveData` del Verdugo).
- **AC489:** la fase 2 empieza al 40 %, con 1.5 s invulnerable, tiempos × 0.8 y manos un 10 % más grandes. Una mano rota sigue rota.

**Reemplazo e integración:**
- **AC490:** `WaveConfig.boss_challenges` tiene al Titán, a los Gemelos y al Verdugo, y no al Coloso. La arena tiene `BossPoolTitan` y no `BossPoolColossus`.
- **AC491:** forzar el desafío Titán genera 1 Titán que aparece desde el piso, no usa turnos y muestra "Titán" en la barra del HUD.
- **AC492:** escala con nivel y rage (incluida la vida de las manos).
- **AC493:** `activate()` restaura las dos manos (vida, tamaño y visibles), quita el aturdimiento y la armadura vuelve a aplicarse.
- **AC494–AC499:** tests viejos que usaban al Coloso como boss de referencia, adaptados sin cambiar lo que verifican:
  - **AC494:** `boss_body_test` (AC147–AC150) pasa a usar al **Titán** como cuerpo grande, con los valores leídos de sus stats (ver Notas).
  - **AC495:** `enemy_attack_test` (AC407 "preparación de boss no interrumpible" y AC410 "manos escaladas") pasa a usar al Gemelo.
  - **AC496:** `attack_coordinator_test` (AC445) pasa a usar al Gemelo.
  - **AC497:** `boss_challenge_run_test` (AC151, AC152 y AC456) pasa a usar al Titán.
  - **AC498:** `boss_hud_bar_test` (AC159 y siguientes) pasa a usar al Titán ("Titán", su vida).
  - **AC499:** `cooldown_hud_test` pasa a usar al Titán.

## Plan de implementación

1. Reservar AC478–AC499 en `CLAUDE.md` (próximo libre → AC500).
2. `needs_hand` y `hands_left` en `BossMoveData`/`BossMoveTable`, y los hooks de `BossBehavior`. Test AC478; los del Verdugo siguen en verde.
3. `EnemyHands`: una sola mano, visibilidad, tamaño y temblor.
4. `HandSlamMoveData`, `SweepMoveData`, `TitanConfig` y `TitanBehavior`. Datos del Titán. Tests AC479–AC489, AC492 y AC493.
5. Reemplazo: desafío y pool del Titán en `wave_config.tres` y `arena.tscn`; borrar los archivos del Coloso. Adaptar los tests AC494–AC499. Tests AC490 y AC491.
6. Suite completa (niveles 3 veces), smoke test y captura (aplastamiento, mano apoyada, barrido y mano rota). Checklist, spec **Implementada** y `CLAUDE.md`.

## Review (checklist de la constitución)

- [x] **I.** Combate y Progresión, como se explica arriba.
- [x] **II.** Solo primitivas y materiales existentes; sin colores nuevos.
- [x] **III.** Todos los números en `.tres`. `BossMoveTable.pick` es puro.
- [x] **IV.** Tipado estático.
- [x] **V.** No se asigna memoria por frame.
- [x] **VI.** Sin input nuevo.

## Notas

- **El Coloso deja de existir.** Si en algún momento lo querés de vuelta como enemigo normal o como boss, habría que reintroducirlo en su propia spec.
- **Por qué la mano como zona:** así el daño a la mano se reparte sin crear enemigos extra ni tocar el código de los ataques del jugador. Cualquier golpe (básico, habilidad o área) cuenta si el jugador está cerca de la mano apoyada.
- Los números son un punto de partida para ajustar jugando, en los `.tres`.

### Implementación: ajustes respecto de lo aprobado

- **AC494 usa al Titán y no al Gemelo:** el test del Empuje que pega al costado de la línea necesita el margen de golpe de un cuerpo grande (el del Gemelo es de 0.3 m y el del Titán de 1.0 m). Además el Titán queda en el juego y el Gemelo se va con `boss-colmena`. Los valores esperados se leen de `titan_stats.tres`.
- **Tercer anillo:** `enemy.tscn` suma `Shockwave3`, porque el pisotón de la fase 2 lanza 3 anillos y antes solo había 2 nodos.
- **Valores nuevos en los datos:**
  - `EnemyHandsConfig.shake_frequency`, para el temblor de la mano golpeada;
  - `BossMoveData.handless_weight`, el peso del pisotón sin manos (2), en lugar de un caso especial en el código;
  - `TitanConfig.stun_body_drop` se multiplica por `body_scale` (0.15 × 3.5 ≈ 0.5 m).
- **`EnemyHands`** guarda por separado la posición base y el temblor, y suma `get_hand_radius()` para calcular el punto débil con el tamaño real de la mano.
- **Pose del barrido:** después de la captura, la mano bajó (y −1.0) para que el barrido se vea a ras del piso, como su hitbox.
- **Los tests del aturdimiento esperan también el `attack_interval`**, porque el Titán elige el siguiente movimiento después de esa pausa.
- **AC484 y AC489 rompen las manos llamando a `_break_hand()` desde el test**, para no depender de dos aplastamientos seguidos.
