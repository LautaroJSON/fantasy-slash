# Feature: Topes por carta de mejora + detalle en el panel sandbox

- **Estado:** Implementada (2026-09-25, 190 tests GdUnit4 en verde, smoke tests headless del menú y de la arena limpios)
- **Constitución:** `docs/constitution.md` **v2.2.1** (esta feature introduce la enmienda PATCH "toda carta declara su tope")
  - *Revisión (2026-09-25):* crítico 5 % (×19 cartas hasta 100 %), daño crítico como bonus +100 % (×14 hasta 300 %, `max_crit_damage`), robo de vida 0 %, dash 1.5 s / 3.0 m; sin cartas de arco, dash, invencibilidad ni salto. Ver `stats-rework.md`.
- **Pilar (Principio I):** Progresión. Las builds tienen límites claros y nunca se ofrece una carta inútil. El sandbox muestra qué aporta cada mejora.
- **Dependencias:** `combat-mvp.md`, `ability-system.md`, `unique-ability-upgrades.md`, `sandbox-mode.md`.

## 1. Topes (`max_stacks`)

Cada `UpgradeData` y cada `AbilityUpgradeData` declaran `max_stacks`. Las únicas ya declaran `max_level`.
- **Normal:** una carta en su tope sale del pool. `Player.apply_upgrade` además ignora una carta que ya llegó al tope.
- **Sandbox:** el **+** se desactiva en el tope y el contador muestra `n/tope`.
- Los pisos y techos existentes siguen como red de seguridad. Los topes de enfriamiento y velocidad de habilidad coinciden exactamente con su piso.

| Personaje | Tope | Estocada | Tope | Swift Strike | Tope |
|---|---|---|---|---|---|
| Daño | 10 | Daño base | 8 | Daño base | 8 |
| Bonus de daño | 10 | Escalado | 8 | Escalado | 8 |
| Prob. de crítico | 10 | Enfriamiento | 6 | Enfriamiento | 9 |
| Daño crítico | 8 | Alcance | 4 | Recorrido | 4 |
| Vel. de ataque | 8 | Ancho | 4 | Ancho | 4 |
| Rango de ataque | 5 | Vel. de casteo | 5 | Vel. del sprint | 6 |
| Arco de ataque | 8 | | | | |
| Robo de vida | 5 | | | | |
| Vida máxima | 10 | | | | |
| Defensa | 8 | | | | |
| Vel. de movimiento | 6 | | | | |
| Salto | 3 | | | | |
| Distancia de dash | 5 | | | | |
| Invulnerabilidad | 4 | | | | |
| Enfriamiento de dash | 3 | | | | |

## 2. Panel sandbox

Cada fila muestra: `Nombre   (base → actual)   n/tope   −  +`.
- **Stats del personaje:** base de `PlayerStats` y valor efectivo, con el formato de `StatDisplayTable` (p. ej. `(15 % → 40 %)`).
- **Stats de habilidad:** base de `AbilityData` y valor efectivo de la ranura, con el formato de `AbilityStatFormats` (`data/ui/ability_stat_formats.tres`), p. ej. `(10 → 35)` o `(6.0 → 9.0 m)`.
- **Únicas:** el valor del nivel actual con su `value_format` (`(20 %)`, `(2 %/s)`). Las que no tienen valor muestran `(activo)` / `(inactivo)`, y con nivel 0, `(—)`.
- **Tooltip** al pasar el mouse por el nombre, con un resumen breve: lo que da cada copia (la descripción de la carta) y el tope. En las únicas muestra el texto de cada nivel.

## 3. Datos nuevos

- `ValueFormat` (Resource): `format`, `multiplier` y `format_value(value)`.
- `AbilityStatFormats` (Resource): `formats: Array[ValueFormat]`, indexado por `AbilityData.Stat`:
  - `BASE_DAMAGE "%.0f"`
  - `ATTACK_SCALING "%.0f %%"` ×100
  - `COOLDOWN "%.1f s"`
  - `HIT_RANGE "%.1f m"`
  - `HIT_WIDTH "%.1f m"`
  - `CAST_DURATION "%.2f s"`
- `AbilityUniqueUpgradeData.value_format: ValueFormat`: Asesinato `"%.0f %%"` ×100, Lacerante `"%.0f %%/s"` ×100, Reset sin formato.

## 4. Criterios de aceptación

- **AC119** Toda carta de stat tiene `max_stacks > 0`. Ninguna carta negativa de habilidad baja su stat del piso al llegar al tope. Las de enfriamiento y velocidad de habilidad llegan exactamente al piso.
- **AC120** Normal: con Daño en 10 copias, la carta no está en el pool disponible y una 11.ª no se aplica.
- **AC121** Sandbox: el contador muestra `n/tope` y el **+** se desactiva en el tope.
- **AC122** Sandbox: con Estocada daño ×5, la fila muestra `(10 → 35)`. Con Prob. de crítico ×5, `(15 % → 40 %)`.
- **AC123** Sandbox: únicas. Asesinato Nv 2 muestra `(20 %)`, Reset activo muestra `(activo)` y sin tomar muestra `(inactivo)`.
- **AC124** El tooltip del nombre incluye la descripción de la carta y su tope.
- **AC125** Swift Strike con 6 copias de velocidad: `CAST_DURATION` = 0.12 (su piso).
- **AC126** Regresión: la suite completa en verde.
  - *Notas:*
    - Dos tests de `ability_component_test.gd` creaban un `UpgradeData` sin `max_stacks`, que equivale a tope 0, y `apply_upgrade` lo ignoraba. Ahora declaran `max_stacks = 1`.
    - Se eliminó `Player.is_unique_maxed`: `Player.is_maxed(card)` cubre todas las cartas.

### Review de la constitución (cierre, v2.2.1)
- **I:** Progresión, como declara la spec.
- **II:** solo UI 2D.
- **III:** todo tope vive en los `.tres` (`max_stacks` / `max_level`). Los formatos de valor son datos (`ValueFormat`, `AbilityStatFormats`, `StatDisplayTable`).
- **IV:** tipado completo.
- **V:** las filas se construyen al abrir la pausa y los textos se recalculan solo al tocar un botón.
- **VI:** sin inputs nuevos.
