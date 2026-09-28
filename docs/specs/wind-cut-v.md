# Feature: Corte de viento en V vertical (Envainar)

- **Estado:** Implementada (ACs renumerados a AC271–AC277 porque AC267–AC270 los tomó `endless-without-upgrades.md` en paralelo; 2026-09-25, 344 tests GdUnit4 en verde, 0 orphans; import y smoke test sin errores ni warnings; captura en tiempo real comparada con la referencia)
- **Constitución:** `docs/constitution.md` v3.3.0 → enmienda **MINOR 3.4.0**:
  - se permiten partículas y luces breves para VFX;
  - la tabla de colores cambia la fila del corte de viento;
  - se registra el color del polvo como no reservado.
- **Pilar (Principio I):** combate. El tajo cargado tiene que *sentirse* monumental y dejar legible su alcance: la V marca la línea exacta del golpe.
- **Reemplaza:** la V horizontal de `sheathe-feel.md` (AC265), que queda marcada como reemplazada por esta spec.
- **Reemplazada en parte por:** `sheathe-visual-rework.md` (AC271–AC272 pasan a AC1043–AC1044: paredes por tramos; chispas, polvo y destello salen en el estallido).
- **Referencia:** captura del usuario. Dos paredes de luz nacen del suelo sobre la línea del corte y se abren hacia el cielo, con un estallido, chispas y polvo.

## 1. Objetivo

Cuando cae el tajo de Envainar (fin del cast), con `factor = charge_factor(carga)` y `L = HIT_RANGE × factor` (el largo del tajo):

1. **Paredes en V.**
   - Son dos paredes planas y translúcidas que salen del suelo sobre la línea central del tajo, desde el samurái hasta `L`.
   - Cada una se inclina `half_angle` hacia afuera desde la vertical (una a la izquierda y otra a la derecha), así que vistas desde atrás forman una V que se abre hacia arriba.
   - Su altura final es `max_height × factor`: 1.8 m sin carga y 6 m a carga completa.
   - Crecen desde el suelo en `grow_duration`, con el borde inferior siempre apoyado en el suelo, y después se desvanecen en `fade_duration`.
2. **Chispas.** Partículas one-shot (`CPUParticles3D` con `BoxMesh` pequeño) que saltan desde toda la línea del tajo hacia arriba y hacia los costados, y caen con gravedad.
3. **Polvo.** Partículas one-shot (`SphereMesh`) de color tierra que se levantan del suelo a lo largo del tajo, crecen y se desvanecen.
4. **Destello en el extremo.** A la distancia `L`, a `flash_height`:
   - una esfera crece hasta `flash_radius` y se desvanece en `flash_duration`;
   - una `OmniLight3D` se enciende con `flash_energy` y se apaga linealmente en el mismo tiempo.

Todo es solo visual y queda donde cayó el tajo (`top_level`). Los nodos se crean una vez y se reutilizan en cada tajo (Principio V).

### Color y materiales (Principio II)

- **Paredes, chispas y destello:** blanco `Color(1,1,1)`, unshaded, con **blend aditivo** y alpha ≤ 0.5. El blend aditivo hace que brillen sobre el fondo, como en la referencia, sin shaders.
- **Polvo:** tierra `Color(0.62, 0.52, 0.4)`, unshaded y translúcido. Es un color no reservado, distinto del gris de los enemigos.
- **Luz:** blanca y breve; no cambia el color de ninguna entidad de forma permanente.

## 2. Diseño

- **`WindCutVfx`** (se reescribe):
  - **Hijos:** `LeftWall` y `RightWall` (`MeshInstance3D` + `BoxMesh`), `Sparks` y `Dust` (`CPUParticles3D`), `Flash` (`MeshInstance3D` + `SphereMesh`) y `FlashLight` (`OmniLight3D`).
  - **`_ready`:** aplica `WindCutConfig` a las partículas (cantidad, vida, velocidades, gravedad, tamaño y spread), así ningún valor queda solo en la escena.
  - **`play(origin, yaw, length, factor)`:**
    - se ubica en `origin` mirando a `yaw`;
    - las partículas se colocan en el centro del tajo, con `emission_box_extents.z = length / 2`, y se relanzan con `restart()`;
    - el destello se ubica en `(0, flash_height, -length)`.
  - **`advance(delta)`:**
    - paredes: crecen (escala Y con el borde inferior fijo) durante `grow_duration` y después se desvanecen;
    - destello: la esfera crece y se desvanece, y la luz baja su energía;
    - al terminar las paredes y el destello, se oculta. Las partículas terminan solas (one-shot).
- **`SheatheAbility.release()`:** pasa también el `factor` a `play()`.

### Datos (Principio III): `WindCutConfig` (reescrito)

| Grupo | Campos (valores iniciales) |
|---|---|
| Paredes | `max_height 6.0` · `half_angle_degrees 25` · `wall_thickness 0.03` · `grow_duration 0.15` · `fade_duration 0.4` · `start_transparency 0.5` |
| Chispas | `spark_amount 48` · `spark_lifetime 0.6` · `spark_speed_min 4` · `spark_speed_max 9` · `spark_spread_degrees 35` · `spark_gravity 14` · `spark_size 0.06` |
| Polvo | `dust_amount 32` · `dust_lifetime 0.8` · `dust_rise_speed_min 0.6` · `dust_rise_speed_max 1.6` · `dust_size 0.35` · `dust_width 0.8` |
| Destello | `flash_height 1.0` · `flash_radius 1.4` · `flash_duration 0.25` · `flash_energy 4.0` · `flash_range 6.0` |

Materiales nuevos: `materials/vfx/wind_cut_additive_material.tres` (sustituye a `wind_cut_material.tres`) y `materials/vfx/wind_dust_material.tres`.

### Enmienda 3.4.0 (MINOR), Principio II

- Se permiten **partículas** (`CPUParticles3D`) **y luces breves** (`OmniLight3D`) **solo para VFX**. Las partículas usan mallas primitivas y un material `.tres` compartido, sin texturas, y sus parámetros vienen de un Resource.
- La fila "Corte de viento" de la tabla pasa a decir: paredes, chispas y destello en blanco, unshaded, blend aditivo, alpha ≤ 0.5.
- Colores no reservados en uso: se agrega el **tierra** del polvo del corte de viento.

## 3. Criterios de aceptación

- **AC265** *Reemplazado por AC271–AC275.*
- **AC271** Cuando cae el tajo:
  - las dos paredes se ubican sobre la línea central del tajo, miden `L` de largo y están inclinadas ±`half_angle` desde la vertical, abriéndose hacia afuera;
  - su borde inferior está en el suelo durante todo el crecimiento;
  - después de `grow_duration` miden `max_height × factor` de alto (6 m a carga completa y 1.8 m sin carga).
- **AC272** Las paredes tienen transparencia ≥ 0.5 en todo momento y se ocultan después de `grow_duration + fade_duration`. Su material es aditivo, blanco y unshaded.
- **AC273** Las chispas emiten una sola vez por tajo (`one_shot`), con `amount = spark_amount`. Su caja de emisión cubre el largo del tajo (`extents.z = L / 2`, centrada en `-L / 2`).
- **AC274** El polvo emite una sola vez por tajo desde el suelo a lo largo del tajo, con `amount = dust_amount` y el material tierra.
- **AC275** El destello aparece en `(0, flash_height, -L)`:
  - la esfera llega a `flash_radius` y la luz a `flash_energy` al inicio;
  - la energía de la luz baja a 0 en `flash_duration`;
  - al terminar, esfera y luz quedan ocultas.
- **AC276** Dos tajos seguidos reutilizan los mismos nodos: la cantidad de hijos de `WindCutVfx` no cambia.
- **AC277** Regresión: suite completa en verde.

## 4. Plan de implementación

1. Enmienda 3.4.0, `WindCutConfig` reescrito con su `.tres` y los materiales nuevos. `sheathe-feel.md` se marca como parcialmente reemplazada (AC265).
2. Reescribir `WindCutVfx` y su nodo en `sheathe_ability.tscn` (paredes, partículas, destello y luz); `SheatheAbility.release()` pasa el `factor`.
3. Tests AC271–AC276, que reemplazan el test de AC265 en `sheathe_feel_test.gd`.
4. Suite completa, smoke test, **captura** para compararla con la referencia (y ajustar valores de datos si hace falta), y cierre: estado **Implementada**, `CLAUDE.md` → AC278.

## 5. Notas de implementación

- **AC275:** la luz arranca con `flash_energy` y baja linealmente a 0. La esfera, en cambio, **crece** hasta `flash_radius` durante `flash_duration` mientras se desvanece, así que llega al radio al final y no al inicio. Esto aclara la redacción del criterio.
- Las partículas se crean en `_ready` a partir de `WindCutConfig` (cantidad, vida, velocidades, spread, gravedad y tamaños), así que la escena no guarda valores de diseño. El fade de las partículas es una `Gradient` (de blanco opaco a transparente) que multiplica el color del material (`vertex_color_use_as_albedo`); el alpha nunca supera el del material (0.5).
- Al terminar se ocultan paredes, destello y luz, pero **no** el nodo raíz: ocultarlo cortaría las partículas que siguen vivas.
- `materials/wind_cut_material.tres` se borró y lo reemplazan `materials/vfx/wind_cut_additive_material.tres` y `wind_dust_material.tres`.
- El test de AC265 de `sheathe_feel_test.gd` se eliminó: los tests de AC271–AC276 viven en `test/components/abilities/wind_cut_vfx_test.gd`.

### Review de la constitución (cierre)
- **I:** combate.
- **II:**
  - Paredes, chispas y destello son primitivas en blanco unshaded, aditivo y con alpha ≤ 0.5. El polvo va en tierra, un color no reservado.
  - Las partículas y la luz breve están permitidas por la 3.4.0.
  - Sin texturas ni shaders.
- **III:** todos los parámetros viven en `wind_cut_config.tres`. `MIN_SIZE` es una constante estructural, y el radio 1 de la esfera base es una identidad (la escala es el radio).
- **IV:** tipado estricto.
- **V:** todos los nodos y mallas se crean una vez; las partículas se relanzan con `restart()` y no se asigna nada por frame.
- **VI:** sin cambios de input.
- **Calidad:** suite completa en verde.
