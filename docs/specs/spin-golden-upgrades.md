# Feature: Mejoras doradas del Giro ("Rompecorazas" y "Vorágine")

- **Estado:** Implementada (2026-09-25, 372 tests GdUnit4 en verde, 0 orphans; las suites nuevas pasaron 3 corridas seguidas; import y smoke test del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.5.0 (enmienda MINOR aprobada con esta spec, §7).
- **Pilares (Principio I):**
  - **Combate:** Rompecorazas premia sostener el Giro sobre el mismo grupo. Vorágine premia meterse en la multitud y rematar girando, porque cada kill acelera y alarga el siguiente tramo.
  - **Progresión:** son las primeras cartas doradas del Berserker y abren dos builds del Giro: anti-armadura (colosos, jefes) y "bola de nieve" contra hordas.
- **Dependencias:** `berserker.md`, `unique-ability-upgrades.md`, `spin-buff-wind-trail.md` y `crit-feedback.md` (Implementadas).

## 1. Objetivo

### 1.1 Rompecorazas (mejora única, 3 niveles)

- Cada golpe del Giro aplica 1 stack de **Debilitar** al enemigo golpeado, después del daño (el golpe que aplica el stack no se beneficia de él).
- **Debilitar** (debuff nuevo): **solo baja armadura, no hace daño**.
  - Se acumula hasta **3 stacks**.
  - Cada aplicación suma 1 stack (sin pasar de 3) y **reinicia la duración a 4 s**. Al vencer, se pierden todos los stacks juntos.
  - Cada stack reduce la **defensa** del enemigo un **5 % / 7 % / 10 %** según el nivel de la carta. Con 3 stacks: −15 % / −21 % / −30 %.
- `max_level 3`, porque tiene un valor que tiene sentido subir. Los valores viven en `level_values` (Principio III).
- La "armadura" del pedido es la `defense` del enemigo: se resta plana a cada golpe (`DamageMath.mitigate`). Debilitar la escala: `defensa efectiva = defense × (1 − reducción)`. El piso `min_damage_after_defense` no cambia.

### 1.2 Vorágine (mejora única, sin niveles). *Modificada por `spin-tornado.md`:* ahora se llama **Vigorizante** (id `invigorating`) y da +7 % de movimiento por stack.

- Cada enemigo que **muere por un golpe del Giro** le da al jugador 1 stack del buff **Conmoción**.
- **Conmoción:**
  - Tope: **10 stacks**.
  - **Cola de pérdida:** cada kill suma 1 stack (sin pasar de 10) y **reinicia el temporizador a 2.5 s**. Cada vez que el temporizador llega a 0 se pierde **1 stack**, y si quedan stacks, el temporizador vuelve a 2.5 s.
  - El buff vive en el jugador y **decae aunque el Giro haya terminado**. Si se lanza el Giro de nuevo antes de que se vacíe, los stacks restantes se aprovechan.
  - **Efectos por stack, solo mientras el Giro está activo:**
    - +5 % de velocidad de movimiento durante el Giro: el factor de `SpinConfig.move_speed_factor` se multiplica por `1 + 0.05 × stacks`.
    - +5 % de velocidad de giro: vueltas por segundo × `1 + 0.05 × stacks`, es decir, tiempo por vuelta `TICK_INTERVAL / (1 + 0.05 × stacks)`.
    - +5 % de probabilidad de crítico **del Giro**. Sin stacks, el Giro no critica (comportamiento actual). No suma la probabilidad crítica del personaje.
  - **Daño crítico:** `CRIT_DAMAGE` del personaje en el momento del golpe (bonus: 1.0 = ×2). El crítico se tira **por enemigo golpeado** y se muestra con el número ámbar.
- **No alarga la duración del Giro.**
- `max_level 1`, porque es un efecto binario. Los valores por stack viven en el `BuffData` de Conmoción, no en el código (Principio III).
- La velocidad extra de giro **puede bajar el tiempo por vuelta por debajo de `min_tick_interval`**, porque ese piso limita las cartas de stats, no un buff temporal. Con 6 copias de velocidad y 10 stacks: 0.4 / 1.5 ≈ 0.267 s por vuelta.

### 1.3 Nombres propuestos

| Qué | Nombre propuesto | Alternativas |
|---|---|---|
| Carta 1 | **Rompecorazas** | Quebranto, Desgarro de acero |
| Carta 2 | **Vorágine** | Frenesí, Torbellino sangriento |
| Debuff | Debilitar (pedido) | — |
| Buff | Conmoción (pedido) | — |

## 2. Estructura

### 2.1 Datos (Principio III)

| Archivo | Cambio |
|---|---|
| `resources/debuff_data.gd` | `+ enum Effect { DAMAGE_OVER_TIME, ARMOR_REDUCTION }`, `+ effect: Effect`, `+ max_stacks: int` (≤ 1 = no acumula, el comportamiento actual). `tick_interval` solo se usa con `DAMAGE_OVER_TIME`. |
| `data/debuffs/weaken.tres` (nuevo) | id `weaken`, `effect ARMOR_REDUCTION`, `duration 4.0`, `max_stacks 3`, ícono `debuff_weaken_material.tres` |
| `materials/debuff_weaken_material.tres` (nuevo) | unshaded, **violeta** `Color(0.55, 0.35, 0.8)` (color no reservado) |
| `data/debuffs/bleed.tres` | sin cambios (el default `effect = DAMAGE_OVER_TIME` es 0) |
| `resources/buff_data.gd` (nuevo) | `id: StringName`, `title: String`, `max_stacks: int`, `stack_duration: float` (segundos hasta perder 1 stack), `icon_color: Color`, `modifiers: Array[BuffModifier]` |
| `resources/buff_modifier.gd` (nuevo) | `enum Stat { MOVE_SPEED, ABILITY_SPEED, CRIT_CHANCE }`, `stat: Stat`, `per_stack: float` |
| `data/buffs/concussion.tres` (nuevo) | id `concussion`, título "Conmoción", `max_stacks 10`, `stack_duration 2.5`, color **verde lima** `Color(0.55, 0.85, 0.25)` (no reservado), modifiers: MOVE_SPEED 0.05, ABILITY_SPEED 0.05, CRIT_CHANCE 0.05 |
| `resources/ability_unique_upgrade_data.gd` | `+ buff: BuffData` (buff que otorga el efecto, si otorga uno) |
| `data/abilities/spin/unique/armor_break.tres` (nuevo) | id `armor_break`, "Rompecorazas", `max_level 3`, `level_values [0.05, 0.07, 0.10]`, `debuff weaken.tres`, `value_format "%.0f %% por stack"` (×100) |
| `data/abilities/spin/unique/maelstrom.tres` (nuevo) | id `maelstrom`, "Vorágine", `max_level 1`, sin `level_values`, `buff concussion.tres` |
| `data/abilities/spin/spin.tres` | `unique_upgrades` = [armor_break, maelstrom] |
| `resources/buff_bar_config.gd` + `data/ui/buff_bar_config.tres` (nuevos) | `max_icons 4`, `icon_size 28`, `spacing 6` (píxeles del HUD) |

**Textos de las cartas:**
- Rompecorazas nivel 1: "Cada golpe del Giro aplica Debilitar (hasta 3 stacks, 4 s): −5 % de armadura por stack". Niveles 2 y 3: "Debilitar: −7 % de armadura por stack" y "Debilitar: −10 % de armadura por stack".
- Vorágine: "Cada enemigo que matás con el Giro te da Conmoción (hasta 10, pierde 1 cada 2.5 s). Por stack, durante el Giro: +5 % de velocidad, +5 % de giro y +5 % de crítico".

### 2.2 Nodos

```
Player (player.tscn)
├── BuffComponent : BuffComponent   (nuevo)
├── BasicAbility / UltimateAbility  + export buffs → BuffComponent
Enemy: DebuffComponent (existente) ahora escribe HealthComponent.defense_reduction
HUD (hud.tscn)
└── … BuffBar : BuffBar (HBoxContainer, nuevo) sobre la barra de vida (abajo al centro)
      └── max_icons × (ColorRect + Label con los stacks), creados una vez en _ready
```

## 3. Interfaz pública

- **`HealthComponent`**
  - `+ defense_reduction: float`: fracción de la defensa ignorada, en [0, 1]. Se pone en 0 en `setup()`.
  - `receive_hit` mitiga con `defense × (1 − defense_reduction)`.
- **`DebuffComponent`**
  - `apply(data, potency)`:
    - Si el debuff ya existe, suma 1 stack (tope `max(data.max_stacks, 1)`), reinicia su duración y conserva la potencia mayor.
    - Si es nuevo, lo crea con 1 stack.
    - Los debuffs de daño siguen como hoy (refrescan, no acumulan, `max_stacks` ≤ 1).
  - `ActiveDebuff`: `+ stacks: int`, `+ time_left: float`. Los `ARMOR_REDUCTION` vencen por `time_left` y los `DAMAGE_OVER_TIME` siguen contando ticks.
  - `+ get_stacks(id) -> int`.
  - `+ get_defense_reduction() -> float`: suma de `stacks × potency` de los `ARMOR_REDUCTION`, con tope 1. Se escribe en `health.defense_reduction` cada vez que la lista cambia (aplicar, vencer, `clear()`).
- **`BuffComponent`** (nuevo, `components/buff_component.gd`), en espejo de `DebuffComponent`:
  - `signal changed`.
  - `add_stack(data: BuffData)`: +1 stack hasta `max_stacks` y reinicia el temporizador a `stack_duration`.
  - `advance(delta)`: por cada buff, al llegar el temporizador a 0 pierde 1 stack y, si le quedan, el temporizador vuelve a `stack_duration`. Con 0 stacks se quita de la lista.
  - `get_stacks(id) -> int`.
  - `get_modifier(id, stat) -> float`: `stacks × per_stack` (0 si no está activo).
  - `get_active()`, `get_time_left(id)`, `clear()`.
  - `_physics_process` solo delega en `advance` y se desactiva con la lista vacía.
- **`AbilityComponent`:** `+ @export var buffs: BuffComponent`.
- **`SpinAbility`**
  - Rotación por **progreso acumulado**: `_turn_progress += step / turn_time`, con `yaw = start + TAU × progress` y un golpe por cada entero cruzado. Así cambiar la velocidad a mitad del Giro no hace saltar el mandoble. `get_turns_done()` se mantiene.
  - `turn_time = TICK_INTERVAL / (1 + get_modifier(concussion, ABILITY_SPEED))`.
  - `move_body`: factor `config.move_speed_factor × (1 + get_modifier(concussion, MOVE_SPEED))`.
  - `_strike`: por enemigo, `is_crit = roll_crit(get_modifier(concussion, CRIT_CHANCE), rng.randf())` y daño `apply_crit(hit_damage, is_crit, CRIT_DAMAGE)`, reportado con `report_hit(enemy, applied, is_crit)`.
  - `_hit_enemy`: si tiene `armor_break`, aplica `weaken` con potencia `get_unique_value(armor_break)` al enemigo si sigue vivo. Si tiene `maelstrom` y el golpe lo mató, llama `buffs.add_stack(concussion)`.
  - `+ var rng: RandomNumberGenerator`, público para que los tests puedan fijar la semilla.
  - Los modificadores de Conmoción se leen solo si el jugador tiene `maelstrom`, así que sin la carta no hay efecto aunque queden stacks (p. ej. al quitarla en el sandbox).
- **`BuffBar`** (nuevo, `ui/buff_bar.gd`): se refresca solo con `BuffComponent.changed` (sin trabajo por frame, así que el texto de stacks se arma en ese momento). *Ajuste de implementación:* reemplaza la idea de actualizar textos por frame con strings precalculados.

## 4. Lógica interna

- **Orden dentro de un golpe del Giro:** tirar el crítico con los stacks actuales → aplicar el daño → Debilitar (si vive) → Conmoción (si murió). Una kill a mitad de la vuelta acelera las vueltas siguientes, no la actual.
- **Debilitar sobre un enemigo del pool:** `Enemy.activate/deactivate` ya llaman `debuffs.clear()`, que ahora también deja `defense_reduction` en 0.
- **Muertes por Sangrado u otras fuentes** no dan Conmoción: solo cuenta la muerte causada por el golpe del Giro.

## 5. Criterios de aceptación

- **AC284** `armor_break.tres`: id `armor_break`, título "Rompecorazas", `max_level 3`, valores [0.05, 0.07, 0.10] y debuff `weaken`. `maelstrom.tres`: id `maelstrom`, título "Vorágine", `max_level 1` y buff `concussion`. Las dos están en `spin.tres` como `unique_upgrades` y aparecen en la oferta solo con el Giro equipado.
- **AC285** `weaken.tres`: `ARMOR_REDUCTION`, 4 s, `max_stacks 3`, ícono violeta. `concussion.tres`: 10 stacks, 2.5 s, y +0.05 por stack en MOVE_SPEED, ABILITY_SPEED y CRIT_CHANCE.
- **AC286** `DebuffComponent`: aplicar `weaken` 4 veces deja 3 stacks. Cada aplicación reinicia la duración a 4 s, y a los 4 s sin aplicar se va entero (0 stacks, ícono oculto).
- **AC287** Con Rompecorazas nivel 1/2/3 y 3 stacks, un enemigo con defensa 10 recibe un golpe de 20 como 20 − 8.5 / 7.9 / 7.0. Sin stacks, como 20 − 10. `defense_reduction` vuelve a 0 al vencer el debuff y al reciclar el enemigo del pool.
- **AC288** Con Rompecorazas, cada vuelta del Giro suma 1 stack de Debilitar a cada enemigo golpeado. Sin la carta, el Giro no aplica debuffs.
- **AC289** Regresión de Sangrado: `bleed.tres` sigue haciendo 5 ticks de `potency × max_health` y reaplicarlo refresca sin acumular (los tests de Lacerante siguen en verde).
- **AC290** `BuffComponent`: 3 `add_stack` seguidos → 3 stacks y temporizador 2.5 s. A los 2.5 s quedan 2, a los 5 s 1 y a los 7.5 s 0 (sale de la lista). Una kill a los 2.0 s de la última vuelve el temporizador a 2.5 s sin perder stacks. Nunca pasa de 10.
- **AC291** Con Vorágine, un enemigo que muere por un golpe del Giro da 1 stack de Conmoción. Uno que sobrevive no da nada. Sin la carta, las kills del Giro no dan stacks.
- **AC292** Con 4 stacks durante el Giro:
  - el tiempo por vuelta es `TICK_INTERVAL / 1.2`;
  - el factor de movimiento es `move_speed_factor × 1.2`;
  - la probabilidad crítica es 0.2.
  Fuera del Giro, los stacks no cambian la velocidad de movimiento del jugador.
- **AC293** Cambiar los stacks a mitad del Giro no hace saltar el yaw del `Visual` (continuidad dentro de un paso de física) y las vueltas se siguen contando bien.
- **AC294** Sin stacks, el Giro nunca critica. Con probabilidad 1 (dato de test), todo golpe es crítico, hace `hit_damage × (1 + CRIT_DAMAGE)` con el `CRIT_DAMAGE` actual del jugador y se reporta con `is_crit = true`.
- **AC295** El HUD muestra Conmoción con su color y la cantidad de stacks mientras esté activa, y la oculta al llegar a 0. Los íconos se crean una sola vez.
- **AC296** Regresión: suite completa en verde, import y smoke test (menú y arena) sin errores ni warnings.

## 6. Tests que pueden necesitar adaptación

- Tests de `SpinAbility` que dependan de `_elapsed` para el yaw: el comportamiento sin buff es idéntico (mismo yaw y mismas vueltas). Si alguno lee un valor interno, se adapta sin cambiar lo que verifica y se anota acá.

## 7. Enmienda: constitución v3.5.0 (MINOR, aplicada)

- **Principio III, "Debuffs":**
  - `DebuffData` también declara su **efecto** (daño por tick o reducción de armadura) y su **tope de stacks**.
  - Nueva viñeta **Buffs**: todo estado temporal positivo del jugador es un Resource de datos (`BuffData`: tope de stacks, duración por stack, modificadores por stack, color del ícono). El jugador guarda una lista de buffs activos. Qué acción aprovecha cada modificador (p. ej. solo durante el Giro) lo decide la mejora que lo otorga y queda en su spec.
- **Principio II, colores no reservados:** se suman el violeta del ícono de Debilitar y el verde lima del ícono de Conmoción en el HUD.

## 8. Plan

1. **Datos base:** extender `DebuffData` (`effect`, `max_stacks`) y crear `BuffData`, `BuffModifier`, `BuffBarConfig`, `weaken.tres`, `concussion.tres` y el material violeta. Verificar que `bleed.tres` conserve su comportamiento.
2. **Debilitar:**
   - Stacks y vencimiento por tiempo en `DebuffComponent`.
   - `defense_reduction` en `HealthComponent`.
   - Tests AC286, AC287 y AC289.
3. **Buffs:** `BuffComponent` y su nodo en `player.tscn`, y el export `buffs` en los dos `AbilityComponent`. Tests AC290.
4. **Giro:**
   - Refactor a progreso acumulado, sin cambio de comportamiento, con la suite de spin en verde.
   - Rompecorazas y Vorágine (crítico, velocidad, movimiento).
   - Cartas `.tres` en `spin.tres`.
   - Tests AC284, AC285, AC288 y AC291 a AC294.
5. **HUD:** `BuffBar` y su config. Test AC295.
6. **Cierre:**
   - Enmienda v3.5.0 en la constitución.
   - Suite completa, import y smoke test (copia en el scratchpad).
   - Review de la constitución en esta spec y estado Implementada.
   - `CLAUDE.md`: próximo AC **AC297** y specs recientes.

## 9. Notas de implementación

- Los tests de `spin_test.gd` no necesitaron cambios: sin Conmoción, el progreso acumulado da el mismo yaw y las mismas vueltas.
- `DebuffComponent.apply` ahora emite `changed` también al refrescar (antes solo al agregar), para que el ícono y `defense_reduction` se actualicen con cada stack.
- AC289 (regresión de Sangrado) lo cubren los tests existentes de Lacerante (AC98 a AC102), que siguen en verde.
- AC284 verifica que el slot que no tiene el Giro no ofrece las cartas, en vez de equipar otra habilidad en el mismo test (dos `equip()` dejan un orphan, ver `CLAUDE.md`).
- `Player.reset_upgrades()` (sandbox) también limpia los buffs.

## 10. Review de la constitución (cierre)

- [x] **I:** Combate (sostener el Giro sobre el grupo, rematar girando) y Progresión (primeras cartas doradas del Berserker), como declara la spec.
- [x] **II:** el ícono de Debilitar es el `BoxMesh` existente con el material compartido `debuff_weaken_material.tres` (violeta, no reservado). El ícono de Conmoción es un `ColorRect` 2D del HUD (verde lima, no reservado). Colores registrados en v3.5.0. Sin shaders ni texturas.
- [x] **III:** los porcentajes por nivel viven en `armor_break.tres`, y la duración y el tope de Debilitar en `weaken.tres`. Los bonos por stack, el tope y la duración de Conmoción viven en `concussion.tres`, y el layout del HUD en `buff_bar_config.tres`. Ninguna mejora muta un Resource compartido: el estado vive en `ActiveDebuff`/`ActiveBuff`. `max_level` declarado (3 y 1).
- [x] **IV:** tipado completo. `_physics_process` de `BuffComponent` solo delega en `advance`.
- [x] **V:** sin allocations por frame. `ActiveBuff`/`ActiveDebuff` se crean solo al aplicar un tipo nuevo, los íconos del HUD se crean una vez y el Giro reutiliza `_hit_buffer` y un `RandomNumberGenerator` miembro.
- [x] **VI:** sin input nuevo.
- [x] **Calidad:** 372 tests en verde, 0 orphans; import y smoke test sin errores ni warnings.
