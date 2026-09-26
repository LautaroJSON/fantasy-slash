# Feature: Alcance del arma alineado con su modelo

- **Estado:** Implementada (2026-09-25, 286 tests GdUnit4 en verde, 0 orphans; import y smoke test headless del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.1.0
- **Pilares (Principio I):**
  - **Combate:** lo que se ve en el barrido es lo que pega, y el Guerrero alcanza a los enemigos que se frenan frente a él (los grunts se detienen a 2.0 m, justo en el límite del rango anterior).
- **Dependencias:** `weapon-models.md`, `hoplite-sword.md` (Implementadas).

## 1. Regla de alineación

> `attack_range` base = `hilt_offset` + |punta del modelo| × cos(`blade_tilt`) + radio del enemigo (0.4)

Pega cuando la punta roza el cuerpo del enemigo. El radio sale del `CapsuleShape3D` de `enemy.tscn`. La mejora "Rango" sigue agrandando solo el hitbox; que el arma crezca con ella queda fuera de alcance.

## 2. Datos y escenas

| Clase | `attack_range` | Punta del modelo (z) | `Model.transform` |
|---|---|---|---|
| Guerrero (`player_stats.tres`, hoplite) | 2.0 → **2.4** | −1.2 → **−1.67** | `Transform3D(0.1672,0,0, 0,0,-0.1672, 0,0.1672,0, 0,0,-0.1672)` |
| Spartan en reserva (`spartan_sword.tscn`) | usa el del Guerrero | −1.2 → **−1.67** | `Transform3D(0.1609,0,0, 0,0,-0.1609, 0,0.1609,0, 0,0,0.037)` |
| Berserker (`berserker_stats.tres`, falchion) | 2.5 → **2.7** | −1.9 → **−1.91** | `Transform3D(0.1593,0,0, 0,0,-0.1593, 0,0.1593,0, 0,0,-0.325)` |

Sin GDScript de gameplay.

## 3. Criterios de aceptación

- **AC205 (actualizado)** Puntas en z ≈ −1.67 (espada) y −1.91 (mandoble), ±0.05.
- **AC208 (actualizado)** `spartan_sword.tscn` tiene la punta en z ≈ −1.67.
- **AC211** Para cada clase, `hilt_offset + |punta| × cos(blade_tilt) + radio del enemigo` coincide con su `attack_range` base (±0.05).
- **AC212** Un grunt frenado a su `attack_range` (2.0 m) frente al Guerrero recibe el golpe.
- **AC213** Regresión: suite completa en verde.

## 4. Plan de implementación

1. Esta spec.
2. `player_stats.tres` y `berserker_stats.tres`.
3. `transform` de las 3 escenas de armas.
4. Tests AC205, AC208, AC211 y AC212; suite completa; estado **Implementada**.

## 5. Notas de implementación

- `boss_body_test.gd` AC149 ("el alcance contra un grunt no cambia") tenía la distancia 2.1 m fija, pensada para el rango 2.0. Ahora la deriva de `ATTACK_RANGE + 0.1`, así que sigue verificando lo mismo: sin padding para cuerpos normales.

### Review de la constitución (cierre)
- **I:** Combate.
- **II:** solo cambia la escala de las escenas adaptadoras.
- **III:** los rangos siguen en `.tres` y son mejorables; la regla de alineación la verifica AC211 contra los datos.
- **IV / V / VI:** sin GDScript de gameplay, sin cambios de performance ni de input.

## 6. Ajuste posterior (2026-09-25)

- Guerrero: `attack_range` 2.4 → **2.2 m** (decisión del usuario). La hoplita se achica a punta z ≈ **−1.47** (`Model` escala 0.1468, z −0.1468; `TrailBase` −0.44, `TrailTip` −1.47). La Spartan en reserva sigue la misma regla (escala 0.1413, z 0.0325). Se mantiene la regla: 0.35 + 1.47 × cos(0.15) + 0.4 ≈ 2.2.
