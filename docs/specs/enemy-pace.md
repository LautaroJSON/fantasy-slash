# Ritmo de los enemigos: dificultad normal más lenta; el Rage vuelve a acelerar

- **Estado:** Implementada (2026-09-26). A pedido del usuario se corrieron solo los suites de esta spec (`enemy_pace_config_test`, `group_ai_config_test`, `enemy_pace_test`, `arena_waves_test`, `boss_challenge_run_test`) y los de `test/entities/enemy` y `test/systems` (151 tests): todos en verde, 0 orphans. Smoke test de la arena sin errores. La suite completa no se corrió.
- **Constitución:** `docs/constitution.md` **v4.5.0**, sin enmienda
- **Pilar (Principio I):** Combate + Supervivencia.
  - **Combate:** los enemigos atacan con preparaciones más largas y pausas más largas entre ataques, así que hay tiempo de leer el aviso y responder.
  - **Supervivencia:** la presión vuelve a subir con el Rage. Los tiempos se acercan a los de hoy y aumentan los atacantes simultáneos, así que el final de una run sigue siendo exigente.
- **Tipo:** balance (cambio de comportamiento). Afecta a todos los enemigos, bosses incluidos.
- **Dependencias:** `enemy-attack-telegraph.md`, `enemy-types.md`, `enemy-group-ai.md`, `enemy-rage.md`, `boss-verdugo.md`, `boss-titan.md`, `enemy-ground-telegraph.md`.

## Objetivo

Los tiempos actuales pasan a ser el ritmo **de Rage**. En una run normal:

1. **Preparación × 1.5:** todas las preparaciones (y sus avisos en el piso) duran 1.5 veces lo que duran hoy. Ejemplos: Bruto 0.5 → 0.75 s, Hostigador 0.3 → 0.45 s, Embestidor 0.8 → 1.2 s, tajo del Verdugo 0.6 → 0.9 s, aplastamiento del Titán 1.4 → 2.1 s.
2. **Intervalo entre ataques × 2:** `attack_interval` (la pausa entre un ataque y el siguiente del mismo enemigo) se duplica. Ejemplos: Bruto 0.4 → 0.8 s, Escudero 1.5 → 3.0 s.
3. **Atacantes simultáneos: 2 fijos.** Ya no suben con las oleadas: solo suben con el Rage (3 en Rage 3, 4 en Rage 6).
4. **El Rage vuelve al ritmo actual:** cada nivel de Rage baja los multiplicadores (preparación −0.1 y intervalo −0.2 por nivel) hasta 1.0, que son los tiempos de hoy. Se llega en el nivel 5.

**Qué no cambia:** los golpes, las recuperaciones, las velocidades de carga y salto, y el daño.

## Cómo se aplica

Los `.tres` de ataques y stats **no cambian**: siguen describiendo el ritmo rápido (Rage máximo). El ritmo normal es un multiplicador que se aplica al generar la oleada:
- `WaveManager._place()`, después de `activate()` y `enrage()`, llama a `enemy.apply_pace(pace, rage_level)`.
- `apply_pace` guarda el multiplicador de preparación en el enemigo y multiplica `attack_interval` en su copia de stats.
- Los enemigos creados a mano o en los tests, sin pasar por la oleada, conservan el ritmo actual. Así los tests existentes no cambian.

## Resources y datos

- **`EnemyPaceConfig`** (`resources/enemy_pace_config.gd`), en `data/enemies/enemy_pace_config.tres`:
  - `windup_scale` (1.5) y `interval_scale` (2.0);
  - `windup_scale_per_rage` (0.1) e `interval_scale_per_rage` (0.2);
  - `min_scale` (1.0).
  - Funciones puras: `windup_scale_for(rage_level)` e `interval_scale_for(rage_level)`, que devuelven `max(min_scale, scale − rage × per_rage)`.
- **`GroupAIConfig`:** los atacantes simultáneos pasan a depender del **nivel de Rage** en vez de la oleada. `base_attackers` (2) + 1 cada `rage_levels_per_extra_attacker` (3), con tope `max_attackers_cap` (4). `waves_per_extra_attacker` se reemplaza por `rage_levels_per_extra_attacker`, y `max_attackers_for(wave)` pasa a ser `max_attackers_for(rage_level)`.
- **`WaveManager`** suma `@export var pace: EnemyPaceConfig`, asignado en `arena.tscn`.

## Interfaz pública

- **`Enemy`:**
  - `apply_pace(config, rage_level)`;
  - `get_windup_scale()` (1.0 si nunca se aplicó ritmo);
  - `windup(seconds) -> float` (`seconds × windup_scale`).
  - `activate()` vuelve el multiplicador a 1.0.
- **Comportamientos** (`MeleeBehavior`, `ChargerBehavior`, `LeaperBehavior`, `HarasserBehavior`, `BossBehavior`, `TitanBehavior`): toda lectura de `windup_time` pasa por `enemy.windup(...)`, incluidos los avisos en el piso y las manos. En los bosses se combina con la escala de la fase 2.
- **`AttackCoordinator.get_max_attackers()`** lee `run_state.get_rage_level()`.

## Criterios de aceptación (AC516–AC526, reservados)

**Datos puros** (`test/resources/enemy_pace_config_test.gd`, `test/resources/group_ai_config_test.gd`):
- **AC516:** `windup_scale_for`: 1.5 con Rage 0, 1.3 con Rage 2, 1.0 con Rage 5 y 1.0 con Rage 9. `interval_scale_for`: 2.0 / 1.6 / 1.0 / 1.0.
- **AC517:** `max_attackers_for(rage)`: 2 con Rage 0, 1 y 2; 3 con Rage 3; 4 con Rage 6 y 4 con Rage 20. (Reemplaza a AC444, que dependía de la oleada.)

**Enemigo** (`test/entities/enemy/enemy_pace_test.gd`):
- **AC518:** con ritmo aplicado (Rage 0), el Bruto no pega antes de 0.75 s y sí pega poco después. Sin ritmo pega a ~0.5 s, como hoy.
- **AC519:** con ritmo aplicado, entre dos golpes del Bruto pasan al menos preparación × 1.5 + golpe + recuperación + `attack_interval` × 2.
- **AC520:** el aviso en el piso dura la preparación escalada: el relleno llega al 100 % a ~0.75 s en el Bruto.
- **AC521:** con Rage 5, el ritmo es el actual (el Bruto pega a ~0.5 s).
- **AC522:** Embestidor, Saltador, Hostigador, Verdugo y Titán escalan su preparación. Se verifica que el aviso de cada uno dura su preparación × 1.5.
- **AC523:** `activate()` vuelve el ritmo a 1.0 (un enemigo reutilizado sin `apply_pace` tiene el ritmo actual) y deja `attack_interval` en el valor de sus stats escaladas.

**Oleadas** (`test/levels/arena_waves_test.gd`):
- **AC524:** los enemigos de una oleada normal tienen `get_windup_scale()` 1.5 y `attack_interval` × 2 respecto de sus stats escaladas por nivel.
- **AC525:** con Rage 2, los enemigos de la oleada tienen 1.3 y × 1.6, y el coordinador permite 2 atacantes. Con Rage 3, 3 atacantes.
- **AC526:** las oleadas de boss también aplican el ritmo.

## Plan de implementación

1. Reservar AC516–AC526 en `CLAUDE.md` (próximo libre → AC527).
2. `EnemyPaceConfig` y su `.tres`. `GroupAIConfig` con atacantes por Rage, y `AttackCoordinator` leyendo el Rage. Tests AC516 y AC517 (se adapta AC444).
3. `Enemy.apply_pace`/`windup`/`get_windup_scale`, y `activate()` restableciendo el ritmo. `WaveManager.pace` y la llamada en `_place()`, con el `.tres` asignado en `arena.tscn`.
4. Reemplazar las lecturas de `windup_time` en los seis comportamientos por `enemy.windup(...)`. Tests AC518–AC523.
5. Tests AC524–AC526. Correr los suites de esta spec y `test/entities/enemy` y `test/systems` (los tests existentes no deben cambiar). Import y smoke test.
6. Checklist, spec **Implementada** y `CLAUDE.md` ("Dónde se ajusta": el ritmo).

## Review (checklist de la constitución)

- [x] **I.** Combate y Supervivencia, como se explica arriba.
- [x] **II.** Sin cambios visuales, salvo que los avisos duran más.
- [x] **III.** Todos los multiplicadores en `enemy_pace_config.tres` y `group_ai_config.tres`; las funciones son puras. Los `.tres` de enemigos quedan intactos.
- [x] **IV.** Tipado estático.
- [x] **V.** No se asigna memoria por frame.
- [x] **VI.** Sin input nuevo.

## Notas

- **Bosses incluidos:** también se hacen más lentos (el aplastamiento del Titán pasa a 2.1 s). Si preferís que los bosses conserven su ritmo, es un flag en `EnemyStats` (por ejemplo `ignores_pace`).
- Los valores (×1.5, ×2 y los pasos por nivel de Rage) se ajustan en el `.tres` sin tocar código.

### Implementación: ajustes respecto de lo aprobado

- **Bosses:** `BossBehavior._windup()` combina el ritmo con la escala de la fase 2. Solo se estiran las preparaciones; las recuperaciones siguen usando `_scaled()`.
- **`GroundTelegraph.get_duration()`:** getter nuevo, para que AC520 y AC522 verifiquen que el aviso dura la preparación escalada.
- **Test adaptado:** `group_ai_test` (AC446) compara con `max_attackers_for(0)`, porque los atacantes ya no dependen de la oleada. AC444 (atacantes por oleada) queda reemplazado por AC517.

## Modificada después del cierre

- **2026-09-26, `enemy-level-pace.md`:** el ritmo también depende del nivel. En el nivel 1 va de ×1.8 (preparación) y ×2.5 (pausa) a ×1.2 y ×1.4 en el nivel 25; el Rage sigue acelerando hasta ×1. AC516 queda reemplazado por AC556.
