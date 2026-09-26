# Feature: Buff del Giro + estela de viento

- **Estado:** Implementada (2026-09-25, 281 tests GdUnit4 en verde; los tests de habilidades pasaron 3 corridas seguidas; smoke test headless del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v2.6.0 (enmienda MINOR aprobada con esta spec: estela en blanco translúcido)
  - *Revisión v3.1.0:* la estela de viento (`SpinWindTrail`, AC198 y siguientes) fue reemplazada por la estela estándar del arma de `weapon-trail.md`. El buff del Giro sigue vigente.
- **Pilares (Principio I):**
  - **Progresión:** la mejora de velocidad del Giro llega más lejos (2.5 vueltas/s).
  - **Combate:** la estela hace legible por dónde pasa el mandoble y a qué ritmo gira.
- **Dependencias:** `berserker.md` (Implementada).

## 1. Objetivo

- **Velocidad del Giro:** la base sigue en 1 s por vuelta. El piso pasa a **0.4 s por vuelta** (2.5 vueltas/s). La mejora sigue siendo −0.1 s por vuelta y su tope pasa de 5 a **6 copias**: 1.0 → 0.4 justo en la 6.ª, sin desperdiciar copias (Principio III).
- **Estela de viento:** mientras gira, un arco muy tenue de franjas blancas translúcidas sigue a la punta del mandoble por detrás. Se desvanece al terminar el giro.

## 2. Estructura

### 2.1 Datos (Principio III)

| Archivo | Cambio |
|---|---|
| `data/abilities/spin/spin.tres` | `min_tick_interval` 0.5 → 0.4 |
| `data/abilities/spin/upgrades/speed.tres` | `max_stacks` 5 → 6 |
| `resources/wind_trail_config.gd` (nuevo) | `segment_count`, `radius`, `arc_degrees`, `height`, `ribbon_height`, `ribbon_thickness`, `head_transparency`, `tail_transparency`, `fade_duration` |
| `data/abilities/spin/wind_trail_config.tres` (nuevo) | 8 franjas · radio 1.9 m · arco 80° · altura 1.1 m · franja 0.08 × 0.02 m · transparencia 0.75 → 0.95 · fade 0.2 s |
| `materials/wind_trail_material.tres` (nuevo) | unshaded, transparencia alpha, `Color(1, 1, 1)` |

### 2.2 Escena

```
SpinAbility (spin_ability.tscn)
└── WindTrail : SpinWindTrail (Node3D, top_level)   config + material
      └── 8 × MeshInstance3D (BoxMesh compartido, creados una sola vez en _ready)
```

## 3. Interfaz pública

- **`SpinWindTrail`** (`components/abilities/spin_wind_trail.gd`), mismo patrón que `AbilityRectIndicator`:
  - `show_trail(blade_yaw)`: arma el arco detrás del mandoble. La franja 0 va junto a la hoja y las siguientes hacia atrás en el sentido del giro, con transparencia de `head` a `tail`.
  - `follow(visual)`: copia la posición y el yaw del `Visual`. Es una asignación por frame, sin allocations.
  - `start_fade()`, `advance(delta)`, `is_showing()`, `get_segment_count()`, `get_segment(i)`, `get_blade_yaw()`.
- **`SpinAbility`:** `begin()` → `show_trail(config.blade_rotation.y)` + `follow`; `channel()` → `follow(visual)`; `release()` → `start_fade()`.

## 4. Criterios de aceptación

- **AC196** `spin.tres`: `tick_interval` 1.0 y `min_tick_interval` 0.4. `speed.tres`: `max_stacks` 6. Con 6 copias `TICK_INTERVAL` queda en 0.4 y la carta está al tope. Ninguna combinación baja de 0.4.
- **AC197** Con 6 copias, un giro de 3 s golpea 7 veces (a los 0.4, 0.8 … 2.8 s).
- **AC198** La estela está oculta en reposo y visible al empezar el giro. Tiene `segment_count` franjas `BoxMesh` con el material compartido de viento, a `radius` del jugador y a `height`, todas detrás del mandoble en el sentido del giro.
- **AC199** La estela gira con el `Visual`: tras un cuarto de vuelta, su yaw avanzó π/2.
- **AC200** La franja junto a la hoja usa `head_transparency` y la última `tail_transparency`. Ninguna es más opaca que `head_transparency`.
- **AC201** Al terminar el giro se desvanece en `fade_duration` y se oculta. Tras dos giros sigue habiendo `segment_count` franjas (se reutilizan, Principio V).
- **AC202** Regresión: la suite completa sigue en verde.
  - *Nota:* AC197 cuenta las vueltas completadas (`SpinAbility.get_turns_done()`), no los golpes a un solo enemigo: un grunt de 40 de vida muere en el 4.º golpe y ya no queda a quién pegarle.

### Review de la constitución (cierre)
- **I:** Progresión (tope de velocidad más alto) y Combate (el giro se lee mejor), como declara la spec.
- **II:** la estela son 8 `BoxMesh` con el material compartido `wind_trail_material.tres` (unshaded, blanco translúcido, transparencia 0.75–0.95), según la enmienda 2.6.0. Sin partículas, shaders ni texturas.
- **III:** la forma, la transparencia y el fade de la estela viven en `wind_trail_config.tres`, y el piso y el tope de la velocidad en `spin.tres` y `speed.tres`. La 6.ª copia llega justo al piso, así que ninguna copia se desperdicia.
- **IV:** tipado completo. `_ready` y `_process` solo delegan.
- **V:** las franjas se crean una vez en `_ready` y se reutilizan. Por frame solo se copia una transformación (`follow`), sin allocations. El fade cambia `transparency` por instancia sin duplicar el material.
- **VI:** sin inputs nuevos.

## 5. Plan de implementación

1. Enmienda 2.6.0 y esta spec.
2. Datos: `spin.tres`, `speed.tres`.
3. `WindTrailConfig`, `wind_trail_config.tres`, `wind_trail_material.tres`.
4. `SpinWindTrail` + nodo en `spin_ability.tscn` + conexión en `SpinAbility`.
5. Tests AC196–AC201, suite completa (AC202), smoke test, checklist, spec **Implementada**.

## 6. Fuera de alcance

- Partículas (`GPUParticles3D`) o shaders: el Principio II no los permite.
- Estela en el ataque básico o en otras habilidades.
- Sonido.
