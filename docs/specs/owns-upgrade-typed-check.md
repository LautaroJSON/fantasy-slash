# Fix: Comprobación tipada en `AbilityComponent.owns_upgrade`

- **Estado:** Implementada (2026-09-25, 234 tests GdUnit4 en verde, 0 errores `Attempted to use 'has'` en la salida)
- **Constitución:** `docs/constitution.md` **v2.4.0**
- **Pilar (Principio I):** Progresión. El pool de cartas de mejora se arma sin errores de motor.
- **Tipo:** corrección de bug, sin cambios de gameplay.
- **Dependencias:** `ability-system.md`, `unique-ability-upgrades.md`, `upgrade-caps.md`.

## Objetivo

`owns_upgrade(card)` devuelve el mismo resultado que antes, pero nunca llama a `Array.has()` con un objeto de otra clase sobre un array tipado. Se eliminan los ~460 `Attempted to use 'has' an object into a TypedArray, that does not inherit from 'GDScript'` que aparecían al armar el pool (`WaveManager.get_available_pool` → `Player.is_maxed` / `count_upgrade`).

Causa: una `AbilityUniqueUpgradeData` se buscaba primero en `_data.upgrades` (`Array[AbilityUpgradeData]`), y una `AbilityUpgradeData` ajena al slot seguía por el `or` hasta `_data.unique_upgrades` (`Array[AbilityUniqueUpgradeData]`).

## Estructura de nodos

Sin cambios.

## Interfaz pública

Sin cambios: `func owns_upgrade(card: UpgradeCard) -> bool`.

## Lógica interna

- `_data == null` → `false`.
- `card is AbilityUpgradeData` → `_data.upgrades.has(card as AbilityUpgradeData)`.
- `card is AbilityUniqueUpgradeData` → `_data.unique_upgrades.has(card as AbilityUniqueUpgradeData)`.
- Cualquier otro `UpgradeCard` (p. ej. `UpgradeData`) → `false`, sin tocar los arrays.

## Criterios de aceptación

En `test/components/abilities/ability_component_test.gd`, con Estocada (Thrust) equipada:

- **AC-OU1:** una carta de stat de Estocada → `true`.
- **AC-OU2:** la mejora única de Estocada (`lacerating`) → `true`.
- **AC-OU3:** una carta de stat de Swift Strike → `false`.
- **AC-OU4:** la mejora única de Swift Strike (`reset`) → `false`.
- **AC-OU5:** una `UpgradeData` del jugador (`data/upgrades/damage.tres`) → `false`.
- **AC-OU6:** con el slot vacío (sin equipar) → `false`.
- **AC-OU7:** la suite completa sigue en verde y la salida ya no contiene `Attempted to use 'has' an object into a TypedArray`.

## Plan de implementación

1. Tests AC-OU1 a AC-OU6 en `ability_component_test.gd`.
2. Reescribir `owns_upgrade` con ramas `is` y casts explícitos.
3. Correr GdUnit4 headless sobre una copia en el scratchpad y buscar el mensaje de error en la salida (AC-OU7).
4. Review con el checklist de la constitución y marcar la spec como *Implementada*.
