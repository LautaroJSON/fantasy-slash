# Feature: Mejora única "Paso del Viento" (Envainar)

- **Estado:** Implementada (2026-09-25, 350 tests GdUnit4 en verde, 0 orphans; `wind_step_test` pasó 3 corridas seguidas; import y smoke test sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.4.0 (sin enmienda).
- **Pilares (Principio I):**
  - **Combate:** premia reposicionarse con el dash mientras cargás, en lugar de quedarse quieto esperando la carga.
  - **Progresión:** es la primera carta dorada del Samurái, y abre una build centrada en el dash.
- **Dependencias:** `samurai.md`, `sheathe-feel.md` y `unique-ability-upgrades.md` (Implementadas).

## 1. Objetivo

- Nueva **mejora única** (carta dorada) de Envainar: **"Paso del Viento"**.
- **Efecto:** cada dash que arranca **mientras Envainar está cargando** suma **1.5 s de carga** al instante.
  - La carga nunca pasa de `CHARGE_TIME`: si ya estaba completa, no pasa nada.
  - Los hitos de feedback que cruce ese salto (temblor, pulso, vibración) se disparan igual que si hubiera pasado el tiempo.
  - El indicador se agranda en el acto.
- **Sin niveles:** `max_level 1`, porque es un efecto binario. Sale del pool al tomarla (Principio III).
- Aparece en el pool solo mientras Envainar está equipada, como las demás mejoras únicas.
- Un dash fuera de la carga no hace nada extra, y sin la mejora el dash no suma carga (comportamiento actual).

## 2. Diseño

- **`data/abilities/sheathe/unique/wind_step.tres`** (`AbilityUniqueUpgradeData`):
  - `id &"wind_step"`, `max_level 1`, `level_values [1.5]`, `value_format "%.1f s"`;
  - título "Paso del Viento";
  - descripción: "Cada dash durante la carga de Envainar suma 1.5 s de carga".
  
  Se agrega a `sheathe.tres` en `unique_upgrades`.
- **`AbilityBehavior.dash_during_charge(ability)`:** hook nuevo; por defecto no hace nada.
- **`AbilityComponent`**
  - `notify_dash()`: si está cargando, llama al hook.
  - `add_charge(seconds)`: adelanta `_charge_elapsed` hasta como mucho `CHARGE_TIME`, llama `behavior.charge(self, 0)` (mirada e indicador) y emite los hitos que haya cruzado.
- **`Player._handle_dash()`:** si `dash.try_dash()` tuvo éxito, llama `notify_dash()` en los dos slots.
- **`SheatheAbility.dash_during_charge`:** con `has_unique(&"wind_step")`, llama `ability.add_charge(get_unique_value(&"wind_step"))`.

## 3. Criterios de aceptación

- **AC278** `wind_step.tres` tiene id `wind_step`, título "Paso del Viento", `max_level` 1 y valor 1.5 s, y está en `sheathe.tres` como mejora única.
- **AC279** Con la mejora, dashear a los 0.5 s de carga deja la carga en 2.0 s (ratio 2/3) y emite los hitos 1 y 2 en ese momento. Dashear otra vez lleva la carga al 100 % (hito de carga completa) y no la pasa.
- **AC280** Sin la mejora, dashear durante la carga no suma carga.
- **AC281** Con la mejora, un dash sin estar cargando no inicia ni cambia ninguna carga.
- **AC282** En una run de samurái, después de elegir Envainar la carta está en el pool. Al tomarla queda en su nivel máximo y sale del pool.
- **AC283** Regresión: suite completa en verde.

## 4. Plan de implementación

1. Datos: `wind_step.tres` y el alta en `sheathe.tres`.
2. Hook `dash_during_charge`, `AbilityComponent.notify_dash()`/`add_charge()` y el aviso desde `Player._handle_dash()`.
3. `SheatheAbility.dash_during_charge`.
4. Tests AC278–AC282, suite completa, smoke test y cierre: estado **Implementada**, `CLAUDE.md` → AC284.

## 5. Notas de implementación

- `AbilityComponent.add_charge(seconds)` reutiliza `_advance_charge()`: suma y tope, `behavior.charge()` (mirada e indicador) y los hitos. Es el mismo camino que el tiempo, así que la carga agregada se comporta igual que la cargada manteniendo la tecla.
- `Player` avisa con `notify_dash()` solo cuando `try_dash()` tuvo éxito: un dash en enfriamiento no suma carga.
- El efecto es binario, pero los 1.5 s viven en `level_values` del `.tres` (Principio III), no en el código.

### Review de la constitución (cierre)
- **I:** combate y progresión.
- **II:** sin cambios visuales nuevos; la carta usa el estilo dorado existente.
- **III:** la carta declara `max_level 1` y su valor por nivel en datos; el id es una constante estructural.
- **IV:** tipado estricto.
- **V:** sin allocations por frame.
- **VI:** solo la acción `dash` del InputMap.
- **Calidad:** suite completa en verde.
