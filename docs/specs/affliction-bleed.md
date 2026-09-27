# Feature: Aflicción Sangrado

- **Estado:** **Implementada** (2026-09-27). Aprobada con la versión resistida propuesta (un décimo en bosses). ACs: AC961–AC967 (reservados AC961–AC970). Constitución enmendada a 4.19.1 (aplicada).
- **Constitución:** `docs/constitution.md` v4.19.0 → **enmienda PATCH a 4.19.1** (Principio II: registro del carmesí, ver §6).
- **Pilar (Principio I):** **progresión** y **combate.** Un quinto tipo de Aflicción que premia insistir sobre el mismo enemigo: cada vez que su barra se llena, el sangrado sube un escalón y hace bastante más daño.
- **Dependencias:** `affliction.md` (barras, cartas violetas, stacks mejorables), `affliction-damage-colors.md` (número de color y cursiva de los DoT), `frost-freeze.md` (versión resistida para bosses).
- **Fuera de alcance:** la Estocada y Lacerante (mejora única de la Estocada), que recibirán un rework aparte. Su Sangrado (`bleed.tres`, 1–3 % de vida por segundo, sin barra) **no cambia**.

## 1. Diseño

- **Tipo nuevo:** `data/afflictions/bleeding.tres` (`id` `bleeding`, título "Sangrado"), con dos cartas violetas globales, como las demás: "Aflicción: Sangrado" con **básicos** (20 / 30 / 40) y con **habilidad** (35 / 50 / 65). Cuenta para el tope de 3 Aflicciones.
- **Estado nuevo:** `data/debuffs/bleeding.tres` (`id` `bleeding`, distinto del `bleed` de Lacerante, así no comparten stacks): `DAMAGE_OVER_TIME` en **% de la vida máxima** (`MAX_HEALTH`), tick de 1 s, **5 s**, **mejorable** (`INTENSITY`), **hasta 3 stacks**. Cada vez que la barra se llena: +1 stack (hasta 3) y la duración vuelve a 5 s.
- **Daño por stacks** (decisión del responsable, opción (a)): 1 stack = **1 %/s**, 2 stacks = **3 %/s**, 3 stacks = **6 %/s** (cada stack suma 1 %, 2 % y 3 %). Como hoy la fuerza de un estado mejorable es `potencia × stacks` (1, 2, 3), se agrega a `DebuffData` una tabla **`stack_multipliers: Array[float]`**: la fuerza es `potencia × stack_multipliers[stacks − 1]`. Vacía = `potencia × stacks`, como hoy (ningún `.tres` existente cambia). Sangrado: potencia 0.01, tabla `[1, 3, 6]`.
- **Bosses (versión resistida, como la Escarcha) — propuesta:** el mismo estado con **un décimo de la potencia**: 0.1 % / 0.3 % / 0.6 % por segundo (`resisted_debuff` = el mismo `bleeding.tres`, `resisted_effect_value = 0.001`).
  - Por qué un décimo: con la potencia completa, 3 stacks (6 %/s) le quitan ≈ 83 de vida por segundo al Verdugo (1380), unas 7 veces el daño del Guerrero. Con un décimo, al máximo son ≈ 8 por segundo (≈ 4 con 2 stacks), en la línea del Veneno (≈ 4.5 por segundo). En los comunes queda como pediste: sobre un Bruto de 40, de 0.4 a 2.4 por segundo.
- **Color:** carmesí `Color(0.75, 0.1, 0.25)` en la barra, el ícono (reusa el glifo `bleeding_wound.svg`) y el número de daño, que va en cursiva por ser un DoT. Es distinto del rojo de la barra de vida `Color(0.85, 0.1, 0.1)`, que queda justo encima.
- **Texto de las cartas:** "Tus ataques básicos / Tu habilidad acumula(n) Sangrado. Al llenarse: Sangrado, 1 % de la vida por segundo durante 5 s; cada stack lo sube (3 %, 6 %)."

## 2. Decisiones

- Resueltas por el responsable: opción (a) de daño por stacks; versión resistida para bosses; carmesí; Estocada y Lacerante fuera de alcance.
- **Aprobado:** un décimo de la potencia en bosses (0.1 / 0.3 / 0.6 %/s).

## 3. Criterios de aceptación (AC961–AC967)

- **AC961** `stack_multipliers`: con `[1, 3, 6]` y potencia 0.01, la fuerza es 0.01 / 0.03 / 0.06 con 1 / 2 / 3 stacks; con la tabla vacía sigue siendo `potencia × stacks` (Corrosión y Debilitar no cambian).
- **AC962** Datos: `bleeding.tres` (Aflicción) con título "Sangrado", barra carmesí, `debuff` = `resisted_debuff` = el estado `bleeding`, `effect_value = 0.01` y `resisted_effect_value = 0.001`; el estado con `DAMAGE_OVER_TIME`, `MAX_HEALTH`, `INTENSITY`, 5 s, tick 1 s, `max_stacks = 3`, `stack_multipliers = [1, 3, 6]`, ícono `bleeding_wound.svg` con `icon_color` carmesí y número de daño carmesí. Dos cartas violetas nuevas en el catálogo (10 en total), con B = 20/30/40 y 35/50/65.
- **AC963** Sobre un común de 1000 de vida: la primera vez que se llena la barra, cada tick quita 10; la segunda, 30; la tercera y las siguientes, 60. Cada llenado reinicia los 5 s.
- **AC964** Sobre un boss (`resists_control`): 1, 3 y 6 por tick con 1000 de vida (0.1 / 0.3 / 0.6 %).
- **AC965** Los ticks muestran su número en carmesí y en cursiva.
- **AC966** El Sangrado de Lacerante (`bleed.tres`) no cambia y no comparte stacks con el de la Aflicción.
- **AC967** Sangrado ocupa un lugar del tope de 3 Aflicciones, como las demás.

## 4. Tests

- `test/components/affliction_status_test.gd`: AC961, AC963, AC964, AC966.
- `test/resources/affliction_data_test.gd`: AC962 (y se adaptan AC852 —8 → 10 cartas— y las listas de AC855/AC936/AC954 para incluir Sangrado; se anota en §7).
- `test/effects/damage_number_pool_test.gd`: AC965.
- `test/components/affliction_loadout_test.gd`: AC963, AC964, AC967 con disparos reales de la barra.
- `test/ui/status_icons_test.gd` AC905 (todo estado tiene ícono): lo cumple sin cambios (reusa un SVG existente).

## 5. Plan

1. `DebuffData.stack_multipliers` y `DebuffComponent.get_strength`. Test AC961.
2. Datos: estado, Aflicción, 2 cartas, materiales (barra y número), catálogo. Tests AC962, adaptaciones.
3. Tests de disparo, bosses, números y tope (AC963–AC967).
4. Cierre: enmienda 4.19.1, `CLAUDE.md`, tests de la spec y de las suites tocadas, smoke test, estado **Implementada**.

## 6. Enmienda de la constitución (PATCH 4.19.0 → 4.19.1)

Principio II, registro de colores de las Aflicciones: se suma el carmesí `Color(0.75, 0.1, 0.25)` de Sangrado (barra, ícono y número), distinto del rojo de la barra de vida y del de Rage.

## 7. Notas de implementación

- **Tests:** `affliction_status_test.gd` (AC961, AC963, AC964, AC966), `affliction_data_test.gd` (AC962), `affliction_loadout_test.gd` (AC963 y AC964 con disparos reales de la barra, AC967) y `damage_number_pool_test.gd` (AC965). En verde junto con las suites de Aflicción, `test/effects/`, `status_icons_test`, `sandbox_run_test`, `ability_run_test` y `unique_upgrades_test`. `spin_golden_upgrades_test` AC288 falla igual en `main` (2 fallos antes y después).
- **Tests viejos adaptados:** `affliction_data_test.gd` AC852 (8 → 10 cartas) y las listas de AC855 y AC954 (suman Sangrado).
- **Tabla de stacks:** `DebuffData.stack_multiplier(stacks)`; pasado el final de la tabla usa su último valor.
