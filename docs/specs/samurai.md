# Feature: Clase Samurái (katana con funda) + habilidad Envainar

- **Estado:** Implementada (2026-09-25, 323 tests GdUnit4 en verde, 0 orphans; `sheathe_test` y `samurai_run_test` pasaron 3 corridas seguidas; import y smoke test headless del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v3.1.2 → enmienda **MINOR 3.2.0**, aprobada con esta spec:
  - texturas de imagen en modelos importados,
  - mallas derivadas cuando el modelo fuente no permite separar partes.
- **Pilar (Principio I):**
  - **Combate:** la primera habilidad de carga (*hold*). Pone en juego el riesgo contra la recompensa: cargás más para pegar más fuerte y más lejos, mientras te movés despacio, reposicionándote con el dash y con menos daño recibido.
  - **Progresión:** una 3.ª clase con su propio pool de habilidades.
- **Dependencias:** `character-classes.md`, `ability-system.md`, `berserker.md`, `weapon-models.md`, `weapon-reach.md`, `weapon-trail.md` (Implementadas).

## 1. Objetivo

- **Samurái:**
  - Clase ágil y crítica.
  - Lleva una katana en la mano y la funda fija en la cintura, del lado izquierdo.
  - Su ataque básico es el barrido procedural (`SwordSwing`) con la configuración de la katana.
- **Envainar (habilidad básica del Samurái, única en su pool):**
  - **Apretar** `ability_basic`: empieza la carga. La katana vuelve a la funda (pose de iaido) y el cooldown **no** arranca.
  - **Mientras mantenés:**
    - La carga crece lineal hasta el 100 % en `CHARGE_TIME` (3 s). Después queda al 100 % **sin límite** hasta que soltás.
    - Caminás a `MOVE_SPEED × 0.2`. No podés atacar ni saltar.
    - **Podés dashear.** El dash tiene su velocidad normal, no rota al personaje, mantiene la pose y la carga, y la carga sigue acumulando durante el dash.
    - Recibir daño no cancela la carga. El daño recibido se reduce un **50 %** después de la defensa.
    - Un rectángulo cian en el suelo muestra el alcance, que crece con la carga, y se ve más sólido al 100 %. El círculo del slot en el HUD muestra un anillo con la carga.
  - **Soltar:**
    - Arranca el cooldown (8 s).
    - El samurái vuelve a mirar al enemigo más cercano y desenvaina con un **gyaku kesa-giri**: un tajo diagonal ascendente, de la cadera izquierda baja al hombro derecho alto. La animación dura `CAST_DURATION` y el golpe cae al final.
    - Si soltás durante un dash, el tajo sale al terminar el dash.
  - **Golpe** (con `factor = lerp(min_charge_factor = 0.3, 1, carga)`):
    - **Tajo frontal:** rectángulo de largo `HIT_RANGE × factor` y ancho `HIT_WIDTH`. Hace `(BASE_DAMAGE + ATTACK_SCALING × DAMAGE) × factor` de daño y **puede ser crítico** con `CRIT_CHANCE`/`CRIT_DAMAGE` del jugador (sin `DAMAGE_BONUS` ni robo de vida). Empuja hacia afuera con `knockback_speed × factor`.
    - **Onda radial:** los enemigos dentro de `wave_radius` que no recibieron el tajo son empujados con `knockback_speed × factor`, **sin daño**.
  - **Mejoras:**
    - Daño: +6 base, máx. 6.
    - Carga rápida: −0.3 s de `CHARGE_TIME`, máx. 5, piso 1.5 s.
    - No tiene carta de cooldown ni mejoras únicas.

## 2. Diseño

### Habilidades cargadas (`AbilityComponent`)

- `AbilityBehavior.is_charged()` es falso por defecto. Cuando es verdadero:
  - `try_cast()` entra en carga: llama `begin_charge()` y emite `charge_started`, sin cooldown.
  - `advance()` acumula `_charge_elapsed` hasta `CHARGE_TIME` y llama `charge(step)`.
- `release_charge()`, que llama `Player`, hace lo siguiente:
  - congela el ratio (`get_released_charge_ratio()`),
  - arranca el cooldown,
  - inicia el cast (`CAST_DURATION`) con `begin()` y emite `cast_started`.
  
  Desde ahí sigue el camino de siempre: `channel()` y al final `release()`.
- `equip()` y `cancel_charge()` cortan la carga llamando `behavior.cancel_charge()`.
- `is_casting()` sigue significando solo la fase de cast, así la estela no se dibuja con la katana envainada. `is_charging()` es nuevo. `Player.is_casting()` pasa a ser "cast o carga".
- `controls_motion()` vale durante la carga o el cast si el behavior lo pide.
- `report_hit(enemy, applied, is_crit = false)`.

### `Player`

- `_handle_abilities()` primero suelta la carga cuya acción ya no está presionada, salvo durante un dash.
- `_handle_dash()` permite dashear si no se está casteando o si solo se está cargando.
- `_equip_weapon()` instancia `WeaponData.sheath` (si existe) bajo `Visual`, en `sheath_position`/`sheath_rotation`.

### Datos (Principio III)

| Resource | Campos nuevos |
|---|---|
| `AbilityData` | `Stat.CHARGE_TIME` (al final del enum), `charge_time`, `min_charge_time` |
| `WeaponData` | `sheath: PackedScene` (opcional), `sheath_position`, `sheath_rotation` |
| `SheatheConfig` | `min_charge_factor`, `charge_move_speed_factor`, `charge_damage_reduction`, `knockback_speed`, `wave_radius`, `sheathed_position`, `sheathed_rotation`, `full_charge_transparency`; más `charge_factor(ratio)` (cálculo puro) |
| `AbilitySlotViewConfig` | `charge_ring_color` |

`HealthComponent.damage_reduction` es estado mutable del nodo (0 = sin reducción). `DamageMath.apply_crit()` sale de `outgoing()`.

| Archivo | Valores |
|---|---|
| `data/classes/samurai/samurai_stats.tres` | daño 14 · defensa 1 · vida 90 · crítico 0.15 · daño crítico 1.0 · 1.4 atq/s · alcance 2.0 · velocidad 6.5 · salto 4.5 · dash 3 m · iframes 1 s · recarga del dash 1.5 s · arco 100° |
| `data/classes/samurai/katana.tres` | modelo `katana.tscn` · funda `katana_sheath.tscn` en la cintura izquierda · swing `katana_swing_config.tres` |
| `data/abilities/sheathe/sheathe.tres` | "Envainar" · base 30 · escalado 0.5 · cooldown 8 (piso 8) · alcance 4 m · ancho 1.2 m · cast 0.25 s (piso 0.25) · carga 3 s (piso 1.5) |
| `data/abilities/sheathe/sheathe_config.tres` | `min_charge_factor 0.3` · `charge_move_speed_factor 0.2` · `charge_damage_reduction 0.5` · `knockback_speed 7` · `wave_radius 2.5` |

### Arte (Principio II)

- `katana.glb` trae **una sola malla skinned** con dos huesos: la funda es hija de la hoja. Por eso no se puede ocultar la hoja sin ocultar también la funda.
- Se derivaron dos mallas estáticas, `katana_blade.res` y `katana_sheath.res` (enmienda 3.2.0, procedimiento en `SOURCE.md`), usadas desde `katana.tscn` y `katana_sheath.tscn`.
- Un solo material, `materials/weapons/katana_material.tres`, con la paleta `katana_palette.png` como albedo y filtro *nearest*.
- Escala 1.1: la punta queda en z ≈ −1.27. Regla AC211: 0.35 + 1.27 × cos(0.15) + 0.4 ≈ 2.0 = `attack_range`.
- La animación `sheathe_slash` va en el `SwingPlayer` de `player.tscn` y anima `Visual/SwordPivot`.

## 3. Criterios de aceptación

- **AC236** El catálogo tiene 3 clases. El samurái tiene los stats de la tabla y su pool es solo Envainar.
- **AC237** El alcance de la katana cumple la regla AC211. La escena tiene `TrailBase`/`TrailTip` y usa `katana_material.tres`, con una textura que vive en la carpeta del asset.
- **AC238** El samurái tiene la funda bajo `Visual` en `sheath_position`. El guerrero y el berserker no tienen funda.
- **AC239** Al apretar empieza la carga, sin cooldown. `get_charge_ratio` es 0.5 a los 1.5 s y queda en 1.0 mientras se mantenga (probado a los 5 s).
- **AC240** *(Reemplazado por `sheathe-dash-cancel.md` AC361: el golpe cae al soltar y el cast pasa a ser una recuperación que el dash puede cortar)* Al soltar, el cooldown arranca con 8 s. El cast dura `CAST_DURATION` y el golpe cae al final.
- **AC241** Daño = `(30 + 0.5 × DAMAGE) × lerp(0.3, 1, carga)`: toque inmediato = 30 %, 1.5 s = 65 %, 3 s o más = 100 %.
- **AC242** Con crítico 100 %, el daño se multiplica por `(1 + CRIT_DAMAGE)` y `enemy_hit` sale con `is_crit = true`. Con 0 %, no hay crítico.
- **AC243** Un enemigo a 3 m no recibe un tajo sin carga (1.2 m), pero sí uno a carga completa (4 m).
- **AC244** Los enemigos golpeados salen empujados hacia afuera con `knockback_speed × factor`.
- **AC245** Los enemigos dentro de `wave_radius` y fuera del rectángulo son empujados sin recibir daño. Los que están fuera de la onda no reciben nada.
- **AC246** Mientras carga, la velocidad máxima es `MOVE_SPEED × 0.2` y no puede atacar ni saltar.
- **AC247** Se puede dashear mientras carga. El dash recorre `DASH_DISTANCE`, la carga sigue acumulando, sigue cargando al terminar y el yaw del `Visual` no cambia por el dash.
- **AC248** Si se suelta la tecla durante el dash, el tajo arranca al terminar el dash.
- **AC249** Mientras carga, el daño recibido es el 50 % del mitigado. Después de soltar vuelve al 100 %. Recibir daño no cancela la carga.
- **AC250** El indicador se muestra desde que se aprieta. Su largo sigue a `HIT_RANGE × factor`, tiene `full_charge_transparency` al 100 % y se desvanece después del golpe.
- **AC251** El slot del HUD muestra la carga en curso mientras carga.
- **AC252** La carta de daño suma +6 al base. La de carga rápida resta 0.3 s con piso de 1.5 s, y el ratio usa el `CHARGE_TIME` mejorado.
- **AC253** Regresión: la Estocada, el Golpe Veloz y el Giro siguen lanzándose al apretar, con el cooldown desde que se aprieta.
- **AC254** `equip()` en medio de una carga la cancela y quita la reducción de daño.
- **AC255** Run en la arena: el samurái equipa Envainar y, con `Input.action_press`/`action_release` de `ability_basic`, golpea a un enemigo.

## 4. Plan de implementación

1. Asset: mover el glb y la textura, derivar las mallas, escribir `SOURCE.md` y borrar `temporal-weapon-model/`.
2. Enmienda 3.2.0, material y escenas adaptadoras.
3. Funda en `WeaponData` y en `Player`.
4. Datos de la clase samurái y alta en el catálogo.
5. Sistema de carga: `AbilityData`, `AbilityBehavior`, `AbilityComponent`, `HealthComponent`, `DamageMath` y `Player`.
6. `SheatheConfig`, `SheatheAbility` con su escena, la animación `sheathe_slash` y los datos de Envainar.
7. Anillo de carga en el HUD.
8. Tests AC236–AC255.
9. Suite completa, smoke test, captura visual y cierre.

## 5. Notas de implementación

- **Modelo:** `katana.glb` trae una sola malla skinned y el hueso de la funda es hijo del de la hoja. Escalar un hueso a 0 no alcanza para mostrar solo la funda. Por eso se derivaron `katana_blade.res` y `katana_sheath.res`, y la enmienda 3.2.0 incluye la regla de "mallas derivadas".
- **Orientación:** el glb tiene la hoja en +Y. El `Transform3D` del `.tscn` se escribe por filas de la base, así que +Y → −Z es `Transform3D(s,0,0, 0,0,s, 0,-s,0, …)`. La fórmula de `CLAUDE.md` vale para los `.obj` con la hoja en −Y.
- **Funda y pose de carga:** `SheatheConfig.sheathed_position/rotation` coincide con `katana.tres` `sheath_position/rotation` (AC250 lo verifica), así la hoja queda exactamente dentro de la funda. La animación `sheathe_slash` también parte de esa pose y termina en el reposo de la katana. Si se mueve la funda, hay que actualizar los tres lugares.
- **Tests viejos adaptados (verifican lo mismo):**
  - `berserker_run_test` AC184: el catálogo *contiene* guerrero y berserker (antes era igual a la lista de 2 clases).
  - `main_menu_test` AC178: 3 tarjetas, con el samurái.
  - `upgrade_offer_test` AC54: la Estocada tiene una carta por stat salvo `TICK_INTERVAL` y `CHARGE_TIME`.
  - `weapon_reach_test` AC211 y `sweep_timing_test` AC224/AC225 incluyen al samurái.
- **`AbilityStatFormats`:** tiene el formato del nuevo stat `CHARGE_TIME` (`%.1f s`), que usa el panel del sandbox.
- **Input en tests:** la acción de ataque se procesa antes de que arranque la carga si ambas se apretan en el mismo cuadro, así que AC246 aprieta primero la habilidad.

### Review de la constitución (cierre)
- **I:** combate (habilidad de carga con riesgo y recompensa) y progresión (3.ª clase).
- **II:**
  - El asset vive en `assets/models/weapons/katana/`, con `SOURCE.md`.
  - Se usa vía escenas adaptadoras, con un material `.tres` compartido que usa una textura permitida por la 3.2.0.
  - Sin shaders.
  - El indicador reutiliza el material cian existente.
  - Los colores reservados se respetan.
- **III:**
  - Todos los valores nuevos viven en `.tres`: `sheathe.tres`, `sheathe_config.tres`, `samurai_stats.tres`, `katana.tres` y el config del HUD.
  - Las cartas declaran `max_stacks`, y el piso de `CHARGE_TIME` está en datos.
  - `HealthComponent.damage_reduction` es estado del nodo.
  - Ningún Resource compartido se muta.
- **IV:** tipado estricto; los callbacks delegan en métodos con nombre.
- **V:** buffers reutilizados en `SheatheAbility`; sin allocations ni búsquedas de nodos por frame. El indicador se re-dimensiona sin crear mallas.
- **VI:** solo acciones del InputMap (`ability_basic`, `dash`).
- **Calidad:** suite completa en verde; sin errores ni warnings nuevos.

## 6. Ajuste posterior (2026-09-25): pose de reposo en diagonal

Decisión del usuario, a partir de una imagen de referencia: en reposo, el samurái sostiene la katana con las manos bajas, delante de la cintura, y la hoja cruza el cuerpo en diagonal hacia arriba, a su derecha. La punta queda por encima de la cabeza.

- `katana.tres`:
  - `rest_position` (0.45, 1.3, 0) → **(−0.1, 0.95, −0.5)**;
  - `rest_rotation` (0.9, 0, 0) → **(0.93, −0.99, 0)**: la hoja apunta a (0.5, 0.8, −0.3) normalizado, es decir, a la derecha, arriba y un poco adelante.
- El último cuadro de `sheathe_slash` en `player.tscn` pasa a esa misma pose, así el tajo termina en el reposo (AC250 lo verifica contra `katana.tres`).
- Solo cambian datos, sin GDScript. Suite completa en verde (344 tests).
