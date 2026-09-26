# Feature: Mejora única "Nuki" (Envainar)

- **Estado:** Implementada, con el ajuste de la §6 (sin espera: cada dash recarga Envainar). Cierre original: 2026-09-25, 396 tests GdUnit4 en verde, 0 orphans; `nuki_test` pasó 3 corridas seguidas; import y smoke test sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.4.0 (sin enmienda).
- **Pilares (Principio I):**
  - **Combate:** el dash deja de ser solo defensa y pasa a recargar tu golpe más fuerte, lo que premia moverse.
  - **Progresión:** 3.ª carta dorada del Samurái. Arma un loop con "Zanshin": el tajo mata → recarga el dash → el dash recarga Envainar.
- **Dependencias:** `samurai.md`, `wind-step.md` y `zanshin.md` (Implementadas).

## 1. Objetivo

- Nueva **mejora única** de Envainar: **"Nuki"** ("desenvainar").
- **Efecto:** cuando arranca un dash y Envainar está **en enfriamiento**, el enfriamiento de Envainar se **reinicia** y queda lista al instante.
- **Espera interna de 4 s:** después de un reinicio, Nuki no vuelve a actuar hasta que pasen 4 s. Esa espera arranca **solo cuando el dash efectivamente reinició** el enfriamiento. Si Envainar ya estaba lista, cargando o casteando, el dash no hace nada y no gasta la espera.
- **Sin niveles:** `max_level 1`. Los 4 s viven en `level_values` del `.tres`. Sale del pool al tomarla.
- Aparece solo mientras Envainar está equipada.
- La espera corre con el tiempo de juego: no avanza en pausa.

## 2. Diseño

- **`data/abilities/sheathe/unique/nuki.tres`** (`AbilityUniqueUpgradeData`):
  - `id &"nuki"`, `max_level 1`, `level_values [4.0]` (la espera en segundos), `value_format "%.0f s"`;
  - título "Nuki";
  - descripción: "Dashear recarga Envainar al instante (una vez cada 4 s)".
  
  Se agrega a `sheathe.tres` en `unique_upgrades`, después de `zanshin`.
- **`AbilityBehavior`**, dos hooks nuevos con implementación vacía por defecto:
  - `dash_started(ability)`: cualquier dash que arranca, esté o no cargando;
  - `advance_passive(ability, delta)`: cada paso del slot, para temporizadores propios del behavior.
- **`AbilityComponent`**
  - `notify_dash()` llama `dash_started` si hay una habilidad equipada, y además `dash_during_charge` si está cargando (como hasta ahora).
  - `advance()` llama `advance_passive` en cada paso.
  - Nuevo `is_on_cooldown()`.
- **`SheatheAbility`**
  - Guarda `_nuki_wait_left`, que baja en `advance_passive`.
  - En `dash_started`, si tiene Nuki, `_nuki_wait_left <= 0`, Envainar está en enfriamiento y no está cargando ni casteando: llama `ability.reset_cooldown()` y pone `_nuki_wait_left = get_unique_value(&"nuki")`.

## 3. Criterios de aceptación

- **AC311** `nuki.tres` tiene id `nuki`, título "Nuki", `max_level` 1 y valor 4 s, y está en `sheathe.tres` junto a "Paso del Viento" y "Zanshin".
- **AC312** Con la mejora y Envainar en enfriamiento, un dash la deja lista (`get_cooldown_ratio() == 0`).
- **AC313** Un segundo reinicio no ocurre antes de 4 s:
  - con Envainar lanzada otra vez, un dash a los 3.9 s del reinicio no la recarga;
  - pasados los 4 s, el siguiente dash sí.
- **AC314** Si Envainar está lista, un dash no gasta la espera: si después se lanza Envainar y se dashea, la recarga ocurre en el acto.
- **AC315** Sin la mejora, dashear no cambia el enfriamiento de Envainar.
- **AC316** En una run de samurái con Envainar, la carta está en el pool y sale al tomarla. Regresión: suite completa en verde. El test de AC305 (`zanshin_test`), que exige exactamente dos mejoras únicas, pasa a verificar que "Paso del Viento" y "Zanshin" *están entre* ellas; verifica lo mismo.

## 4. Plan de implementación

1. Reservar AC311–AC316 en `CLAUDE.md` (próximo libre → AC317) al empezar.
2. Datos: `nuki.tres` y el alta en `sheathe.tres`.
3. Hooks `dash_started` y `advance_passive`, `AbilityComponent.notify_dash()`/`advance()` e `is_on_cooldown()`.
4. `SheatheAbility`: espera interna y reinicio.
5. Tests AC311–AC316, adaptación de AC305, suite completa, smoke test y cierre (estado **Implementada**).

## 5. Notas de implementación

- `AbilityComponent.notify_dash()` ahora avisa `dash_started` a cualquier habilidad equipada, y `dash_during_charge` solo mientras carga ("Paso del Viento" sigue igual). Con el slot vacío no hace nada.
- La espera de Nuki la lleva el behavior (`_nuki_wait_left`) y baja en `advance_passive`, que `AbilityComponent.advance()` llama en cada paso. Corre con el tiempo de física, así que no avanza en pausa, y los tests la manejan paso a paso.
- **Test viejo adaptado:** `zanshin_test` AC305 ahora verifica que "Paso del Viento" y "Zanshin" *están entre* las mejoras únicas de Envainar. Verifica lo mismo.
- AC311–AC316 se reservaron en `CLAUDE.md` al empezar la implementación, para evitar colisiones con sesiones en paralelo.

### Review de la constitución (cierre)
- **I:** combate y progresión.
- **II:** sin cambios visuales.
- **III:** carta binaria (`max_level 1`) y espera de 4 s en `level_values`; id como constante estructural.
- **IV:** tipado estricto.
- **V:** sin allocations por frame.
- **VI:** sin cambios de input.
- **Calidad:** suite completa en verde.

## 6. Ajuste (2026-09-25): sin espera — Implementado (417 tests en verde; import y smoke test sin errores)

Decisión del usuario: Nuki deja de tener la espera de 4 s. **Cada dash** que arranca con Envainar en enfriamiento la deja lista.

- **Datos:** `nuki.tres` pasa a ser binaria sin valor (`level_values []`, sin `value_format`). Descripción: "Cada dash recarga Envainar al instante".
- **Código:**
  - Se quitan de `SheatheAbility` la espera (`_nuki_wait_left`, `advance_passive`, `get_nuki_wait_left`).
  - También se quitan el hook `AbilityBehavior.advance_passive` y su llamada en `AbilityComponent.advance()`, porque solo los usaba Nuki y quedarían muertos.
  - `dash_started` reinicia el enfriamiento cada vez que Envainar esté en enfriamiento y no esté cargando ni casteando.
- **Criterios:**
  - **AC311** (actualizado): la carta no tiene valor por nivel.
  - **AC313** (reemplazado): dos tajos seguidos, cada uno seguido de un dash inmediato, dejan Envainar lista las dos veces.
  - **AC314** (actualizado): un dash con Envainar lista o cargando no cambia nada.
  - AC312, AC315 y AC316 no cambian.
