# Feature: Feedback de daño recibido

- **Estado:** Implementada (2026-09-25, 146 tests GdUnit4 en verde, smoke test headless limpio)
- **Constitución:** `docs/constitution.md` v2.1.0 (sin enmiendas ni excepciones)
- **Pilares (Principio I):** Combate y Supervivencia. Cada golpe recibido se siente y se lee al instante, sin mirar la barra de vida.
- **Dependencias:** `combat-mvp.md`, `combat-feedback.md` (Implementadas).

## 1. Objetivo

Cada golpe que **aplica daño** al jugador dispara:
- **Camera shake:** la vista tiembla durante `shake_duration`, con una amplitud que decae hasta 0. Intensidad = `clamp(daño / damage_for_full_shake, min_strength, 1)` y desplazamiento máximo = `intensidad × shake_max_offset`. Se hace con `Camera3D.h_offset/v_offset`, sin tocar la órbita.
- **Parpadeo:** el `Visual` del jugador alterna visible e invisible cada `flicker_interval` durante `flicker_duration`, y termina visible. No se recolorea nada (Principio II).

Los golpes absorbidos por los iframes del dash no disparan nada. Al morir, el temblor se corta y el personaje queda visible.

## 2. Datos (Principio III)

| Resource | Valores |
|---|---|
| `HitFeedbackConfig` (`data/player/hit_feedback_config.tres`) | `damage_for_full_shake 20` · `min_strength 0.3` · `flicker_duration 0.4` s · `flicker_interval 0.06` s |
| `CameraConfig` (+) | `shake_duration 0.25` s · `shake_max_offset 0.3` m |

Un golpe de grunt (8 de daño) da una intensidad de 0.4.

## 3. Código

- `HealthComponent`: señal `damaged(amount)`, emitida solo si el daño aplicado es mayor que 0.
- `ThirdPersonCamera`: `shake(strength)`, `stop_shake()`, `get_shake_offset()`. `_process` delgado → `_update_shake`.
- `HitFeedbackComponent` (nodo `HitFeedback` en `player.tscn`): escucha `damaged` y `died`. Tiene la función pura `shake_strength(amount, config)`.

## 4. Criterios de aceptación

- **AC82** `damaged` informa el daño aplicado. No se emite si el jugador es invulnerable o si ya está muerto.
- **AC83** Un golpe inicia el parpadeo (alterna la visibilidad). Pasado `flicker_duration`, el visual queda visible.
- **AC84** Un golpe desplaza la vista (≠ 0, ≤ `shake_max_offset`). Pasado `shake_duration` vuelve a (0, 0).
- **AC85** `shake_strength`: 1 → 0.3 (mínimo), 8 → 0.4, 20 y 50 → 1.
- **AC86** Un golpe durante los iframes del dash no produce parpadeo ni temblor.
- **AC87** Al morir, el visual queda visible y la vista sin desplazamiento.
- **AC88** Regresión: la suite completa en verde.

### Review de la constitución (cierre)
- **I:** Combate y Supervivencia, como declara la spec.
- **II:** solo se alterna la visibilidad. El blanco del jugador y el negro de la espada nunca cambian.
- **III:** todos los tiempos, intensidades y desplazamientos viven en `.tres`.
- **IV:** tipado completo. `_process` delega en `_update_shake` y `_update_flicker`.
- **V:** sin allocations por frame (el RNG es un miembro). El proceso del parpadeo se apaga cuando no está activo.
- **VI:** sin inputs nuevos.

## 5. Fuera de alcance

- Flash rojo en bordes, barra de vida reactiva, hitstop, números de daño sobre el jugador y aviso de vida baja.
- Iframes después de recibir daño.
