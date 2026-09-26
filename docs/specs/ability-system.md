# Feature: Sistema de habilidades (básica + ultimate) y Estocada

- **Estado:** Implementada (2026-09-25, 120 tests GdUnit4 en verde, smoke test headless sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v2.1.0 (sin enmiendas ni excepciones nuevas)
- **Pilares (Principio I):**
  - **Combate:** una herramienta con cooldown que obliga a elegir cuándo quedarse quieto y expuesto a cambio de daño concentrado.
  - **Progresión:** la habilidad se elige al empezar la run y crece con su propia línea de mejoras, que compite con las del personaje por las cartas.
- **Dependencias:** `combat-mvp.md`, `combat-feedback.md`, `attack-indicator.md` (Implementadas).

## 1. Objetivo

- El personaje tiene **dos ranuras de habilidad**: **básica** (click derecho) y **ultimate** (R).
- **Antes de la oleada 1** se abre un menú que pausa el juego y ofrece elegir **1 de N habilidades básicas**. Por ahora N = 1 (la Estocada). La elección de ultimate es una feature futura: su ranura existe, se ve **gris y más grande** en el HUD y no hace nada.
- Cada habilidad tiene **stats propios** (daño base plano, % de escalado sobre el DAMAGE del personaje, cooldown, alcance, ancho, duración de casteo) y **su propio catálogo de mejoras**.
- Las mejoras del personaje **no modifican los stats de la habilidad**. La habilidad solo **lee** el DAMAGE efectivo del personaje para su escalado. Crítico, bonus de daño y robo de vida no aplican a la Estocada. Habilidades futuras podrán declarar stats extra (p. ej. robo de vida) agregándolos al enum `AbilityData.Stat`.
- Las mejoras de la habilidad equipada entran al **mismo sorteo** de cartas post-oleada, con el mismo peso que las del personaje. Sus cartas se ven **celestes**.
- **Estocada:** el personaje queda **quieto** (no avanza), apunta al enemigo más cercano y, al terminar el casteo, golpea en un **rectángulo** hacia delante. Daño = `10 + 5 % × DAMAGE`.
- **Input:** el dash se mueve de click derecho a **Shift izquierdo** (decisión del responsable, 2026-09-25).
  - **Enmienda (2026-09-25, `thrust-indicator.md`):** la habilidad básica pasa a **E** y el dash vuelve al **click derecho**. AC58 queda reemplazado por AC65.

## 2. Estructura

### 2.1 Archivos nuevos

```
res://
├── resources/
│   ├── upgrade_card.gd              # UpgradeCard (base de UpgradeData y AbilityUpgradeData)
│   ├── ability_data.gd              # AbilityData
│   ├── ability_upgrade_data.gd      # AbilityUpgradeData
│   ├── ability_catalog.gd           # AbilityCatalog
│   ├── ability_slot_view_config.gd  # AbilitySlotViewConfig
│   └── upgrade_picker_config.gd     # UpgradePickerConfig
├── data/
│   ├── abilities/ability_catalog.tres
│   ├── abilities/thrust/thrust.tres
│   ├── abilities/thrust/upgrades/{damage,scaling,cooldown,range,width,cast_speed}.tres
│   ├── ui/ability_slot_view_config.tres
│   └── ui/upgrade_picker_config.tres
├── combat/hitbox_math.gd            # HitboxMath (funciones puras)
├── components/abilities/
│   ├── ability_component.gd         # AbilityComponent (una ranura)
│   ├── ability_behavior.gd          # AbilityBehavior (base de la lógica de cada habilidad)
│   ├── thrust_ability.gd            # ThrustAbility
│   └── thrust_ability.tscn
└── ui/
    ├── ability_picker.gd / .tscn    # AbilityPicker (menú inicial)
    └── ability_slot_view.gd         # AbilitySlotView (círculo del HUD)
```

### 2.2 Datos (Principio III)

| Resource | Campos |
|---|---|
| `UpgradeCard` | `title`, `description`. Método puro `is_same_kind(other) -> bool` (no ofrecer dos cartas del mismo stat). |
| `UpgradeData` (ahora `extends UpgradeCard`) | `stat: PlayerStats.Stat`, `amount`. Los `.tres` existentes no cambian. |
| `AbilityData` | `title`, `description`, `slot` (enum `Slot {BASIC, ULTIMATE}`), `behavior: PackedScene`, stats base (enum `Stat {BASE_DAMAGE, ATTACK_SCALING, COOLDOWN, HIT_RANGE, HIT_WIDTH, CAST_DURATION}` con `get_base(stat)`), pisos `min_cooldown` y `min_cast_duration`, y `upgrades: Array[AbilityUpgradeData]`. |
| `AbilityUpgradeData extends UpgradeCard` | `stat: AbilityData.Stat`, `amount`. |
| `AbilityCatalog` | `abilities: Array[AbilityData]`, `get_for_slot(slot)`. |
| `AbilitySlotViewConfig` | `basic_radius`, `ultimate_radius`, `ring_width`, `arc_point_count`, `ready_color`, `cooldown_color`, `cooldown_ring_color`, `locked_color`. |
| `UpgradePickerConfig` | `ability_card_color`, `ability_card_hover_color`, `ability_card_font_color`. |

**Estocada** (`thrust.tres`): `base_damage 10` · `attack_scaling 0.05` · `cooldown 4 s` · `hit_range 3.5 m` · `hit_width 1.0 m` · `cast_duration 0.35 s` · `min_cooldown 1 s` · `min_cast_duration 0.1 s`.

**Mejoras de la Estocada:** +5 de daño base · +5 % de escalado · −0.5 s de cooldown · +1 m de alcance · +0.4 m de ancho · −0.05 s de casteo.

**Empuje:** la Estocada empuja con `PlayerTuning.knockback_speed`, igual que el ataque básico. No es un valor nuevo: reutiliza la excepción ya justificada en `combat-feedback.md §0`.

**Colores:** las cartas de habilidad son celeste `Color(0.55, 0.85, 1.0)` con texto oscuro. La ranura bloqueada es gris. Son UI 2D: no usan ningún color reservado del Principio II ni texturas o shaders (el círculo se dibuja con `draw_circle` / `draw_arc`).

### 2.3 Escenas

```
Player (player.tscn)
├── ...
├── SwingPlayer             # + animaciones "thrust" y "thrust_recover"; "swing" también fija la posición de la espada
├── BasicAbility    : AbilityComponent (slot BASIC)
└── UltimateAbility : AbilityComponent (slot ULTIMATE, sin habilidad)
      └── <behavior instanciado por equip(), p. ej. ThrustAbility>

Arena
└── UI
    ├── Hud          # + BasicSlot y UltimateSlot (AbilitySlotView) abajo a la derecha
    └── AbilityPicker
```

## 3. Interfaz pública

### 3.1 `AbilityComponent` (Node)
- `equip(data: AbilityData)`: instancia `data.behavior` una sola vez y reinicia el estado de la ranura.
- `is_equipped()`, `get_data()`, `get_stat(stat)`: stats efectivos = base + mejoras, con pisos. Se cachean y solo se recalculan al agregar una mejora.
- `add_upgrade(upgrade)`, `get_upgrades()`, `owns_upgrade(card)`.
- `try_cast() -> bool`: falla si no hay habilidad, si está en cooldown o si ya está casteando. El cooldown **empieza al pulsar**.
- `is_casting()`, `get_cooldown_ratio()` (1 = recién usada, 0 = lista), `advance(delta)`.
- Señales: `cast_started`, `cast_released`, `enemy_hit(enemy, applied, is_crit)`.

### 3.2 `AbilityBehavior` / `ThrustAbility`
- `begin(ability)`: al pulsar. La Estocada gira hacia el enemigo más cercano y toca "thrust" escalada a `CAST_DURATION`.
- `release(ability)`: al terminar el casteo. La Estocada aplica el daño a los enemigos dentro del rectángulo y toca "thrust_recover".

### 3.3 Fórmulas puras
- `DamageMath.ability_damage(base, scaling, attack) = base + scaling × attack`. Después, la defensa enemiga mitiga como en cualquier golpe.
- `HitboxMath.in_rectangle(origin, flat_forward, point, length, half_width)`: el centro del enemigo está delante (0 ≤ avance ≤ largo) y a no más de `half_width` a los costados.

### 3.4 Cambios en código existente
- `Player`: `basic_ability`, `ultimate_ability`, `is_casting()`, `apply_upgrade(card)`. Mientras castea: sin movimiento horizontal (la gravedad sigue), sin salto, sin dash, sin ataque básico. No se puede castear durante un dash.
- `MovementComponent.hold(delta)`: frena en seco en XZ y aplica gravedad.
- `UpgradeOffer.pick(pool: Array[UpgradeCard], count, rng)` y `UpgradeOffer.build_pool(catalog, ability_upgrades)`.
- `UpgradePicker`: trabaja con `UpgradeCard`. Las cartas de habilidad son celestes.
- `WaveManager`: abre el `AbilityPicker` antes de la oleada 1. Al elegir, equipa, arma el pool de cartas y arranca la oleada.
- `PauseMenu`: no abre mientras el `AbilityPicker` está abierto.
- `DamageNumberPool`: muestra también los golpes de las habilidades.
- `project.godot`: `ability_basic` = click derecho, `ability_ultimate` = R, `dash` = Shift izquierdo.

## 4. Lógica de estado de una ranura

```
LISTA --try_cast--> CASTEANDO (cast_left = CAST_DURATION, cooldown corre desde el pulso)
CASTEANDO --cast_left <= 0--> release() --> EN COOLDOWN
EN COOLDOWN --cooldown <= 0--> LISTA
```

## 5. Criterios de aceptación

- **AC46** `DamageMath.ability_damage(10, 0.05, 15) == 10.75`.
- **AC47** Stats efectivos: sin mejoras son los del `.tres`. Con +5 de daño base y +0.05 de escalado, un enemigo en el rectángulo recibe `15 + 0.10 × DAMAGE`. Las mejoras del personaje (p. ej. +4 de DAMAGE) cambian el daño solo a través del escalado y **no** modifican ningún stat de la habilidad.
- **AC48** Pisos: 10 mejoras de −0.5 s de cooldown dejan el cooldown en `min_cooldown`. 10 mejoras de −0.05 s de casteo dejan el casteo en `min_cast_duration`.
- **AC49** `try_cast` con cooldown en curso devuelve `false`. Tras avanzar `COOLDOWN` segundos vuelve a funcionar. `get_cooldown_ratio()` es 1 justo al pulsar y 0 al terminar.
- **AC50** Hitbox rectangular: un enemigo a 3 m al frente recibe daño. Uno a 4 m al frente, uno a 1 m al costado y uno detrás no reciben. El daño se aplica al terminar el casteo, no al pulsar.
- **AC51** La Estocada gira al jugador hacia el enemigo más cercano.
- **AC52** Mientras castea, el jugador no se desplaza en XZ aunque haya velocidad previa, y no puede atacar ni hacer dash. Al terminar el casteo recupera el control.
- **AC53** La arena arranca pausada con el `AbilityPicker` abierto y sin enemigos. Elegir la Estocada la equipa en la ranura básica, despausa y arranca la oleada 1. La ranura ultimate queda vacía.
- **AC54** El pool de cartas contiene las mejoras del personaje y **solo** las de la habilidad equipada. Cada oferta tiene 3 cartas de tipos distintos y, con suficientes sorteos, aparece cada mejora de la Estocada.
- **AC55** Elegir una carta de habilidad la aplica a la ranura básica, no cambia ningún stat del personaje y arranca la siguiente oleada.
- **AC56** Las cartas de habilidad del `UpgradePicker` usan el color celeste de `UpgradePickerConfig`. Las del personaje no.
- **AC57** HUD: la ranura ultimate es más grande que la básica y se dibuja bloqueada (gris). La ranura básica refleja el cooldown de la habilidad.
- **AC58** InputMap: `ability_basic` = click derecho, `ability_ultimate` = R, `dash` = Shift. Ninguna acción comparte binding.
- **AC59** Pausa: no se abre mientras el `AbilityPicker` está abierto.
- **AC60** Regresión: la suite completa sigue en verde. Los tests de arena existentes eligen la habilidad en su `before_test`.
  - *Nota:* `upgrade_offer_test.gd` se adaptó a la nueva firma `UpgradeOffer.pick(pool, …)`. Los AC21 siguen verificando lo mismo sobre el pool del personaje.

### Review de la constitución (cierre)
- **I:** sirve a Combate y Progresión, como declara la spec.
- **II:** sin assets externos. La espada sigue negra (solo cambian sus animaciones). El HUD se dibuja con `draw_circle`/`draw_arc`, sin texturas ni shaders.
- **III:** todos los valores de la habilidad, sus mejoras, los pisos y los colores de UI viven en `.tres`. `AbilityData` no se muta; las mejoras se acumulan en `AbilityComponent`.
- **IV:** tipado estático completo y callbacks de ciclo de vida delgados.
- **V:** hitbox lógico sin `Area3D`, buffer de impactos reutilizado, behavior instanciado una sola vez al equipar, el HUD solo redibuja cuando cambia el cooldown.
- **VI:** solo acciones del InputMap (`ability_basic`, `ability_ultimate`, `dash`).

## 6. Plan de implementación

1. Resources y datos (`.tres`) + funciones puras (`DamageMath.ability_damage`, `HitboxMath`).
2. `AbilityComponent`, `AbilityBehavior`, `ThrustAbility` + animaciones en `player.tscn` + cambios en `Player` y `MovementComponent`.
3. Cartas: `UpgradeCard`, `UpgradeOffer`, `UpgradePicker` (celeste), `WaveManager`, `AbilityPicker`, `PauseMenu`.
4. HUD: `AbilitySlotView` ×2.
5. InputMap.
6. Tests AC46-AC59 y adaptación de los tests de arena. Suite completa (AC60), smoke test, checklist de la constitución, spec **Implementada**.

## 7. Fuera de alcance

- Elegir la ultimate (feature futura) y cualquier habilidad ultimate concreta.
- Indicador en el suelo del área de la Estocada.
- Mostrar los stats de la habilidad en el menú de pausa.
- Pesos distintos para cartas de habilidad vs. personaje.
