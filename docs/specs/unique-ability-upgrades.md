# Feature: Mejoras únicas de habilidad + debuffs

- **Estado:** Implementada (2026-09-25, 167 tests GdUnit4 en verde; los tests de física de mejoras únicas pasaron 3 corridas seguidas; smoke test headless limpio)
- **Constitución:** `docs/constitution.md` **v2.2.0** (esta feature introduce la enmienda "Mejoras únicas de habilidad")
- **Pilares (Principio I):**
  - **Progresión:** las builds cambian cómo funciona la habilidad, no solo sus números.
  - **Combate:** kills en cadena con Swift Strike y daño en el tiempo con la Estocada.
- **Dependencias:** `ability-system.md`, `swift-strike.md`, `upgrade-ban.md`, `combat-feedback.md`.

## 1. Mejoras

| Habilidad | Mejora (id) | Efecto | Niveles (`level_values`) | ¿Mejorable? |
|---|---|---|---|---|
| Swift Strike | **Reset** (`reset_on_kill`) | Si el sprint mata al menos a un enemigo, el cooldown se reinicia al terminar el sprint. | — (1 nivel) | **No**: el efecto es binario, un "reset más fuerte" no existe. |
| Swift Strike | **Asesinato** (`execute`) | Después del corte, si al enemigo le queda ≤ X de su vida máxima, muere (ignora la defensa). Cuenta como kill para Reset. | 0.15 · 0.20 · 0.25 | Sí: sube el umbral. |
| Estocada | **Lacerante** (`bleed`) | Aplica **Sangrado**: X de la vida máxima por segundo durante 5 s, ignorando la defensa. Reaplicarlo reinicia la duración y usa la potencia mayor (no se apila). | 0.01 · 0.02 · 0.03 | Sí: sube el daño por segundo. |

- Las cartas son **doradas** y muestran el nivel que otorgan ("Asesinato (Nv 2)"). La descripción sale de `level_descriptions`.
- Entran al mismo sorteo que las demás mejoras, solo las de la habilidad equipada. En nivel máximo salen del pool. Se pueden bloquear con la carta roja.

## 2. Debuffs

- `DebuffData`: `id`, `duration`, `tick_interval`, `icon_material`. Sangrado (`data/debuffs/bleed.tres`): 5 s, tick cada 1 s, `materials/debuff_bleed_material.tres` rojo oscuro `Color(0.55, 0.05, 0.05)`.
- `DebuffComponent` (en `enemy.tscn`):
  - Guarda `Array` de debuffs activos (`ActiveDebuff`: data, potencia, tiempo restante, tick restante).
  - Reaplicar el mismo id refresca la duración con la potencia mayor. Ids distintos conviven.
  - En cada tick quita `potencia × vida máxima` con `HealthComponent.receive_true_damage` y emite `ticked(amount)`.
  - Se limpia en `activate` y `deactivate` del enemigo (pool).
- `EnemyRegistry` reenvía los ticks (`enemy_debuff_ticked(enemy, amount)`) y `DamageNumberPool` muestra un número blanco por tick.
- `DebuffIconRow` (hijo de `HealthBar`):
  - Tiene `max_icons` casilleros de `BoxMesh` creados una sola vez, alineados sobre la barra.
  - Cada debuff activo ocupa uno con su `icon_material`, y se ocultan al expirar.
  - Config: `DebuffIconConfig` (`max_icons 4`, `icon_size 0.12`, `spacing 0.04`, `height_above_bar 0.12`).

## 3. Código

- `AbilityUniqueUpgradeData extends UpgradeCard`: `id`, `max_level`, `level_values: Array[float]`, `level_descriptions: Array[String]`, `debuff: DebuffData` (opcional). `is_same_kind` compara el id.
- `AbilityData.unique_upgrades: Array[AbilityUniqueUpgradeData]`.
- `AbilityComponent`: niveles por id (se reinician en `equip`), `add_unique_upgrade`, `get_unique_level`, `get_unique_value`, `get_unique_upgrade`, `is_unique_maxed`, `reset_cooldown`. `owns_upgrade` incluye las únicas.
- `HealthComponent`: `execute()` y `receive_true_damage(amount)`.
- `WaveManager`: el pool incluye las únicas de la habilidad elegida, y el pool disponible saca las bloqueadas y las que están en nivel máximo.
- `UpgradePicker`: cartas doradas (`unique_card_*` en `UpgradePickerConfig`) con el texto del nivel siguiente, que obtiene de `player`.

## 4. Criterios de aceptación

- **AC95** Reset: un sprint que mata reinicia el cooldown al terminar. Uno que no mata, no lo reinicia. Sin la mejora nunca se reinicia.
- **AC96** Asesinato nivel 1: un enemigo que queda en 14 % muere y uno en 16 % sobrevive. En nivel 2 el umbral es 20 %.
- **AC97** Una ejecución cuenta como kill para Reset.
- **AC98** Lacerante: después del golpe, el enemigo tiene Sangrado. En 5 s pierde 5 × 1 % de su vida máxima, ignorando la defensa. Después el debuff desaparece.
- **AC99** Reaplicar Sangrado reinicia la duración sin duplicar la entrada. En nivel 3 quita 3 %/s.
- **AC100** Debuffs como lista: dos `DebuffData` distintos conviven y se limpian cuando el enemigo se recicla.
- **AC101** Íconos: un debuff activo muestra un ícono con su material sobre la barra, y al expirar se oculta.
- **AC102** Cada tick de sangrado genera un número de daño.
- **AC103** Cartas únicas: doradas, con "Nv N". Al elegirlas se aplican a la ranura correcta. Reset sale del pool después del nivel 1 y Asesinato después del nivel 3.
- **AC104** El pool solo incluye las únicas de la habilidad equipada.
- **AC105** Datos: Reset tiene `max_level 1`. Asesinato y Lacerante tienen `max_level 3`, y su cantidad de `level_values` y `level_descriptions` coincide con `max_level`.
- **AC106** Regresión: la suite completa en verde.
  - *Notas:*
    - En `ability_run_test.gd`, AC54 y AC80 cuentan también las mejoras únicas del pool.
    - Cada tick de sangrado se reporta **antes** de aplicar el daño. Así el tick que mata también muestra su número, porque la muerte desregistra al enemigo.
    - `DamageNumberPool` recibe el registro como export opcional.

### Review de la constitución (cierre, v2.2.0)
- **I:** Progresión y Combate, como declara la spec.
- **II:** íconos de `BoxMesh` con `StandardMaterial3D` `.tres` (rojo oscuro, no reservado). Las cartas doradas son UI 2D.
- **III:** cada mejora única declara `max_level` (Reset = 1, justificado). Los valores y textos por nivel viven en `.tres`, el sangrado es un `DebuffData` y los debuffs activos son una lista por enemigo. Ningún Resource se muta: los niveles viven en `AbilityComponent`.
- **IV:** tipado completo. Los ids de las mejoras son constantes `StringName`.
- **V:** los debuffs solo procesan mientras hay alguno activo, sin allocations por frame (una instancia por aplicación, no por tick). Los íconos se crean una sola vez.
- **VI:** sin inputs nuevos.

## 5. Fuera de alcance

- Mejoras únicas de la ultimate y otros debuffs.
- Mostrar las mejoras únicas en el menú de pausa.
