# Feature: Barrido propio por clase, adaptado a la velocidad de ataque

- **Estado:** Implementada (2026-09-25, 292 tests GdUnit4 en verde, 0 orphans; import y smoke test headless del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.1.0
- **Pilares (Principio I):**
  - **Combate:** cada arma tiene su propio ritmo de corte (el mandoble se siente pesado), y subir la velocidad de ataque se nota también en la animación, no solo en la frecuencia.
- **Dependencias:** `sword-sweep.md`, `berserker-heavy-sweep.md` (Implementadas).

## 1. Objetivo

- El barrido (el cruce de la hoja por el arco en el ataque básico) es 100 % por clase: forma y tiempos viven en su `SwordSwingConfig`.
- La duración del barrido y de la recuperación se escala con la velocidad de ataque.
- El golpe sigue siendo instantáneo al hacer clic. Lo que depende del barrido, además de lo visual, es el bloqueo de giro del auto-aim.

## 2. Datos (Principio III)

- `swing_duration` sale de `PlayerTuning` y pasa a `SwordSwingConfig`: "duración del cruce a la velocidad de ataque **base de la clase**".

| Config | `swing_duration` | `recover_duration` | Velocidad base |
|---|---|---|---|
| `data/classes/warrior/sword_swing_config.tres` (Guerrero) | 0.25 s | 0.12 s | 1.2 |
| `data/classes/berserker/greatsword_swing_config.tres` (Berserker) | **0.35 s** | 0.25 s | 0.7 |

## 3. Regla de adaptación

> `time_scale` = velocidad de ataque base de la clase / velocidad de ataque actual
> barrido = min(`swing_duration` × `time_scale`, intervalo entre ataques)
> recuperación = `recover_duration` × `time_scale`

| | Base | Con 8 mejoras de velocidad (+1.2) |
|---|---|---|
| Guerrero | 1.2 → 0.25 s | 2.4 → 0.125 s |
| Berserker | 0.7 → 0.35 s | 1.9 → 0.13 s |

Las mejoras de velocidad tienen tope (`max_stacks`), así que no hace falta un piso de duración.

## 4. Interfaz pública y cambios

- `SwordSwingConfig`: + `swing_duration`. `PlayerTuning`: − `swing_duration`.
- `AttackComponent`: calcula `time_scale` con `stats.base_stats.attack_speed`; el barrido y el bloqueo de giro usan la duración escalada.
- `SwordSwing.play(arc_degrees, duration, time_scale)`: la recuperación posterior a un ataque dura `recover_duration × time_scale`. `recover()` (lo usan las habilidades) sigue sin escalar.
- `SwordSwing.get_swing_duration()` y `get_recover_duration()`: getters de solo lectura para los tests.

## 5. Criterios de aceptación

- **AC224** Sin mejoras, el barrido del Guerrero dura 0.25 s y el del Berserker 0.35 s (cruza el arco en ese tiempo y no antes). *(Reemplazado por `humanoid-player-model.md`: el ataque básico ya no barre; lo cubren AC600 y AC601.)*
- **AC225** Con +100 % de velocidad de ataque sobre la base, el barrido y la recuperación duran la mitad. *(Reemplazado por AC600 de `humanoid-player-model.md`.)*
- **AC226** El barrido nunca dura más que el intervalo entre ataques. *(Reemplazado por `humanoid-player-model.md`: sin barrido ni intervalo, la cadencia la marca el combo.)*
- **AC227** El bloqueo de giro del auto-aim dura lo mismo que el barrido escalado. *(Adaptado en `humanoid-player-model.md`: el bloqueo dura todo el golpe del combo.)*
- **AC228** Regresión: AC89–AC92, AC187 y AC222 leen la duración de `SwordSwingConfig`; suite completa en verde.

## 6. Plan de implementación

1. Esta spec y notas en `sword-sweep.md`, `combat-mvp.md` y `berserker-heavy-sweep.md`.
2. Mover `swing_duration` a los dos `SwordSwingConfig` y quitarlo de `PlayerTuning`.
3. `AttackComponent` y `SwordSwing.play`.
4. Tests adaptados y AC224–AC227; suite, smoke test; estado **Implementada**.

### Review de la constitución (cierre)
- **I:** Combate.
- **II:** sin cambios visuales de assets.
- **III:** las duraciones viven en `SwordSwingConfig` por clase; la escala sale de los stats (mejorables). Ningún Resource se muta.
- **IV:** firmas tipadas; `_physics_process`/`_process` sin cambios; la lógica está en `_swing_time`/`_play_swing`.
- **V:** solo aritmética en el clic, sin allocations.
- **VI:** sin cambios de input.
