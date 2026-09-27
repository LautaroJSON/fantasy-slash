# Feature: íconos de estado estilo LoL (buffs y debuffs)

- **Estado:** Propuesta (2026-09-27).
- **ACs reservados:** AC901–AC930 (reservados en `CLAUDE.md` al escribir la spec).
- **Constitución:** `docs/constitution.md` v4.15.0 → **enmienda MINOR a 4.16.0** (Principio II, ver §8).
- **Pilar (Principio I):** **combate** (legibilidad).
  - De un vistazo se sabe qué estado tiene cada enemigo, cuántos stacks tiene y cuánto le falta, sin leer números. Un ícono se reconoce aunque dos estados tengan colores parecidos (Rage y Sangrado son rojos).
  - Todos los estados se leen igual: los del jugador, los de un boss y los de un enemigo común. Eso prepara la mecánica global de acumulación (otra sesión), que va a sumar estados nuevos.
- **Dependencias:** `cooldown-clock.md` (reloj cuadrado), `cooldown-timers.md`, `debuff-stacks-display.md`, `boss-hud-bar.md`, `spin-golden-upgrades.md` y `enemy-rage.md` (Implementadas).
- **Fuera de alcance:**
  - VFX o animaciones por estado en el cuerpo del enemigo. Las auras de Rage y de Escudo no cambian. El sistema genérico de VFX por estado va en otra spec.
  - Debuffs sobre el jugador: hoy no existen. Cuando existan, usan el mismo `StatusIconView` (§3).
  - La barra de acumulación de la mecánica global y el aturdimiento (otras specs).
  - Tooltips con el nombre del estado.
  - Los botones de habilidad (`AbilitySlotView`): siguen mostrando sus segundos.

## 1. Estado actual

Hay tres implementaciones del mismo concepto, con reglas distintas:

| Dónde | Nodo | Cómo se dibuja | Reloj | Segundos | Stacks |
|---|---|---|---|---|---|
| Enemigo común (sobre su barra 3D) | `DebuffIconRow` (`components/debuff_icon_row.gd`) | `BoxMesh` con `DebuffData.icon_material` | no | `TextMesh` arriba del ícono | `TextMesh` en la esquina |
| Boss (barra del HUD) | `BossHealthBar` (`ui/boss_health_bar.gd`) | `ColorRect` con el `albedo_color` de ese material | sí | `Label` centrado | `Label` en la esquina |
| Buffs del jugador (HUD) | `BuffBar` (`ui/buff_bar.gd`) | `ColorRect` con `BuffData.icon_color` | sí | `Label` centrado | `Label` en la esquina |

Problemas:
1. **No hay íconos, solo colores planos.** Rage (`Color(0.9, 0.1, 0.1)`) y Sangrado (`Color(0.55, 0.05, 0.05)`) se confunden.
2. **Un enemigo que nunca fue golpeado no muestra sus estados.** La fila 3D es hija de la barra de vida, que está oculta hasta el primer golpe (`EnemyHealthBar.reset()`). Un enemigo con Rage recién aparecido solo muestra el aura.
3. Hay tres implementaciones que duplican lo mismo (casillas, reloj, textos, stacks).

## 2. Diseño

### 2.1 Anatomía del ícono (igual en todos lados)

Un **cuadrado** con cinco capas, de abajo hacia arriba:

1. **Fondo:** el color del estado oscurecido (`icon_color.darkened(background_darken)`).
2. **Glifo:** el SVG del estado, centrado, con un margen interior (`glyph_margin`). Se tiñe con el color del estado aclarado (`icon_color.lightened(glyph_lighten)`), así el glifo contrasta con su fondo sin usar blanco puro (reservado, Principio II).
3. **Reloj:** el `CooldownClock` cuadrado de siempre, un sector oscuro translúcido. **Cubre el tiempo transcurrido** y crece en sentido horario desde las 12 hasta cubrir todo el ícono al vencer, como en el LoL (D1). Los estados permanentes (Rage, Escudo) no tienen reloj.
4. **Marco:** un borde de `border_width` px. Es **rojo** en los debuffs y **verde** en los buffs. Los estados que benefician a quien los tiene (Rage y Escudo en un enemigo, Conmoción en el jugador) llevan marco de buff.
5. **Stacks:** un número abajo a la derecha, con el contorno de `CooldownTextConfig`. Se muestra solo en los estados que acumulan (`get_stack_cap() > 1` o, en buffs, `max_stacks > 1`), igual que hoy (AC383).

**Desaparecen los segundos:** ningún ícono de estado muestra texto de tiempo. El reloj es la única indicación de duración.

### 2.2 Dónde se muestra

| Dónde | Contenedor | Tamaño | Cambio |
|---|---|---|---|
| Buffs del jugador | `BuffBar` (HUD, mismo lugar) | 36 px (`BuffBarConfig.icon_size`) | `ColorRect` → `StatusIconView` |
| Debuffs de un boss | `BossHealthBar` (HUD) | 28 px (`BossBarConfig.debuff_icon_size_px`, hoy 24) | `ColorRect` → `StatusIconView` |
| Estados de un enemigo común | **`EnemyStatusOverlay`**, una capa 2D nueva del HUD | 22 px | reemplaza a la fila 3D |

**Capa 2D para los enemigos comunes:**
- La fila de cada enemigo se dibuja en pantalla, centrada sobre el punto de su barra de vida (`unproject_position` de `EnemyHealthBar.global_position`) y corrida `row_offset_px` hacia arriba.
- El tamaño en píxeles es fijo, no se achica con la distancia, como en el LoL.
- Se ve **aunque la barra de vida esté oculta** (enemigo sin golpear), en el mismo lugar donde aparecería la barra. La barra sigue apareciendo recién con el primer golpe.
- No se muestra para bosses (barra suprimida: sus estados van en el HUD), ni para enemigos detrás de la cámara, inactivos o apareciendo desde el piso.

### 2.3 Íconos

Son SVG de [game-icons.net](https://game-icons.net) (licencia **CC BY 3.0**, con crédito por autor). Se bajan del repo `github.com/game-icons/icons` y viven en `assets/icons/status/`.

| Estado | Archivo | Origen (autor/ícono) | Color (`icon_color`) | Tipo |
|---|---|---|---|---|
| Sangrado (`bleed`) | `bleeding_wound.svg` | lorc/bleeding-wound | `Color(0.55, 0.05, 0.05)` | debuff |
| Debilitar (`weaken`) | `cracked_shield.svg` | lorc/cracked-shield | `Color(0.55, 0.35, 0.8)` | debuff |
| Rage (`rage`) | `enrage.svg` | delapouite/enrage | `Color(0.9, 0.1, 0.1)` | buff del enemigo |
| Escudo de la Colmena (`shield`) | `checked_shield.svg` | lorc/checked-shield | `Color(0.95, 0.78, 0.25)` | buff del enemigo |
| Conmoción (`concussion`) | `whirlwind.svg` | lorc/whirlwind | `Color(0.55, 0.85, 0.25)` | buff del jugador |

- Los colores son los de hoy (materiales y `icon_color`), así que nada cambia de tono.
- **Preparación:** cada SVG de game-icons trae un cuadrado negro de fondo (`<path d="M0 0h512v512H0z"/>`). Se borra con `sed` para que quede el glifo blanco sobre transparente, que después se tiñe. El procedimiento y los créditos quedan en `assets/icons/status/SOURCE.md`.
- **Importación:** textura 2D con `svg/scale` suficiente para 64 px (el tamaño más grande) y mipmaps activados.

## 3. Estructura de nodos

```
StatusIconView (Control, ui/status_icon_view.gd)        ← creado una vez por casilla
├── Background (ColorRect, full rect)
├── Glyph (TextureRect, full rect con margen, expand + keep aspect centered)
├── Clock (CooldownClock, Shape.SQUARE)
├── Border (Control que dibuja el marco con draw_rect(filled=false))
└── StackLabel (Label, abajo a la derecha)

Hud
├── EnemyStatusOverlay (Control, full rect, mouse ignore)   ← nuevo, primer hijo (debajo del resto del HUD)
│   └── Row × max_rows (HBoxContainer)
│       └── StatusIconView × max_icons
├── TopCenter/BossBars/…/DebuffIcons → StatusIconView × max_debuff_icons
└── BuffBar → StatusIconView × max_icons

Enemy (entities/enemy/enemy.tscn)
└── HealthBar
    └── DebuffIcons   ← se borra
```

`Hud` recibe `enemy_registry: EnemyRegistry` (enlazado en `arena.tscn`) y se lo pasa al overlay.

## 4. Resources y datos

- **`StatusIconConfig`** (nuevo, `resources/status_icon_config.gd`, instancia `data/ui/status_icon_config.tres`). Es el aspecto compartido:
  - `background_darken: float` (0.55)
  - `glyph_lighten: float` (0.45)
  - `glyph_margin: float`: fracción del lado (0.12)
  - `border_width: float`: px (2.0)
  - `debuff_border_color: Color`: `Color(0.85, 0.2, 0.15)`
  - `buff_border_color: Color`: `Color(0.3, 0.8, 0.35)`
  - `stack_font_ratio: float`: tamaño de fuente = lado × ratio (0.42)
  - `clock: CooldownClockConfig`
  - `cooldown_text: CooldownTextConfig`: solo el estilo del contorno
- **`EnemyStatusOverlayConfig`** (nuevo, `data/ui/enemy_status_overlay_config.tres`):
  - `max_rows: int` (24)
  - `max_icons: int` (4)
  - `icon_size_px: float` (22)
  - `spacing_px: int` (3)
  - `row_offset_px: Vector2`: `Vector2(0, -16)`
  - `status_icon: StatusIconConfig`
- **`DebuffData`:**
  - `+ icon: Texture2D`
  - `+ icon_color: Color`
  - `+ is_beneficial: bool`: marco de buff; `true` en `rage.tres` y `shield.tres`
  - `− icon_material` (se borra; ver §7)
- **`BuffData`:** `+ icon: Texture2D`. `icon_color` sigue igual.
- **`BuffBarConfig`:**
  - `− time_font_size`, `− stack_font_size`, `− clock`, `− cooldown_text`
  - `+ status_icon: StatusIconConfig`
  - Se quedan `max_icons`, `icon_size` y `spacing`.
- **`BossBarConfig`:**
  - `− debuff_time_font_size`, `− debuff_stack_font_size`
  - `+ status_icon: StatusIconConfig`
  - `debuff_icon_size_px` pasa de 24 a 28.
  - `clock` y `cooldown_text` se quedan solo si los usa otra cosa del boss bar; si no, se borran.
- **`DebuffComponent`:** `+ var revision: int`, que se incrementa cada vez que emite `changed`. Es estado del nodo (Principio III) y le permite al overlay saber sin señales si tiene que reescribir una fila.

## 5. Interfaz pública

```gdscript
class_name StatusIconView extends Control
enum Kind { DEBUFF, BUFF }
static func create(config: StatusIconConfig, side: float) -> StatusIconView
func show_status(icon: Texture2D, color: Color, kind: Kind, stacks: int, shows_stacks: bool) -> void
## Remaining time over the full duration, in [0, 1]; the clock covers 1 - ratio.
## Permanent statuses pass `has_clock = false`.
func set_remaining(ratio: float, has_clock: bool) -> void
func get_glyph_texture() -> Texture2D
func get_glyph_color() -> Color
func get_border_color() -> Color
func get_stack_text() -> String
func get_clock() -> CooldownClock
# Static helpers so every container maps its data the same way:
static func debuff_kind(data: DebuffData) -> Kind
static func shows_debuff_stacks(data: DebuffData) -> bool

class_name EnemyStatusOverlay extends Control
@export var config: EnemyStatusOverlayConfig
var registry: EnemyRegistry        # set by Hud
func update_rows() -> void          # called by _process and by tests
func get_row_enemy(index: int) -> Enemy
func get_row_position(index: int) -> Vector2
func get_visible_row_count() -> int
func get_icon(row: int, index: int) -> StatusIconView
```

`BuffBar` y `BossHealthBar` conservan sus *getters* de conteo y devuelven `StatusIconView` en `get_icon()` / `get_debuff_icon()`. Se borran `get_time_text()` y `get_debuff_time_text()`.

## 6. Lógica interna

- **`StatusIconView`:**
  - Crea sus cinco hijos en `create()`, una sola vez.
  - `show_status` solo asigna textura y colores y ajusta el texto de stacks. Se llama cuando cambia la lista de estados, nunca por frame.
  - `set_remaining` llama a `clock.set_fraction(1 − ratio)`; el reloj ya redibuja solo si cambia la fracción.
  - Sin `has_clock`, el reloj se oculta.
- **`BuffBar` y `BossHealthBar`:** misma lógica que hoy (refrescan contenido en `changed` y fracciones en `_process` mientras haya estados), sin labels de tiempo. La fracción sale de:
  - buffs: `time_left / stack_duration`;
  - debuffs: `DebuffComponent.get_remaining_ratio()`, que ya existe y devuelve 0 en los permanentes.
- **`EnemyStatusOverlay._process` → `update_rows()`**, sin *allocations* (Principio V):
  1. Obtiene la cámara con `get_viewport().get_camera_3d()`. Es un *getter* del viewport, no una búsqueda en el árbol; se cachea mientras siga siendo válida.
  2. Recorre `registry.get_active()`, que devuelve el array interno sin copiarlo.
  3. Por cada enemigo elegible toma la siguiente fila libre `k`. Es elegible si:
     - tiene estados;
     - su barra no está suprimida;
     - no está apareciendo desde el piso;
     - no está detrás de la cámara (`camera.is_position_behind`).
  4. Si la fila `k` estaba asignada a otro enemigo, o si la `revision` del `DebuffComponent` cambió desde la última vez, reescribe su contenido con `show_status`.
  5. Posiciona la fila (centrada en X) y actualiza las fracciones de sus íconos.
  6. Oculta las filas que sobran después de `k`.
  7. Con más enemigos elegibles que `max_rows`, los que sobran no se muestran. Nunca se crean nodos en runtime.
  8. Con cero filas visibles, el `_process` sigue corriendo: el recorrido es barato y lo necesita para detectar estados nuevos. Alternativa descartada: conectarse a `changed` de cada enemigo, porque obliga a conectar y desconectar cada vez que el pool recicla.
- **Enemigo desactivado:** `registry.unregister` lo saca de la lista, así que en el frame siguiente su fila queda libre.

## 7. Qué se borra

| Archivo o campo | Motivo |
|---|---|
| `components/debuff_icon_row.gd` y el nodo `HealthBar/DebuffIcons` de `enemy.tscn` | Lo reemplaza `EnemyStatusOverlay` |
| `resources/debuff_icon_config.gd` y `data/ui/debuff_icon_config.tres` | Sin uso |
| `DebuffData.icon_material` y `materials/debuff_{bleed,weaken,rage,shield}_material.tres` | Solo los usaban los íconos; el color pasa a `icon_color` |

`enemy_level_material.tres` **se queda**: lo usa el nivel del enemigo (`enemy_health_bar.tscn`).

## 8. Enmienda de la constitución (MINOR 4.15.0 → 4.16.0)

**Principio II:**
- Nuevo punto:
  > **Íconos de estado** (desde 4.16.0): los buffs y debuffs se muestran con íconos SVG monocromos importados en `assets/icons/<categoría>/`, con su `SOURCE.md` (origen, licencia y crédito) y sin fondo propio. Solo se usan en la UI 2D (`StatusIconView`) y se referencian desde los Resources de estado (`DebuffData.icon`, `BuffData.icon`), sin escena adaptadora. Se tiñen con el color del estado, nunca en blanco puro.
- En "Assets importados permitidos" se agrega "e íconos SVG de UI (desde 4.16.0)" a los formatos.
- En la tabla de colores, la fila "Tiempo restante y stacks de debuff (sobre su ícono, en el enemigo) — `TextMesh` blanco" **se borra**: los estados ya no son 3D.
- En el registro de colores no reservados se suman:
  - el rojo del marco de debuff `Color(0.85, 0.2, 0.15)`;
  - el verde del marco de buff `Color(0.3, 0.8, 0.35)`;
  - los fondos y glifos de los íconos, derivados del color de cada estado.
- Se aclara que los colores de estado viven en `icon_color`, ya no en materiales `.tres` de íconos.

**Historial:**
> 4.16.0 (fecha de aplicación): Principio II: íconos de estado SVG en la UI 2D, con un estándar único para buffs y debuffs; desaparecen los íconos 3D de los enemigos (ver `status-icons.md`).

## 9. Tests y ACs existentes que cambian

Lo que verifican se mantiene. Cambia cómo se ve.

| AC | Hoy | Pasa a |
|---|---|---|
| AC322 (`cooldown_timers_test`) | Buffs: segundos `"2.5"` en el centro | Sin segundos; se verifican el stack y el reloj (AC906) |
| AC324 (`cooldown_timers_test`) | Texto de tiempo en la fila 3D | **Reemplazado** por AC909 (el overlay no tiene texto de tiempo) |
| AC325 (`cooldown_timers_test`) | Boss: `"4.0"` centrado, 24 px | Sin segundos; 28 px (AC907) |
| AC349 y AC350 (`cooldown_hud_test`) | El reloj vale 1 al aplicar y baja (cubre lo que falta) | Vale 0 al aplicar y sube (cubre lo transcurrido, D1). Los valores pasan a `1 − x`. La parte "los íconos 3D no tienen reloj" se reemplaza por AC909. |
| AC382 (`status_effects_test`) | Stacks en `TextMesh` 3D | Stacks en el `StatusIconView` del overlay |
| AC162, AC384 (`boss_hud_bar_test`) | Color del material | `icon_color` y textura |
| AC285 (`spin_golden_upgrades_test`) | `icon_material.albedo_color` violeta | `icon_color` violeta |
| AC295 (`player_hud_test`) | Color de Conmoción en un `ColorRect` | Glifo, color y stacks en `StatusIconView` |

Los tests de `unique_upgrades_test` que crean un veneno de prueba con `icon_material` pasan a usar `icon` e `icon_color`.

## 10. Criterios de aceptación

- **AC901** `StatusIconView.create()` deja exactamente cinco hijos en este orden: fondo, glifo, reloj cuadrado, marco y stacks. No tiene ningún `Label` de tiempo. Después de `create()`, `show_status` y `set_remaining` no crean ni liberan nodos.
- **AC902** `show_status` con Debilitar:
  - glifo con la textura `cracked_shield.svg`;
  - color del glifo `icon_color.lightened(0.45)`;
  - fondo `icon_color.darkened(0.55)`;
  - marco `debuff_border_color`.

  Con Rage o Escudo (`is_beneficial`) y con Conmoción, el marco es `buff_border_color`.
- **AC903** Stacks:
  - Debilitar aplicado 1, 2, 3 y 4 veces muestra `"1"`, `"2"`, `"3"` y `"3"`;
  - Sangrado muestra el texto vacío;
  - Conmoción con 2 stacks muestra `"2"`.
- **AC904** Reloj (D1):
  - Debilitar recién aplicado: fracción 0. A 1.5 s: 0.375. Reaplicado: vuelve a 0.
  - Sangrado recién aplicado: 0.
  - Rage: el reloj está oculto todo el tiempo.
- **AC905** Todo `DebuffData` de `data/debuffs/` y todo `BuffData` de `data/buffs/` cumple:
  - tiene `icon` no nulo, en `assets/icons/status/`;
  - tiene un `icon_color` con alpha 1;
  - ningún SVG de esa carpeta contiene el path de fondo `M0 0h512v512H0z`.
- **AC906** Buffs del jugador: con 2 stacks de Conmoción, la `BuffBar` muestra un `StatusIconView` de 36 px con el glifo de Conmoción, `"2"` y el reloj en 0. A 1.0 s el reloj vale 0.4. Al perder un stack vuelve a 0. Al vaciarse, el ícono se oculta y la barra deja de procesar. No hay texto de tiempo.
- **AC907** Boss: con Sangrado, la barra del boss muestra un `StatusIconView` de 28 px con el glifo y el color de `bleed.tres`, sin stacks. Desaparece al limpiar el debuff. Con 2 stacks de Debilitar muestra `"2"`.
- **AC908** `assets/icons/status/SOURCE.md` existe y lista cada SVG de la carpeta con su autor, la URL de origen y la licencia CC BY 3.0.
- **AC909** Overlay: un enemigo común con Debilitar que **nunca fue golpeado** (barra de vida oculta) tiene una fila visible con 1 ícono. La fila está centrada en `camera.unproject_position(health_bar.global_position) + row_offset_px` (±1 px).
- **AC910** Overlay, casos sin fila:
  - enemigo sin estados;
  - boss con estados (barra suprimida);
  - enemigo detrás de la cámara;
  - enemigo apareciendo desde el piso.

  Al desactivar (pool) un enemigo con estados, su fila se oculta en el siguiente `update_rows()`.
- **AC911** Overlay, capacidad: la cantidad de hijos se fija en `_ready` (`max_rows` filas de `max_icons` íconos) y no cambia después de 100 `update_rows()` con enemigos que ganan y pierden estados. Con `max_rows + 2` enemigos con estados, hay exactamente `max_rows` filas visibles. Un enemigo con 5 estados muestra 4.
- **AC912** Overlay, contenido: `show_status` se llama para una fila solo cuando cambia su enemigo o la `revision` de su `DebuffComponent` (se cuenta con un doble del ícono o un contador de test). Diez `update_rows()` sin cambios de estados no lo llaman.
- **AC913** `DebuffComponent.revision` sube en 1 cada vez que se emite `changed` (aplicar, sumar un stack, vencer, `remove` y `clear` con estados).
- **AC914** Limpieza:
  - `enemy.tscn` no tiene el nodo `DebuffIcons`;
  - no existen `DebuffIconRow`, `DebuffIconConfig`, `debuff_icon_config.tres` ni los cuatro `debuff_*_material.tres`;
  - `DebuffData` no tiene `icon_material`;
  - ningún script, escena o recurso los referencia.
- **AC915** Los colores no cambian: `bleed`, `weaken`, `rage` y `shield` tienen como `icon_color` los `albedo_color` de sus materiales de antes (tabla §2.3), y Conmoción conserva el suyo.
- **AC916** Integración: en `arena.tscn` el `Hud` tiene `EnemyStatusOverlay` enlazado al `EnemyRegistry`. Un enemigo de la oleada con Rage (enrage de nivel 1) muestra su ícono sobre la cabeza antes de recibir un golpe.

## 11. Plan

Cada paso deja el proyecto abriendo y la suite en verde.

1. **Íconos:**
   - bajar los 5 SVG;
   - quitarles el fondo con `sed`;
   - escribir `SOURCE.md`;
   - importar en la copia del scratchpad y copiar los `.import` de vuelta;
   - tests AC905 (parte de archivos) y AC908.
2. **Datos, aditivos:**
   - `StatusIconConfig`, `EnemyStatusOverlayConfig` y sus `.tres`;
   - `icon`, `icon_color` e `is_beneficial` en `DebuffData`, e `icon` en `BuffData`;
   - completar los `.tres` de estados;
   - `DebuffComponent.revision`.

   Todavía conviven con `icon_material`. Tests AC905, AC913 y AC915.
3. **`StatusIconView`** y sus tests (AC901–AC904).
4. **`BuffBar`** migra a `StatusIconView` (config reducida). Adaptar AC322, AC349 y AC295. Test AC906.
5. **`BossHealthBar`** migra (28 px). Adaptar AC325, AC350, AC162 y AC384. Test AC907.
6. **`EnemyStatusOverlay`** en el HUD y enlace en `arena.tscn`. Tests AC909–AC912 y AC916.
7. **Limpieza:**
   - borrar `DebuffIconRow`, el nodo, la config, los materiales y `icon_material`;
   - adaptar AC324 y AC382 y los tests de `unique_upgrades_test`;
   - test AC914.
8. **Cierre:**
   - aplicar la enmienda 4.16.0;
   - actualizar `CLAUDE.md` ("Dónde se ajusta cada cosa": íconos de estado);
   - captura visual (enemigo común sin golpear con Rage, enemigo con Debilitar ×3 + Sangrado, boss y buff del jugador);
   - suite completa, import y smoke test;
   - checklist de review y estado **Implementada**.

## 12. Decisiones para aprobar

- **D1 — Dirección del reloj:** el sector oscuro cubre el tiempo **transcurrido**: ícono limpio al aplicarse, que se oscurece hasta vencer, como en el LoL. Hoy los buffs y los bosses hacen lo contrario, igual que los botones de habilidad (el sector cubre lo que falta). Los botones de habilidad no cambian.
- **D2 — Colores del marco:** rojo `Color(0.85, 0.2, 0.15)` para los debuffs y verde `Color(0.3, 0.8, 0.35)` para los buffs.
- **D3 — Rage y Escudo:** llevan marco de buff porque benefician al enemigo, como en el LoL. La alternativa es clasificar todo lo que está sobre un enemigo como debuff.
- **D4 — Límites:**
  - 4 íconos por enemigo común (hoy también 4);
  - 24 filas en pantalla;
  - tamaños de 22, 28 y 36 px.

## 13. Checklist de review (al cerrar)

- [ ] Identidad (I)
- [ ] Arte (II)
- [ ] Datos (III)
- [ ] GDScript (IV)
- [ ] Performance (V)
- [ ] Input (VI)
- [ ] Combate (VII)
- [ ] Calidad
