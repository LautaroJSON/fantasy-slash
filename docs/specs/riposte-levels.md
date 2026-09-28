# Feature: Contragolpe con 3 niveles y vórtice blanco

- **Estado:** Propuesta (2026-09-28). ACs reservados: AC1056–AC1070.
- **Constitución:** `docs/constitution.md` v4.24.0 → **enmienda MINOR a 4.25.0** (ver §8).
- **Pilar (Principio I):** **combate.**
  - Contragolpe es el remate culminante del Guerrero, pero hoy no crece: la run no lo hace más fuerte.
  - Con dos niveles más, el alcance y el daño de la Estocada mejorada escalan con la build.
  - El VFX pasa de una cinta fina a un **vórtice blanco denso** que se agranda con cada nivel, así que la mejora se ve.
- **Pedido del responsable (2026-09-28):**
  1. Contragolpe se puede mejorar **2 veces más** (3 niveles);
  2. **nivel 2:** el alcance crece otro **30 %** y el daño otro **50 %**;
  3. **nivel 3:** el alcance crece otro **40 %** y el daño otro **75 %**;
  4. un VFX mejor, como la referencia (un remolino rojo, denso, de trazos que giran alrededor del personaje), pero **en blanco**.
- **Decisiones del responsable (2026-09-28):**
  - los aumentos se **multiplican** (cada nivel multiplica al anterior);
  - el VFX **crece con el nivel**: su radio sigue al del golpe, y en los niveles 2 y 3 suma trazos, chispas y polvo.
- **Dependencias:**
  - `parry-riposte-rework.md` (la Estocada mejorada, `CircleSlashVfx`; AC1024–AC1030);
  - `warrior-abilities-rework.md` (mejoras únicas con niveles, como Contundencia).

## 1. Estado actual (verificado sobre el working tree)

- `data/abilities/parry/unique/riposte.tres`: `max_level = 1`, sin `level_values` ni `level_descriptions`.
- `ParryConfig`:
  - `empowered_range_scale = 1.3`: radio = `ATTACK_RANGE × 1.3`;
  - `empowered_damage_multiplier = 1.5`: daño = 1.5 × un golpe del combo.
- Ambos los lee `ParryAbility` (`get_empowered_radius()`, `_empowered_hit()`), que no mira el nivel de la mejora.
- `CircleSlashVfx`: una sola cinta horizontal de 0.45 m de ancho a 1.05 m de alto. Su cabeza barre 360° en 0.25 s con una cola de 300°, y se desvanece en 0.2 s. Aditiva, alpha 0.5 en la cabeza.
- Las mejoras únicas con niveles ya existen (Contundencia, 2 niveles): `AbilityComponent.get_unique_level(id)`, y la carta se vuelve a ofrecer hasta `max_level`.

## 2. Diseño

### 2.1 Niveles

| Nivel | Alcance (× `ATTACK_RANGE`) | Daño (× un golpe del combo) |
|---|---|---|
| 1 (hoy) | ×1.3 | ×1.5 (150 %) |
| 2 | 1.3 × 1.3 = **×1.69** | 1.5 × 1.5 = **×2.25** (225 %) |
| 3 | 1.69 × 1.4 = **×2.366** | 2.25 × 1.75 = **×3.9375** (≈ 394 %) |

- En datos se guardan los **pasos**, tal como los pidió el responsable, y el valor de un nivel es el producto de los primeros N:
  - `empowered_range_steps = [1.3, 1.3, 1.4]`;
  - `empowered_damage_steps = [1.5, 1.5, 1.75]`.
  - Reemplazan a `empowered_range_scale` y `empowered_damage_multiplier`.
- `riposte.tres`: `max_level = 3`, con una descripción por nivel (los números de la tabla).
- **Nada más cambia con el nivel:** congelamiento, zoom, sacudida, enfriamiento renovado, inmortalidad, Duelo y empuje siguen igual.

### 2.2 El vórtice (`CircleSlashVfx` reescrito)

El nodo y su lugar no cambian (un `SlashVfx` prearmado en `parry_ability.tscn`), y sigue arrancando con el barrido (`empowered_trail_start`). `play()` recibe además el **nivel**. Capas:

1. **Hoja principal:** la cinta de hoy, más ancha y en espiral:
   - ancho por nivel `[0.8, 1.0, 1.2]` m, hacia adentro desde el radio del golpe;
   - la cabeza va por el borde exterior; hacia la cola, la cinta **se cierra hacia el centro** (el borde interior baja hasta el 45 % del radio): se lee como un remolino, no como un aro;
   - a 1.0 m de alto, con una leve inclinación que sube hacia la cola (0.25 m).
2. **Trazos:** cintas finas (0.06–0.18 m) que giran con la hoja:
   - cantidad por nivel `[4, 7, 10]`;
   - cada una con su radio (entre el 35 % y el 105 % del radio del golpe), altura (0.2–1.6 m), desfase de arranque, largo de cola (120°–320°) y velocidad (1.0–1.5 × la de la hoja), sacados de una tabla fija, sin azar: el vórtice se ve igual cada vez;
   - también en espiral hacia adentro en la cola;
   - así el área se llena de trazos a distintas alturas, como la referencia.
3. **Remolino en el piso:** una espiral plana a 5 cm del piso, del radio del golpe hacia el centro en 540°, alpha ≤ 0.3. Aparece con el golpe y se desvanece con la hoja: marca el área barrida.
4. **Chispas** (`CPUParticles3D`, `BoxMesh` alargado): salen del anillo del golpe al caer el daño, en dirección tangente al giro y un poco hacia afuera. Cantidad por nivel `[16, 28, 44]`.
5. **Polvo** (`CPUParticles3D`, `SphereMesh`, tierra registrado): se levanta del borde del anillo en el piso. Cantidad por nivel `[0, 14, 28]` (solo desde el nivel 2).
6. **Destello** (`OmniLight3D` blanca en el centro, a la altura del torso): se enciende al caer el daño y se apaga en 0.15 s. Energía por nivel `[1.0, 2.0, 3.0]`.

- **Color:** todo blanco `Color(1, 1, 1)`, unshaded, blend **aditivo**, alpha ≤ 0.5 por capa (≤ 0.3 el piso). Al superponerse, el centro del remolino se ve casi blanco sólido, como la referencia, sin pasar de 0.5 en ningún material. El polvo, tierra `Color(0.62, 0.52, 0.4)`, alpha ≤ 0.6.
- **Tiempos:** la hoja barre en 0.25 s y se desvanece en 0.25 s (hoy 0.2); todo se apaga ≤ 0.6 s después del arranque.
- **Rendimiento (Principio V):**
  - hoja, trazos y piso van en **una** `ImmediateMesh` (una superficie `PRIMITIVE_TRIANGLES` por cuadro), como hoy;
  - los parámetros de los trazos se calculan una vez en `_ready()` para el máximo de trazos, en `PackedFloat32Array`;
  - las partículas y la luz están prearmadas en la escena; `play()` solo ajusta `amount`, `emission_ring_radius` y `light_energy` y dispara `restart()`.
- Todos los números viven en `CircleSlashVfxConfig` (y en la tabla de trazos del mismo config), y los materiales en `.tres` compartidos.

## 3. Resources y datos

| Archivo | Cambio |
|---|---|
| `resources/parry_config.gd`, `parry_config.tres` | − `empowered_range_scale`, − `empowered_damage_multiplier`; + `empowered_range_steps: Array[float]` `[1.3, 1.3, 1.4]`, + `empowered_damage_steps: Array[float]` `[1.5, 1.5, 1.75]`; + `get_empowered_range_scale(level)` y `get_empowered_damage_multiplier(level)` (producto de los primeros `level` pasos, con el nivel limitado al tamaño del array) |
| `data/abilities/parry/unique/riposte.tres` | `max_level = 3`, `level_descriptions` (3) |
| `resources/circle_slash_vfx_config.gd`, `circle_slash_vfx_config.tres` | hoja: `band_width_by_level`, `inner_radius_ratio` (0.45), `tail_rise`; trazos: `streak_count_by_level`, rangos de radio, alto, ancho, cola y velocidad, `streak_alpha`; piso: `floor_turns_degrees` (540), `floor_alpha` (0.3), `floor_height`; `spark_amount_by_level`, `dust_amount_by_level`, `flash_energy_by_level`, `flash_duration`; `fade_duration` 0.25 |
| `materials/vfx/circle_slash_material.tres` | sin cambios (blanco, unshaded, aditivo, color por vértice) |
| `materials/vfx/circle_slash_spark_material.tres` | nuevo: blanco, unshaded, aditivo, alpha 0.5 |
| `materials/vfx/circle_slash_dust_material.tres` | nuevo: tierra, unshaded, alpha 0.6 |
| `components/abilities/parry_ability.tscn` | `SlashVfx` gana los hijos `Sparks`, `Dust` (`CPUParticles3D`) y `Flash` (`OmniLight3D`) |

## 4. Interfaz pública

```gdscript
# ParryConfig
## Product of the first `level` range steps (level clamped to 1..steps.size()).
func get_empowered_range_scale(level: int) -> float
func get_empowered_damage_multiplier(level: int) -> float

# ParryAbility
## Radius of the empowered riposte's 360° strike at the current "Contragolpe" level.
func get_empowered_radius(ability: AbilityComponent) -> float   # now uses the level

# CircleSlashVfx
func play(center: Node3D, radius: float, level: int) -> void     # + level
func burst() -> void              # sparks, dust and flash, at the hit
func get_streak_count() -> int    # streaks of the current play
func get_band_inner_radius(tail_ratio: float) -> float   # for the spiral test
```

## 5. Criterios de aceptación (AC1056–AC1070)

**Niveles**

- **AC1056** `riposte.tres` tiene `max_level` 3 y tres `level_descriptions`; el nivel 2 dice "+30 %" y "+50 %", y el nivel 3 "+40 %" y "+75 %". La carta se ofrece hasta el nivel 3 y no más (`is_unique_maxed`).
- **AC1057** `ParryConfig.get_empowered_range_scale(n)` vale 1.3, 1.69 y 2.366 (±0.001) para n = 1, 2 y 3, y `get_empowered_damage_multiplier(n)` 1.5, 2.25 y 3.9375. Con n mayor que los pasos, vale lo del último nivel.
- **AC1058** En cada nivel, un enemigo a `ATTACK_RANGE × escala − 0.05` (más su radio) recibe el golpe de 360° y uno a `+ 0.05` no.
- **AC1059** En cada nivel, el daño es `multiplicador(n) ×` el de un golpe del combo con los mismos stats (sin crítico), y sigue contando como ataque básico (`AttackComponent.enemy_hit`, no `AbilityComponent.enemy_hit`).
- **AC1060** En el nivel 3 no cambia el resto: el enfriamiento queda en 0, los enemigos se congelan 0.3 s, el jugador es invulnerable 0.9 s y, con Duelo, los alcanzados quedan Retados.

**Vórtice**

- **AC1061** Al arrancar el barrido, el VFX recibe el nivel y el radio del golpe de ese nivel; la cabeza de la hoja recorre 360° en 0.25 s (±1 cuadro) y todo el VFX (malla, partículas y luz) queda apagado ≤ 0.6 s después.
- **AC1062** Crece con el nivel: el ancho de la hoja es 0.8 / 1.0 / 1.2 m, los trazos 4 / 7 / 10, las chispas 16 / 28 / 44, el polvo 0 / 14 / 28 y la energía del destello 1 / 2 / 3, para los niveles 1 / 2 / 3.
- **AC1063** Es un remolino: el borde interior de la hoja en la cola está al 45 % (±2 %) del radio, y en la cabeza al radio menos el ancho; los trazos también terminan en la cola más cerca del centro que en la cabeza.
- **AC1064** Los trazos se ven igual en cada uso: dos `play()` con el mismo nivel dan los mismos radios, alturas y desfases; sus radios quedan entre el 35 % y el 105 % del radio del golpe, y sus alturas entre 0.2 y 1.6 m.
- **AC1065** Chispas, polvo y destello salen al caer el daño (`empowered_hit_time`), no antes, y las chispas y el polvo nacen en el anillo del radio del golpe.
- **AC1066** Materiales compartidos (`.tres`): la malla y las chispas en blanco, unshaded y aditivo, alpha ≤ 0.5 (el remolino del piso ≤ 0.3); el polvo en tierra `Color(0.62, 0.52, 0.4)`, alpha ≤ 0.6.
- **AC1067** Sin allocations por cuadro ni nodos nuevos en combate: `SlashVfx`, `Sparks`, `Dust` y `Flash` están en `parry_ability.tscn`, y los parámetros de los trazos se calculan una sola vez, para el máximo de trazos.

**Regresión**

- **AC1068** `parry_rework_test` (adaptado a los helpers por nivel), `parry_test`, `unique_upgrades_test`, `unique_upgrade_run_test` y `warrior_abilities_test` en verde, salvo los fallos previos registrados.
- **AC1069** Import y smoke test del arena sin errores ni warnings.
- **AC1070** Hoja de capturas del vórtice en los tres niveles, en el arena con Brutos alrededor, revisada por el responsable.

**Próximo libre después de esta spec: AC1071.**

## 6. Plan

Cada paso deja el proyecto andando.

1. **Reserva:** AC1056–AC1070 en `CLAUDE.md` (próximo libre AC1071).
2. **Niveles:** `ParryConfig` con los pasos y sus helpers; `ParryAbility` lee el nivel de Contragolpe (`get_unique_level(RIPOSTE)`); `riposte.tres` con 3 niveles. `parry_rework_test` adaptado. Tests de AC1056–AC1060 en `test/components/abilities/riposte_levels_test.gd`.
3. **Vórtice:** `CircleSlashVfxConfig` nuevo, `CircleSlashVfx` reescrito (hoja en espiral, trazos, piso, `burst()`), materiales y nodos en `parry_ability.tscn`. Tests de AC1061–AC1067.
4. **Capturas:** hoja del vórtice cuadro a cuadro en los niveles 1, 2 y 3 desde la cámara del juego. **Te la muestro** y ajusto los datos.
5. **Cierre:** suites de AC1068, import y smoke test, constitución 4.25.0, notas, `CLAUDE.md` (mapa: Parry) y estado **Implementada**.

## 7. Tests que cambian

- `parry_rework_test` AC1026/AC1027 usan `CONFIG.empowered_range_scale` y `CONFIG.empowered_damage_multiplier`: pasan a `get_empowered_range_scale(1)` y `get_empowered_damage_multiplier(1)`. Verifican lo mismo (nivel 1).
- `parry_rework_test` AC1030 (el VFX): si lee `band_width` u otros campos borrados, pasa a los nuevos del nivel 1; sigue verificando 360° en 0.25 s, radio, material y un solo nodo.

## 8. Constitución: enmienda MINOR 4.25.0

**Principio II, tabla de colores:** la fila del corte circular pasa a:

> Corte circular (VFX de la Estocada mejorada de Contragolpe): vórtice de cintas horizontales en espiral alrededor del Guerrero, remolino en el piso, chispas y destello | Cintas procedurales (`ImmediateMesh`), partículas `BoxMesh`, `OmniLight3D` breve | **Blanco**: `Color(1, 1, 1)`, unshaded, blend aditivo, alpha ≤ 0.5 (el remolino del piso ≤ 0.3); 0 en la cola

Y en los colores no reservados: el tierra `Color(0.62, 0.52, 0.4)` también colorea el polvo del vórtice (alpha ≤ 0.6).

## 9. Riesgos

- **Alcance en el nivel 3:** ×2.37 del `ATTACK_RANGE` es un radio grande; contra oleadas numerosas, sumado a la inmortalidad y al enfriamiento renovado, puede barrer media pantalla. Es un remate que exige leer un golpe, y los pasos son datos.
- **Daño ×3.94 contando como básico:** también carga las Aflicciones de ataque básico en todos los alcanzados. Es la recompensa buscada, pero se vigila en la sandbox.
- **Blanco aditivo denso:** muchas capas superpuestas pueden saturar a blanco y tapar a los enemigos o a sus avisos en el piso por ~0.5 s. Se revisa en la hoja de capturas; las alphas y las cantidades son datos.

## 10. Checklist de review de la constitución (se completa al cerrar)

- [ ] I. Pilar declarado (combate).
- [ ] II. VFX con `ImmediateMesh` y partículas prearmadas, materiales compartidos, blanco y tierra registrados (4.25.0).
- [ ] III. Pasos de nivel, cantidades por nivel, tiempos y alphas en `ParryConfig` y `CircleSlashVfxConfig`.
- [ ] IV. Tipado estático, identificadores en inglés.
- [ ] V. Sin allocations por cuadro (trazos precalculados, una `ImmediateMesh`).
- [ ] VI. Sin input nuevo.
- [ ] VII. Sin cambios en el tiempo congelado.
