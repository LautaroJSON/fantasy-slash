# Feature: animación y VFX del dash, y dash extensible por clase

- **Estado:** Implementada (2026-09-27). ACs: AC778–AC800. Constitución enmendada a 4.15.0 (aplicada). Tests: solo los de esta spec (pedido del responsable), ver §10.
- **Constitución:** `docs/constitution.md` v4.14.0 → **enmienda MINOR a 4.15.0** (Principio II, ver §7).
- **Pilar (Principio I):** **combate.** El dash es la salida defensiva y ahora también el arranque de la carrera. Hoy se ve como un paso de caminar que se desliza y no muestra que el jugador es invulnerable. Con una animación propia por clase, las imágenes residuales durante los iframes y el polvo y las líneas del impulso, el dash se lee y se siente. Además, el dash pasa a tener datos y un *behavior* por clase, igual que las habilidades, para sumarle reglas después (dash aéreo, dash que hace daño, reemplazarlo por un bloqueo).
- **Dependencias:** `dash-speed.md`, `dash-iframes.md`, `sprint-stamina.md` (§11–§12: el dash lleva a la carrera), `class-combat-identity.md` (perfiles), `humanoid-player-model.md`, `spin-dash-slash.md` (patrón de VFX del dash), `wind-cut-v.md` (polvo).

## 1. Estado actual

1. `PlayerAnimator` reproduce `run` (el clip de **caminar**) durante el dash (`CLIP_DASH`).
2. El dash dura `dash_distance / dash_speed`: 0.20 s el Guerrero y el Berserker, 0.14 s el Samurái.
3. `DashComponent.try_dash(direction)` va hacia el input o, sin input, hacia donde mira el cuerpo. **El cuerpo no gira**: un dash hacia atrás se ve de frente.
4. No hay VFX propios del dash, salvo el corte del Giro (`DashSlashVfx`), que es de la habilidad.
5. El dash es igual para todas las clases y no tiene datos ni *behavior* propio.

## 2. Diseño

### 2.1 Dirección y giro

Al empezar el dash, **el cuerpo (`Visual`) gira al instante hacia la dirección del dash**. Si no hay input, esa dirección es hacia donde ya mira, así que no cambia nada: el personaje siempre dashea "hacia donde mira", también cuando la dirección sale del input. Hay un solo clip por clase, hacia adelante.

### 2.2 Animación personalizada por clase (clip `dash`)

Cada perfil (Guerrero, Berserker, Samurái) define `dash` con una **plantilla de tiempos común**, en fracciones de la duración:

| Fracción | Pose | Qué se ve |
|---|---|---|
| 0.00 | **Impulso** | Sale del sprint o de la guardia: cuerpo cargado hacia la dirección. |
| ~0.35 | **Estirado** | El tramo más largo: piernas abiertas, torso volcado, arma en su lugar de carrera. |
| 1.00 | **= primer cuadro de `sprint`** | Termina en la pose con la que arranca la carrera (regla de conexión). |

- **Guerrero:** embestida detrás del escudo, que sube al pecho como en su sprint; la espada baja al frente.
- **Berserker:** se lanza pesado con el hombro del mandoble adelante y se clava al final.
- **Samurái:** se desliza bajo, con la katana horizontal atrás y la funda paralela (iaido en movimiento).
- El clip dura lo que diga su perfil y `PlayerAnimator` lo reproduce con `speed_scale = largo del clip / duración del dash`, así siempre llena el dash aunque una mejora cambie la distancia o la velocidad.
- `legacy` no tiene `dash`: usa `run` como hoy.

### 2.3 Regla de conexión con correr (vale para todo clip de dash)

1. **El último cuadro de `dash` es el primer cuadro de `sprint`** de la misma clase: todas las articulaciones a ≤ 2° y `hips_pos` a ≤ 1 cm, con el mismo peso de agarre de cada mano. Dash → sprint no salta.
2. **La entrada** al dash se mezcla en `dash_entry_blend` (0.05 s, `PlayerAnimationConfig`), venga del sprint, de caminar o de la guardia.
3. **El arma no cambia de agarre** durante el dash: manos, arma y funda siguen el recorrido del sprint.
4. **La salida:**
   - Corriendo (lo normal tras un dash con movimiento): `SPRINT` desde su cuadro 0, sin mezcla.
   - Sin input: `SPRINT_STOP`, que derrapa desde esa pose.
   - Con input pero sin estamina para correr: `RUN` con `sprint_exit_blend`.
5. Un test por perfil verifica los puntos 1 y 3 (AC786).

### 2.4 VFX modulares

Cada efecto es un **módulo** independiente (escena con un script que hereda `DashVfxModule`). Los módulos activos se listan en un Resource compartido, `data/player/dash/dash_vfx_set.tres`: para sacar o cambiar un efecto se toca una línea de esa lista (o su config), sin tocar código. Cada módulo tiene su config `.tres` en `data/player/dash/`.

| Módulo | Qué hace | Config (valores iniciales) |
|---|---|---|
| **A · Imágenes residuales** (`DashAfterimageVfx`) | Durante el dash deja **3** copias translúcidas de la silueta del cuerpo (torso, cabeza, manos y pies), en las fracciones 0.15, 0.5 y 0.85. Cada una se desvanece en 0.25 s. Muestran los iframes. | `count 3`, `fractions [0.15, 0.5, 0.85]`, `lifetime 0.25`, `start_alpha 0.35` |
| **C · Líneas de velocidad** (`DashSpeedLinesVfx`) | **4** franjas finas aditivas detrás del cuerpo, orientadas al dash, a distintas alturas y lados. Siguen al jugador y se desvanecen en 0.15 s al terminar. | `count 4`, `length 1.2 m`, `thickness 0.02 m`, `spread 0.35 m`, `height_min 0.4 / max 1.5 m`, `fade 0.15`, `alpha 0.4` |
| **D · Polvo** (`DashDustVfx`) | Una ráfaga de partículas tierra en los pies **al despegar** y otra **al terminar** (solo en el piso). | `amount 10`, `lifetime 0.35`, `speed 1.0–2.5`, `size 0.12`, `burst_on_end true` |
| **F · Zoom de cámara** (`DashFovKickVfx`) | El FOV sube **+6°** al empezar y vuelve en 0.25 s, con curva ease-out. | `fov_add 6.0`, `return_time 0.25` |

- **Materiales compartidos:** A usa `materials/vfx/dash_afterimage_material.tres` (blanco, unshaded, alpha ≤ 0.35). C usa el aditivo blanco existente (`wind_cut_additive_material.tres`). D usa el polvo existente (`wind_dust_material.tres`, tierra).
- **Pooling (Principio V):** todas las mallas y partículas se crean una vez al cargar el jugador. En el dash solo se mueven, se muestran, se ocultan y se re-emiten. Las imágenes residuales copian las `global_transform` de las 6 mallas del cuerpo a su pool (18 `MeshInstance3D` prearmadas).
- Los VFX de la Giro (`DashSlashVfx`) no cambian y conviven con estos.

### 2.5 Dash extensible por clase (datos y *behavior*)

Nuevo Resource **`DashData`** (`resources/dash_data.gd`), uno por clase en `data/classes/<clase>/<clase>_dash.tres`, referenciado desde `CharacterClassData.dash`:

| Campo | Qué es |
|---|---|
| `clip: StringName` | Clip del perfil para el dash (`&"dash"`). |
| `behavior: PackedScene` | Escena con un `DashBehavior`; `null` = el dash estándar. |
| `vfx_set: DashVfxSet` | Qué módulos de VFX usa (hoy las tres clases usan `dash_vfx_set.tres`). |

**`DashBehavior`** (`components/dash/dash_behavior.gd`, `extends Node`), con los *hooks* que llama `DashComponent` y que por defecto no hacen nada:

```gdscript
func can_start(dash: DashComponent) -> bool            # true: rules on top of the cooldown
func started(dash: DashComponent) -> void              # after the dash starts (iframes on)
func step(dash: DashComponent, delta: float) -> void   # every dash step, after the motion
func ended(dash: DashComponent, cancelled: bool) -> void
func get_clip(dash: DashComponent, default_clip: StringName) -> StringName  # e.g. an air variant
```

`DashComponent.equip(data: DashData)` instancia el *behavior* (como `AbilityComponent.equip`) y `Player` lo llama al aplicar la clase. Así caben los casos futuros sin reescribir el dash:

- **"Dash aéreo del Samurái hace X":** un `SamuraiDashBehavior` que, en `started`, mira `dash.is_airborne()` y aplica X (y puede pedir otro clip en `get_clip`).
- **"El dash del Guerrero hace daño":** un `WarriorDashBehavior` que en `step` golpea a los enemigos que cruza (usa `dash.get_player().enemy_registry`).
- **"Una mejora cambia el dash por un bloqueo":** la mejora equipa otro `DashData` (`DashComponent.equip`), cuyo *behavior* devuelve `false` en `can_start` y hace lo suyo. El botón del HUD sigue mostrando la recarga (`DashSlotSource`). La acción del bloqueo es de esa spec.

En esta spec las tres clases usan `behavior = null` (el dash estándar). **No se implementa ninguna regla nueva**, solo los puntos de extensión.

### 2.6 Estructura de nodos

```
Player
├── DashComponent        (+ equip(DashData), behavior hijo, señal dash_step)
│   └── <DashBehavior>   (instanciado desde DashData.behavior, si hay)
├── DashVfx (nuevo)      DashVfxHost: instancia los módulos de DashData.vfx_set y les pasa los eventos
│   ├── DashAfterimageVfx (top_level)
│   ├── DashSpeedLinesVfx
│   ├── DashDustVfx       (top_level)
│   └── DashFovKickVfx
└── …
```

### 2.7 Interfaz pública

```gdscript
# DashComponent
signal dash_step(delta: float)                   # every dash step, after the motion
func equip(data: DashData) -> void
func get_data() -> DashData
func get_clip() -> StringName                    # behavior.get_clip(data.clip)
func get_progress() -> float                     # 0 → 1 along the running dash
func get_duration() -> float                     # of the running (or last) dash
func is_airborne() -> bool                       # the body is off the floor
func get_player() -> Player

# DashVfxModule (base, components/dash/vfx/dash_vfx_module.gd)
func setup(player: Player) -> void               # once: build the pool
func dash_started(dash: DashComponent) -> void
func dash_step(dash: DashComponent) -> void
func dash_ended(dash: DashComponent, cancelled: bool) -> void

# LowPolyHumanoid
func get_body_meshes() -> Array[MeshInstance3D]  # torso, head, hands, feet (built once)

# ThirdPersonCamera
func kick_fov(amount_deg: float, return_time: float) -> void
```

### 2.8 Lógica interna

- `DashComponent.try_dash()`: pide `behavior.can_start()`; gira `visual` hacia la dirección (`visual.rotation.y = atan2(-dir.x, -dir.z)`); guarda la duración; emite `dash_started` y llama `behavior.started()`. `move_body()` emite `dash_step` y llama `behavior.step()`. `_end_dash()` llama `behavior.ended()` antes de emitir `dash_ended`.
- `PlayerAnimator._play_action_clip()`: el clip del dash sale de `dash.get_clip()` (y cae a `run` si el perfil no lo tiene) y se reproduce con `dash_entry_blend` y `speed_scale = length / duration`. `settled_locomotion` ya deja `SPRINT` si se va a correr. Al terminar el dash, el cambio a `sprint` se pide con mezcla 0.
- `DashVfxHost._ready()`: instancia los módulos de `vfx_set` una vez, les llama `setup(player)` y conecta `dash_started`, `dash_step` y `dash_ended`. `Player._apply_character_class()` lo reconfigura si el `vfx_set` de la clase es otro.
- Sin allocations por cuadro: cada módulo usa sus buffers y nodos prearmados.

## 3. Criterios de aceptación (AC778–AC800)

**Datos y extensión**
- **AC778** Cada clase tiene `<clase>_dash.tres` (`DashData`) con `clip = &"dash"`, `behavior = null` y `vfx_set = dash_vfx_set.tres`, referenciado por `CharacterClassData.dash`.
- **AC779** `DashComponent.equip(data)` instancia el `behavior` de `data` como hijo (y libera el anterior). Con `behavior = null` el dash es el de siempre (AC14–AC16, AC395 y `dash-iframes` siguen verdes).
- **AC780** Con un `DashBehavior` de prueba, `can_start` falso impide el dash (sin recarga ni iframes), y `started`, `step` (una vez por paso) y `ended(cancelled)` se llaman en orden, con `cancelled = true` si lo corta una habilidad.
- **AC781** `get_clip` del *behavior* decide el clip que reproduce el animador.

**Giro y animación**
- **AC782** Al empezar un dash con input hacia la derecha de la cámara, el `Visual` mira hacia la dirección del dash en ese mismo cuadro. Sin input, no gira.
- **AC783** Los perfiles Guerrero, Berserker y Samurái tienen `dash` (sin bucle, 0.15–0.35 s), con sus tres poses clave en las fracciones 0, ~0.35 y 1.
- **AC784** Durante el dash suena `dash` con `speed_scale = largo / duración` (± 1 %), también con otra `dash_distance`.
- **AC785** Con un perfil sin `dash` (`legacy`), el animador reproduce `run` y no falla.
- **AC786** **Conexión:** para cada perfil, el último cuadro de `dash` y el primero de `sprint` difieren ≤ 2° en cada articulación, ≤ 1 cm en `hips_pos`, y tienen el mismo peso de agarre de cada mano.
- **AC787** Un dash que termina corriendo pasa a `sprint` desde su cuadro 0. Uno que termina sin input pasa a `sprint_stop`. Uno con input y sin estamina para correr pasa a `run`.

**VFX**
- **AC788** `dash_vfx_set.tres` lista los cuatro módulos (A, C, D y F). `DashVfx` instancia uno por entrada. Con un set sin un módulo, ese módulo no existe y los demás funcionan.
- **AC789** Imágenes residuales: en un dash aparecen `count` copias (3), cada una con 6 mallas en la pose del cuerpo de su fracción, con `start_alpha` (0.35) que baja a 0 en `lifetime` (0.25 s), y después se ocultan.
- **AC790** Las copias no se crean en el dash: el pool (3 × 6 `MeshInstance3D`) existe desde que el jugador está listo, y el número de nodos no cambia después de 5 dashes.
- **AC791** Líneas de velocidad: `count` (4) franjas visibles durante el dash, alineadas con la dirección (su eje largo a ≤ 5° del dash), detrás del cuerpo. Se desvanecen en `fade` (0.15 s) tras el final y se ocultan.
- **AC792** Polvo: al empezar un dash en el piso emite una ráfaga en los pies. Al terminar en el piso, otra. En el aire, ninguna.
- **AC793** Zoom de cámara: al empezar, el FOV sube `fov_add` (6°) y a los `return_time` (0.25 s) vuelve al valor base (± 0.1°). Dos dashes seguidos no acumulan más de un `fov_add`.
- **AC794** Materiales: las copias usan `dash_afterimage_material.tres` (blanco, unshaded, transparente; su alpha visible es `start_alpha` ≤ 0.35 vía `GeometryInstance3D.transparency`), las franjas el aditivo blanco existente y el polvo el material tierra existente.
- **AC795** Cada módulo lee sus números de su `.tres` (cambiar `count` a 2 da 2 copias o 2 franjas).

**Integración**
- **AC796** Un dash cortado por una habilidad (Envainar) termina los VFX como un final (`dash_ended(cancelled = true)`): las franjas se desvanecen y hay polvo si está en el piso.
- **AC797** El corte del dash del Giro (`DashSlashVfx`) sigue funcionando junto con estos VFX (`spin_dash_slash_test` verde).
- **AC798** Dash → sprint en el juego: sin salto visible en la captura, y el sprint arranca en su cuadro 0.
- **AC799** El botón de dash, la recarga y la estamina no cambian (`dash_button_test`, `sprint_test` verdes).
- **AC800** Con la mitad de los enemigos máximos de una oleada activos, 10 dashes seguidos no crean nodos nuevos (conteo de nodos estable).

## 4. Tests

- `test/components/dash/dash_data_test.gd` (AC778–AC781, con un *behavior* de prueba en `test/helpers/`).
- `test/entities/player/dash_anim_test.gd` (AC782–AC787).
- `test/components/dash/dash_vfx_test.gd` (AC788–AC797).
- Se corren también `dash_component_test`, `dash_cancel_test`, `spin_dash_slash_test`, `sprint_test`, `sprint_anim_test`, `dash_button_test` y `player_animator_test` (AC799).
- Captura: hoja por clase (sprint → dash → sprint, de lado y de 3/4) y un cuadro en juego con los VFX, para aprobación.

## 5. Riesgos

- **Carga visual:** cuatro efectos en 0.14–0.20 s. Por eso son módulos: se sacan o se afinan desde `dash_vfx_set.tres` y sus configs después de probarlos.
- **Samurái muy corto (0.14 s):** la pose de estirado apenas se ve. Si hace falta, se corre la fracción del estirado solo en su perfil (la plantilla lo permite).
- **Giro instantáneo** en dashes hacia atrás (180°): es intencional (se lee la dirección). Si molesta, se puede agregar un giro rápido en otra spec.
- **Choque con otras sesiones:** `class-combat-identity.md` y las specs del Samurái y del Guerrero tocan los perfiles. Los clips nuevos van en funciones propias (`_add_dash()`), como el sprint.

## 6. Datos nuevos (resumen)

- `resources/dash_data.gd`, `resources/dash_vfx_set.gd`, `resources/dash_afterimage_config.gd`, `resources/dash_speed_lines_config.gd`, `resources/dash_dust_config.gd` y `resources/dash_fov_kick_config.gd`.
- `data/classes/<clase>/<clase>_dash.tres` (×3) y `data/player/dash/dash_vfx_set.tres`, más un `.tres` por módulo.
- `materials/vfx/dash_afterimage_material.tres`.
- `PlayerAnimationConfig.dash_entry_blend = 0.05`.

## 7. Enmienda de la constitución (MINOR 4.14.0 → 4.15.0)

Principio II:

- **Imágenes residuales del jugador** (nuevo punto de VFX): un VFX puede mostrar copias de las mallas del cuerpo del humanoide. Son las mismas `ArrayMesh`, con un material `.tres` translúcido compartido y un pool creado una vez al cargar. Duran décimas de segundo y no son entidades.
- **Tabla de colores:** fila "VFX del dash: imágenes residuales y líneas de velocidad", blanco `Color(1, 1, 1)` unshaded; residuos con alpha ≤ 0.35 y líneas aditivas con alpha ≤ 0.5. Se suma a la lista de elementos que comparten el blanco: "…el corte del dash del Giro y los VFX del dash, que no se confunden: son translúcidos y se desvanecen en décimas de segundo".
- El polvo del dash usa el tierra ya registrado. Se amplía su registro: "…para el polvo del corte de viento y del dash".

## 8. Plan

1. Reservar AC778–AC800 en `CLAUDE.md` (próximo libre: AC801) y aplicar la enmienda 4.15.0.
2. **Datos y extensión:** `DashData`, `DashBehavior`, `DashComponent.equip()`/hooks/`dash_step`/giro del `Visual`, `CharacterClassData.dash` y los tres `.tres`; `Player` equipa el dash de la clase. Tests AC778–AC782 y los tests del dash existentes.
3. **Animador:** `dash.get_clip()`, `speed_scale`, `dash_entry_blend` y las salidas (AC784–AC787, con `run` como clip mientras no existan los nuevos).
4. **Clips:** `_add_dash()` en los tres perfiles, siguiendo la plantilla y la regla de conexión. Test de conexión AC786. Hojas de captura para tu aprobación (ajusto hasta que te conformen).
5. **VFX:** `DashVfxModule`, `DashVfxHost` y `DashVfxSet`, y después los cuatro módulos, cada uno con su config y su test. Material de las imágenes residuales. `kick_fov` en la cámara.
6. **Integración:** cortes por habilidad, convivencia con la Giro, conteo de nodos (AC796–AC800), captura en juego.
7. Cierre: tests de esta spec y de los que toca, smoke test, checklist, estado **Implementada** y `CLAUDE.md` ("Dónde se ajusta": dash y sus VFX).

## 9. Checklist de review (constitución)

- [x] Principio I: pilar de combate (el dash se lee, muestra los iframes y conecta con la carrera).
- [x] Principio II: enmendado a 4.15.0. Las imágenes residuales usan las mismas mallas del cuerpo con un material compartido y un pool; las líneas son `BoxMesh` con el aditivo blanco existente; el polvo es `CPUParticles3D` con el material tierra existente. Sin texturas ni shaders.
- [x] Principio III: cada VFX lee su `.tres` en `data/player/dash/`; qué módulos se usan sale de `dash_vfx_set.tres`; el dash de cada clase es un `DashData`; `dash_entry_blend` está en `player_animation_config.tres`. La única constante nueva (`HEIGHT_SEQUENCE_STEP`) es estructural.
- [x] Principio IV: tipado estricto. `DashBehavior` y `DashVfxModule` son clases base tipadas; los callbacks (`_process` de los módulos) solo orquestan.
- [x] Principio V: todos los nodos se crean en `setup()`, y AC790 y AC800 verifican que el conteo de nodos no cambia al dashear. Los módulos procesan solo mientras tienen algo que desvanecer.
- [x] Principio VI: sin cambios de input.
- [x] Principio VII: sin cambios en el golpe; el dash sigue cortándolo.

## 10. Notas de implementación

1. **Poses:** los tres `dash` usan la plantilla (0, 0.35 y 1 sobre 0.24 s) y los brazos del primer cuadro del sprint en todo el clip, así el arma nunca cambia de agarre. El test de conexión (AC786) compara el último cuadro del dash con el primero del sprint articulación por articulación. Hojas de captura (sprint → dash → sprint) revisadas: el último cuadro del dash y el primero del sprint coinciden.
2. **Salida del dash:** `PlayerAnimator._leave_dash()` elige el estado al terminar (sprint desde el cuadro 0 sin mezcla, `sprint_stop` sin input, `run` con input sin estamina) porque el dash deja la velocidad horizontal en 0 y la regla por velocidad pasaría a `run_stop`.
3. **Alpha de las imágenes residuales:** el material es blanco con transparencia, y cada copia se desvanece con `GeometryInstance3D.transparency` (desde `1 - start_alpha`). Así un solo material compartido sirve para copias con distinto alpha.
4. **AC800** se verificó sin enemigos: los VFX son hijos del jugador y los enemigos no los tocan. El conteo de nodos del jugador es estable tras 10 dashes.
5. **GdUnit:** si una aserción falla dentro de un test con `await` en `dash_anim_test.gd`, GdUnit corta el resto de la suite (se vio con AC782 en la primera corrida, antes de esperar un cuadro más para el dash).
6. **Resultado:** `dash_data_test` 5/5, `dash_anim_test` 8/8, `dash_vfx_test` 10/10, `dash_component_test` 14/14, `spin_dash_slash_test` 11/11, `sprint_test` 25/25, `sprint_anim_test` 6/6, `dash_button_test` 7/7 y `player_animator_test` 13/13 en verde. `dash_cancel_test` 7/8: AC363 (pose de reposo de la katana después de Envainar) falla igual que antes de esta spec y no depende del dash nuevo. Smoke test de la arena sin errores. Captura en juego (Samurái, dash lateral): imágenes residuales, líneas, polvo y zoom de cámara visibles.
