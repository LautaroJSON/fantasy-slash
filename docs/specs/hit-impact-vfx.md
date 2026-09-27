# Impacto de golpe (VFX en el punto de contacto)

**Estado:** Implementada · **Constitución:** aprobada contra 4.17.0; enmienda aplicada como **4.21.0** (MINOR, §8) · **ACs:** AC931–AC942

## 1. Pilar (Principio I)

**Combate:** hace el golpe más legible. Hoy el impacto se siente (hit lag, empuje, shake) pero no se *ve dónde* ocurre. Un fragmento de luz en el punto donde la hoja cruza al enemigo confirma qué enemigo recibió el golpe y desde dónde, algo clave con muchos enemigos en pantalla.

## 2. Alcance

- **Sí:** golpes del combo básico (`AttackComponent.enemy_hit`) y golpes de **Envainar** y **Giro** (incluido el corte del dash del Giro), vía `AbilityComponent.enemy_hit`.
- **No (por ahora):** Tajo aéreo del Berserker, Estocada y Golpe veloz del Guerrero, flash blanco del cuerpo del enemigo, golpes que recibe el jugador, variantes por clase, congelar el efecto durante el hit lag.
- Mismo efecto para todas las clases.

## 3. Qué se ve

Estilo "mágico", tipo BDO: luz, sin sangre. En el punto de impacto, durante `duration` (0.18 s):

1. **Fragmento de luz:** un elipsoide (`SphereMesh` de diámetro 1, escalado) fino y alargado, con las puntas afinadas como un trazo de luz, orientado según el **movimiento de la punta del arma**. Lleva un **halo** hijo, `shard_halo_scale` veces más ancho y más transparente (`shard_halo_transparency`). En `grow_time` se estira de 0 a `shard_length` y después se afina (`shard_width` → 0) y se desvanece.
2. **Destello:** una `SphereMesh` que llega a `flash_radius` junto con el fragmento (en `grow_time`) y se desvanece durante toda la duración, más una `OmniLight3D` breve (`flash_energy`, `flash_range`) que se apaga en el mismo tiempo.
3. **Chispas:** `CPUParticles3D` one-shot (`spark_amount` cajitas de `spark_size`), que salen en la dirección del corte con `spark_spread`, sin gravedad y desvaneciéndose en `spark_lifetime`.

**Crítico:** todo se escala por `crit_scale` y se suma un segundo fragmento (con su halo) cruzado a `crit_cross_angle`, lo que forma una estrella. Usa el **mismo blanco** (ver §12, desvío 1).

**Material:** `materials/vfx/hit_impact_material.tres`, blanco `Color(1, 1, 1)`, unshaded, blend aditivo, alpha ≤ 0.5 y `no_depth_test`. Se dibuja por encima de todo para que el cuerpo del jugador, que queda entre la cámara y el enemigo, no lo tape (§12, desvío 3).

## 4. Punto de impacto y orientación

El daño se decide por sector lógico, así que el punto se **calcula** al emitirse `enemy_hit`:

1. `blade_point` = punto del segmento `TrailBase`→`TrailTip` del arma equipada más cercano, en horizontal, al eje vertical del enemigo (el medio de la hoja si está vertical).
2. Dirección horizontal desde el eje del enemigo hacia `blade_point`. Si es casi nula, se usa la dirección hacia el jugador.
3. **Impacto** = eje del enemigo + esa dirección × `enemy.get_hit_padding()` (su radio), a la altura de `blade_point` limitada a `[enemy.y + min_height, enemy.y + max_height]`.

**Orientación:** el efecto **mira a la cámara** (Z local = dirección del impacto a la cámara activa; sin cámara, la dirección del paso 2). La dirección del corte (X local) es la velocidad de la punta (`TrailTip` ahora − `TrailTip` del cuadro de física anterior, guardado en un miembro con `process_physics_priority` alta) proyectada sobre ese plano. Si su largo es menor que `min_tip_speed`, el fragmento queda horizontal: `UP × facing`.

## 5. Estructura de nodos

```
Player (player.tscn)
└── HitImpactVfx (Node, components/vfx/hit_impact_vfx_host.gd)
      └── Impact0 … Impact15 (HitImpactVfx, Node3D top_level, creados en _ready)
            ├── Shard (elipsoide) └── Halo
            ├── CrossShard (elipsoide, solo crítico) └── Halo
            ├── Flash (SphereMesh) + OmniLight3D
            └── Sparks (CPUParticles3D)
```

- `HitImpactVfxHost`: `@export attack: AttackComponent`, `@export abilities: Array[AbilityComponent]` (los dos slots, igual que la estela), `@export visual: Node3D`, `@export config: HitImpactVfxConfig`, `@export glow_material`. Se conecta a los `enemy_hit`. En `_physics_process` solo guarda la posición de la punta.
- `HitImpactVfx`: un efecto con sus nodos creados una vez. Reproduce, avanza y se oculta solo; las chispas terminan por su cuenta.
- `Player._equip_weapon()` llama a `hit_impact_vfx.attach(base, tip)` con los mismos marcadores que la estela.

## 6. Resources y datos

- `resources/hit_impact_vfx_config.gd` → `HitImpactVfxConfig`: `pool_size`, `duration`, `grow_time`, `shard_length`, `shard_width`, `shard_thickness`, `shard_start_transparency`, `shard_halo_scale`, `shard_halo_transparency`, `flash_radius`, `flash_start_transparency`, `flash_energy`, `flash_range`, `spark_amount`, `spark_size`, `spark_lifetime`, `spark_speed_min`, `spark_speed_max`, `spark_spread`, `min_height`, `max_height`, `min_tip_speed`, `crit_scale`, `crit_cross_angle`.
- `data/player/hit_impact_vfx_config.tres`: pool de 16; 0.18 s (crece en 0.04 s); fragmento de 1.8 × 0.1 m con halo ×4 (transparencia 0.75); destello de 0.45 m; 10 chispas; altura entre 0.5 y 1.6 m; crítico ×1.4 cruzado a 70°. Ajustados con capturas.
- `AbilityData.shows_hit_impact: bool`: `true` en `spin.tres` y `sheathe.tres`. El host ignora los golpes de habilidades con `false`.

## 7. Interfaz pública

```gdscript
# HitImpactVfxHost
func attach(base: Node3D, tip: Node3D) -> void
func show_impact(enemy: Enemy, is_crit: bool) -> void
func get_active_count() -> int
func get_pool() -> Array[HitImpactVfx]
static func impact_point(enemy_pos, radius, blade_a, blade_b, player_pos, min_height, max_height) -> Vector3
static func impact_normal(enemy_pos, blade_a, blade_b, player_pos) -> Vector3
static func closest_blade_point(enemy_pos, blade_a, blade_b) -> Vector3
static func cut_direction(tip_motion, normal, min_speed) -> Vector3

# HitImpactVfx
func setup(config, glow_material) -> void
func play(point: Vector3, normal: Vector3, slash_dir: Vector3, is_crit: bool) -> void
func advance(delta: float) -> void
func is_playing() -> bool
func is_crit() -> bool
func get_elapsed() -> float
```

**Pool:** toma el primer efecto libre; si están todos activos, reutiliza el de mayor `get_elapsed()`. Nunca hay `instantiate()`/`queue_free()` después de `_ready` (Principio V).

## 8. Enmienda 4.21.0 (MINOR), aplicada

Principio II, tabla de colores, fila nueva: *Impacto de golpe (combo básico, Envainar y Giro)*: elipsoides y partículas en **blanco** `Color(1, 1, 1)`, unshaded, aditivo, alpha ≤ 0.5, sin prueba de profundidad. El párrafo del blanco compartido suma el impacto de golpe entre los VFX translúcidos. El crítico usa el mismo blanco, así que no se registra ningún color nuevo.

## 9. Criterios de aceptación

- **AC931** `HitImpactVfxConfig` existe, todos sus campos son > 0 en el `.tres`, y los scripts no tienen literales tuneables (solo `0.0`, `0.5`, `1.0`, `2.0` estructurales y constantes).
- **AC932** Un golpe del combo que alcanza N enemigos deja N efectos activos, cada uno sobre la silueta de su enemigo.
- **AC933** `impact_point` devuelve un punto a distancia `radius` (±0.01) del eje del enemigo, del lado de la hoja.
- **AC934** La altura del impacto sigue a la hoja dentro de `[min_height, max_height]` sobre los pies del enemigo y se limita fuera de ese rango.
- **AC935** Con la hoja sobre el eje del enemigo, el impacto cae del lado del jugador.
- **AC936** El fragmento se alinea con el movimiento de la punta proyectado (ángulo < 5°). Bajo `min_tip_speed` queda horizontal y perpendicular a la dirección de vista. El efecto mira a la cámara activa.
- **AC937** Un golpe crítico (también desde el combo) escala por `crit_scale` y muestra el fragmento cruzado a `crit_cross_angle`. Uno normal lo oculta. Los dos usan el material blanco.
- **AC938** Los golpes de Envainar y del Giro (incluido su corte del dash) muestran impacto. Los de una habilidad con `shows_hit_impact = false` y los del Tajo aéreo no.
- **AC939** La cantidad de hijos del pool no cambia después de `_ready`, ni al pasar `pool_size`. Con el pool lleno, se reutiliza el efecto más viejo.
- **AC940** El fragmento llega a su largo y ancho en `grow_time`. Pasada `duration`, fragmentos, destello y luz están ocultos, la luz queda en 0 y `is_playing()` es false.
- **AC941** El material es blanco, unshaded, aditivo y translúcido, con alpha ≤ 0.5.
- **AC942** Smoke: el proyecto y `arena.tscn` corren 300 cuadros sin errores. Capturas de golpes normales y críticos de las 3 clases, desde la cámara de juego y con una cámara lateral fija.

Tests: `test/components/vfx/hit_impact_vfx_test.gd` (AC931–AC937, AC939–AC941) y `test/components/vfx/hit_impact_abilities_test.gd` (AC938).

## 10. Plan (ejecutado)

1. `HitImpactVfxConfig` + `.tres` + material; `AbilityData.shows_hit_impact` en `spin.tres` y `sheathe.tres`.
2. `HitImpactVfx` (un efecto).
3. `HitImpactVfxHost`: funciones puras, orientación, pool y conexiones.
4. Enganche en `player.tscn` y `Player._equip_weapon()`.
5. Enmienda en `constitution.md` (4.21.0).
6. Capturas, ajuste de valores y smoke.
7. Tests, checklist, CLAUDE.md.

## 11. Checklist de review

- [x] **Identidad (I):** combate, legibilidad del golpe.
- [x] **Arte (II):** primitivas (`SphereMesh`, `BoxMesh`) y `CPUParticles3D`, `OmniLight3D` breve, material `.tres` compartido, sin texturas ni shaders; color blanco registrado en la tabla (4.21.0).
- [x] **Datos (III):** todo en `HitImpactVfxConfig` y `AbilityData.shows_hit_impact`; ningún Resource se muta.
- [x] **GDScript (IV):** tipado estricto, `_process`/`_physics_process` de una línea.
- [x] **Performance (V):** pool creado en `_ready`, sin allocations por cuadro (el host solo guarda un `Vector3`); la cámara se consulta una vez por golpe, no por cuadro.
- [x] **Input (VI):** sin input nuevo.
- [x] **Combate (VII):** no toca `Engine.time_scale` ni los tiempos del golpe.
- [x] **Calidad:** 16 tests de la spec + suites vecinas (combo, hitstop, Envainar) en verde (62 casos); smoke del proyecto y de la arena sin errores. `spin_test.gd` AC188 falla por el cambio de `tick_interval` (0.8) de `spin-visual-rework.md`, ajeno a esta spec.

## 12. Notas de implementación (desvíos aprobados durante el cierre)

1. **Crítico en blanco, no ámbar.** Mientras se implementaba, la 4.18.0 pasó los números críticos a blanco (el ámbar dejó de significar "crítico") y la 4.18.1 dio a Estallido un naranja casi igual. El usuario eligió blanco: el crítico se distingue por tamaño y cruz. Se eliminó `hit_impact_crit_material.tres`.
2. **Elipsoide con halo en vez de `BoxMesh`.** En las capturas, la caja se veía como un palo. El elipsoide afina las puntas y el halo da el brillo, con primitivas y sin texturas. Se sumaron `shard_halo_scale` y `shard_halo_transparency`.
3. **Mira a la cámara y se dibuja por encima.** Orientado según la superficie del enemigo, desde la cámara de juego se veía de canto o quedaba tapado por el jugador. Ahora el efecto se orienta hacia la cámara, conservando la dirección del corte proyectada, y el material usa `no_depth_test`.
4. **Destello:** llega a su radio en `grow_time` (antes crecía durante toda la duración y casi no se veía).
5. `abilities` es un array (los dos slots), como en `WeaponTrail`.
