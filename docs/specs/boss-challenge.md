# Feature: Boss challenge cada 4 oleadas + cartas doradas solo tras jefes

- **Estado:** Implementada (2026-09-25, 234 tests GdUnit4 en verde junto con el fix `owns-upgrade-typed-check.md`, smoke tests headless del menú y de la arena limpios)
- **Constitución:** `docs/constitution.md` **v2.4.0** (sin enmienda: los jefes son enemigos, cápsulas grises)
- **Pilar (Principio I):** Supervivencia (un pico de tensión cada 4 oleadas) y Progresión (las mejoras únicas pasan a ser la recompensa de vencer a un jefe).
- **Dependencias:** `combat-mvp.md`, `enemy-levels.md`, `crit-feedback.md`, `unique-ability-upgrades.md`, `upgrade-ban.md`, `upgrade-caps.md`.

## 1. Objetivo

- Las oleadas **4, 8, 12…** (`wave % boss_wave_interval == 0`) son un *boss challenge*. Solo aparecen jefes, y el tipo se **sortea al azar** entre:
  - **Coloso** (tipo 1): 1 enemigo a ×2.5 de tamaño.
  - **Gemelos** (tipo 2): 2 enemigos a ×1.75.
- Los jefes escalan por nivel igual que los grunts (la oleada 4 es nivel 2).
- **Cartas doradas** (mejoras únicas): **solo** se ofrecen al vencer a un jefe. Esa oferta muestra **todas las doradas disponibles** (hasta `cards_per_offer`) y se completa con cartas normales. Si no queda ninguna dorada disponible, la oferta es normal.
- **HUD:** `Oleada 4 · Coloso` / `Oleada 8 · Gemelos`.
- "Asesinato" ejecuta a los jefes normalmente.

## 2. Stats (nivel 1)

| Stat | Grunt | Coloso | Gemelo (×2) |
|---|---|---|---|
| `max_health` | 40 | 400 | 150 |
| `damage` | 8 | 20 | 12 |
| `defense` | 0 | 4 | 2 |
| `attack_interval` | 1.0 | 1.8 | 1.3 |
| `attack_range` | 2.0 | 3.0 | 2.5 |
| `move_speed` | 3.5 | 2.6 | 3.0 |
| `knockback_friction` | 20 | 80 | 45 |
| `body_scale` | 1.0 | 2.5 | 1.75 |
| `health_bar_scale` | 1.0 | 1.8 | 1.35 |

**Crecimiento por nivel:**

| Stat | Por nivel | Tope Coloso | Tope Gemelo |
|---|---|---|---|
| Vida | +20 % | — | — |
| Daño | +10 % | — | — |
| Defensa | +0.5 | 10 | 7 |
| Velocidad | +0.1 | 3.4 | 4.0 |

## 3. Edge cases

1. **Hitbox de cuerpos grandes.** `Enemy.get_hit_padding()` = radio de la cápsula × (`body_scale` − 1): 0 en el grunt, 0.6 en el Coloso y 0.3 en el Gemelo. Se suma al alcance del ataque básico y al largo y medio ancho de los rectángulos de Estocada y Swift Strike.
2. `attack_range` siempre supera la suma de radios (jefe + jugador).
3. Se escalan `Body` y `CollisionShape3D`, nunca el `CharacterBody3D`, una sola vez en `_ready`.
4. La barra sube a `height_offset × body_scale` y el nodo se escala por `health_bar_scale`; la etiqueta de nivel, los íconos y la vibración escalan con ella.
5. Los números de daño aparecen a `spawn_height × body_scale`.
6. `WaveConfig.min_spawn_separation` (3.0 m) aplica a todo spawn de la oleada, grunts incluidos. Si se agotan los intentos, se usa el último candidato.
7. Un `EnemyPool` por desafío, de tamaño `count`, pre-instanciado al cargar.
8. **Ban:** su regla no cambia y el picker de ban sigue mostrando todo el pool disponible, doradas incluidas.
9. **Sandbox:** las oleadas de jefe también aparecen, sin cartas.
10. Cada jefe cuenta como 1 kill. La muerte del jugador lleva al game over normal.
11. **Riesgos aceptados:**
    - La vibración por golpe fuerte (≥ 1/3 de la vida) casi no se dispara contra jefes.
    - El sangrado escala con la vida del jefe.
    - El Coloso puede tapar la cámara.
    - No hay telegraph del golpe.

## 4. Datos (Principio III)

- `EnemyStats`: + `body_scale`, `health_bar_scale` (fuera del enum `Stat`, no escalan por nivel).
- `BossChallengeData` (nuevo): `title: String`, `stats: EnemyStats`, `count: int`.
- `WaveConfig`: + `boss_wave_interval: int` (4), `boss_challenges: Array[BossChallengeData]`, `min_spawn_separation: float` (3.0), y la función `is_boss_wave(wave) -> bool`.
- `.tres`:
  - `data/enemies/colossus_stats.tres`
  - `data/enemies/twin_stats.tres`
  - `data/enemies/boss_challenges/colossus.tres` (Coloso, count 1)
  - `data/enemies/boss_challenges/twins.tres` (Gemelos, count 2)

## 5. Escenas, nodos e interfaz

- **`EnemyPool`:** `@export var challenge: BossChallengeData` (opcional). Si está asignado, instancia `challenge.count` enemigos con `stats = challenge.stats`.
- **`arena.tscn`:** `BossPoolColossus` y `BossPoolTwins`. `WaveManager.boss_pools: Array[EnemyPool]`.
- **`Enemy`:** `get_body_scale() -> float`, `get_hit_padding() -> float`.
- **`EnemyHealthBar`:** `apply_body(body_scale: float, bar_scale: float) -> void`.
- **`WaveManager`:**
  - `start_wave()` sortea el desafío en las oleadas de jefe.
  - `start_boss_wave(challenge: BossChallengeData)` es público (tests).
  - `build_offer() -> Array[UpgradeCard]` (pública, para tests): oferta de jefe o normal según la oleada que se acaba de limpiar.
- **`UpgradeOffer`:** `without_unique(pool)`, `only_unique(pool)`, `boss_offer(pool, count, rng)`.
- **`RunState`:** `challenge_title: String`, `set_challenge(title: String)`, `is_boss_wave() -> bool` (hay título).
- **`Hud`:** muestra `"Oleada %d · %s"` cuando hay título.

## 6. Criterios de aceptación

- **AC146** `is_boss_wave`: 4, 8 y 12 → sí. 1, 3 y 5 → no.
- **AC147** Grunt sin cambios: `body_scale` 1, padding 0, la barra en `height_offset` y la colisión sin escalar.
- **AC148** Coloso: colisión y cuerpo escalados ×2.5, barra en reposo a `2.2 × 2.5 = 5.5` m y escalada ×1.8, padding ≈ 0.6.
- **AC149** El ataque básico le pega a un Coloso con el centro a 2.5 m y no a un grunt a 2.1 m. La Estocada le pega a un Coloso desplazado de costado a `half_width + 0.5`.
- **AC150** Los números de daño sobre un Coloso aparecen a `spawn_height × 2.5`.
- **AC151** La oleada 4 tiene solo jefes (1 Coloso o 2 Gemelos) en nivel 2. Las oleadas 3 y 5 son de grunts.
- **AC152** Los Gemelos aparecen a ≥ `min_spawn_separation` entre sí.
- **AC153** Tras una oleada normal, la oferta nunca incluye doradas.
- **AC154** Con Swift Strike, tras vencer al jefe de la oleada 4 la oferta muestra Asesinato y Reset más 1 carta normal.
- **AC155** Con las doradas baneadas o en su tope, la oferta tras un jefe es normal (3 cartas no doradas).
- **AC156** El HUD muestra `Oleada 4 · Coloso` durante esa oleada y `Oleada 5` en la siguiente.
- **AC157** Regresión: la suite completa en verde.

### Notas de implementación

- **Desvío de interfaz:** en lugar de `WaveManager.is_boss_wave_active()`, la pregunta vive en `RunState.is_boss_wave()`, porque el HUD y la oferta ya leen `RunState`.
- **Barra escalada:** `_face_camera` asignaba `global_basis` y pisaba la escala. Ahora usa `camera.global_basis.orthonormalized() * _bar_scale`.
- **Enemigos por pool:** cada pool asigna `enemy.stats` antes de `add_child`, así que se reutiliza `enemy.tscn` sin escenas nuevas.
- **Test existente ajustado:** en `upgrade_ban_run_test.gd` (AC71), la oleada 4 ahora es de jefe. La aserción pasó de "5 enemigos" a "empezó una oleada de jefe con enemigos vivos"; sigue verificando lo mismo: que el ban avanza a la oleada siguiente.
- **Tests nuevos:**
  - `test/entities/enemy/boss_body_test.gd` (AC147–AC150)
  - `test/levels/boss_challenge_run_test.gd` (AC146, AC151–AC156)

### Review de la constitución (cierre, v2.4.0)
- **I:** Supervivencia y Progresión, como declara la spec.
- **II:** los jefes son la misma `CapsuleMesh` gris (`enemy_material.tres`), solo escalada. Sin assets nuevos.
- **III:** los stats, las escalas, los tamaños de desafío, el intervalo de jefes, la separación y los títulos viven en `.tres`. El padding se deriva del radio de la cápsula de la escena, sin literales nuevos. Ningún Resource compartido se muta: `enemy.stats` es una referencia y el escalado por nivel sigue en el `duplicate()` propio.
- **IV:** tipado completo; `_ready` delgado (`_apply_body_scale`).
- **V:** los jefes se pre-instancian en sus pools, y el buffer de spawns es un miembro que se limpia. Sin allocations por frame nuevas: el padding es un `float` cacheado.
- **VI:** sin inputs nuevos.
