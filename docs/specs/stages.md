# Feature: Stages (mapas por etapa, portal y el Mar de Flores)

- **Estado:** Implementada (2026-09-29), sin commitear, salvo AC1323 (medición en el teléfono, pendiente del responsable). Suites corridas: `stage_data_test`, `stage_run_test`, `obstacle_steering_test`, `mar_de_flores_test` y las adaptadas (`wave_config_test`, `horde_config_test`, `arena_waves_test`, `arena_horde_test`, `boss_challenge_run_test`), no la suite completa (preferencia del responsable).
- **Constitución:** `docs/constitution.md` **v6.1.0** → **MINOR 6.2.0 aplicada** con esta spec (Principio II, viñeta nueva "Escenarios (stages)"; ver §9 y `constitution-history.md`). Anexo de colores: sección nueva "Escenario y portal".
- **Criterios de aceptación:** usa **AC1286–AC1325** (renumerados desde AC1266–AC1305: otra sesión tomó ese rango en paralelo).
- **Pilar (Principio I):** Progresión, y de rebote Supervivencia.
  - Hoy la run es una sola arena gris infinita: pasar un jefe no cambia nada del mundo. Con los stages, cada jefe derrotado abre un portal a un lugar nuevo y la run se siente como un viaje (progresión dentro de la run, con la base para lore y meta-progresión entre runs).
  - Las columnas, los árboles y las rocas del mapa son obstáculos reales: el jugador puede usarlos para cortar embestidas o separar grupos, y los enemigos los rodean (posicionamiento táctico, Supervivencia).
- **Tipo:** feature (arquitectura de la run + primer mapa).
- **Dependencias:** `enemy-types.md` y `boss-*.md` (pools por tipo y por jefe, `WaveConfig`), `fodder-minion.md` (hordas), `enemy-group-ai.md` (`AttackCoordinator.separation_for`), `enemy-ground-telegraph.md` (avisos en el piso), `early-power-curve.md` (cartas por oleada), `mobile-touch-controls.md` (Android).

## Decisiones del responsable (2026-09-29)

| Pregunta | Decisión |
|---|---|
| Cuándo cambia el mapa | **Después de cada jefe.** Un stage = **10 oleadas normales + 1 oleada de jefe**. |
| Mapas de jefe | A futuro, un mapa por jefe (lore). **Ahora no:** todos los jefes pelean en el mapa del stage. La arquitectura queda lista para sumarlos. |
| Contenido por stage | Cada stage declara en datos su nombre, sus tipos de enemigos y sus jefes posibles (`nombre = x enemigos, x jefe`). |
| Transición | **Se abre un portal.** El portal es modular: su estilo es una escena intercambiable, así puede haber varios estilos. |
| Obstáculos | **Con columnas** (y árboles y rocas): los enemigos los rodean. |
| Tema del primer mapa | Campo abierto, **light fantasy**: pradera de flores, ruinas con arcos y columnas, un arroyo, piedras y árboles, un castillo a lo lejos, cielo azul con nubes enormes. Referencias: las 6 imágenes del 2026-09-29 (jinete en el valle, caballero entre flores, caballero sobre la roca, castillo en la montaña, castillo junto al lago, campamento nocturno). |
| Último mapa | **Estático:** en el último stage, al vencer al jefe no se abre portal y las oleadas siguen (un jefe cada 11 oleadas). |
| Tamaño y forma | **2 a 2.5 veces el área** de la arena actual (900 m² → unos 2 000 m² jugables, ≈ 50 × 42 m), **forma irregular**, piso con relieve, que parezca explorable, con **paredes invisibles** para jugador y enemigos. |
| Orden | **Mar de Flores → Arena actual** (la Arena queda como último stage, estático, hasta que haya más mapas). |
| Ritmo | Confirmado: el jefe pasa de la oleada 10 a la **11** de cada stage. |
| Nombre | **"Mar de Flores"** (subtítulo provisional "Donde empieza el viaje"). |

## 1. Objetivo

1. **Arquitectura de stages.** La escena de la run (`levels/arena/arena.tscn`, que conserva su ruta) deja de tener geometría: carga un **Stage** (escena intercambiable con piso, paredes, luz, cielo y decorado) según una secuencia en datos. Cada stage define sus enemigos, sus jefes y su portal.
2. **Portal.** Al terminar las cartas del jefe de un stage que no es el último, se abre un portal en un punto del mapa. Cuando el jugador lo cruza, la pantalla funde a negro, se cambia el stage, aparece un cartel con el nombre del nuevo stage y empieza la oleada siguiente. Las mejoras, la vida, el nivel de los enemigos y el número de oleada se conservan.
3. **Primer mapa: el Mar de Flores**. Pradera de relieve suave de unos 50 × 42 m (≈ 2 000 m² jugables), irregular, rodeada de colinas, con ruinas, arboleda, arroyo y un castillo en el horizonte.
4. **La arena actual pasa a ser un Stage** (`Arena`), con exactamente la misma geometría y el mismo spawn que hoy.

## 2. Arquitectura

### 2.1 Árbol de nodos

```
Arena (arena.gd)                         ← la run; conserva ruta y nombre para menús y tests
├── StageDirector (stage_director.gd)    ← carga stages, abre el portal, dirige la transición
├── StageRoot (Node3D)                   ← hijo único: el Stage actual
│   └── <Stage instanciado>              ← p. ej. mar_de_flores_stage.tscn
├── Portal (portal.tscn)                 ← uno solo, reusado; oculto y sin monitoreo hasta abrirse
├── EnemyRegistry, Player, DamageNumberPool, EnemyHitFeedback, pools, WaveManager, AttackCoordinator…
└── HUD / pickers / pausa / game over / StageTransition (stage_transition.tscn)
```

`WorldEnvironment`, `DirectionalLight3D`, `Floor` y los cuatro `Wall*` se mueven de `arena.tscn` a `levels/stages/arena/arena_stage.tscn`: cada stage trae su propia luz y su propio ambiente.

### 2.2 Escena de un Stage

```
<Nombre>Stage (Stage, stage.gd)
├── WorldEnvironment               ← cielo, niebla, tonemap
├── Sun (DirectionalLight3D)
├── Terrain (StaticBody3D, capa world)
│   ├── Mesh (MeshInstance3D)
│   └── Shape (CollisionShape3D)   ← HeightMapShape3D, o BoxShape3D en la Arena
├── Bounds (Node3D)                ← paredes invisibles: StaticBody3D + BoxShape3D por tramo, capa obstacles
├── Props (Node3D)                 ← instancias de escenas adaptadoras (árboles, rocas, ruinas…)
│   └── …/StageObstacle (Marker3D) ← círculo de bloqueo para la IA (radio en metros)
├── Scatter (Node3D)               ← MultiMeshInstance3D de pasto y flores, por parcelas
├── Backdrop (Node3D)              ← montañas, castillo y nubes lejanas (sin colisión)
├── PlayerStart (Marker3D)
└── PortalPoint (Marker3D)
```

- `Stage` (`levels/stages/stage.gd`, `class_name Stage extends Node3D`) es la **escena adaptadora del mapa**: todo lo demás del juego habla con el Stage, nunca con sus nodos internos.
- Los `StageObstacle` se recogen **una vez** en `_ready` en un `PackedVector3Array` (x, z, radio) que la IA lee sin copiar.

### 2.3 Resources y datos

| Resource | Archivo | Campos |
|---|---|---|
| `StageData` (nuevo) | `data/stages/<id>/<id>_stage.tres` | `id: StringName`, `display_name: String`, `subtitle: String`, `scene: PackedScene`, `regular_waves: int` (10), `enemy_types: Array[EnemySpawnEntry]`, `boss_challenges: Array[BossChallengeData]`, `portal: PortalData`, `layout: StageLayout` |
| `StageSequence` (nuevo) | `data/stages/stage_sequence.tres` | `stages: Array[StageData]`. Cálculos puros: `count()`, `is_last(index)`, `get_stage(index)` |
| `StageLayout` (nuevo) | `data/stages/<id>/<id>_layout.tres` | `spawn_polygon: PackedVector2Array` (XZ, horario), `max_spawn_distance: float` (0 = sin tope), `spawn_lift: float`. Cálculos puros: `contains(p)`, `bounds()`, `clamp_inside(p)` |
| `PortalData` (nuevo) | `data/stages/portals/<estilo>_portal.tres` | `style_scene: PackedScene`, `open_delay: float` (tras la última carta), `open_duration: float`, `enter_radius: float` |
| `StageTransitionConfig` (nuevo) | `data/stages/stage_transition_config.tres` | `fade_out`, `hold`, `fade_in`, `banner_duration`, `fade_color: Color`, `banner_title_format: String` ("Stage %d") |
| `ObstacleAvoidanceConfig` (nuevo) | `data/enemies/obstacle_avoidance_config.tres` | `lookahead: float`, `margin: float`, `strength: float` |
| `WaveConfig` (cambia) | `data/waves/wave_config.tres` | **Se van** `enemy_types`, `boss_challenges`, `boss_wave_interval` y `spawn_half_extent` (pasan a `StageData` / `StageLayout`). Se quedan los tamaños, cartas, niveles, horda y `min_spawn_distance`. |

Datos iniciales:

- `arena_stage.tres`: `display_name` "Arena", los 5 tipos y los 4 jefes de hoy, `regular_waves` 10, `layout` con el cuadrado ±12 de hoy y `max_spawn_distance` 0.
- `mar_de_flores_stage.tres`: "Mar de Flores", subtítulo "Donde empieza el viaje", los mismos 5 tipos y 4 jefes (se ajustan por stage cuando haya más mapas), `regular_waves` 10, `max_spawn_distance` ≈ 18 m.
- `stage_sequence.tres`: **Mar de Flores → Arena** (decisión del responsable; la Arena es el último stage hasta que haya más mapas).
- `ruin_portal.tres`: estilo "anillo de runas de piedra" (§4).

### 2.4 Interfaz pública

```gdscript
# Stage (levels/stages/stage.gd)
func get_data() -> StageData
func get_player_start() -> Transform3D
func get_portal_transform() -> Transform3D
func height_at(x: float, z: float) -> float          # altura del terreno (0 en la Arena)
func random_spawn_point(rng: RandomNumberGenerator) -> Vector3   # dentro del polígono, fuera de obstáculos, a height_at + spawn_lift
func clamp_inside(point: Vector3) -> Vector3          # al polígono y fuera de obstáculos
func get_obstacles() -> PackedVector3Array            # (x, z, radio), sin copiar

# StageDirector (systems/stage_director.gd)
signal stage_started(data: StageData, index: int)
signal portal_opened
func load_stage(index: int) -> void
func get_stage() -> Stage
func get_index() -> int
func open_portal() -> void                             # la llama WaveManager al cerrar el jefe de un stage no final

# Portal (entities/portal/portal.gd, Area3D)
signal entered
func open(data: PortalData, at: Transform3D) -> void
func close() -> void

# PortalStyle (entities/portal/portal_style.gd, base de cada estilo)
func play_open(duration: float) -> void
func play_idle() -> void

# StageTransition (ui/stage_transition.gd, CanvasLayer)
signal covered                                        # pantalla negra: momento de cambiar el stage
signal finished
func play(title: String, subtitle: String) -> void
func show_banner(title: String, subtitle: String) -> void   # solo el cartel (inicio de la run)

# ObstacleSteering (systems/obstacle_steering.gd, estático y puro)
static func steer(position: Vector3, direction: Vector3, obstacles: PackedVector3Array, config: ObstacleAvoidanceConfig) -> Vector3

# RunState (cambia)
func get_stage_index() -> int
func get_stage_wave() -> int                          # oleada dentro del stage, 1…regular_waves + 1
func set_stage(index: int) -> void                    # reinicia stage_wave
func is_stage_boss_wave(regular_waves: int) -> bool

# WaveManager (cambia)
signal stage_cleared                                  # terminó el jefe (y sus cartas) de un stage no final
func set_stage(stage: Stage) -> void                  # re-empareja pools con los tipos y jefes del stage
```

### 2.5 Lógica interna

**Inicio de la run.** `StageDirector._ready` carga el stage 0 **antes** de que `WaveManager` ofrezca la habilidad (el director va antes en el árbol y la oferta ya es diferida). Coloca al jugador en `PlayerStart`, orienta la cámara y muestra el cartel "Stage 1 · Mar de Flores".

**Oleadas por stage.** `RunState.wave` sigue siendo global (nivel de enemigos, horda, cartas tempranas y baneos no cambian). Se suma `stage_wave`: la oleada es de jefe cuando `stage_wave == regular_waves + 1`. En el último stage, `stage_wave` vuelve a 1 después de cada jefe (un jefe cada 11 oleadas). Los tipos y jefes salen del `StageData` actual.

**Cierre de un stage.** Tras la última carta de la oleada de jefe (o sin cartas: sandbox, Rage o pool vacío), `WaveManager._advance_wave`:
- si el stage **no** es el último: no arranca oleada; emite `stage_cleared`. El director pide la carga en segundo plano del siguiente stage (`ResourceLoader.load_threaded_request`) y, tras `open_delay`, abre el portal en `PortalPoint` (animación de `open_duration`).
- si **es** el último: sigue como hoy (`stage_wave` a 1, siguiente oleada).

**Cruce del portal.** El `Portal` (Area3D, máscara solo `player`, `monitoring` apagado hasta abrirse) emite `entered` cuando el jugador entra. El director bloquea el input de juego, corre `StageTransition.play(...)` y, en `covered`:
1. cierra el portal y libera el stage viejo (`queue_free`; es un cambio de nivel, no una entidad frecuente);
2. instancia el nuevo (ya cargado) en `StageRoot`;
3. mueve al jugador a `PlayerStart` (velocidad a cero), reubica la cámara sin interpolar;
4. `run_state.set_stage(i + 1)`, `wave_manager.set_stage(stage)`;
5. en `finished`: devuelve el input y llama `wave_manager.start_wave()`.

**Spawn.** `_random_point` pasa a `stage.random_spawn_point(rng)`: muestrea en el rectángulo que encierra el polígono (mismo orden de llamadas al RNG que hoy: x y después z) y reintenta si cae fuera del polígono o dentro de un obstáculo. Se acepta si cumple `min_spawn_distance`, `min_spawn_separation` y, si `max_spawn_distance > 0`, si está a menos de esa distancia del jugador (así en un mapa grande los enemigos no aparecen a 50 m). Las hordas y las invocaciones usan `stage.clamp_inside` en vez del cuadrado. La altura es `height_at + spawn_lift` y la gravedad los asienta. **En la Arena, el resultado es idéntico al de hoy.**

**Esquivar obstáculos.** `Enemy.walk` (el único punto por donde caminan todos los comportamientos) aplica `ObstacleSteering.steer` después de la separación del grupo: para cada obstáculo a menos de `lookahead` delante, si la línea de marcha pasa a menos de `radio + margin`, suma un desvío tangencial hacia el lado más cercano, con peso `strength` que crece al acercarse. Es solo cálculo de distancias sobre el array cacheado (Principio V: sin queries físicas ni allocations). Las embestidas, saltos y estocadas (`move_with_velocity`) no esquivan: chocan con la columna y se frenan, lo que el jugador puede usar a su favor. El destino de un salto (Saltador, Titán) se pasa por `stage.clamp_inside` para no caer dentro de una columna.
- Regla de diseño del mapa para que la IA no se trabe: obstáculos convexos (círculos) con **al menos 2.5 m libres entre ellos** dentro del polígono de spawn; no hay rincones cóncavos en la zona de combate. Si más adelante un mapa necesita pasillos o laberintos, se agrega navegación (navmesh) en otra spec.

**Capas de colisión.** Capa nueva `layer_4 = "obstacles"` para las paredes invisibles y las colisiones de props. El jugador y los enemigos la suman a su máscara; el `SpringArm3D` de la cámara **no** (la cámara no salta al pasar detrás de una columna ni tiembla contra el borde invisible). El terreno sigue en `world`, así la cámara nunca entra en una colina.

**Avisos enemigos en pendientes.** Los avisos se dibujan a la altura de los pies del enemigo. El relieve de la zona de combate se limita a `≤ 8°` (§3.2) y, si la captura muestra avisos cortados por el pasto o el terreno, sus materiales pasan a `no_depth_test` (cambio de datos en los `.tres` de aviso).

## 3. El Mar de Flores

### 3.1 Distribución (vista de arriba, norte arriba, ~50 × 42 m jugables)

```
            montañas nevadas ─── castillo sobre la colina (≈ 180 m) ─── nubes enormes
      ~~~~~~~~~~~~~~~~ colinas con árboles (fuera del borde) ~~~~~~~~~~~~~~~~
     /                                                                        \
    /   (arboleda)                     [ RUINAS ]                              \
   |    T  T   o                  ║     ╔════╗     ║         o o               |
   |  T   T  T                    ║     ║ P  ║     ║     (columna caída)       |
   |    T   o                          arco + portal                            |
   |                                                                        ≈≈≈ |
   |         o                 PRADERA CENTRAL (flores, relieve suave)     ≈≈≈   |
   |                                                                   ≈≈≈      |
    \      piedras                                                ≈≈≈  o        |
     \                          ◉ PlayerStart                ≈≈≈  (arroyo)     /
      \___            o                              ≈≈≈≈≈≈≈                  /
          \______________________________________≈≈≈≈_______________________/
                          colinas bajas, arbustos y rocas (borde)
```

- **Pradera central:** la zona de combate principal, abierta, con ondulaciones suaves y flores.
- **Ruinas (norte):** 4 columnas en pie, una caída y un **arco de piedra**. El portal se abre **bajo el arco** (`PortalPoint`): el arco enmarca la salida hacia el castillo del horizonte.
- **Arboleda (oeste):** 6 a 8 árboles y rocas; sus troncos son obstáculos.
- **Arroyo (sureste):** entra por el borde este y sale por el sur. Es **poco profundo y se puede cruzar caminando** (sin efecto de juego); tiene piedras para decorar.
- **Borde:** el terreno sube en colinas, con árboles densos, arbustos y rocas, así el límite se ve natural. Las paredes invisibles van por dentro de esas colinas.
- **Horizonte:** montañas con nieve alrededor, el castillo al norte sobre una colina y nubes de cúmulo gigantes.

### 3.2 Terreno

- **Malla generada offline** (como las armas generadas, Principio II ampliado en §9): un script en `assets/models/environment/mar_de_flores/tools/build_mar_de_flores.gd` arma una grilla de 1 m con alturas definidas por constantes (colinas como campanas + ruido `FastNoiseLite` con semilla fija + el cauce del arroyo + un sendero de tierra), y guarda:
  - `mar_de_flores_terrain.res` (`ArrayMesh`, normales planas, **colores por vértice**: verdes de pasto, tierra del sendero, lecho del arroyo, parches más claros de flores);
  - `mar_de_flores_heights.res` (`HeightMapShape3D` con las mismas alturas, para la colisión y para `height_at`);
  - `mar_de_flores_backdrop.res` (anillo de montañas lejanas: roca abajo y nieve arriba por color de vértice);
  - `mar_de_flores_scatter_<parcela>.res` (`MultiMesh` de pasto y flores por parcelas de 10 × 10 m, así se descartan fuera de cámara y tienen `visibility_range_end`).
- Relieve: dentro del polígono de spawn, **alturas entre −0.8 y +1.2 m y pendiente ≤ 8°**; fuera, las colinas del borde suben hasta ~6 m y el backdrop hasta cientos de metros.
- Un test verifica que el script reproduce los `.res` del repo y que se cumplen los límites de pendiente.

### 3.3 Assets importados (todos CC0)

| Qué | Pack (fuente) | Uso |
|---|---|---|
| Árboles, arbustos, rocas, flores, pasto | [Stylized Nature MegaKit](https://quaternius.com/packs/stylizednaturemegakit.html) (Quaternius, CC0, glTF, texturizado, estilo "Ghibli") | Arboleda, borde, scatter del pasto y las flores, piedras del arroyo |
| Columnas y arco | [Modular Dungeons Pack](https://poly.pizza/bundle/Modular-Dungeons-Pack-HaFPqhAp3w) (Quaternius, CC0, glTF): `Column`, `Arch` | Ruinas, con material de piedra clara y musgo |
| Castillo lejano | [Castle Kit](https://kenney.nl/assets/castle-kit) (Kenney, CC0, glTF): torres, muros, techos cónicos | Silueta del castillo en el horizonte, armada como una escena |

- Cada asset va en `assets/models/environment/<pack>/<asset>/` con su `SOURCE.md` (origen, licencia, fecha, cambios), se usa **solo** vía su escena adaptadora en `levels/stages/props/<asset>.tscn` (pivot en la base, escala en metros, colisión simple: cilindro para troncos y columnas, caja para el arco) y con materiales `.tres` en `materials/environment/`.
- Si al importarlos un pack no encaja con el estilo (se ve con captura), ese elemento se hace con primitivas (Principio II por defecto) y se anota acá.
- **Descargar los packs requiere tu permiso explícito** (te voy a indicar archivo, origen y tamaño antes de bajar cada uno).

### 3.4 Cielo, luz y agua (sin shaders propios)

- **Cielo:** `ProceduralSkyMaterial` (azul intenso arriba, horizonte claro). Las **nubes gigantes** son racimos de `SphereMesh` achatados (cúmulos low-poly) a 250–450 m, con un material mate blanco-crema sombreado por el sol (no blanco puro, reservado). Sin colisión.
- **Luz:** sol cálido de media mañana con sombras solo en el sol (en Android, sombra de menor resolución si la medición lo pide), luz ambiente del cielo, **niebla de distancia** azulada para la perspectiva aérea y un tonemap suave. Todo con nodos y materiales del motor (Principio II: sin shaders personalizados).
- **Agua del arroyo:** una malla plana que sigue el cauce, con `StandardMaterial3D` translúcido verde-azulado, rugosidad baja (refleja el cielo) y un mapa de normales de agua del pack o sin él. Queda **quieta** en esta versión: animarla (ondas, pasto que se mueve con el viento) pide shaders o scripts de material, fuera de esta spec (§10).

### 3.5 Colores (anexo `color-registry.md`)

- El escenario **no usa colores reservados**: nada de blanco puro `Color(1, 1, 1)` (las margaritas y las nubes son crema), ni el gris `Color(0.5, 0.5, 0.5)`.
- **Dentro de la zona de combate**, las flores y el terreno evitan el rojo anaranjado de los avisos (±20° de tono con saturación > 0.3) y el rojo de Rage, para que un aviso en el piso se lea siempre sobre las flores. Se usan azules, violetas, amarillos, rosas y lilas (como las referencias).
- Los tonos del pasto son más apagados que los cuerpos del jugador y los enemigos, para que los personajes resalten.
- **Follaje de los árboles** (pedido del responsable, 2026-09-29): cada árbol tiene la copa entera de un solo color. **70 % verdes**, con tonos claros y oscuros mezclados (materiales `leaves_green_light` y `leaves_green_dark`), y **30 % otoñales**, repartidos entre **amarillo** (`leaves_yellow`, ≈ `Color(0.9, 0.78, 0.28)`) y **naranja ámbar** (`leaves_orange`, ≈ `Color(0.9, 0.6, 0.15)`, tono 36°). El naranja se mantiene a más de 20° de tono del rojo anaranjado de los avisos. El color de cada árbol es fijo, lo asigna el script del mapa con semilla fija (no cambia entre runs) y se reparte por todo el mapa, sin agrupar los otoñales en un solo lugar.
- Portal: **celeste luminoso** `Color(0.45, 0.8, 1.0)` (anillo emisivo y partículas), no reservado.

## 4. Portal (estilo "anillo de runas")

- `entities/portal/portal.tscn`: `Portal` (Area3D con `SphereShape3D` de radio `enter_radius`, capa ninguna, máscara `player`) + un hijo `Style` que se instancia desde `PortalData.style_scene`.
- Estilo 1, `entities/portal/styles/rune_ring_portal.tscn`: un anillo vertical (`TorusMesh`) de piedra clara con runas emisivas celestes, un disco interior translúcido y partículas que suben (`CPUParticles3D` con parámetros en un Resource `PortalStyleConfig`, material `.tres` compartido). Al abrirse, el anillo sale del piso y el disco crece en `open_duration`, con una luz breve (VFX, Principio II).
- Otro estilo = otra escena que extiende `PortalStyle` + otro `PortalData`. Cambiar el estilo de un stage es cambiar un `.tres`.

## 5. Transición y cartel

- `ui/stage_transition.tscn` (`CanvasLayer` sobre el HUD): un `ColorRect` a pantalla completa para el fundido y un cartel centrado con `Stage N` (formato en datos) y el nombre y subtítulo del stage.
- Fundido: `fade_out` → `hold` (se cambia el stage) → `fade_in` y el cartel queda `banner_duration`. Al empezar la run solo se muestra el cartel.
- Durante la transición el jugador no recibe input de juego y no hay enemigos activos. La pausa sigue funcionando.

## 6. Criterios de aceptación (AC1286–AC1325)

**Datos y secuencia**
- **AC1286** `StageSequence.is_last(i)` es verdadero solo para el último índice y `get_stage(i)` devuelve el `StageData` de ese índice.
- **AC1287** `StageLayout.contains(p)` es verdadero dentro del polígono y falso fuera; `clamp_inside(p)` devuelve un punto dentro para cualquier `p`.
- **AC1288** `WaveConfig` ya no tiene `enemy_types`, `boss_challenges`, `boss_wave_interval` ni `spawn_half_extent`, y cada `StageData` del repo declara tipos, jefes, `regular_waves`, escena, portal y layout.

**Run y oleadas**
- **AC1289** Al arrancar la run, el Stage 0 de la secuencia es el único hijo de `StageRoot` y el jugador está en su `PlayerStart`.
- **AC1290** Con `regular_waves = 10`, las oleadas 1–10 del stage son normales y la 11 es de jefe; el jefe sale de `boss_challenges` del stage actual.
- **AC1291** Las oleadas normales solo sacan tipos de `enemy_types` del stage actual (un stage con un solo tipo solo saca ese tipo).
- **AC1292** `RunState.wave` sigue contando en todo la run (la primera oleada del Stage 2 es la 12) y el nivel de enemigos sale de ese número global.
- **AC1293** Tras la última carta del jefe de un stage no final, no empieza ninguna oleada y se emite `stage_cleared` una vez.
- **AC1294** En el último stage, tras el jefe empieza la oleada siguiente como hoy, y el próximo jefe llega 11 oleadas después.
- **AC1295** Sandbox, Rage y "sin cartas disponibles" también llevan al portal al cerrar el jefe de un stage no final.

**Portal y transición**
- **AC1296** El portal se abre en `PortalPoint` `open_delay` segundos después de `stage_cleared`, con el estilo de `PortalData.style_scene`.
- **AC1297** Antes de abrirse, el portal está oculto y con `monitoring` apagado; entrar a su posición no hace nada.
- **AC1298** Con el portal abierto, el jugador dentro de `enter_radius` dispara la transición una sola vez.
- **AC1299** En `covered`: el stage viejo se libera, el nuevo es el único hijo de `StageRoot`, el jugador está en el `PlayerStart` nuevo con velocidad cero y `RunState.get_stage_index()` avanzó 1.
- **AC1300** Tras la transición, la vida, las mejoras, las habilidades, los baneos y el nivel de Rage del jugador son los mismos que antes de cruzar.
- **AC1301** Al terminar la transición empieza la oleada siguiente con los tipos del stage nuevo, y no queda ningún enemigo activo del stage anterior.
- **AC1302** El cartel muestra "Stage N" con el formato de `StageTransitionConfig` y el nombre y subtítulo del `StageData`; al empezar la run muestra el del Stage 1.
- **AC1303** Durante la transición, las acciones de juego (mover, atacar, dash, habilidades) no tienen efecto.
- **AC1304** Cambiar `PortalData.style_scene` por otra escena `PortalStyle` cambia el portal sin tocar código (test con un estilo de prueba).

**Spawn y obstáculos**
- **AC1305** En la Arena, con la misma semilla, las posiciones de spawn de una oleada son idénticas a las de antes de esta spec.
- **AC1306** En el Mar de Flores, todo spawn cae dentro del polígono, fuera de todo obstáculo (radio + margen), a `min_spawn_distance`–`max_spawn_distance` del jugador y a `height_at + spawn_lift`.
- **AC1307** Hordas e invocaciones quedan dentro del polígono (`clamp_inside`), también cerca del borde.
- **AC1308** `ObstacleSteering.steer` no cambia la dirección cuando no hay obstáculo delante y la desvía cuando la línea de marcha cruza un obstáculo a menos de `lookahead`.
- **AC1309** Un enemigo que camina hacia el jugador con una columna en medio llega a menos de su distancia de ataque en un tiempo acotado (test de escena), sin quedar trabado contra ella.
- **AC1310** El destino de un salto de Saltador o Titán nunca cae dentro de un obstáculo.
- **AC1311** Jugador y enemigos colisionan con la capa `obstacles`; el `SpringArm3D` de la cámara no.
- **AC1312** Ni el jugador (caminando, dasheando o saltando) ni los enemigos (caminando, embistiendo o saltando) salen del área encerrada por `Bounds` (test que empuja a cada uno contra el borde).

**Mapa**
- **AC1313** `build_mar_de_flores.gd` reproduce los `.res` del repo (malla del terreno, alturas, backdrop y scatter).
- **AC1314** Dentro del polígono de spawn, las alturas están entre −0.8 y +1.2 m y ninguna pendiente supera 8°.
- **AC1315** `Stage.height_at(x, z)` coincide con la colisión del terreno (raycast de prueba) con un error ≤ 0.05 m.
- **AC1316** Entre obstáculos dentro del polígono de spawn hay al menos 2.5 m libres.
- **AC1317** Ningún material de `materials/environment/` usa blanco puro ni el gris reservado; los de flores, follaje y terreno de la zona de combate no están a ±20° de tono (saturación > 0.3) del rojo de los avisos ni del de Rage; y del total de árboles del Mar de Flores, entre 25 % y 35 % tienen follaje amarillo o naranja (ambos presentes) y el resto verde claro u oscuro.
- **AC1318** Todo asset de `assets/models/environment/` tiene `SOURCE.md` y se usa solo desde su escena adaptadora.
- **AC1319** La Arena como Stage conserva el piso de 30 × 30 m, las cuatro paredes y el spawn ±12 de hoy.

**Verificación visual y rendimiento (manuales)**
- **AC1320** Capturas del Mar de Flores (vista de juego desde el `PlayerStart`, desde las ruinas hacia el castillo, desde el arroyo y cenital) comparadas con las referencias: cielo azul con nubes grandes, flores, ruinas, arroyo, castillo en el horizonte.
- **AC1321** Captura de un aviso de ataque sobre las flores y en una pendiente: se lee completo.
- **AC1322** Video de la apertura del portal y de la transición completa (a velocidad real).
- **AC1323** En el teléfono de pruebas, el Mar de Flores con una oleada completa y horda mantiene la tasa de cuadros de la Arena o se ajustan densidad y distancias de visibilidad del scatter según la medición (Principio V).
- **AC1324** Smoke test: run desde el menú hasta el jefe del Stage 1 (sandbox para acortar), cruce del portal y primera oleada del Stage 2, sin errores ni warnings nuevos.
- **AC1325** Suite completa en verde (tests viejos adaptados sin cambiar lo que verifican, anotados en §11).

## 7. Tests

- `test/resources/stage_sequence_test.gd`, `stage_layout_test.gd` (AC1286–AC1288).
- `test/systems/stage_director_test.gd` (AC1289, AC1293–AC1304), `wave_manager_stage_test.gd` (AC1290–AC1292, AC1305–AC1307), `obstacle_steering_test.gd` (AC1308).
- `test/levels/mar_de_flores_test.gd` (AC1309–AC1319).
- Los tests de `test/levels/` que precargan `arena.tscn` suponen piso plano en el origen: si alguno falla por el relieve o los obstáculos del Mar de Flores, se le da una secuencia de prueba con solo la Arena (`test/data/arena_only_sequence.tres`), sin cambiar lo que verifica.

## 8. Rendimiento (Principio V)

- El stage se instancia una vez por cambio, detrás de la pantalla negra y con carga en segundo plano iniciada al abrirse el portal.
- La IA de obstáculos es cálculo de distancias sobre un array cacheado: O(enemigos × obstáculos cercanos), sin queries físicas.
- Colisiones estáticas simples: `HeightMapShape3D` para el terreno, cilindros y cajas para props y bordes. Nada de trimesh.
- Scatter en `MultiMesh` por parcelas con `visibility_range_end`; backdrop y nubes sin sombras propias.

## 9. Enmienda a la constitución (MINOR 6.2.0)

Principio II, viñeta nueva **"Escenarios (stages)"**:

> Un stage es una escena adaptadora (`Stage`) que agrupa el terreno, los límites, la luz, el ambiente y el decorado de un mapa. Puede usar: modelos importados de escenario (vegetación, rocas, ruinas, edificios lejanos) con las reglas de assets importados; un **terreno y un fondo generados offline** por un script en `tools/` de la carpeta del asset (alturas por constantes y semilla fija, colores por vértice, `ArrayMesh` + `HeightMapShape3D` guardados como `.res`, con un test que verifica que el script los reproduce; nunca en runtime); **scatter** de vegetación en `MultiMesh` generados del mismo modo; nubes y decorado lejano con primitivas; y cielo, niebla y luz con los recursos del motor (`ProceduralSkyMaterial`, `Environment`). Siguen prohibidos los shaders personalizados. El escenario no usa colores reservados y, dentro de la zona de combate, evita los tonos de los avisos y de Rage.

También: `color-registry.md` suma la fila "Escenario" y el celeste del portal; la tabla de capas de colisión suma `obstacles`.

## 10. Fuera de alcance (posibles ampliaciones)

- Mapa propio por jefe (la secuencia podrá tener un `boss_scene` opcional por stage).
- Navegación con navmesh para mapas con pasillos o rincones.
- Viento en el pasto, agua animada (pide enmendar "sin shaders").
- Día/noche por stage (la referencia del campamento nocturno queda para otro mapa).
- Elegir stage inicial en el sandbox, y mostrar el stage alcanzado en el game over.
- Mapas 2 en adelante.

## 11. Notas de implementación

### Fase A (2026-09-29)

**Cambios de nombre e interfaz respecto de §2** (sin cambio de comportamiento):
- La clase `Stage` se llama **`StageMap`** (`levels/stages/stage_map.gd`): `Stage` chocaba con los enums `Stage` que ya existen dentro de `WindCutVfx` y `BossBehavior`. Donde §2 dice `Stage`, léase `StageMap`.
- `StageDirector.get_index()` se llama **`get_stage_index()`**: `get_index()` pisa un método nativo de `Node`.
- `WaveManager.set_stage(stage, is_last)` recibe también si el stage es el último (así el `WaveManager` no depende de la secuencia).
- `StageData.is_boss_wave(stage_wave)` es el cálculo puro; `RunState.is_stage_boss_wave(regular_waves)` lo usa con el contador del run.
- **Portal sin cuerpo físico:** en vez de un `Area3D`, el portal mide cada cuadro la distancia al jugador (Principio V: "no se usan cuerpos físicos donde basta un cálculo de distancia"). Mismo radio (`enter_radius`) y mismo comportamiento.
- **`StageTransition` es un `Control`** dentro del `CanvasLayer` "UI", entre el HUD y los pickers (no un `CanvasLayer` propio): así el fundido tapa el HUD pero no el menú de pausa.
- **Input durante la transición:** el director llama `Player.begin_hold(duración del fundido)`, el mismo bloqueo que usan los agarres del Verdugo. No se pausa el árbol, así la pausa sigue funcionando.
- **Sin carga en segundo plano:** `StageData.scene` es un `PackedScene`, así que la escena de cada stage ya se carga con la secuencia; solo la instanciación ocurre detrás del fundido. Si en la Fase B el Mar de Flores tarda en cargar el menú, se cambia a una ruta con carga en hilo.
- Las invocaciones de los bosses buscan su pool entre **todos** los pools de la run (no solo los tipos del stage), así una Colmena puede invocar un tipo que su stage no saca en oleadas normales.
- La secuencia del repo tiene por ahora **solo la Arena** (el juego se ve y se juega igual que antes, salvo el jefe en la oleada 11). Los tests del portal usan `test/data/two_arena_sequence.tres` (Arena → Arena). El Mar de Flores entra primero en la Fase B.

**Tests viejos adaptados** (verifican lo mismo, con el jefe en la oleada 11 y los datos en el stage):
- `boss_challenge_run_test.gd`: AC146 (el jefe es la oleada 11 del stage; antes "cada 10"), AC151 (el jefe llega en la oleada 11, a su nivel 6), AC156 ("Oleada 11 · …" y luego "Oleada 12"); tipos y jefes leídos de `arena_stage.tres`.
- `arena_waves_test.gd`: AC19 (el cuadrado de spawn sale del layout de la Arena), AC269 (el jefe sin mejoras llega en la oleada 11), AC415 (tipos del stage).
- `arena_horde_test.gd`: AC1150 (cuadrado del layout), AC1154 (la oleada de jefe se marca con `stage_wave`).
- `wave_config_test.gd`: AC1122 (`picks_for_wave(wave, boss)`), AC1123 (10 oleadas normales y el jefe), AC1134 (tipos del stage).
- `horde_config_test.gd`: AC1152 (el Esbirro no está en los tipos del stage).

**Fallos que ya existían** (no son de esta spec y no se tocaron): `arena_waves_test` AC22 y AC23 esperan el daño base 15 y la vida 100 del Guerrero, que hoy son 20 y 200 (commit 16c855a); `boss_challenge_run_test` AC155 aplica Contragolpe y Duelo una vez y espera que salgan del pool, pero desde `riposte-levels` tienen varios niveles.

## Plan de implementación

Cada paso deja el juego funcionando. Los tests y smoke tests los corre `godot-tester`; las capturas y videos, `godot-capture`.

**Fase A: arquitectura (sin mapa nuevo, todo sigue viéndose como hoy)**
1. Enmienda 6.2.0 en `constitution.md`, `constitution-history.md` y `color-registry.md`; reservar AC1286–AC1325 en `ac-registry.md` y `CLAUDE.md`.
2. Resources nuevos (`StageData`, `StageSequence`, `StageLayout`, `PortalData`, `StageTransitionConfig`, `ObstacleAvoidanceConfig`) con sus tests.
3. `Stage` base y `arena_stage.tscn` (geometría movida desde `arena.tscn`); `StageDirector` + `StageRoot` en la run; `enemy_types`, jefes y spawn pasan de `WaveConfig` al stage. Secuencia provisional: solo la Arena. Correr la suite: tiene que seguir en verde (AC1305, AC1319).
4. `RunState.stage_wave`, cierre de stage, `Portal` + estilo "anillo de runas", `StageTransition` y cartel. Secuencia provisional de prueba: Arena → Arena. Tests AC1289–AC1304 y video del portal.

**Fase B: el Mar de Flores**
5. Pedirte permiso y descargar los tres packs; importar solo los modelos usados, `SOURCE.md`, escenas adaptadoras en `levels/stages/props/` y materiales en `materials/environment/`.
6. Capa `obstacles`, `ObstacleSteering` en `Enemy.walk`, `clamp_inside` en saltos, hordas e invocaciones (AC1306–AC1312).
7. `build_mar_de_flores.gd`: terreno, alturas, backdrop y scatter; test de reproducción y de pendientes (AC1313–AC1315).
8. Armar `mar_de_flores_stage.tscn`: layout de §3.1, props y obstáculos, bordes invisibles, arroyo, castillo, nubes, cielo y luz. Capturas contra las referencias y ajuste (AC1316–AC1321). Te las muestro antes de seguir.
9. Secuencia final, smoke test completo, medición en el teléfono, `where-to-tune.md` (viñeta "Stages"), `specs/README.md`, checklist de la constitución y estado **Implementada**.

### Fase B (2026-09-29)

**Assets:**
- Los tres packs se bajaron el 2026-09-29: el Stylized Nature MegaKit y el Modular Dungeons Pack como `.glb` sueltos desde Poly Pizza (la descarga del autor en itch.io no es directa) y el Castle Kit como zip de kenney.nl.
- **No se guardan los `.glb` en el repo.** Cada uno traía sus texturas de 1024 px embebidas y repetidas (34 MB para 22 modelos). Se guardan **mallas derivadas** (`meshes/*.res`, sin materiales) y las texturas una sola vez a 512 px, con `stylized_nature/tools/extract_environment_assets.gd` (ver cada `SOURCE.md`). Son 2,6 MB en total.
- Texturas derivadas: `leaves_mask.png` (hojas en blanco, el color lo pone el material de cada árbol) y `flowers.png` (los pétalos rojos y salmón pasan a magenta: caían a menos de 20° del rojo de los avisos).
- No se usan los árboles retorcidos (16 m y 3 MB cada uno) ni el Arch Door. Las mallas del castillo se usan dentro de la escena del mapa: el `StageMap` es la escena adaptadora del mapa (Principio II 6.2.0).

**Mapa:**
- Todo el Mar de Flores sale de `MarDeFloresBuilder`: forma, relieve, ubicación de los 31 props, bosque del borde (150 árboles), flores y pasto (7 800 instancias en 3 × 3 parcelas de 30 m con `visibility_range_end`) y nubes.
- La escena del stage también la arma el script (`build_mar_de_flores.gd`). Hay que correrlo **sin `--headless`**: con el renderer falso los `MultiMesh` se guardan sin instancias.
- El colorido de flores y pasto sale de las texturas del pack, no de colores de instancia. El pasto usa color de instancia para variar el tono.
- El naranja otoñal quedó en **`Color(0.9, 0.6, 0.15)` (36°)**: el primero, `Color(0.88, 0.52, 0.16)` (30°), estaba a 17° del rojo de los avisos.
- El color del terreno es **por vértice** (bordes suaves del sendero); las normales siguen planas.
- El arco de las ruinas va a escala ×1,7 (hueco de 3,7 m) para que entre el anillo del portal (3,4 m).

**Cambios respecto de §2:**
- El esquive de obstáculos vive en `Enemy.walk` (`ObstacleSteering`) con los obstáculos que pasa el `WaveManager` en cada spawn (`Enemy.set_obstacles`).
- El destino del salto del **Saltador** se aleja de los obstáculos (`Enemy.clear_of_obstacles`). El Titán no salta (su golpe de área no necesita ajuste), así que AC1310 cubre solo al Saltador.
- AC1309 (rodear una columna) se verifica con una caminata cinemática del steering, no con física; el smoke test y el video muestran a los enemigos en el mapa real.
- AC1312 (nadie sale del mapa) se verifica por geometría: un muro por tramo del borde, más largo que el tramo y más alto que un salto.
- **AC1295 cambió de alcance:** mientras se implementaba, `sandbox-arena-control.md` (otra sesión) sacó las oleadas del sandbox, así que el sandbox ya no llega al portal. El test cubre el camino sin cartas (Rage).
- El cartel lleva un contorno oscuro (`outline_color`/`outline_size` en `StageTransitionConfig`) porque sobre el cielo claro no se leía.

**Tests viejos adaptados en la Fase B:**
- `arena_waves_test`, `arena_horde_test` y `boss_challenge_run_test` corren con la secuencia de solo-Arena (`test/data/arena_only_sequence.tres`, vía `test_world.arena_only()`), porque verifican el cuadrado de spawn de la Arena y el jefe seguido de la oleada siguiente.
- `stage_run_test` AC1294 usa la misma secuencia.

**Verificación visual:**
- Maqueta de primitivas y capturas del mapa (juego, ruinas hacia el castillo, arroyo, panorámica, arboleda, cenital).
- Video del juego real en el Mar de Flores con la primera oleada: los avisos naranjas se leen sobre las flores, aunque algunas flores asoman por encima. Se decidió no poner `no_depth_test` por ahora.
- Video del portal: se abre bajo el arco, el jugador entra, funde a negro y aparece el cartel "Stage 2 · Arena".

**Pendiente del responsable:**
- **AC1323:** medir en el teléfono. Si baja la tasa de cuadros, se reducen los conteos de `SCATTER`/`FOREST_COUNT` del builder o `visibility_range_end`, y se regenera.
- Probar el mapa jugando.

### Checklist de la constitución (6.2.0)

- [x] **Identidad (I):** progresión (un viaje por stages) y supervivencia (obstáculos que se usan para posicionarse).
- [x] **Arte (II):** assets en `assets/models/environment/<pack>/` con `SOURCE.md`, usados vía escenas adaptadoras (`levels/stages/props/`, `StageMap`); terreno y scatter generados offline con test de reproducción; sin shaders propios; sin colores reservados y con los tonos de aviso y Rage evitados en la zona de combate (AC1317); materiales `.tres` compartidos.
- [x] **Datos (III):** stages, layout, portal, transición y esquive en Resources; las formas del mapa son constantes del script generador (como los modelos generados).
- [x] **GDScript (IV):** tipado estricto, `_process` delgados (`advance()`).
- [x] **Performance (V):** esquive por distancias sobre un array cacheado, portal por distancia (sin `Area3D`), colisiones simples (height map, cilindros y cajas), stage instanciado solo detrás del fundido, scatter en `MultiMesh` por parcelas. Medición en el teléfono pendiente (AC1323).
- [x] **Input (VI):** sin input nuevo; durante el fundido el jugador queda retenido (`begin_hold`) y la pausa sigue disponible.
- [x] **Combate (VII):** no cambia. Las embestidas chocan con las columnas.
- [x] **Animación (VIII):** no aplica (sin clips nuevos). El portal es un VFX con video.
- [x] **Calidad:** las suites de la spec y las adaptadas están en verde, salvo tres fallos previos ajenos (AC22, AC23, AC155). El smoke test corre sin errores.
