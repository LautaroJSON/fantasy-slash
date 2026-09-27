# Feature: Barrido pesado del Berserker

- **Estado:** Implementada (2026-09-25, 288 tests GdUnit4 en verde, 0 orphans; import y smoke test headless del menú y de la arena sin errores ni warnings; render de control del barrido)
- **Constitución:** `docs/constitution.md` v3.1.0
- **Pilares (Principio I):**
  - **Combate:** el mandoble se siente más pesado: llega más lejos, cubre más ancho y pega más fuerte, pero ataca con menos frecuencia.
- **Dependencias:** `berserker.md`, `weapon-reach.md`, `weapon-trail.md` (Implementadas).

## 1. Datos (`data/classes/berserker/berserker_stats.tres`)

| Stat | Antes | Después |
|---|---|---|
| `attack_range` (hitbox) | 2.7 m | **3.0 m** |
| `attack_arc_degrees` | 120° | **150°** |
| `attack_speed` | 0.8 (1.25 s) | **0.7** (1.43 s) |
| `damage` | 22 | **25** |

El DPS del ataque básico queda igual (22 × 0.8 ≈ 25 × 0.7). El barrido seguía en 0.25 s compartido; desde `class-sweep-timing.md` el mandoble tiene su propio barrido de 0.35 s.

## 2. Visual (`entities/player/weapons/greatsword.tscn`)

| | Antes | Después |
|---|---|---|
| Punta de la hoja (alcance horizontal) | 2.3 m | **2.6 m** |
| Punta del modelo (z) | −1.91 | **−2.21** |
| `Model.transform` | escala 0.1593 | `Transform3D(0.1864,0,0, 0,0,-0.1864, 0,0.1864,0, 0,0,-0.355)` |
| `TrailBase` / `TrailTip` | −0.68 / −1.91 | **−0.77 / −2.21** |

La guarda sigue en z = −0.15. Se mantiene la regla de `weapon-reach.md`: 2.6 + 0.4 = 3.0.

## 3. Criterios de aceptación

- **AC205 y AC214 (actualizados)** Punta del mandoble y `TrailTip` en z ≈ −2.21.
- **AC211** Punta + radio = rango para el Berserker con los valores nuevos.
- **AC221** El Berserker tiene `attack_range` 3.0, arco 150°, `attack_speed` 0.7 y daño 25. Sigue con más daño y menos cadencia que el Guerrero (AC184).
- **AC222** El barrido cruza los 150°: arranca en ±75° y termina del lado opuesto. *(Adaptado en `humanoid-player-model.md`: el arco de 150° se verifica en el hitbox del golpe.)*
- **AC223** Regresión: suite completa en verde; el Guerrero sin cambios.

## 4. Fuera de alcance

- El radio del Giro (`hit_range 3.0`): es un stat de la habilidad, no del ataque básico.
- Un barrido más lento por arma: resuelto después en `class-sweep-timing.md`.

## 5. Plan de implementación

1. Esta spec.
2. `berserker_stats.tres` y `greatsword.tscn`.
3. Tests AC205, AC214, AC221 y AC222.
4. Suite, smoke test, render de control; estado **Implementada**.

### Review de la constitución (cierre)
- **I:** Combate.
- **II:** solo cambia la escala de la escena adaptadora del Falchion y sus marcadores de estela.
- **III:** los cuatro stats viven en `berserker_stats.tres` y siguen siendo mejorables; AC211 verifica la alineación punta/rango.
- **IV / V / VI:** sin GDScript de gameplay; sin cambios de performance ni de input.

## Ajuste posterior (2026-09-25)

- Tuning del usuario desde el editor: `attack_speed` 0.7 → **0.65** (un golpe cada ~1.54 s) y `move_speed` 6.0 → **5.5 m/s**. AC221 actualizado a 0.65. El barrido sigue en 0.35 s a velocidad base (`class-sweep-timing.md`).
