# Ritmo por nivel, descanso entre turnos y exposición de la Colmena

- **Estado:** Implementada (2026-09-26), junto con `boss-health-tuning.md`. Se corrieron solo los suites tocados (`enemy_pace_config_test`, `group_ai_config_test`, `colmena_data_test`, `attack_coordinator_test`, `test/entities/enemy` completo, `arena_waves_test`, `boss_challenge_run_test`): todos en verde, 0 orphans. Smoke test de la arena sin errores. La suite completa no se corrió.
- **Constitución:** `docs/constitution.md` **v4.6.0**, sin enmienda
- **Pilar (Principio I):** Combate + Supervivencia.
  - **Combate:** entre tandas de ataques hay un respiro real, así que no parece que pegaran 4 a la vez.
  - **Supervivencia:** la presión crece con el nivel (la oleada), no solo con el Rage.
- **Tipo:** balance (cambio de comportamiento). Modifica `enemy-pace.md` y `enemy-group-ai.md`.
- **Dependencias:** `enemy-pace.md`, `enemy-group-ai.md`, `boss-colmena.md`.

## Problema

1. **La preparación y la pausa solo dependen del Rage**, no del nivel: todo el tramo normal de la run tiene el mismo ritmo.
2. **Los turnos pasan de uno a otro sin respiro.** Cuando los 2 atacantes terminan, devuelven su turno y los 2 que esperaban lo reciben enseguida (con 0.35 s entre entregas). Se siente como 4 enemigos pegando casi a la vez.
3. **La Colmena está muy poco tiempo sin escudo** (6 s / 4 s).

## Cambios

### 1. El nivel acelera la preparación y la pausa (rampa suave)

- Con `t = (nivel − 1) / (nivel_máximo − 1)`, siendo el nivel máximo 25:
  - **preparación** = `max(1, lerp(1.8, 1.2, t) − 0.1 × rage)`
  - **pausa** = `max(1, lerp(2.5, 1.4, t) − 0.2 × rage)`
- Queda así:

  | Nivel (oleada) | Preparación | Pausa |
  |---|---|---|
  | 1 (1–2) | ×1.8 | ×2.5 |
  | 2 (oleada 4) | ×1.78 | ×2.45 |
  | 5 (9–10) | ×1.7 | ×2.32 |
  | 10 (19–20) | ×1.58 | ×2.09 |
  | 25 (49+) | ×1.2 | ×1.4 |
  | 25 + Rage 2 | ×1.0 | ×1.0 |

- Ejemplo con un Bruto: a nivel 1 prepara 0.9 s con 1.0 s de pausa (hoy 0.75 s y 0.8 s). A nivel 25 prepara 0.6 s con 0.56 s de pausa.
- Se aplica igual a los bosses, con el nivel del boss.

### 2. Descanso del grupo entre turnos

- Cuando un enemigo **termina un ataque que llegó a empezar** y devuelve su turno, ese turno **descansa** un tiempo antes de poder entregarse otra vez. Mientras descansa, cuenta como ocupado.
- **Descanso** = `max(0.3, lerp(1.5, 0.5, t) − 0.1 × rage)`, con `t` calculado con el nivel del enemigo que lo devolvió. Da 1.5 s a nivel 1, 1.125 s a nivel 10, 0.5 s a nivel 25 y 0.3 s como mínimo con Rage.
- **Sin descanso:** los turnos que se pierden sin atacar (cancelación de la preparación, muerte antes de empezar, o sin usar durante `token_approach_timeout`) se liberan enseguida, como hoy.
- **Ejemplo** a nivel 1 con 4 Brutos y 2 turnos: los 2 primeros pegan, terminan su recuperación y, **1.5 s después**, entra el siguiente; el cuarto, 0.35 s más tarde. Antes el siguiente entraba de inmediato.

### 3. Colmena: más tiempo expuesta

`exposed_time_phase_one` pasa de 6 a **10 s** y `exposed_time_phase_two` de 4 a **7 s**.

## Resources y datos

- **`EnemyPaceConfig`:**
  - reemplaza `windup_scale`/`interval_scale` por `windup_scale_first_level` (1.8), `windup_scale_last_level` (1.2), `interval_scale_first_level` (2.5), `interval_scale_last_level` (1.4) y `last_level` (25);
  - mantiene `windup_scale_per_rage` (0.1), `interval_scale_per_rage` (0.2) y `min_scale` (1.0);
  - funciones puras `windup_scale_for(level, rage)` e `interval_scale_for(level, rage)`.
- **`GroupAIConfig`:** suma `rest_first_level` (1.5), `rest_last_level` (0.5), `rest_per_rage` (0.1), `min_rest` (0.3) y `last_level` (25), con la función pura `rest_for(level, rage)`.
- **`colmena_boss.tres`:** exposición 10 / 7.

## Interfaz pública

- `Enemy.apply_pace(config, rage_level)` usa el `level` del enemigo, que ya está puesto en `activate()`.
- **`AttackCoordinator`:**
  - `release_token(enemy)` pone a descansar el turno si el enemigo había empezado el ataque (`mark_started`); si no, lo libera al instante;
  - `get_resting_count()`;
  - la capacidad pasa a ser `titulares + turnos descansando < max_attackers`;
  - `advance(delta)` baja los descansos.
- El coordinador lee el Rage de `run_state` y el nivel del enemigo que devuelve el turno.

## Criterios de aceptación (AC556–AC565, reservados)

**Datos puros:**
- **AC556** (reemplaza a AC516): `windup_scale_for`/`interval_scale_for` dan los valores de la tabla (niveles 1, 10 y 25; nivel 25 con Rage 2 → 1.0/1.0; nunca menos de 1).
- **AC557:** `rest_for` da 1.5 a nivel 1, 1.125 a nivel 10 y 0.5 a nivel 25; con nivel 25 y Rage 5, 0.3.

**Ritmo en el enemigo** (se adaptan `enemy_pace_test` AC518–AC523 y los de oleada AC524–AC526):
- **AC558:** un Bruto de nivel 1 con ritmo aplicado no pega antes de 0.9 s y sí poco después; entre dos golpes pasan al menos 0.9 + 0.15 + 0.45 + 1.0 s.
- **AC559:** un Bruto de nivel 25 prepara en 0.6 s. Con Rage 2 vuelve a 0.5 s.
- **AC560:** en la arena, los enemigos de la oleada 1 tienen preparación ×1.8, y los de un boss de la oleada 4 (nivel 2) ×1.775.

**Descanso entre turnos** (`attack_coordinator_test`):
- **AC561:** un turno devuelto después de empezar el ataque descansa `rest_for(nivel, rage)`: mientras tanto un tercer enemigo no recibe turno aunque solo haya 1 titular, y después sí.
- **AC562:** un turno devuelto sin haber empezado (cancelación o vencimiento) no descansa.
- **AC563** (`group_ai_test`): con 4 Brutos de nivel 1 y 2 turnos, entre el final del ataque del primer par y el comienzo de la preparación del siguiente pasa al menos `rest_for(1, 0)` − 1 frame.

**Colmena:**
- **AC564:** expuesta 10 s en la fase 1 y 7 s en la fase 2 (se adapta AC527 y los tiempos de `colmena_test`).

**Tests existentes:**
- **AC565:** los tests del coordinador y del grupo que devolvían un turno y pedían otro enseguida avanzan el descanso antes (AC443, AC446). Siguen verificando lo mismo.

## Plan de implementación

1. Reservar AC556–AC565 en `CLAUDE.md` (próximo libre → AC566).
2. `EnemyPaceConfig` por nivel y `apply_pace` con el nivel del enemigo. Tests AC556, AC558–AC560; se adaptan los de `enemy-pace`.
3. `GroupAIConfig.rest_for` y el descanso en `AttackCoordinator`. Tests AC557, AC561–AC563 y AC565.
4. Exposición de la Colmena. Test AC564.
5. Correr los suites tocados (`enemy_pace_config_test`, `enemy_pace_test`, `group_ai_config_test`, `attack_coordinator_test`, `group_ai_test`, `colmena_data_test`, `colmena_test`, `arena_waves_test`, `boss_challenge_run_test`) y `test/entities/enemy`. Smoke test.
6. Checklist, spec **Implementada**, notas en `enemy-pace.md` y `enemy-group-ai.md`, y `CLAUDE.md`.

## Review (checklist de la constitución)

- [x] **I.** Combate y Supervivencia, como se explica arriba.
- [x] **II.** Sin cambios visuales, salvo que los avisos duran lo que la preparación.
- [x] **III.** Todos los valores en `enemy_pace_config.tres`, `group_ai_config.tres` y `colmena_boss.tres`; las funciones son puras.
- [x] **IV.** Tipado estático.
- [x] **V.** Los descansos son un array reutilizado, sin asignar memoria por frame.
- [x] **VI.** Sin input nuevo.

## Notas de implementación

- **ACs renumerados:** la spec se aprobó con AC550–AC559, pero esos números los tomó la spec `dash-iframes` de otra sesión. Quedaron en **AC556–AC565**, con el mismo contenido.
- **AC560 (bosses):** los bosses forzados en los tests aparecen en la oleada en curso, así que el test compara con `windup_scale_for(nivel del boss, 0)` en lugar del valor fijo de la oleada 4 (×1.775).
- **Descanso al morir:** si un enemigo muere en medio de un ataque que ya empezó, su turno también descansa. Se considera un ataque que llegó a empezar.
- Se agregaron notas en `enemy-pace.md` y `enemy-group-ai.md`.
