# Feature: "Tornado" y ajustes de "Vigorizante" (Giro)

- **Estado:** Implementada (2026-09-25; `spin_tornado_test` 10/10 y suite completa en verde, 0 orphans; import y smoke test del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.5.0 (sin enmienda).
- **Pilares (Principio I):**
  - **Combate:** Tornado premia rematar con el Giro. Cuantos más enemigos matás girando, antes vuelve a estar lista.
  - **Progresión:** es la tercera carta dorada del Giro, y combina con Vigorizante en una build de hordas.
- **Dependencias:** `spin-golden-upgrades.md` (Implementada). Esta spec modifica su §1.2.

## 1. Objetivo

### 1.1 Vorágine pasa a llamarse "Vigorizante"

- **Nombre:** cambia el título de la carta y también su id y su archivo: `maelstrom` → `invigorating`, `maelstrom.tres` → `invigorating.tres`. Así el código no guarda el nombre viejo.
- **Velocidad de movimiento:** +5 % → **+7 % por stack** (`concussion.tres`, modifier MOVE_SPEED 0.05 → 0.07). Con 10 stacks, +70 % de movimiento durante el Giro.
- **Sin otros cambios:** la velocidad de giro y el crítico siguen en +5 % por stack, y el tope (10) y la duración (2.5 s) no cambian.
- **Texto:** "Cada enemigo que matás con el Giro te da Conmoción (hasta 10, pierde 1 cada 2.5 s). Por stack, durante el Giro: +7 % de velocidad, +5 % de giro y +5 % de crítico".

### 1.2 Tornado (mejora única nueva, sin niveles)

- Cada enemigo que **muere por un golpe del Giro** resta **1 s** al enfriamiento restante del Giro, en el instante de la kill.
  - El enfriamiento arranca al apretar la tecla (9 s base) y corre también mientras se gira.
  - Ejemplo: si al matar quedaban 7 s, pasan a quedar 6 s.
- **Sin enfriamiento, no pasa nada:** el enfriamiento nunca baja de 0 y los segundos sobrantes se pierden, no se guardan.
- **Varias kills en el mismo golpe:** cada una resta 1 s.
- **No se puede relanzar mientras se gira**, aunque el enfriamiento llegue a 0 a mitad del Giro. Esto ya lo garantiza `AbilityComponent.try_cast()` (`is_casting()`), y un test lo fija. Al terminar el Giro, si el enfriamiento está en 0, se puede lanzar de inmediato.
- `max_level 1`, porque es un efecto binario. `level_values [1.0]`: los segundos por kill son datos (Principio III).
- `min_cooldown` limita el enfriamiento total que dejan las cartas de stats, no el tiempo restante, así que Tornado no lo toca.
- Solo cuentan las muertes causadas por un golpe del Giro, igual que Vigorizante.

## 2. Estructura

| Archivo | Cambio |
|---|---|
| `data/abilities/spin/unique/maelstrom.tres` → `invigorating.tres` | id `invigorating`, título "Vigorizante", texto nuevo |
| `data/buffs/concussion.tres` | modifier MOVE_SPEED `per_stack` 0.05 → 0.07 |
| `data/abilities/spin/unique/tornado.tres` (nuevo) | id `tornado`, "Tornado", `max_level 1`, `level_values [1.0]`, `value_format "%.0f s por kill"`. Texto: "Cada enemigo que matás con el Giro reduce 1 s su enfriamiento" |
| `data/abilities/spin/spin.tres` | `unique_upgrades` = [armor_break, invigorating, tornado] |

## 3. Interfaz pública

- **`AbilityComponent.reduce_cooldown(seconds: float) -> void`** (nuevo): `_cooldown_left = maxf(_cooldown_left − seconds, 0)`. Sin enfriamiento no hace nada. El HUD lo refleja solo, porque lee `get_cooldown_ratio()`.
- **`SpinAbility`**
  - `MAELSTROM` pasa a llamarse `INVIGORATING` (`&"invigorating"`).
  - `+ TORNADO` (`&"tornado"`).
  - Al matar con un golpe (el mismo punto donde hoy se suma Conmoción), si tiene Tornado llama `ability.reduce_cooldown(get_unique_value(TORNADO))`.

## 4. Criterios de aceptación

- **AC297** `invigorating.tres`: id `invigorating`, título "Vigorizante", `max_level 1` y buff `concussion`. `maelstrom.tres` ya no existe, y `spin.tres` lista armor_break, invigorating y tornado.
- **AC298** `concussion.tres`: MOVE_SPEED 0.07 por stack, y ABILITY_SPEED y CRIT_CHANCE siguen en 0.05. Con 4 stacks durante el Giro, el factor de movimiento es `move_speed_factor × 1.28`.
- **AC299** `tornado.tres`: id `tornado`, título "Tornado", `max_level 1` y valor 1.0, en `spin.tres` como mejora única.
- **AC300** Con Tornado, lanzar el Giro, avanzar 2 s (quedan 7 s) y matar a un enemigo con la vuelta deja el enfriamiento en 6 s (±0.05). Dos kills en la misma vuelta lo dejan en 5 s.
- **AC301** Con el enfriamiento en 0.5 s, una kill lo deja en 0, no negativo. `reduce_cooldown` sin enfriamiento no cambia nada.
- **AC302** Sin Tornado, las kills no cambian el enfriamiento. Los golpes que no matan tampoco.
- **AC303** Con el enfriamiento en 0 a mitad del Giro, `try_cast()` devuelve false mientras gira y true apenas termina.
- **AC304** Regresión: la suite completa sigue en verde, y el import y el smoke test no dan errores ni warnings.

## 5. Tests a adaptar

- `spin_golden_upgrades_test.gd`:
  - la constante `MAELSTROM` pasa a `INVIGORATING`, con el título y el id nuevos (AC284);
  - el factor de movimiento pasa de ×1.2 a ×1.28 (AC292).

  Lo que verifican no cambia. Se anota en esta spec y en `spin-golden-upgrades.md`, cuyo §1.2 queda marcado como modificado por esta spec.

## 6. Plan

1. **Datos:**
   - Renombrar `maelstrom.tres` a `invigorating.tres` (id, título, texto) y actualizar `spin.tres`.
   - Poner MOVE_SPEED en 0.07.
   - Crear `tornado.tres`.
2. **Código:** `AbilityComponent.reduce_cooldown`, y en `SpinAbility` la constante `INVIGORATING` y Tornado en el punto de la kill.
3. **Tests:** adaptar `spin_golden_upgrades_test.gd` y crear `spin_tornado_test.gd` (AC297 a AC303).
4. **Cierre:**
   - Suite completa, import y smoke test (copia en el scratchpad).
   - Nota en `spin-golden-upgrades.md`.
   - Review de la constitución y estado Implementada.
   - `CLAUDE.md`: próximo AC **AC305**.

## 7. Notas de implementación

- Tests adaptados sin cambiar lo que verifican:
  - `spin_golden_upgrades_test.gd`: `MAELSTROM` pasa a `INVIGORATING`, con el id y el título nuevos, y el factor de movimiento pasa de ×1.2 a ×1.28.
  - `buff_component_test.gd`: MOVE_SPEED pasa de 0.05 a 0.07 (`test_ac285_ac298_concussion_data`).
- En la corrida de cierre falló `wind_step_test` (AC278). No lo causó esta feature: la sesión paralela de `zanshin.md` agregó una carta a Envainar y adaptó ese test después de que se tomó la copia. Con la versión actual pasa (6/6).
- **Choque de ACs:** `zanshin.md` (Propuesta) también numera AC297 a AC302. Esta spec se aprobó e implementó con AC297 a AC304, así que Zanshin debe renumerar desde **AC305**.

## 8. Review de la constitución (cierre)

- [x] **I:** Combate (rematar girando acelera el siguiente Giro) y Progresión (tercera carta dorada del Giro), como declara la spec.
- [x] **II:** sin elementos visuales nuevos.
- [x] **III:** los segundos por kill viven en `tornado.tres` (`level_values [1.0]`) y el +7 % en `concussion.tres`. `max_level 1` declarado. No se muta ningún Resource compartido.
- [x] **IV:** tipado completo y nombres según convención. `reduce_cooldown` es un método con nombre.
- [x] **V:** sin allocations ni búsquedas por frame. La reducción ocurre solo en el golpe que mata.
- [x] **VI:** sin input nuevo.
- [x] **Calidad:** suite en verde (el único fallo era ajeno y se verificó aparte), sin errores ni warnings nuevos.
