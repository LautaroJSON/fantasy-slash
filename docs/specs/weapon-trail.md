# Feature: Estela estándar del arma (sword trail)

- **Estado:** Implementada (2026-09-25, 286 tests GdUnit4 en verde, 0 orphans; import y smoke test headless del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.1.0 (enmienda MINOR aprobada con esta spec: mallas procedurales solo para VFX; estela del arma en la tabla de colores)
- **Pilares (Principio I):**
  - **Combate:** cada golpe se lee como un corte, con el mismo lenguaje visual en todas las armas, ataques y habilidades.
- **Dependencias:** `weapon-models.md`, `hoplite-sword.md`, `weapon-reach.md`.
- **Reemplaza:** `attack-indicator.md` (arco en el suelo) y la estela de `spin-buff-wind-trail.md` (la parte "buff" del Giro se mantiene).

## 1. Objetivo

- Una estela blanca translúcida (ribbon) sigue a la hoja real del arma durante el ataque básico y durante cualquier habilidad, y se desvanece en décimas de segundo.
- Es un solo componente, el mismo para todas las clases. Un arma nueva solo necesita dos `Marker3D`.
- Se quitan el arco del ataque en el suelo y la estela de franjas del Giro.

## 2. Nodos

```
Player
├── Visual/SwordPivot/<arma>
│     ├── Model
│     ├── TrailBase (Marker3D)   a ~30 % de la hoja desde la guarda
│     └── TrailTip  (Marker3D)   en la punta
└── WeaponTrail (MeshInstance3D, top_level, ImmediateMesh creado una vez)
```

| Arma | `TrailBase` z | `TrailTip` z |
|---|---|---|
| `sword.tscn` (hoplite) | −0.5 | −1.67 |
| `spartan_sword.tscn` | −0.5 | −1.67 |
| `greatsword.tscn` (falchion) | −0.68 | −1.91 |

## 3. Datos (Principio III)

| Resource | Campos |
|---|---|
| `WeaponTrailConfig` | `lifetime`, `head_alpha`, `max_samples` |

| Archivo | Valores |
|---|---|
| `data/player/weapon_trail_config.tres` | `lifetime 0.15 s` · `head_alpha 0.5` · `max_samples 32` |
| `materials/weapon_trail_material.tres` | blanco, unshaded, transparencia alpha, `vertex_color_use_as_albedo`, sin culling |

## 4. Interfaz pública

- **`WeaponTrail`** (`components/weapon_trail.gd`, `MeshInstance3D`):
  - `@export sword_swing: SwordSwing`, `@export abilities: Array[AbilityComponent]`, `@export config: WeaponTrailConfig`, `@export material: StandardMaterial3D`.
  - `attach(base: Node3D, tip: Node3D)`: lo llama `Player._equip_weapon` con los marcadores del arma.
  - `advance(delta)`: si emite, agrega una muestra (posición global de base y punta). Envejece las muestras, descarta las que superan `lifetime` y reconstruye la tira de triángulos con alpha de `head_alpha` a 0 según la edad.
  - `is_emitting()`, `get_sample_count()`, `get_sample_tip(i)`, `get_sample_alpha(i)` (i = 0 es la más nueva).
- **`SwordSwing`:** + señales `swing_started` y `swing_ended`. `swing_ended` se emite al salir del barrido, también cuando se cancela.
- **Encendido y apagado:** `WeaponTrail` escucha `swing_started`/`swing_ended` y `cast_started`/`cast_released`. Emite mientras `sword_swing.is_swinging()` o alguna habilidad `is_casting()`.

## 5. Lógica interna

- Buffer circular preasignado en `_ready` (`PackedVector3Array` × 2 y `PackedFloat32Array` de edades, tamaño `max_samples`). Sin allocations de GDScript por frame (Principio V).
- `_process` solo llama a `advance`. El proceso se apaga cuando no emite y no quedan muestras, y la malla se oculta.

## 6. Criterios de aceptación

- **AC214** Cada escena de arma tiene `TrailBase` y `TrailTip`, y `TrailTip` está en la punta del modelo (±0.05).
- **AC215** Un ataque básico enciende la estela. Al terminar el barrido deja de emitir y, pasado `lifetime`, queda sin muestras.
- **AC216** La estela emite durante todo el casteo de la Estocada, el Golpe Veloz y el Giro, y se apaga al terminar.
- **AC217** Durante un barrido, la última muestra coincide con la posición global de `TrailTip`.
- **AC218** La muestra más nueva tiene alpha `head_alpha`, las más viejas menos, y nunca hay más de `max_samples`.
- **AC219** El jugador ya no tiene `AttackIndicator` y el Giro ya no tiene `WindTrail`.
- **AC220** Regresión: suite completa en verde.

## 7. Plan de implementación

1. Enmienda 3.1.0 y esta spec.
2. `WeaponTrailConfig`, `.tres`, material y marcadores en las 3 armas.
3. `weapon_trail.gd`, señales en `SwordSwing`, nodo en `player.tscn` y `attach` en `_equip_weapon`.
4. Borrar `AttackIndicator` y `SpinWindTrail` con sus datos y tests.
5. Tests AC214–AC219, suite completa, smoke test, render de control; estado **Implementada**.

## 8. Notas de implementación

- AC216 quedó en tres tests, uno por habilidad: equipar varias habilidades en el mismo slot dentro de un test deja la anterior en `queue_free` y GdUnit la cuenta como orphan.
- `SwordSwing._set_phase()` centraliza los cambios de fase y emite `swing_started`/`swing_ended`.
- Se verificó con un render real (no headless) del Guerrero y del Berserker en pleno barrido: la cinta sigue a la hoja y se desvanece hacia la cola.

### Review de la constitución (cierre)
- **I:** Combate: el mismo lenguaje visual de corte para ataques y habilidades.
- **II (v3.1.0):** `ImmediateMesh` solo para VFX, con material `.tres` compartido (blanco, unshaded, alpha ≤ 0.5) y sin texturas.
- **III:** `lifetime`, `head_alpha` y `max_samples` viven en `weapon_trail_config.tres`; las posiciones de la estela, en los marcadores de cada escena de arma.
- **IV:** tipado completo; `_process` solo llama a `advance`; `Player` solo agrega `attach` en `_equip_weapon`.
- **V:** buffers `Packed*Array` preasignados en `_ready`; sin `get_node` ni allocations de GDScript por frame; el proceso se apaga cuando la estela está vacía.
- **VI:** sin cambios de input.
