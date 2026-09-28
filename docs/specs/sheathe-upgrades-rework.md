# Feature: rework de las mejoras únicas de Envainar (Hosho, Nuki y Zen)

- **Estado:** Implementada (2026-09-28). ACs: AC1071–AC1090.
- **Constitución:** `docs/constitution.md` v4.24.0 → **enmienda MINOR 4.25.0** (ver §8; `riposte-levels.md` pasa a proponer 4.26.0).
- **Pilar (Principio I):** **combate.**
  - Hoy las mejoras doradas de Envainar giran alrededor del dash y del propio Envainar (Paso del Viento, Zanshin, Tsubame Gaeshi). El combo básico del Samurái no alimenta a su habilidad.
  - **Hosho** une el combo con Envainar: pegar construye un remate ×4 que sale con un toque.
  - **Zen** premia el Envainar al máximo con una ventana de 3 s de combo al doble de velocidad. Así se forma un ciclo: combo → Envainar mejorado → combo desatado.
- **Pedido del responsable (2026-09-28):**
  1. se eliminan todas las mejoras únicas de Envainar, **salvo Nuki**;
  2. **Hosho:**
     - los ataques básicos que golpean dan cargas de **Compensación**;
     - con 5 cargas, Envainar se carga solo: pasa a ser de un toque, con la mecánica de "Envainar: mejorado" que ya existe;
     - ese Envainar hace **+300 %** de daño;
  3. **Nuki** se mantiene;
  4. **Zen:** lanzar un Envainar cargado al máximo, o un Envainar mejorado, da el buff **Netsui**, que rompe el límite de velocidad de ataque durante 3 s y duplica la actual.
- **Decisiones del responsable (2026-09-28):**
  - +300 % = **×4** el daño de un Envainar al 100 %;
  - **1 carga por golpe del combo que alcanza al menos a un enemigo**, sin importar a cuántos. Con 5:
    - Envainar queda mejorado y **se recarga** si estaba en enfriamiento;
    - las cargas vuelven a 0.
  - **Netsui:** ×2 la velocidad de ataque efectiva (con cartas incluidas) durante 3 s. Volver a ganarlo reinicia los 3 s; no se acumula. Hoy no existe un tope de velocidad de ataque (solo la carta tiene 8 stacks), así que "romper el límite" es duplicar el valor efectivo sin ningún tope;
  - las cartas celestes ("Envainar: carga rápida" y "Envainar: daño") **se quedan**.
- **Dependencias:**
  - `tsubame-gaeshi.md`: "Envainar: mejorado", el brillo dorado de la katana y el marco dorado del HUD;
  - `nuki.md`;
  - `status-icons.md`: íconos de buffs en `BuffBar`;
  - `warrior-abilities-rework.md`: buffs `global` en `StatsComponent`.
  - **Choque con trabajo en curso:** `sheathe-visual-rework.md` tiene sin commitear cambios en `sheathe_ability.gd`, `sheathe_config.gd/.tres` y `ability_component.gd`. Esta spec se implementa **encima** de ese working tree y solo toca las partes de las mejoras (ver §6, paso 0).

## 1. Estado actual (verificado sobre el working tree)

- `data/abilities/sheathe/sheathe.tres` ofrece cuatro mejoras únicas:

  | Mejora | Qué hace |
  |---|---|
  | `wind_step` (Paso del Viento) | cada dash durante la carga suma 1.5 s |
  | `zanshin` (Zanshin) | un Envainar que mata recarga el dash |
  | `nuki` (Nuki) | cada dash recarga Envainar |
  | `tsubame_gaeshi` (Tsubame Gaeshi) | un Envainar cargado a mano al 100 % que conecta deja el próximo **mejorado** |

- **"Envainar: mejorado"** (`SheatheAbility._empowered`):
  - `skips_charge()` hace que `AbilityComponent` lo lance al apretar, al 100 % de carga;
  - la katana brilla (`empowered_flash_overlay` y luego `empowered_overlay`), y el slot del HUD muestra el marco dorado (`notify_empowered`, `is_empowered`).
- `AttackComponent.attacked(hit_count, total_damage, was_crit)` se emite en cada golpe del combo, aunque no alcance a nadie (`hit_count` 0).
- `BuffComponent`: los stacks vencen con `stack_duration`. No existe un buff que no venza, ni una forma de quitar un buff.
- `StatsComponent` aplica los buffs `global` solo a `MOVE_SPEED` y `DAMAGE`. `BuffModifier.Stat` no tiene `ATTACK_SPEED`.
- La velocidad de los clips del combo es `ATTACK_SPEED / reference_attack_speed` (`AttackComponent`). No hay tope en `combat_rules.tres`.
- Tests propios de las mejoras que se van: `wind_step_test.gd`, `zanshin_test.gd` y `tsubame_gaeshi_test.gd`.

## 2. Diseño

### 2.1 Limpieza

- Se borran `wind_step.tres`, `zanshin.tres` y `tsubame_gaeshi.tres`, sus constantes y su código en `SheatheAbility` (`dash_during_charge` con Paso del Viento, la recarga del dash de Zanshin y `_connects_full_manual_charge`).
- **"Envainar: mejorado" se conserva**, con el mismo brillo, el mismo marco dorado y el mismo toque al 100 %. Ahora solo lo otorga Hosho.
- `sheathe.tres` queda con `unique_upgrades = [hosho, nuki, zen]`.
- `wind-step.md`, `zanshin.md` y `tsubame-gaeshi.md` se marcan "Reemplazada por `sheathe-upgrades-rework.md`" (en `tsubame-gaeshi.md`, solo el disparador: el estado mejorado sigue vigente).

### 2.2 Hosho (`hosho`)

- **Cargas de Compensación:**
  - cada emisión de `AttackComponent.attacked` con `hit_count > 0` suma **1 carga**;
  - cuenta cada golpe del combo, incluido cada golpe del remate doble del Samurái (`auto_chain`). Los golpes al aire no cuentan;
  - no se ganan cargas mientras Envainar ya está mejorado: se guarda un solo Envainar mejorado.
- **Al llegar a 5 cargas** (`HoshoConfig.charges_needed`):
  1. las cargas vuelven a 0;
  2. el enfriamiento de Envainar queda en 0 (`reset_cooldown()`);
  3. Envainar queda **mejorado** (`_grant_empowered()`, con brillo y marco).
- **El Envainar mejorado de Hosho:**
  - sale con un toque al 100 % de carga, como hoy;
  - hace **×4** el daño de un Envainar al 100 % (`HoshoConfig.damage_multiplier = 4.0`), aplicado antes del crítico, como el `factor` de la carga;
  - el empuje, el alcance y el VFX son los del 100 %, sin cambios.
- **HUD:** las cargas se ven en la `BuffBar` como el buff **Compensación**, con su número de stacks (1–4):
  - no vence (`BuffData.stack_duration = 0`, que pasa a significar "no vence");
  - al llegar a 5 desaparece (`BuffComponent.remove(id)`), y a partir de ahí lo muestran la katana dorada y el marco del slot.
- Las cargas se pierden al terminar la run o al cambiar de clase (`BuffComponent.clear()`, como los demás buffs).

### 2.3 Nuki (`nuki`)

Sin cambios: cada dash recarga Envainar.

### 2.4 Zen (`zen`)

- **Disparo:** al lanzar Envainar (`begin`), se gana **Netsui** si:
  - la carga soltada a mano es del 100 % (`get_released_charge_ratio() >= 1.0`), o
  - el lanzamiento es un Envainar mejorado (de Hosho).
  - No hace falta que el corte conecte.
- **Netsui** (`data/buffs/netsui.tres`):
  - buff `global`, `max_stacks` 1, `stack_duration` 3 s;
  - modificador nuevo `ATTACK_SPEED` con `per_stack = 1.0`: `StatsComponent` devuelve `ATTACK_SPEED × (1 + 1.0)` = **×2** del valor efectivo, sin tope;
  - volver a ganarlo reinicia los 3 s;
  - acelera todo lo que lee `ATTACK_SPEED` (hoy, la velocidad de los clips del combo y su timing).
- **HUD:** ícono de buff Netsui en la `BuffBar` (`is_beneficial`), con el reloj de 3 s.

### 2.5 Íconos (Principio II, `status-icons.md`)

- Dos SVG blancos nuevos de game-icons.net (CC BY 3.0) en `assets/icons/status/`, con su fila en `SOURCE.md`:
  - **Compensación:** p. ej. `stack.svg` o `sword-array`;
  - **Netsui:** p. ej. `lightning-frequency.svg`.
  - Te pido permiso antes de descargarlos, y te muestro cuáles elijo.
- Colores de ícono no reservados:
  - Compensación: índigo `Color(0.45, 0.4, 0.9)`;
  - Netsui: naranja fuego `Color(1.0, 0.45, 0.2)`, distinto del naranja de Estallido `Color(1.0, 0.55, 0.15)` en tono y brillo.
  - Quedan registrados en la enmienda.

## 3. Resources y datos

| Archivo | Cambio |
|---|---|
| `resources/hosho_config.gd` + `data/abilities/sheathe/hosho_config.tres` | nuevo `HoshoConfig`: `charges_needed` 5, `damage_multiplier` 4.0, `charge_buff: BuffData` (Compensación) |
| `resources/sheathe_config.gd`/`.tres` | + `hosho: HoshoConfig`, + `netsui: BuffData` |
| `data/abilities/sheathe/unique/hosho.tres`, `zen.tres` | nuevas `AbilityUniqueUpgradeData` (`max_level` 1) con sus descripciones |
| `data/abilities/sheathe/unique/nuki.tres` | sin cambios |
| `data/abilities/sheathe/unique/{wind_step,zanshin,tsubame_gaeshi}.tres` | se borran |
| `data/abilities/sheathe/sheathe.tres` | `unique_upgrades = [hosho, nuki, zen]` |
| `data/buffs/compensation.tres` | nuevo: `id` `compensation`, "Compensación", `max_stacks` 4, `stack_duration` 0 (no vence), sin modificadores, `is_beneficial` |
| `data/buffs/netsui.tres` | nuevo: `id` `netsui`, "Netsui", `max_stacks` 1, `stack_duration` 3, `global`, modificador `ATTACK_SPEED` 1.0, `is_beneficial` |
| `resources/buff_modifier.gd` | + `Stat.ATTACK_SPEED` (al final del enum, para no mover los valores guardados) |
| `resources/buff_data.gd` | doc: `stack_duration` 0 = no vence |
| `components/buff_component.gd` | `advance()` ignora los buffs con `stack_duration` 0; + `remove(id)` |
| `components/stats_component.gd` | los buffs `global` también multiplican `ATTACK_SPEED` |
| `assets/icons/status/*.svg` + `SOURCE.md` | dos glifos nuevos |

## 4. Interfaz pública

```gdscript
# SheatheAbility
const HOSHO: StringName = &"hosho"
const ZEN: StringName = &"zen"
func get_compensation_charges() -> int          # 0..charges_needed-1
## The stored empowered Sheathe came from Hosho (its slash deals ×damage_multiplier).
func is_empowered() -> bool                     # sin cambios

# BuffComponent
## Removes the buff at once (no-op if absent); emits changed.
func remove(id: StringName) -> void

# BuffModifier.Stat: + ATTACK_SPEED   (fraction added to ATTACK_SPEED; global buffs only)
```

- `SheatheAbility` se conecta a `ability.attack.attacked` al equiparse y se desconecta al desequiparse. `AbilityComponent.attack` ya existe desde `parry-riposte-rework`.
- Los callbacks son delgados: solo suman la carga y llaman a `_grant_empowered()`.

## 5. Criterios de aceptación (AC1071–AC1090)

**Limpieza**

- **AC1071** No existen `wind_step.tres`, `zanshin.tres` ni `tsubame_gaeshi.tres`, ni `WIND_STEP`, `ZANSHIN` o `TSUBAME_GAESHI` en el código. `sheathe.tres` ofrece exactamente Hosho, Nuki y Zen.
- **AC1072** Sin mejoras, Envainar se comporta como antes: un dash durante la carga no suma carga, una muerte no recarga el dash y un Envainar al 100 % que conecta no deja un Envainar mejorado.
- **AC1073** Nuki sigue igual: con Nuki, un dash con Envainar en enfriamiento lo deja listo (AC de `nuki.md`).

**Hosho**

- **AC1074** Con Hosho, cada golpe del combo que alcanza a ≥ 1 enemigo suma 1 carga; un golpe a 3 enemigos suma 1; un golpe al aire suma 0.
- **AC1075** La 5.ª carga: las cargas vuelven a 0, el enfriamiento de Envainar queda en 0 y Envainar queda mejorado (`is_empowered()`, brillo de la katana y marco dorado del slot).
- **AC1076** Mientras Envainar está mejorado, los golpes del combo no suman cargas.
- **AC1077** El Envainar mejorado sale al apretar (sin mantener), al 100 % de carga. Su daño es 4 × (el de un Envainar soltado a mano al 100 %, con los mismos stats y sin crítico), y su empuje y alcance son los del 100 %.
- **AC1078** Después de lanzarlo, Envainar deja de estar mejorado, la katana pierde el brillo y las cargas arrancan de 0.
- **AC1079** Sin Hosho, los golpes del combo no suman cargas ni muestran Compensación.
- **AC1080** HUD: con 1 a 4 cargas, la `BuffBar` muestra Compensación con ese número de stacks, y no vence aunque pasen 60 s sin golpear. Con la 5.ª carga desaparece.

**Zen y Netsui**

- **AC1081** Con Zen, soltar un Envainar cargado a mano al 100 % da Netsui aunque el corte no alcance a nadie; soltarlo al 99 % no da nada.
- **AC1082** Con Zen y Hosho, lanzar el Envainar mejorado da Netsui.
- **AC1083** Con Netsui, `StatsComponent.get_stat(ATTACK_SPEED)` vale el doble del valor sin el buff, también con 8 cartas de velocidad de ataque (sin tope). A los 3 s (±1 cuadro) vuelve al valor normal.
- **AC1084** Ganar Netsui con 1 s restante reinicia los 3 s y la velocidad sigue en ×2, no en ×3 ni ×4.
- **AC1085** Con Netsui, la velocidad de los clips del combo (`AttackComponent`) es el doble, y un combo completo del Samurái tarda la mitad.
- **AC1086** Sin Zen, ningún Envainar da Netsui.

**Datos, íconos y regresión**

- **AC1087** `BuffModifier.Stat.ATTACK_SPEED` existe y es el último valor del enum (los valores guardados de Triunfo y demás no cambian). `BuffComponent.remove()` quita un buff y emite `changed`. Un buff con `stack_duration` 0 no vence.
- **AC1088** Compensación y Netsui tienen su glifo SVG en `assets/icons/status/` con su fila en `SOURCE.md`, su `icon_color` y `is_beneficial`.
- **AC1089** Pasan `nuki_test`, `sheathe_*_test`, `ability_component_test`, `unique_upgrades_test`, `unique_upgrade_run_test`, `buff_component_test`, `stats_component_test` y `status_icon*_test`, salvo los fallos previos registrados. `wind_step_test`, `zanshin_test` y `tsubame_gaeshi_test` se borran; lo que verificaban del estado mejorado (brillo, marco, toque al 100 %) pasa a `sheathe_upgrades_rework_test`.
- **AC1090** Import y smoke test del arena sin errores ni warnings.

**Próximo libre después de esta spec: AC1091** (con `riposte-levels.md` reservando AC1056–AC1070).

## 6. Plan

Cada paso deja el proyecto andando.

0. **Coordinación:** `sheathe-visual-rework.md` tiene cambios sin commitear en `sheathe_ability.gd` y `sheathe_config.*`. Antes de tocarlos:
   - reviso que esa spec esté cerrada o que sus cambios estén estables;
   - trabajo encima de ellos, sin revertir nada;
   - solo toco las funciones de las mejoras.
1. **Reserva:** AC1071–AC1090 en `CLAUDE.md` (junto con la de `riposte-levels.md` si la aprobás).
2. **Buffs:**
   - `BuffModifier.Stat.ATTACK_SPEED`, `StatsComponent` con `ATTACK_SPEED` global, `stack_duration` 0 = no vence y `BuffComponent.remove()`;
   - `compensation.tres` y `netsui.tres`, con íconos provisorios (un glifo existente).
   - Tests de AC1083, AC1084 y AC1087.
3. **Limpieza:** se borran las tres mejoras, su código y sus tests. Se migran a `sheathe_upgrades_rework_test` los casos del estado mejorado. AC1071–AC1073.
4. **Hosho:** `HoshoConfig`, la conexión a `attacked`, las cargas, la recarga, el ×4 y el buff Compensación. AC1074–AC1080.
5. **Zen:** Netsui al lanzar. AC1081, AC1082, AC1085 y AC1086.
6. **Íconos:** te pido permiso, descargo los dos SVG de game-icons.net, los agrego a `SOURCE.md` y te muestro la `BuffBar` con Compensación y Netsui.
7. **Cierre:** suites de AC1089, import y smoke test, la enmienda, `CLAUDE.md` (mapa: mejoras de Envainar), las specs viejas marcadas y el estado **Implementada**.

## 7. Tests que cambian

- `wind_step_test`, `zanshin_test` y `tsubame_gaeshi_test` se borran. Los casos de Tsubame Gaeshi que prueban el estado mejorado en sí (toque al 100 %, brillo, marco y gasto al lanzar) se reescriben en `sheathe_upgrades_rework_test` con Hosho como disparador.
- `unique_upgrades_test` y `unique_upgrade_run_test`: si usan Paso del Viento, Zanshin o Tsubame Gaeshi, pasan a Hosho o Zen y verifican lo mismo.
- `ability_slot_view` y sus tests del marco dorado no cambian: el estado mejorado sigue existiendo.

## 8. Constitución: enmienda MINOR

- **Principio II, colores no reservados:** índigo `Color(0.45, 0.4, 0.9)` para el ícono de Compensación y naranja fuego `Color(1.0, 0.45, 0.2)` para el de Netsui.
- **Principio III (datos):** sin cambios de regla. Los buffs `global` suman `ATTACK_SPEED` a los stats que ya multiplicaban, y el ×2 de Netsui vive en `netsui.tres`.
- Se anota que "Envainar: mejorado" (el dorado de la katana y del marco, 4.0.1) ahora lo otorga Hosho (antes, Tsubame Gaeshi).

## 9. Riesgos

- **Netsui sin tope:** con 8 cartas de velocidad de ataque (1.6 + 1.2 = 2.8), Netsui da 5.6: los clips del combo van a ×3.5. Ventanas de cancelación, buffer y eventos del clip escalan con esa velocidad. Hay que ver que no se salteen eventos en un cuadro (AC641). Si pasa, se agrega un tope de datos en `combat_rules.tres`.
- **Hosho ×4 al 100 %** con un toque es muy fuerte contra bosses. Son 5 golpes que conectan por uso, y los datos se ajustan en la sandbox.
- **Ciclo Hosho + Zen + Nuki:** el combo carga Hosho → Envainar mejorado da Netsui → el combo al doble carga Hosho más rápido. Es el ciclo buscado, pero se vigila que no se vuelva perpetuo; hoy no lo es, porque cada Envainar mejorado exige 5 golpes nuevos.
- **Choque con `sheathe-visual-rework`:** ver el paso 0 del plan.

## 10. Checklist de review de la constitución (se completa al cerrar)

- [x] I. Pilar declarado (combate).
- [x] II. Íconos SVG con fuente (`sword_array.svg` y `lightning_frequency.svg`, Lorc) y colores registrados (4.25.0).
- [x] III. Cargas, ×4, duración y ×2 en datos (`HoshoConfig`, `netsui.tres`, `compensation.tres`).
- [x] IV. Tipado estático, identificadores en inglés, callbacks delgados.
- [x] V. Sin allocations por cuadro.
- [x] VI. Sin input nuevo (el toque del Envainar mejorado ya existe).
- [x] VII. Sin tocar `Engine.time_scale`.

## 11. Notas de implementación (2026-09-28)

- **Código:**
  - `SheatheAbility` se conecta a `AttackComponent.attacked` en `_ready()` (su padre es el `AbilityComponent`) y se desconecta en `_exit_tree()`, donde también quita Compensación. Así, un Envainar reemplazado no deja cargas;
  - `_hit_enemy()` ya no devuelve si mató (solo lo usaba Zanshin);
  - el hook `AbilityBehavior.dash_during_charge()` queda en la base, sin uso, como punto de extensión.
- **Desvío menor:** `BuffData` no tiene `is_beneficial` (solo `DebuffData` lo tiene), porque los buffs siempre llevan marco verde. Compensación y Netsui no lo necesitan.
- `StatusIconView.update_buff_time()`: un buff permanente no muestra reloj (antes dividía por `stack_duration`).
- **AC1085:** se verifica con `AttackComponent.get_clip_speed()`, que da la velocidad de todos los clips y tiempos del combo. No se mide un combo completo cuadro a cuadro.
- **AC1073:** lo cubre `nuki_test`.
- **Tests:**
  - `sheathe_upgrades_rework_test` (20 casos) y `nuki_test` (8), en verde;
  - `unique_upgrades_test` (4), `unique_upgrade_run_test` (5) y `status_icons_test` (11), en verde.
- **Tests adaptados:** `nuki_test` AC311 comprobaba que Envainar ofreciera Paso del Viento, Zanshin y Nuki; ahora solo exige Nuki, porque las otras dos se borraron.
- **Tests borrados:** `wind_step_test`, `zanshin_test` y `tsubame_gaeshi_test`. Sus casos del estado mejorado (toque al 100 %, brillo, marco dorado, gasto al lanzar, carta en el pool) están en `sheathe_upgrades_rework_test`.
- **Fallos previos y ajenos:** idénticos sobre `HEAD` limpio (5a5ff55), por datos cambiados en otros commits:
  - `ability_component_test`: AC47 (×3) y AC50 (×2), por el daño del Guerrero;
  - `sheathe_test` AC241;
  - `buff_component_test` AC285/AC298 (Conmoción);
  - `stats_component_test` AC5 (×2).
- Import y smoke tests (proyecto y arena) sin errores ni warnings.
- **Íconos (paso 6, con permiso del responsable):**
  - `lorc/sword-array` → `sword_array.svg` (Compensación) y `lorc/lightning-frequency` → `lightning_frequency.svg` (Netsui), bajados del repo `game-icons/icons` con el procedimiento de `SOURCE.md`, con su fila en la tabla;
  - AC1088 verifica el glifo y la fila.
