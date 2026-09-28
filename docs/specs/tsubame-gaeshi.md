# Feature: Mejora única "Tsubame Gaeshi" (Envainar)

- **Estado:** Parcialmente reemplazada por `sheathe-upgrades-rework.md` (2026-09-28): la carta Tsubame Gaeshi se eliminó; el estado "Envainar: mejorado" (toque al 100 %, brillo y marco dorado) sigue vigente y ahora lo otorga Hosho. Estado anterior: Implementada (2026-09-26). Los 82 tests del samurái pasaron 3 corridas seguidas; import y smoke test sin errores. La suite completa (444 tests) tiene **4 fallos ajenos** a esta spec: tests del Giro y de Conmoción (AC188, AC288, AC298 y AC285/AC298) que fallan por un cambio de datos en curso de otra sesión (`data/buffs/concussion.tres`, modificado después de sus tests).
- **Constitución:** `docs/constitution.md` v4.0.0 → enmienda **PATCH 4.0.1** (el dorado ya registrado como no reservado suma dos usos: el brillo de la katana y el marco del HUD).
- **Pilares (Principio I):**
  - **Combate:** premia el tajo perfecto (cargado al máximo y que conecta) con un segundo tajo instantáneo, como el contragolpe de la golondrina de Kojirō.
  - **Progresión:** 4.ª carta dorada del Samurái.
- **Dependencias:** `samurai.md`, `sheathe-dash-cancel.md` y `nuki.md` (Implementadas).

## 1. Objetivo

- **Obtener "Envainar: mejorado":** con la carta, si un Envainar **cargado a mano al 100 %** (incluida la carga que suma "Paso del Viento") **golpea con el tajo frontal al menos a un enemigo**, queda guardado un **Envainar mejorado**.
  - La onda de empuje sola no cuenta.
  - Solo hay uno guardado a la vez; no se acumulan.
  - Queda guardado hasta usarlo.
- **Usarlo:** el próximo Envainar es un **tap**. Al apretar E (si Envainar está lista), el tajo sale **al instante con carga al 100 %**: daño, alcance, empuje, V y crítico completos.
  - No pasa por la fase de carga (no camina lento ni tiene reducción de daño).
  - Después sigue la recuperación de siempre, cancelable con el dash.
  - Si E está apretada durante un dash, lo corta igual que un Envainar normal.
- **Un uso por tajo cargado:** el Envainar mejorado **no** vuelve a dar otro, aunque conecte.
- **Feedback mientras está guardado:**
  - **Katana brillante:** la hoja lleva un brillo dorado (un overlay emisivo sobre su material).
  - **Marco dorado en el HUD:** el marco del círculo de la habilidad pasa a dorado.
- **Feedback al obtenerlo:** un temblor de cámara leve y un destello: durante `flash_duration`, la katana usa un overlay más intenso antes de quedar en el brillo normal.
- **Sin niveles:** `max_level 1`. Sale del pool al tomarla y solo aparece con Envainar equipada.

## 2. Diseño

- **Datos:**
  - `data/abilities/sheathe/unique/tsubame_gaeshi.tres`: id `&"tsubame_gaeshi"`, `max_level 1`, sin valores; título "Tsubame Gaeshi"; descripción "Un Envainar cargado al máximo que conecta deja tu próximo Envainar mejorado: sale al instante al 100 %". Se agrega a `sheathe.tres`.
  - `SheatheConfig` suma: `empowered_overlay: Material`, `empowered_flash_overlay: Material`, `empowered_flash_duration` (0.25 s) y `empowered_shake` (0.35).
  - Materiales nuevos en `materials/weapons/`: `katana_empowered_overlay.tres` y `katana_empowered_flash_overlay.tres`. Son unshaded, blend aditivo, dorado `Color(0.85, 0.68, 0.2)`, con alpha 0.35 y 0.8.
  - `AbilitySlotViewConfig` suma `empowered_frame_color` (el mismo dorado, opaco).
- **`AbilityBehavior`**, dos hooks nuevos:
  - `skips_charge() -> bool` (false): un behavior cargado puede lanzarse sin carga;
  - `is_empowered() -> bool` (false).
- **`AbilityComponent`**
  - `try_cast()`: si el behavior es cargado y `skips_charge()` da verdadero, fija `_released_charge_ratio = 1` y arranca el cast directo, sin carga.
  - Nueva señal `empowered_changed(active: bool)`; el behavior la dispara con `notify_empowered(active)`.
  - `is_empowered()` delega en el behavior.
- **`SheatheAbility`**
  - Estado `_empowered` y `_cast_is_empowered` (el cast en curso usa el mejorado).
  - `skips_charge()` devuelve `_empowered`.
  - `begin()`: si `_empowered`, lo consume (`_cast_is_empowered = true`, se quita el brillo, `notify_empowered(false)`).
  - `_slash()`: con la carta, sin `_cast_is_empowered`, ratio liberado ≥ 1 y al menos un enemigo golpeado, llama `_grant_empowered()`. Eso pone el overlay de destello, lo cambia por el brillo normal con un temporizador one-shot de `empowered_flash_duration` y llama `notify_empowered(true)`.
  - El `MeshInstance3D` de la hoja se busca **una sola vez** y se cachea (`sword_swing.pivot` → arma → `Model`).
- **`ChargeFeedbackComponent`:** escucha `empowered_changed(true)` y sacude la cámara con `empowered_shake`.
- **`AbilitySlotView`:** si `is_empowered()`, dibuja el marco con `empowered_frame_color`; forma parte del chequeo de redibujado.

## 3. Criterios de aceptación (se reservan al empezar la implementación)

- **AC387** `tsubame_gaeshi.tres` tiene id `tsubame_gaeshi`, título "Tsubame Gaeshi" y `max_level` 1, y está entre las mejoras únicas de Envainar.
- **AC388** Con la carta, un Envainar soltado al 100 % que golpea a un enemigo deja el mejorado guardado (`is_empowered()`), y emite `empowered_changed(true)` una vez.
- **AC389** No lo deja guardado si:
  - se suelta por debajo del 100 %;
  - al 100 % no golpea a nadie (aunque la onda empuje a alguien);
  - no se tiene la carta.
- **AC390** Con el mejorado guardado, apretar E lanza el tajo al instante:
  - no hay fase de carga;
  - el golpe usa ratio 1 (daño y alcance completos);
  - se consume (`is_empowered()` en falso, `empowered_changed(false)`).
- **AC391** El Envainar mejorado que conecta no deja otro mejorado.
- **AC392** Mientras está guardado, la hoja tiene el overlay de brillo. Al obtenerlo, primero usa el de destello y después de `flash_duration` el normal. Al usarlo, el overlay se quita. Al obtenerlo, la cámara tiembla con `empowered_shake`.
- **AC393** Mientras está guardado, el slot del HUD dibuja el marco con `empowered_frame_color`; al usarlo vuelve a `frame_color`.
- **AC394** En una run de samurái con Envainar, la carta está en el pool y sale al tomarla. Regresión: suite completa en verde. Los tests que exigen la lista exacta de mejoras únicas de Envainar pasan a verificar "está entre".

## 4. Plan de implementación

1. Reservar AC387–AC394 en `CLAUDE.md` (próximo libre → AC395) y aplicar la enmienda PATCH 4.0.1.
2. Datos: carta, materiales, `SheatheConfig`, `AbilitySlotViewConfig` y alta en `sheathe.tres`.
3. Hooks `skips_charge` e `is_empowered`, `AbilityComponent` (`try_cast`, señal, `notify_empowered`, `is_empowered`).
4. `SheatheAbility`: obtener, consumir y el brillo de la katana.
5. `ChargeFeedbackComponent` (shake) y `AbilitySlotView` (marco dorado).
6. Tests, suite completa, smoke test, captura del brillo y cierre.

## 5. Notas de implementación

- **Desvío de diseño:** `empowered_shake` quedó en `ChargeFeedbackConfig` (`data/player/charge_feedback_config.tres`) en lugar de `SheatheConfig`, porque el temblor lo aplica `ChargeFeedbackComponent`, que no ve la configuración de la habilidad. El valor (0.35) no cambió.
- El Envainar mejorado no pasa por `begin_charge()`, así que no hay indicador de carga, reducción de daño ni caminata lenta. `begin()` consume el mejorado antes del golpe, y `_cast_is_empowered` evita que ese mismo tajo guarde otro.
- El overlay dorado se aplica con `material_overlay` sobre el `MeshInstance3D` de la hoja, que se busca una vez y se cachea. Un `Timer` creado en `_ready` cambia el destello por el brillo normal. `_exit_tree()` quita el overlay si la habilidad se reemplaza.
- **Tests adaptados:** `nuki_test` AC311 ahora verifica que las cartas "están entre" las mejoras únicas de Envainar. Verifica lo mismo.

### Review de la constitución (cierre)
- **I:** combate y progresión.
- **II:** overlay aditivo unshaded en el dorado no reservado (4.0.1), sin shaders; el marco dorado del HUD usa el mismo color.
- **III:** carta binaria en datos; materiales, duración y temblor en `.tres`.
- **IV:** tipado estricto.
- **V:** la hoja se cachea, el `Timer` se crea una vez y no hay allocations por frame.
- **VI:** el tap usa la acción `ability_basic`, que tiene binding de teclado y de mando.
- **Calidad:** los tests de esta spec y los del samurái están en verde. Los 4 fallos ajenos quedan anotados arriba.
