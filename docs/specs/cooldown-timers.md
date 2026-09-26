# Feature: Segundos restantes en habilidades, dash, buffs y debuffs

- **Estado:** Implementada (2026-09-25, 405 tests GdUnit4 en verde, 0 orphans; import y smoke test del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.6.0 (enmienda MINOR aprobada con esta spec, §7).
- **Pilares (Principio I):**
  - **Combate:** saber exactamente cuándo vuelve una habilidad o el dash permite planear el siguiente intercambio (esquivar ahora o esperar 0.4 s al Giro) sin adivinar a partir de un anillo.
  - **Progresión:** los buffs y debuffs de las mejoras doradas (Conmoción, Debilitar, Sangrado) se vuelven legibles: el jugador ve cuánto le queda para encadenar la siguiente kill o volver a aplicar el stack.
- **Dependencias:** `player-hud-layout.md`, `boss-hud-bar.md` y `spin-golden-upgrades.md` (Implementadas).

## 1. Objetivo

Mostrar los segundos restantes como texto en cada elemento con temporizador:

| Elemento | Dónde se ve el tiempo | Extra |
|---|---|---|
| Habilidades (básica y definitiva) | Centro del círculo, reemplazando la tecla (`E`/`R`) mientras hay recarga | Al terminar la recarga el círculo hace un **pulso** (escala breve) y vuelve la tecla |
| Dash | Centro de la barra, reemplazando el texto `DASH` mientras hay recarga | — |
| Buffs del jugador | **Centro** del cuadrado, en grande. Los stacks pasan a la **esquina inferior derecha**, en chico | — |
| Debuffs en la barra del jefe (HUD) | Centro de cada ícono (el ícono crece para que entre el texto) | — |
| Debuffs sobre los enemigos (3D) | Encima de cada ícono, en **todos** los enemigos | — |

### 1.1 Formato

- Por debajo de 10 s: `S.S`, redondeado **hacia arriba** a la décima (`2.51` → `2.6`, `0.03` → `0.1`). Nunca se muestra `0.0` mientras quede tiempo.
- Desde 10 s: segundos enteros, también hacia arriba (`10.2` → `11`). El redondeo decide el formato: `9.95` sube a `10.0` y se muestra `10`.
- Con 0 s restantes no se muestra texto.
- Tope visual: más allá de `max_seconds` (999) se muestra `999`.
- El umbral (10 s), la décima y el tope son datos (`CooldownTextConfig`, Principio III).

### 1.2 Qué tiempo se muestra

| Elemento | Tiempo |
|---|---|
| Habilidad | Recarga restante (`AbilityComponent`). Mientras se **carga** una habilidad de *hold* no hay recarga (empieza al soltar), así que se ve el anillo de carga sin número, como hoy. |
| Dash | `DashComponent.get_cooldown_remaining()`. |
| Buff | Tiempo hasta perder **el próximo stack** (`ActiveBuff.time_left`). Conmoción con 3 stacks muestra `2.5` → `0.1`, pierde un stack y vuelve a `2.5`. |
| Debuff por tiempo (Debilitar) | `time_left`. |
| Debuff por ticks (Sangrado) | Tiempo hasta el último tick: `(ticks_left − 1) × tick_interval + tick_left`. Sangrado recién aplicado muestra `5.0`. |

## 2. Estructura

### 2.1 Datos (Principio III)

| Archivo | Cambio |
|---|---|
| `resources/cooldown_text_config.gd` (nuevo) | `decimal_below_seconds: float` (10.0), `decimal_step: float` (0.1), `max_seconds: int` (999), `rounding_epsilon: float` (0.0001, tolerancia de float para que `2.5000001` no suba a `2.6`). Fuente 2D: `outline_size: int`, `outline_color: Color` (legibilidad sobre cualquier fondo). |
| `data/ui/cooldown_text_config.tres` (nuevo) | Los valores de arriba; `outline_size 4`, `outline_color Color(0, 0, 0, 0.85)`. |
| `resources/ability_slot_view_config.gd` | `+ cooldown_font_size: int` (básica), `+ ultimate_cooldown_font_size: int`, `+ ready_pulse_scale: float` (1.2), `+ ready_pulse_duration: float` (0.25 s), `+ cooldown_text: CooldownTextConfig`. |
| `resources/buff_bar_config.gd` | `+ time_font_size: int` (16), `+ stack_font_size: int` (11), `+ cooldown_text: CooldownTextConfig`. |
| `resources/boss_bar_config.gd` | `+ debuff_time_font_size: int` (11), `+ cooldown_text: CooldownTextConfig`. `debuff_icon_size_px` pasa de 14 a **24** para que entre `4.0`. |
| `resources/debuff_icon_config.gd` | `+ time_font_size: int`, `+ time_pixel_size: float`, `+ time_height_above_icon: float` (metros), `+ time_material: StandardMaterial3D`, `+ cooldown_text: CooldownTextConfig`. |
| `data/ui/debuff_icon_config.tres` | `time_material` = `materials/enemy_level_material.tres` (el mismo blanco unshaded, sin depth test, del nivel del enemigo; material compartido). |
| `resources/hud_config.gd` (nuevo) | `dash_ready_text: String` ("DASH") y `cooldown_text: CooldownTextConfig`. Export `config` en `Hud`. Hoy "DASH" está escrito en la escena; pasa a dato porque el `Hud` lo reescribe. |
| `data/ui/hud_config.tres` (nuevo) | Los valores de arriba. |

Los tamaños exactos de fuente se ajustan con una captura en el paso 6 del plan y se anotan en §9.

### 2.2 Clases y nodos

| Archivo | Cambio |
|---|---|
| `ui/cooldown_text.gd` (nuevo) | `class_name CooldownText extends RefCounted`. Convierte segundos en un **paso** entero (décimas por debajo del umbral, segundos enteros por encima) y un paso en su `String`. Los strings salen de una **tabla** (`PackedStringArray`) construida **una sola vez** por config (`0.1`…`9.9`, `10`…`999`), así que actualizar un texto no crea strings por frame (Principio V). |
| `components/abilities/ability_component.gd` | `+ get_cooldown_remaining() -> float`. |
| `components/debuff_component.gd` | `+ static func get_remaining(debuff: ActiveDebuff) -> float` (§1.2) y `+ get_remaining_seconds(id: StringName) -> float`. `get_time_left()` no cambia (sus tests siguen igual). |
| `ui/ability_slot_view.gd` | Crea en `setup()` un `Label` centrado para el tiempo (una vez). `+ @export var key_label: Label`: se oculta durante la recarga. Pulso: al pasar de recarga a lista, `scale` arranca en `ready_pulse_scale` y vuelve linealmente a 1 en `ready_pulse_duration`, con `pivot_offset` en el centro. No pulsa al equipar ni al empezar la run. |
| `ui/hud.tscn` | `BasicSlot.key_label` → `KeyLabel`, ídem `UltimateSlot`. `DashLabel` pasa a `unique_name_in_owner` (`%DashLabel`). `Hud.config` → `hud_config.tres`. |
| `ui/hud.gd` | `_update_dash_bar()` también actualiza `%DashLabel`: el tiempo durante la recarga y `dash_ready_text` al estar listo. Solo escribe el texto cuando cambia el paso. |
| `ui/buff_bar.gd` | Cada slot tiene dos `Label`: tiempo (centro) y stacks (esquina inferior derecha). `_process` se activa solo mientras haya buffs activos y actualiza el tiempo cuando cambia el paso. Los stacks siguen actualizándose por la señal `changed`. `+ get_time_text(index) -> String`. |
| `ui/boss_health_bar.gd` | Cada ícono de debuff tiene un `Label` centrado. `advance()` actualiza los tiempos cuando cambia el paso. `+ get_debuff_time_text(index) -> String`. |
| `components/debuff_icon_row.gd` | Cada slot crea (una vez) un `MeshInstance3D` hijo con su propio `TextMesh` (`depth 0`, material compartido `time_material`) encima del ícono. `_process` se activa solo mientras haya debuffs y reescribe el `TextMesh` solo cuando cambia el paso. `+ get_time_text(index) -> String`. |

## 3. Interfaz pública

```gdscript
# ui/cooldown_text.gd
class_name CooldownText extends RefCounted
## 0 = nothing to show. Steps below the threshold are tenths, above it whole seconds.
static func to_step(seconds: float, config: CooldownTextConfig) -> int
## "" for step 0. Strings come from a table built once per config.
static func text_for_step(step: int, config: CooldownTextConfig) -> String
## Shorthand for tests and one-off use: text_for_step(to_step(seconds)).
static func format(seconds: float, config: CooldownTextConfig) -> String

# AbilityComponent
func get_cooldown_remaining() -> float

# DebuffComponent
static func get_remaining(debuff: ActiveDebuff) -> float
func get_remaining_seconds(id: StringName) -> float

# AbilitySlotView
func get_time_text() -> String
func is_key_visible() -> bool
func is_pulsing() -> bool

# BuffBar
func get_time_text(index: int) -> String
func get_stack_text(index: int) -> String   # sin cambios

# BossHealthBar
func get_debuff_time_text(index: int) -> String

# DebuffIconRow
func get_time_text(index: int) -> String
```

## 4. Lógica interna

- **Paso:** con `r` segundos restantes, `décimas = ceili(r / decimal_step − rounding_epsilon)`. Si `décimas × decimal_step < decimal_below_seconds`, el paso es `décimas` (1–99). Si no, el paso es `99 + ceili(r − rounding_epsilon) − 9` (10 s → 100, 11 s → 101…), con tope en `max_seconds`. `r ≤ 0` da paso 0.
- **Tabla:** índice = paso. `0 → ""`, `1…99 → "0.1"…"9.9"`, `100… → "10"…"999"`. Se construye la primera vez que se pide un paso con esa config (una sola config en el juego) y se guarda en una variable estática.
- **Solo escribir al cambiar:** cada vista guarda el último paso mostrado por slot (`PackedInt32Array` miembro) y asigna `text` solo si cambia. Cada texto cambia como mucho 10 veces por segundo, y el string asignado sale de la tabla, sin allocations.
- **Enemigos (3D):** con muchos enemigos, el costo es un cálculo entero por ícono activo por frame y una regeneración de `TextMesh` por ícono 10 veces por segundo como mucho. El `_process` de la fila solo corre mientras el enemigo tiene debuffs. Al reciclar el enemigo, `clear()` emite `changed` y la fila apaga su proceso.
- **Pulso:** `AbilitySlotView` recuerda si en el frame anterior había recarga. En la transición recarga → lista arranca el pulso. Mientras pulsa, `_process` interpola `scale` y el slot se redibuja igual que hoy.
- **Dash:** la barra ya se actualiza cada frame. Se suma el mismo control de paso para el label.

## 5. Criterios de aceptación

- **AC317** `CooldownText.format` con la config del juego: `0` → `""`, `0.03` → `"0.1"`, `2.5` → `"2.5"`, `2.5000001` → `"2.5"`, `2.51` → `"2.6"`, `9.9` → `"9.9"`, `9.95` → `"10"`, `10.0` → `"10"`, `10.2` → `"11"`, `45.0` → `"45"`, `5000.0` → `"999"`. Dos llamadas con el mismo paso devuelven strings iguales desde la tabla.
- **AC318** Habilidad: tras lanzar una habilidad con 6 s de recarga, el slot muestra `"6.0"` y oculta la tecla. Tras 3.45 s muestra `"2.6"`. Al terminar la recarga el tiempo queda vacío y la tecla vuelve. `AbilityComponent.get_cooldown_remaining()` devuelve la recarga restante.
- **AC319** Pulso: al terminar la recarga, `is_pulsing()` es true y `scale` vale `ready_pulse_scale`. Después de `ready_pulse_duration`, `scale` vuelve a 1 y deja de pulsar. Equipar una habilidad o arrancar la run no dispara el pulso.
- **AC320** Habilidad de carga: mientras se mantiene Envainar, el slot no muestra tiempo (solo el anillo de carga). Al soltar arranca la recarga y aparece el número.
- **AC321** Dash: listo, `%DashLabel` dice `DASH`. Tras dashear con 1.5 s de recarga dice `"1.5"`, a los 0.7 s dice `"0.8"`, y al terminar vuelve a `DASH`.
- **AC322** Buffs: con 2 stacks de Conmoción, el slot muestra `"2.5"` en el centro y `"2"` en la esquina. A 1.0 s muestra `"1.5"`. Al perder un stack muestra `"2.5"` y `"1"`. Al vaciarse el ícono se oculta y la barra deja de procesar.
- **AC323** `DebuffComponent.get_remaining_seconds`: Debilitar recién aplicado da 4.0 y a 1.5 s da 2.5. Sangrado recién aplicado da 5.0 y a 2.3 s da 2.7. Reaplicar reinicia ambos.
- **AC324** Enemigo común: con Sangrado y Debilitar, la fila 3D muestra un texto encima de cada ícono visible (`"5.0"` y `"4.0"`), cada uno con su propio `TextMesh` creado una sola vez y el material compartido `enemy_level_material.tres`. Al vencer un debuff su texto se oculta con el ícono. Sin debuffs, la fila no procesa.
- **AC325** Jefe: con Debilitar, la barra del jefe muestra `"4.0"` centrado en el ícono y a 1.5 s `"2.5"`. Los íconos miden `debuff_icon_size_px` (24).
- **AC326** Regresión: suite completa en verde, import y smoke test (menú y arena) sin errores ni warnings.

## 6. Tests que pueden necesitar adaptación

- `player_hud_test.gd` (AC295): `get_stack_text` sigue existiendo; el label solo se mueve a la esquina.
- `boss_hud_bar_test.gd`: si algún test verifica el tamaño de los íconos de debuff con 14 px, pasa a leer `debuff_icon_size_px` de la config.
- Cualquier test que lea el texto de `DashLabel` como `"DASH"` fijo pasa a leer `dash_ready_text`.

## 7. Enmienda: constitución v3.6.0 (MINOR, aplicada)

- **Principio II, tabla de colores:** nueva fila **"Tiempo restante de debuff (sobre el ícono del enemigo) | `TextMesh` | Blanco `Color(1, 1, 1)`"**.
- La frase sobre el blanco compartido suma este texto a los "textos flotantes" (junto a los números de daño y el nivel del enemigo). Es texto chico sobre un ícono de color, así que no se confunde con el cuerpo del jugador ni con la estela.
- Los textos del HUD 2D (tiempos de habilidades, dash, buffs y barra del jefe) no están alcanzados por la tabla (son UI 2D, como el resto de los labels del HUD).

## 8. Plan

1. **Base:** `CooldownTextConfig` + `.tres`, `CooldownText` con su tabla, `AbilityComponent.get_cooldown_remaining()` y `DebuffComponent.get_remaining*`. Tests AC317 y AC323.
2. **Habilidades:** label de tiempo, tecla oculta durante la recarga y pulso en `AbilitySlotView`; campos nuevos en `AbilitySlotViewConfig`; `key_label` en `hud.tscn`. Tests AC318 a AC320.
3. **Dash:** `HudConfig` + `.tres`, `%DashLabel` y su actualización en `Hud`. Test AC321.
4. **Buffs:** dos labels por slot y `_process` condicionado en `BuffBar`. Test AC322.
5. **Debuffs:** texto en la barra del jefe (íconos de 24 px) y `TextMesh` en `DebuffIconRow`. Tests AC324 y AC325.
6. **Ajuste visual:** captura de la arena con una habilidad en recarga, Conmoción activa y un enemigo con dos debuffs; ajustar tamaños de fuente y alturas en los `.tres`.
7. **Cierre:**
   - Enmienda v3.6.0 en la constitución.
   - Suite completa, import y smoke test (copia en el scratchpad).
   - Copiar al proyecto los `.uid` nuevos.
   - Review de la constitución en esta spec y estado Implementada.
   - `CLAUDE.md`: próximo AC **AC327** y specs recientes.

## 9. Notas de implementación

- **Números de AC:** la spec se escribió con AC297–AC306, pero `spin-tornado` y `nuki` los usaron en paralelo. Se renumeró a **AC317–AC326** (+20) antes de cerrar.
- **Tamaños finales** (ajustados con capturas de la arena):
  - Habilidades: fuente 18 (básica) y 22 (definitiva); pulso ×1.2 durante 0.25 s.
  - Buffs: el cuadrado pasa de 28 a **36 px** para que entren el tiempo (fuente 15) y los stacks (fuente 10) sin pisarse.
  - Debuffs 3D: `time_font_size 36`, `time_pixel_size 0.005` (≈ 75 % del "lv. 1"), `time_height_above_icon 0.16`. `spacing` pasa de 0.04 a **0.2 m** para que los textos de dos debuffs no se superpongan.
  - Barra del jefe: íconos de 24 px con fuente 11.
- **Reaplicar Sangrado** reinicia los ticks pero no la fase del tick en curso (comportamiento previo de `DebuffComponent`), así que el tiempo vuelve a `4 + tick_left` y no a 5.0 exacto. AC321 lo verifica así.
- **§6:** ningún test viejo necesitó cambios. `DashLabel` conserva `text = "DASH"` en la escena (el `Hud` lo reescribe con `dash_ready_text` en el primer frame).
- Los timers de la fila 3D son hijos de cada ícono, así que se ocultan y se reubican con él sin código extra.

## 10. Review de la constitución (cierre)

- [x] **I:** Combate (planear el siguiente intercambio con el tiempo exacto de habilidades y dash) y Progresión (buffs y debuffs de las mejoras doradas legibles), como declara la spec.
- [x] **II:** el texto 3D es un `TextMesh` (primitiva) con el material compartido `enemy_level_material.tres`, blanco registrado en la tabla por la enmienda v3.6.0. El resto es UI 2D (`Label`). Sin shaders ni texturas.
- [x] **III:** formato, umbral, décima, tope y contorno en `cooldown_text_config.tres`; tamaños y pulso en `ability_slot_view_config.tres`, `buff_bar_config.tres`, `boss_bar_config.tres` y `debuff_icon_config.tres`; el texto "DASH" en `hud_config.tres`. Ningún Resource se muta en runtime.
- [x] **IV:** tipado completo. Los `_process` nuevos solo delegan (`advance`, `update_times`).
- [x] **V:** los strings salen de una tabla construida una vez; cada vista reescribe su texto solo cuando cambia el paso (≤ 10 veces por segundo). Labels y `TextMesh` se crean una vez por slot. `BuffBar` y `DebuffIconRow` procesan solo mientras hay buffs o debuffs activos.
- [x] **VI:** sin input nuevo.
- [x] **Calidad:** 405 tests en verde, 0 orphans; import y smoke test sin errores ni warnings.
