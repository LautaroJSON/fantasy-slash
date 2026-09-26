# Feature: Mejora única "Zanshin" (Envainar)

- **Estado:** Implementada (2026-09-25, 388 tests GdUnit4 en verde, 0 orphans; `zanshin_test` y `wind_step_test` pasaron 3 corridas seguidas; import y smoke test sin errores ni warnings). ACs renumerados dos veces (AC284 → AC297 → AC305) porque `spin-golden-upgrades.md` y `spin-tornado.md` tomaron esos números en paralelo.
- **Constitución:** `docs/constitution.md` v3.4.0 (sin enmienda).
- **Pilares (Principio I):**
  - **Combate:** matar con el tajo te deja listo para moverte de nuevo, y premia rematar con Envainar.
  - **Progresión:** 2.ª carta dorada del Samurái; combina con "Paso del Viento" (dash → carga → tajo que mata → dash).
- **Dependencias:** `samurai.md` y `wind-step.md` (Implementadas).

## 1. Objetivo

- Nueva **mejora única** de Envainar: **"Zanshin"** (la mente que permanece alerta después del golpe).
- **Efecto:** si el tajo de Envainar **mata al menos a un enemigo**, el **enfriamiento del dash se reinicia**, y el dash queda listo al instante.
  - El reinicio pasa una sola vez por tajo, aunque mate a varios.
  - Solo cuenta el daño del tajo frontal; la onda de empuje no hace daño, así que no puede matar.
  - No da invencibilidad: el próximo dash da sus iframes normales.
- **Sin niveles:** `max_level 1`, porque es un efecto binario, y sale del pool al tomarla.
- Aparece solo mientras Envainar está equipada.

### Nota sobre la regla "el enfriamiento del dash supera la invencibilidad"

Esa regla es un piso de datos (`min_dash_cooldown_gap`) que evita encadenar iframes con dashes normales. Zanshin no la cambia, pero reiniciar el dash permite, en el mejor caso, un dash más dentro de los iframes del anterior. Para eso hace falta matar con un tajo que tiene 8 s de enfriamiento, así que el encadenamiento está acotado por Envainar. No es una violación de la constitución, porque el piso sigue aplicándose al enfriamiento normal; lo registro como decisión de diseño.

## 2. Diseño

- **`data/abilities/sheathe/unique/zanshin.tres`** (`AbilityUniqueUpgradeData`):
  - `id &"zanshin"`, `max_level 1`, `level_values []`;
  - título "Zanshin";
  - descripción: "Si Envainar mata a un enemigo, tu dash se recarga al instante".
  
  Se agrega a `sheathe.tres` en `unique_upgrades`, después de `wind_step`.
- **`DashComponent.reset_cooldown()`:** deja `_cooldown_left` en 0 y emite `dash_ready` si estaba en enfriamiento. No toca iframes ni un dash en curso.
- **`AbilityComponent`:** nuevo export `dash: DashComponent`, asignado en `player.tscn`, para las habilidades que afectan el dash.
- **`SheatheAbility.release()`:** después de aplicar el daño, si algún enemigo golpeado quedó muerto y `has_unique(&"zanshin")`, llama `ability.dash.reset_cooldown()`.

## 3. Criterios de aceptación

- **AC305** `zanshin.tres` tiene id `zanshin`, título "Zanshin" y `max_level` 1, y está en `sheathe.tres` junto a "Paso del Viento".
- **AC306** Con la mejora, después de un dash (enfriamiento activo), un tajo que mata deja el dash listo (`get_cooldown_ratio() == 0`) y emite `dash_ready` una vez, aunque mate a dos enemigos.
- **AC307** Con la mejora, un tajo que golpea pero no mata no cambia el enfriamiento del dash.
- **AC308** Sin la mejora, un tajo que mata no cambia el enfriamiento del dash.
- **AC309** En una run de samurái con Envainar, la carta está en el pool y sale al tomarla.
- **AC310** Regresión: suite completa en verde. El test de AC278 (`wind_step_test`) pasa a verificar que "Paso del Viento" *está entre* las mejoras únicas de Envainar, en lugar de ser la única; verifica lo mismo.

## 4. Plan de implementación

1. Datos: `zanshin.tres` y el alta en `sheathe.tres`.
2. `DashComponent.reset_cooldown()` y el export `dash` en `AbilityComponent` (con `player.tscn`).
3. `SheatheAbility.release()`: detectar muertes y reiniciar el dash.
4. Tests AC305–AC309, adaptación de AC278, suite completa, smoke test y cierre (estado **Implementada**, `CLAUDE.md` → AC311).

## 5. Notas de implementación

- `SheatheAbility._hit_enemy()` devuelve si el golpe mató. `release()` acumula ese resultado y reinicia el dash una sola vez, después de aplicar todo el daño.
- `DashComponent.reset_cooldown()` no emite `dash_ready` si el dash ya estaba listo (AC308), así el feedback del HUD no se dispara de más.
- `AbilityComponent` ya tenía el export `buffs`, agregado en paralelo por `spin-golden-upgrades.md`; `dash` se sumó al lado, y los dos slots de `player.tscn` lo conectan a `../DashComponent`.
- **Test viejo adaptado:** `wind_step_test` AC278 ahora verifica que "Paso del Viento" *está entre* las mejoras únicas de Envainar. Verifica lo mismo.

### Review de la constitución (cierre)
- **I:** combate y progresión.
- **II:** sin cambios visuales.
- **III:** carta binaria (`max_level 1`) en datos; id como constante estructural. El piso `min_dash_cooldown_gap` sigue aplicándose al enfriamiento normal (ver nota de la §1).
- **IV:** tipado estricto.
- **V:** sin allocations por frame.
- **VI:** sin cambios de input.
- **Calidad:** suite completa en verde.
