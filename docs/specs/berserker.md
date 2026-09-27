# Feature: Clase Berserker (mandoble) + habilidad Giro

- **Estado:** Implementada (2026-09-25, 275 tests GdUnit4 en verde; `spin_test` pasó 3 corridas seguidas; smoke test headless del menú y de la arena sin errores ni warnings)
- **Constitución:** `docs/constitution.md` v2.5.0 (enmienda MINOR aprobada con esta spec: color reservado del mandoble)
  - *Revisión v3.0.0:* las mallas `BoxMesh` del arma y sus colores reservados fueron reemplazados por modelos importados (Falchion para el mandoble, Spartan sword para la espada). AC185 quedó reescrito en `weapon-models.md`.
- **Pilares (Principio I):**
  - **Combate:** un arma lenta y pesada, y una habilidad de área que se usa en movimiento y cambia cómo te posicionás.
  - **Progresión:** 2.ª clase con su propio pool de habilidades y mejoras, lo que abre builds distintas.
- **Dependencias:** `character-classes.md`, `ability-system.md`, `sword-sweep.md` (Implementadas).

## 1. Objetivo

- **Arma = dato fijo de la clase** (`WeaponData`). La espada sale de `player.tscn` a su propia escena, y cada clase instancia su arma bajo `Visual/SwordPivot` al arrancar. No existe un sistema para cambiar de arma.
- **Berserker:** usa un mandoble gris oscuro hecho con `BoxMesh`, que en reposo va apoyado en el hombro. Tiene más daño, algo más de vida y ataques más lentos. El ataque básico reutiliza el barrido procedural (`SwordSwing`) con la configuración propia del mandoble.
- **Giro (habilidad básica del Berserker):**
  - Dura `CAST_DURATION` (3 s) y da una vuelta completa cada `TICK_INTERVAL` (1 s).
  - Al completar cada vuelta golpea a todos los enemigos dentro del radio `HIT_RANGE` por `BASE_DAMAGE + ATTACK_SCALING × DAMAGE` (sin crítico, bonus ni robo de vida). Aplica un empuje leve hacia afuera.
  - Una vuelta que queda a medias al terminar el giro no golpea.
  - Mientras gira, el jugador se mueve a `move_speed_factor × MOVE_SPEED`. No ataca, no salta ni hace dash.
  - Mejoras: + duración, + velocidad de giro (menos `TICK_INTERVAL`, con piso), + daño base, + radio. No tiene mejoras únicas.

## 2. Datos (Principio III)

| Resource | Campos |
|---|---|
| `WeaponData` | `model: PackedScene`, `rest_position`, `rest_rotation`, `swing: SwordSwingConfig` |
| `CharacterClassData` | + `weapon: WeaponData` |
| `AbilityData` | + `Stat.TICK_INTERVAL`, `tick_interval`, `min_tick_interval` |
| `SpinConfig` | `move_speed_factor`, `knockback_speed`, `blade_position`, `blade_rotation` (no mejorables) |

| Archivo | Valores |
|---|---|
| `data/classes/warrior/sword.tres` | reposo `(0.45, 1.3, 0)` / `(0.9, 0, 0)` · swing `sword_swing_config.tres` |
| `data/classes/berserker/berserker_stats.tres` | igual a `player_stats.tres` salvo `damage 22` · `max_health 120` · `attack_speed 0.8` |
| `data/classes/berserker/greatsword.tres` | reposo sobre el hombro derecho · swing `greatsword_swing_config.tres` |
| `data/abilities/spin/spin.tres` | `base_damage 8` · `attack_scaling 0.15` · `cooldown 9 s` · `hit_range 2.5 m` · `cast_duration 3 s` · `tick_interval 1 s` · `min_tick_interval 0.5 s` (*0.4 s desde `spin-buff-wind-trail.md`*) |
| `data/abilities/spin/spin_config.tres` | `move_speed_factor 0.5` · `knockback_speed` menor que el de `PlayerTuning` |
| `data/abilities/spin/upgrades/*.tres` | +0.5 s de giro · −0.1 s por vuelta · +4 de daño base · +0.5 m de radio |
| `materials/greatsword_material.tres` | `Color(0.2, 0.2, 0.22)` |

## 3. Interfaz pública y cambios

- `Player._apply_character_class()` también instancia el arma (`_equip_weapon`) y llama a `SwordSwing.setup(weapon)`.
- `SwordSwing.setup(weapon)`: la pose de reposo y el `SwordSwingConfig` salen de los datos, ya no se capturan en `_ready`. `SwordSwing.recover()` vuelve al reposo con la transición existente.
- `AbilityBehavior.move_body(ability, delta, wish_direction)` / `AbilityComponent.move_body(delta, wish_direction)`: reciben la dirección de input.
- `AbilityComponent`: + exports `movement`, `sword_swing`. Piso de `TICK_INTERVAL`.
- `MovementComponent.move(direction, delta, speed_factor = 1.0)`.
- `HitboxMath.in_radius(origin, point, radius)`.
- `SpinAbility` (`components/abilities/spin_ability.gd/.tscn`).

**Agregados durante la implementación** (no cambian el comportamiento aprobado):
- `AbilityBehavior.channel(ability, step)`: `AbilityComponent` lo llama en cada paso del casteo. El Giro gira y golpea ahí (no en `move_body`), así los golpes dependen solo del tiempo del casteo y son deterministas. `move_body` queda solo para el desplazamiento.
- `SwordSwing.hold_pose(position, rotation)`: cancela el barrido y sostiene el arma en la pose del Giro.
- `Enemy.get_knockback_velocity()`: getter de solo lectura para verificar AC190.
- `SpinAbility.TIME_EPSILON` (0.0001): tolerancia de float al contar vueltas. Es una constante estructural, no de diseño.

## 4. Criterios de aceptación

- **AC184** `class_catalog.tres` ofrece Guerrero y Berserker. El Berserker tiene más `DAMAGE`, más `MAX_HEALTH` y menos `ATTACK_SPEED` que el Guerrero, y su pool es solo el Giro.
- **AC185** Cada clase instancia su arma bajo `SwordPivot`: el Guerrero la espada negra y el Berserker el mandoble. Todas sus mallas son `BoxMesh` con el material compartido de su color. Hay una sola arma por jugador.
- **AC186** Al arrancar, el pivot está en la pose de reposo de la clase. En el Berserker es la pose del hombro, distinta a la del Guerrero.
- **AC187** El ataque básico del Berserker barre el arco y vuelve a la pose del hombro. Su cadencia es `1 / 0.8` s. *(Adaptado en `humanoid-player-model.md`: los golpes del Berserker suenan a la mitad de velocidad.)*
- **AC188** Giro: con los valores base golpea 3 veces a un enemigo dentro de 2.5 m (en t ≈ 1, 2 y 3 s), cada golpe por `8 + 0.15 × DAMAGE`. Un enemigo a más de `2.5 m + padding` no recibe daño.
- **AC189** El `Visual` completa una vuelta por `TICK_INTERVAL`. Al terminar, el mandoble vuelve al reposo.
- **AC190** Los enemigos golpeados reciben un empuje que los aleja del jugador, con el `knockback_speed` del Giro.
- **AC191** Mientras gira, con input el jugador se desplaza a `MOVE_SPEED × 0.5` (±5 %). Sin input se queda quieto. No puede atacar ni hacer dash.
- **AC192** Mejoras: +0.5 s de duración → 3.5 s de giro (3 golpes). −0.1 s por vuelta ×3 → 0.7 s por vuelta y 4 golpes en 3 s. Nunca baja de `min_tick_interval`. + radio golpea a un enemigo a 2.8 m. + daño suma al daño base.
- **AC193** Con el Berserker, el pool de cartas tiene las mejoras del personaje y solo las del Giro. El sandbox muestra `TICK_INTERVAL` con su formato.
- **AC194** Guerrero sin cambios: sus stats, su espada, su pose de reposo, la Estocada y el Golpe Veloz se comportan igual.
- **AC195** Regresión: la suite completa sigue en verde.
  - *Nota:* los dos AC54 de `upgrade_offer_test.gd` asumían "una mejora de la Estocada por cada `AbilityData.Stat`". `TICK_INTERVAL` solo aplica a habilidades canalizadas, así que ahora excluyen ese stat y comparan contra las mejoras de la Estocada. Siguen verificando lo mismo.

### Review de la constitución (cierre)
- **I:** Combate y Progresión, como declara la spec.
- **II:** el mandoble son 4 `BoxMesh` con el material compartido `greatsword_material.tres`, en el gris oscuro reservado por la enmienda 2.5.0. La espada sigue negra y ahora vive en `sword.tscn` con `sword_material.tres`. No se agregó ningún asset externo.
- **III:** stats de clase, arma, pose de reposo, Giro, mejoras (con `max_stacks`) y `SpinConfig` viven en `.tres`. Ningún Resource se muta: la pose y el tiempo del Giro viven en los nodos.
- **IV:** tipado completo. `_ready`/`_physics_process` sin lógica nueva; la lógica está en métodos con nombre.
- **V:** hitbox lógico por distancia (`HitboxMath.in_radius`), `_hit_buffer` reutilizado y sin allocations por frame. El arma se instancia una sola vez al cargar.
- **VI:** sin inputs nuevos; el Giro usa la dirección del InputMap que ya lee `Player`.

## 5. Plan de implementación

1. Enmienda 2.5.0 y esta spec.
2. `WeaponData` + espada como escena; `SwordSwing.setup`/`recover`; `Player._equip_weapon`. Suite en verde (AC194).
3. Mandoble y Berserker (datos, escena, material).
4. Motor: `TICK_INTERVAL`, `speed_factor`, `move_body` con dirección, exports, `HitboxMath.in_radius`.
5. `SpinAbility`, `spin.tres` y sus mejoras.
6. Tests AC184–AC193, suite completa (AC195), smoke test, checklist, spec **Implementada**.

## 6. Fuera de alcance

- Indicador en el suelo del radio del Giro.
- Mejoras únicas del Giro.
- Animaciones exclusivas del ataque básico del mandoble.
- Balance fino de números (quedan en `.tres`).
