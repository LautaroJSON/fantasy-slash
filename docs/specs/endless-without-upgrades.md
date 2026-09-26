# Hotfix: Oleadas sin mejoras disponibles

- **Estado:** Implementada (2026-09-25, 338 tests GdUnit4 en verde, smoke test de la arena sin errores)
- **Constitución:** `docs/constitution.md` (sin enmiendas)
- **Pilar (Principio I):** Supervivencia. La run sigue generando presión (oleadas y jefes) después de agotar las mejoras, en vez de quedar trabada. Respeta el ciclo *empezar run → pelear → mejorar → morir*: sin esto la run no puede terminar.
- **Tipo:** corrección de bug (hotfix).
- **Dependencias:** `combat-mvp.md`, `upgrade-caps.md`, `upgrade-ban.md`, `unique-ability-upgrades.md`, `sandbox-mode.md`.

## Objetivo

Alrededor de la oleada 115 todas las cartas están en su tope (`max_stacks` / `max_level`) o bloqueadas. `WaveManager._on_all_dead()` abre igual el `UpgradePicker` con una oferta vacía: el juego queda pausado, sin cartas para elegir y sin forma de avanzar.

Con el hotfix, si la oferta de la oleada queda vacía, no se abre el picker y la siguiente oleada empieza sola, como en el sandbox. El contador de oleadas sigue subiendo, los jefes siguen saliendo cada `boss_wave_interval` oleadas y el nivel de los enemigos sigue la regla actual de `WaveConfig.enemy_level_for` (tope `max_enemy_level`, sin cambios).

La carta roja de bloqueo no cambia nada: bloquea una carta del mismo pool disponible, así que si la oferta está vacía tampoco habría qué bloquear.

## Estructura de nodos

Sin cambios.

## Resources y datos

Sin cambios. No hay valores nuevos.

## Interfaz pública

Sin cambios.

## Lógica interna

`WaveManager._on_all_dead()`:

1. Si el jugador está muerto → nada (igual que hoy).
2. Si es sandbox → `_advance_wave.call_deferred()` (igual que hoy).
3. Se arma la oferta con `build_offer()`.
4. **Nuevo:** si la oferta está vacía → `_advance_wave.call_deferred()` y termina. Diferido por el mismo motivo que en el sandbox: el último enemigo termina su propia muerte antes de que el pool lo reutilice.
5. Si no → `picker.show_offer(...)` (igual que hoy). Una oferta con menos cartas que `cards_per_offer` se sigue mostrando.

## Criterios de aceptación

En `test/levels/arena_waves_test.gd` (Estocada equipada, pool de cartas vaciado con `WaveManager.get_card_pool().clear()`, equivalente a tener todo topado o bloqueado):

- **AC267:** al limpiar la oleada 1 sin cartas disponibles, el picker no se abre y el juego no queda pausado.
- **AC268:** un frame después la run está en la oleada 2, con `enemies_per_wave` enemigos vivos.
- **AC269:** al limpiar la oleada 3 sin cartas disponibles, empieza la oleada 4 como desafío de jefe (`RunState.is_boss_wave()` es `true`).
- **AC270:** con cartas disponibles, el picker se sigue abriendo al limpiar la oleada (AC20 existente, sin cambios) y la suite completa sigue en verde.

## Plan de implementación

1. Tests AC267 a AC269 en `arena_waves_test.gd`.
2. Extraer en `_on_all_dead` la rama "oferta vacía → avanzar diferido".
3. Correr GdUnit4 headless sobre una copia en el scratchpad y el smoke test de la arena.
4. Review con el checklist de la constitución, marcar la spec como *Implementada* y actualizar el próximo AC libre (AC271) en `CLAUDE.md`.

## Review (checklist de la constitución)

- [x] **I.** Sirve a Supervivencia y destraba el ciclo de la run.
- [x] **II.** Sin cambios visuales.
- [x] **III.** Sin valores nuevos: la regla depende solo de que la oferta esté vacía.
- [x] **IV.** Tipado estático; `_on_all_dead` es un callback de señal, no de ciclo de vida.
- [x] **V.** Sin allocations por frame nuevas (`build_offer` ya se llamaba una vez por oleada).
- [x] **VI.** Sin input nuevo.

## Notas

- Ningún test viejo se modificó.
