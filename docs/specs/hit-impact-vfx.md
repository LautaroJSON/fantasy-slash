# Impacto de golpe (VFX en el punto de contacto)

**Estado:** Propuesta · **Constitución:** 4.17.0 → 4.18.0 (enmienda MINOR, §8) · **ACs:** AC931–AC942

## 1. Pilar (Principio I)

**Combate:** hace el golpe más legible. Hoy el impacto se siente (hit lag, empuje, shake) pero no se *ve dónde* ocurre. Un fragmento de luz en el punto donde la hoja cruza al enemigo confirma qué enemigo recibió el golpe y desde dónde, algo clave con muchos enemigos en pantalla.

## 2. Alcance

- **Sí:** golpes del combo básico (`AttackComponent.enemy_hit`) y golpes de **Envainar** y **Giro** (incluido el corte del dash del Giro), vía `AbilityComponent.enemy_hit`.
- **No (por ahora):** Tajo aéreo del Berserker, Estocada y Golpe veloz del Guerrero, flash blanco del cuerpo del enemigo, golpes que recibe el jugador, variantes por clase, congelar el efecto durante el hit lag.
- Mismo efecto para todas las clases.

## 3. Qué se ve

Estilo "mágico", tipo BDO: luz, sin sangre. En el punto de impacto, durante `duration` (~0.18 s):

1. **Fragmento de luz:** un `BoxMesh` fino y alargado (la "raja" del corte), orientado según el **movimiento de la punta del arma** en ese instante y apoyado sobre la superficie del enemigo. En `grow_time` se estira de 0 a `shard_length`, y después se afina (`shard_width` → 0) y se desvanece.
2. **Destello:** una `SphereMesh` que crece hasta `flash_radius` y se desvanece, más una `OmniLight3D` breve (`flash_energy`, `flash_range`) que se apaga en el mismo tiempo.
3. **Chispas:** `CPUParticles3D` one-shot (`spark_amount` cajitas de `spark_size`), que salen en la dirección del corte con `spark_spread`, sin gravedad y desvaneciéndose en `spark_lifetime`.

**Crítico:** todo se escala por `crit_scale`, se suma un segundo fragmento cruzado a `crit_cross_angle` (una "X") y se usa el material ámbar.

Colores: blanco aditivo unshaded (alpha ≤ 0.5) para el golpe normal; **ámbar** `Color(1, 0.55, 0.1)` aditivo unshaded (alpha ≤ 0.5) para el crítico, el mismo ámbar de los números de daño críticos (requiere la enmienda del §8).

## 4. Punto de impacto (cruce hoja–enemigo)

El daño se decide por sector lógico, así que el punto se **calcula** al emitirse `enemy_hit`:

1. `blade_point` = punto del segmento `TrailBase`→`TrailTip` del arma equipada más cercano al eje vertical del enemigo.
2. Dirección horizontal desde el eje del enemigo hacia `blade_point`. Si es casi nula, se usa la dirección hacia el jugador.
3. **Impacto** = eje del enemigo + esa dirección × `enemy.get_hit_padding()` (su radio), a la altura de `blade_point` limitada a `[enemy.y + min_height, enemy.y + max_height]`.

Así, un golpe bajo pega abajo, uno alto pega arriba, y el efecto queda siempre sobre la silueta del lado de la hoja.

**Orientación del fragmento:** la velocidad de la punta = `TrailTip` ahora − `TrailTip` en el cuadro de física anterior (guardado en un miembro, sin allocations). Se proyecta sobre el plano tangente a la superficie. Si su largo es menor que `min_tip_speed`, el fragmento queda horizontal y perpendicular a la dirección jugador→enemigo.

## 5. Estructura de nodos

```
Player (player.tscn)
└── HitImpactVfx (Node, hit_impact_vfx_host.gd)   ← nuevo
      [pool de `pool_size` HitImpactVfx (Node3D, top_level), creados en _ready]
```

- `HitImpactVfxHost` (`components/vfx/hit_impact_vfx_host.gd`): `@export attack: AttackComponent`, `@export abilities: AbilityComponent`, `@export config: HitImpactVfxConfig`, `@export glow_material`, `@export crit_material`. Se conecta a los dos `enemy_hit`. En `_physics_process` solo guarda la posición de la punta.
- `HitImpactVfx` (`components/vfx/hit_impact_vfx.gd`): un efecto (fragmento, fragmento cruzado, destello, luz y chispas), con los nodos creados una vez. Reproduce, avanza y se oculta solo.
- `Player._equip_weapon()` llama a `hit_impact_vfx.attach(base, tip)` con los mismos marcadores que la estela.

## 6. Resources y datos

- `resources/hit_impact_vfx_config.gd` → `class_name HitImpactVfxConfig extends Resource`: `pool_size`, `duration`, `grow_time`, `shard_length`, `shard_width`, `shard_thickness`, `flash_radius`, `flash_start_transparency`, `flash_energy`, `flash_range`, `spark_amount`, `spark_size`, `spark_lifetime`, `spark_speed_min`, `spark_speed_max`, `spark_spread`, `min_height`, `max_height`, `min_tip_speed`, `crit_scale`, `crit_cross_angle`.
- `data/player/hit_impact_vfx_config.tres`: valores iniciales (pool 16, duración 0.18 s, fragmento de 1.4 × 0.08 m, destello de 0.35 m, 10 chispas, altura entre 0.5 y 1.6 m, crítico ×1.4 y cruce a 70°). Se ajustan con capturas.
- `AbilityData.shows_hit_impact: bool`: `true` en `spin.tres` y `sheathe.tres`. El host ignora los golpes de habilidades con `false`.
- `materials/vfx/hit_impact_material.tres` (blanco) y `materials/vfx/hit_impact_crit_material.tres` (ámbar): unshaded, blend aditivo, alpha ≤ 0.5, sin sombras.

## 7. Interfaz pública

```gdscript
# HitImpactVfxHost
func attach(base: Node3D, tip: Node3D) -> void
func show_impact(enemy: Enemy, is_crit: bool) -> void      # also used by tests
func get_active_count() -> int
static func impact_point(enemy_pos: Vector3, radius: float, blade_a: Vector3, blade_b: Vector3,
		player_pos: Vector3, min_height: float, max_height: float) -> Vector3   # pure

# HitImpactVfx
func play(point: Vector3, normal: Vector3, slash_dir: Vector3, is_crit: bool) -> void
func advance(delta: float) -> void
func is_playing() -> bool
```

**Lógica del pool:** toma el primer efecto libre; si están todos activos, reutiliza el más viejo. Nunca se hace `instantiate()`/`queue_free()` después de `_ready` (Principio V).

## 8. Enmienda propuesta: 4.18.0 (MINOR)

Principio II, tabla de colores, nueva fila:

| Impacto de golpe (combo, Envainar y Giro): fragmento de luz, destello y chispas en el punto de contacto | `BoxMesh` / `SphereMesh`, partículas | **Blanco** `Color(1, 1, 1)`; **crítico ámbar** `Color(1, 0.55, 0.1)`; unshaded, aditivo, alpha ≤ 0.5 |

Además se amplía el texto de los colores compartidos: el blanco también lo usa el impacto de golpe (translúcido, décimas de segundo), y el ámbar pasa a compartirse entre los números de daño críticos y el impacto crítico (los dos significan "crítico" y aparecen juntos). Historial: *4.18.0: VFX de impacto de golpe en el punto de contacto; el ámbar del crítico se comparte con su impacto (ver `hit-impact-vfx.md`).*

## 9. Criterios de aceptación

- **AC931** `HitImpactVfxConfig` existe, `hit_impact_vfx_config.tres` tiene todos sus campos > 0, y ni `hit_impact_vfx.gd` ni `hit_impact_vfx_host.gd` tienen literales tuneables.
- **AC932** Un golpe del combo que alcanza N enemigos deja N efectos activos, uno por enemigo.
- **AC933** `impact_point` devuelve un punto a distancia `radius` (±0.01) del eje del enemigo, del lado de la hoja: el producto punto con la dirección eje→hoja es > 0.
- **AC934** La altura del impacto sigue a la hoja dentro de `[min_height, max_height]` y se limita fuera de ese rango.
- **AC935** Con la hoja sobre el eje del enemigo, la dirección cae en la del jugador.
- **AC936** El fragmento se alinea con el movimiento de la punta (ángulo < 5° con la velocidad proyectada). Bajo `min_tip_speed` queda horizontal y perpendicular a jugador→enemigo.
- **AC937** Un golpe crítico usa `hit_impact_crit_material`, escala por `crit_scale` y muestra el fragmento cruzado. Uno normal usa el material blanco y oculta el cruzado.
- **AC938** Los golpes de Envainar y del Giro (incluido su corte del dash) muestran impacto. Los de una habilidad con `shows_hit_impact = false` y los del Tajo aéreo no.
- **AC939** Después de `_ready`, la cantidad de hijos del pool no cambia al mostrar impactos, ni al pasar `pool_size`. Con el pool lleno, se reutiliza el efecto más viejo.
- **AC940** Pasados `duration` segundos, el efecto se oculta, la luz queda apagada y `is_playing()` es false.
- **AC941** Los dos materiales son unshaded, aditivos, con alpha ≤ 0.5 y los colores del §8.
- **AC942** Smoke: el proyecto y `arena.tscn` corren 300 cuadros sin errores. Captura visual de un golpe normal y uno crítico de cada clase.

## 10. Plan

1. `HitImpactVfxConfig` + `.tres` + los dos materiales. `AbilityData.shows_hit_impact` en `true` para `spin.tres` y `sheathe.tres`.
2. `HitImpactVfx` (un efecto) con sus tests (AC937, AC940, AC941).
3. `HitImpactVfxHost`: `impact_point` puro, orientación, pool y conexiones, con tests (AC931–AC936, AC938, AC939).
4. Enganche en `player.tscn` y `Player._equip_weapon()` (`attach`).
5. Enmienda 4.18.0 en `constitution.md`.
6. Capturas en el scratchpad (normal y crítico, las 3 clases), ajuste de valores del `.tres` y smoke (AC942).
7. Tests de esta spec en verde, checklist de review, estado **Implementada**, CLAUDE.md (próximo AC y "Dónde se ajusta"), reserva de AC931–AC942.

## 11. Checklist de review

- [ ] I · [ ] II · [ ] III · [ ] IV · [ ] V · [ ] VI (sin input nuevo) · [ ] VII (sin `Engine.time_scale`) · [ ] Calidad
