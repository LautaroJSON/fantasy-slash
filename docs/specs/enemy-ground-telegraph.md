# Avisos de ataque enemigo en el piso

- **Estado:** Implementada (2026-09-26). A pedido del usuario se corrieron solo los suites de esta spec (`ground_telegraph_test`, `ground_telegraph_integration_test`) y todos los de `test/entities/enemy` (112 tests): todos en verde, 0 orphans. Import y smoke test de la arena sin errores; capturas del sector, la franja y el círculo (con destello y polvo) revisadas. La suite completa no se corrió.
- **Constitución:** `docs/constitution.md` **v4.4.0** → **v4.5.0** (enmienda MINOR, ver abajo)
- **Pilar (Principio I):** Combate. Cada ataque enemigo marca en el piso **dónde** va a pegar (la hitbox real) y **cuándo**: un relleno que llega al borde justo en el golpe. Así esquivar es una decisión informada incluso con muchos enemigos en pantalla.
- **Tipo:** feature. Complementa `enemy-attack-telegraph` (manos), `enemy-types`, `boss-verdugo` y `boss-titan`.
- **Dependencias:** las cuatro specs de arriba.

## Objetivo

- **Aviso:** mientras un enemigo prepara un ataque, en el piso se ve la zona de su hitbox en **rojo anaranjado**:
  - la zona completa, tenue;
  - encima, un **relleno** que crece desde el origen del golpe hasta el borde durante la preparación.
- **Al pegar:** la zona **destella** y se desvanece. En los golpes contra el piso, además, sale una **nube de polvo tierra**.
- **Si el ataque se cancela** (empuje, objetivo perdido), el aviso desaparece al instante.

| Forma | Ataques | Tamaño | Origen y relleno |
|---|---|---|---|
| **Sector** | Bruto, Gemelo y golpe de escudo del Escudero (`MeleeBehavior`); tajos del Verdugo; barrido del Titán | `hit_range` y `hit_arc_degrees` del ataque | Desde el enemigo, siguiéndolo mientras gira o avanza. El relleno crece hacia afuera. |
| **Franja** | Carga del Embestidor; estocada del Hostigador; agarre del Verdugo | Largo: el recorrido planeado + `hit_range`. Ancho: 2 × `hit_range` (Embestidor) o `hit_range` (estocada y agarre). | Desde el enemigo, hacia donde mira mientras prepara. El relleno avanza a lo largo. |
| **Círculo** | Caída del Saltador; aplastamiento del Titán | Saltador: `hit_range`. Titán: `impact_radius`. | Sigue al jugador hasta que se fija el punto y después queda quieto. El relleno crece desde el centro. |
| — | Onda y pisotón | — | Sin aviso extra: el anillo ya es visible. |

**Duración del relleno:**
- **Sector y franja:** la preparación.
- **Círculo del Saltador:** preparación + vuelo, hasta la caída.
- **Círculo del Titán:** preparación + golpe, hasta el impacto.

**Destello:** al empezar el golpe (sector), la carga, la estocada o el agarre (franja), o el impacto (círculo, con polvo).

## Enmienda a la constitución (MINOR → 4.5.0)

- **Principio II, mallas procedurales:** además de las VFX con trayectoria, se permiten **mallas planas procedurales** (`ArrayMesh`) para los avisos de ataque enemigo en el piso: sectores circulares de un arco dado. Se construyen **una vez al cargar** (cuando el pool crea el enemigo), con material `.tres` compartido y sin texturas. Los círculos y las franjas siguen siendo primitivas (`CylinderMesh`, `BoxMesh`).
- **Principio II, colores no reservados:** se registra el **rojo anaranjado** `Color(1.0, 0.3, 0.1)` de los avisos enemigos: unshaded, alpha ≤ 0.5, con destello de hasta 0.8. Es distinto del rojo del Rage, del ámbar de los críticos y del celeste de los avisos del jugador. El polvo del impacto reusa el tierra ya registrado.

## Estructura de nodos (`enemy.tscn`)

```
Enemy
└─ GroundTelegraph (Node3D, top_level, components/enemies/ground_telegraph.gd)   ← nuevo
   ├─ Base (MeshInstance3D)   zona completa, tenue
   ├─ Fill (MeshInstance3D)   relleno que crece
   └─ Dust (CPUParticles3D)   polvo del impacto (one-shot)
```

`Base` y `Fill` cambian de malla según la forma: sector (del caché), `CylinderMesh` unitario o `BoxMesh` unitario. El tamaño se aplica con escala y la transparencia por instancia (`GeometryInstance3D.transparency`), así el material queda compartido.

## Resources y datos

- **`TelegraphConfig`** (`resources/telegraph_config.gd`), en `data/enemies/telegraph_config.tres`:
  - `ground_offset`, `base_transparency`, `fill_transparency`, `flash_transparency`, `flash_time` y `fade_time`;
  - `sector_segments` (resolución del arco);
  - polvo: `dust_amount`, `dust_lifetime`, `dust_size`, `dust_rise_speed_min`, `dust_rise_speed_max` y `dust_spread`.
- **Materiales:**
  - `materials/vfx/telegraph_material.tres` (rojo anaranjado, unshaded, transparente, sin sombras), compartido por `Base` y `Fill`;
  - el polvo reusa `materials/vfx/wind_dust_material.tres` (tierra).
- **`EnemyBehavior.get_telegraph_arcs() -> Array[float]`:** los arcos de sector que usa el tipo, para construir sus mallas al cargar.

## Interfaz pública

- **`GroundTelegraph`:**
  - `prepare_arcs(arcs)`: construye y guarda los sectores (al cargar).
  - `show_sector(origin, facing, radius, arc_degrees, duration)`, `show_line(origin, direction, length, width, duration)` y `show_circle(center, radius, duration)`.
  - `follow(origin, direction)` y `move_center(center)`: mientras el aviso no está fijo.
  - `flash(with_dust)`, `clear()`, `advance(delta)`, `is_showing()` y `get_fill_ratio()`.
- **`Enemy`:** `get_telegraph()`. En `_ready` llama a `prepare_arcs(behavior.get_telegraph_arcs())` y en `activate()`/`deactivate()` a `clear()`.
- Cada comportamiento llama a `show_*` al empezar la preparación, a `follow`/`move_center` mientras no fija, a `flash` al pegar y a `clear` si cancela.

## Criterios de aceptación (AC500–AC515, reservados)

**Componente** (`test/components/ground_telegraph_test.gd`):
- **AC500:** `show_sector` muestra `Base` con el radio y el arco pedidos, orientado al `facing`. El relleno escala `elapsed / duration`: 0 al empezar, 0.5 a mitad y 1 al final.
- **AC501:** `show_line`: `Base` mide largo × ancho, empieza en el origen y apunta en la dirección pedida. El relleno avanza a lo largo desde el origen.
- **AC502:** `show_circle`: disco del radio pedido. El relleno crece desde el centro, y `move_center` lo mueve mientras no está fijo.
- **AC503:** `flash()` lleva el relleno al 100 % con `flash_transparency`, se desvanece en `fade_time` y el aviso se oculta. Con `with_dust`, emite el polvo.
- **AC504:** `clear()` lo oculta al instante. `prepare_arcs` no repite mallas para arcos iguales, y mostrar un sector no crea mallas nuevas.

**Integración** (`test/entities/enemy/ground_telegraph_integration_test.gd`):
- **AC505:** Bruto: durante la preparación hay un sector de `hit_range` y `hit_arc_degrees`, con el relleno avanzando. Al empezar el golpe destella y después se oculta.
- **AC506:** un empuje que cancela la preparación del Bruto borra el aviso.
- **AC507:** Escudero y Gemelo muestran el sector de su ataque.
- **AC508:** Embestidor: franja de `charge_distance` + `hit_range` que sigue su giro en la preparación, destella al empezar la carga y se oculta al terminar.
- **AC509:** Saltador: círculo que sigue al jugador en la preparación, queda en el punto de caída durante el vuelo y destella con polvo al caer.
- **AC510:** Hostigador: franja de la estocada en la preparación, que destella al lanzarse.
- **AC511:** Verdugo: sector en cada golpe del tajo (uno por paso) y franja del agarre. La onda no tiene aviso extra.
- **AC512:** Titán: círculo del aplastamiento que se fija al `lock_fraction` y destella con polvo en el impacto. Sector de 200° en el barrido.
- **AC513:** `activate()` y `deactivate()` limpian el aviso. Un enemigo reutilizado arranca sin aviso.
- **AC514:** si no pasa el ataque (sin token, en aparición), no hay aviso.
- **AC515:** los tests de las specs de enemigos siguen en verde sin cambios.

## Plan de implementación

1. Reservar AC500–AC515 en `CLAUDE.md` (próximo libre → AC516).
2. Enmienda de la constitución (4.5.0).
3. `TelegraphConfig`, material y `GroundTelegraph` (sectores, círculo, franja, relleno, destello, polvo). Nodo en `enemy.tscn` y `Enemy.get_telegraph()`. Tests AC500–AC504.
4. Integrar en `MeleeBehavior`/`ShieldbearerBehavior`, `ChargerBehavior`, `LeaperBehavior`, `HarasserBehavior`, `BossBehavior` y `TitanBehavior`, con `get_telegraph_arcs()` en cada uno. Tests AC505–AC514.
5. Correr los suites de esta spec y los de `test/entities/enemy` (AC515), import y smoke test de la arena. Capturas de cada forma. Checklist, spec **Implementada** y `CLAUDE.md`.

## Review (checklist de la constitución)

- [x] **I.** Combate: el dónde y el cuándo de cada golpe se leen en el piso.
- [x] **II.** Sectores `ArrayMesh` construidos al cargar (enmienda 4.5.0); círculos y franjas son primitivas. Materiales `.tres` compartidos, sin shaders ni texturas. El rojo anaranjado queda registrado.
- [x] **III.** Todos los números del aviso en `telegraph_config.tres`; los tamaños salen de los datos de cada ataque.
- [x] **IV.** Tipado estático.
- [x] **V.** No se asigna memoria por frame: las mallas y partículas existen desde la carga, y en combate solo se escalan, mueven y muestran.
- [x] **VI.** Sin input nuevo.

### Implementación: ajustes respecto de lo aprobado

- **Nodos creados por código:** `Base`, `Fill` y `Dust` los crea `GroundTelegraph._ready()` (al cargar, cuando el pool crea el enemigo) y no están escritos en `enemy.tscn`. La escena solo tiene el nodo `GroundTelegraph` con su config y materiales. El efecto es el mismo.
- **Valores nuevos en `TelegraphConfig`:** `fill_lift` (el relleno va apenas por encima de la zona, para que no titile), `thickness` y `dust_cone_degrees`.
- **Material:** alpha 0.8, con `cull_mode` desactivado para que el sector se vea sin depender del sentido de los triángulos. La transparencia por instancia deja la zona en ≈0.2, el relleno en ≈0.45 y el destello en 0.8, dentro de lo que registra la enmienda.
- **Getters para los tests:** `get_size()`, `get_width()`, `get_arc()`, `get_origin()` y `get_direction()`.
- **Carga del Embestidor:** el destello se desvanece en `flash_time + fade_time` (0.35 s), antes de que termine la carga (≈0.7 s), así que el aviso ya no está cuando llega al final.
- **Error corregido después del cierre (2026-09-26):** la franja se escalaba en los ejes del mundo (`Basis.scaled`) en vez de en los suyos, así que solo se veía bien apuntando a lo largo de ±Z. En cualquier otra dirección salía atravesada o como un rombo deformado; lo reportó el usuario con la carga del Embestidor. Ahora se escala en ejes locales (`yaw * Basis.from_scale(...)`), lo que también corrige la estocada del Hostigador y el agarre del Verdugo. Se agregó un test de regresión a AC501 (`test_ac501_line_keeps_its_size_in_any_direction`, con 4 direcciones) y se revisó con una captura de 8 Embestidores alrededor del jugador, vistos desde arriba y en ángulo.
