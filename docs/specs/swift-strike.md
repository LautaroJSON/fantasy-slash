# Feature: Habilidad Swift Strike

- **Estado:** Implementada (2026-09-25, 139 tests GdUnit4 en verde; los tests de física de Swift Strike pasaron 3 corridas seguidas; smoke test headless limpio)
- **Constitución:** `docs/constitution.md` v2.1.0 (sin enmiendas ni excepciones)
- **Pilares (Principio I):**
  - **Combate:** una herramienta de enganche que atraviesa grupos y recoloca al jugador.
  - **Progresión:** segunda opción en el menú inicial, con su propia línea de mejoras.
- **Dependencias:** `ability-system.md`, `thrust-indicator.md` (Implementadas).

## 1. Objetivo

- Habilidad básica (tecla E). **Esprinta hacia el enemigo más cercano** (o hacia donde mira el personaje si no hay enemigos) y **rebana una vez a cada enemigo que atraviesa**.
- Daño = `12 + 10 % × DAMAGE`, sin crítico, bonus ni robo de vida. Los enemigos cortados se empujan **de costado**.
- **Sin invulnerabilidad**: el dash sigue siendo la herramienta defensiva. Durante el sprint no se puede atacar, saltar ni hacer dash.
- Las paredes cortan el sprint.
- Muestra el mismo indicador en el suelo que la Estocada: el rectángulo del recorrido completo desde que se pulsa, y se desvanece al terminar.
- El menú inicial pasa a ofrecer 2 habilidades.

## 2. Datos (Principio III)

Se reutiliza `AbilityData.Stat`: `HIT_RANGE` = distancia del sprint, `HIT_WIDTH` = ancho del corte, `CAST_DURATION` = duración del sprint (velocidad = distancia / duración).

| Archivo | Valores |
|---|---|
| `data/abilities/swift_strike/swift_strike.tres` | `base_damage 12` · `attack_scaling 0.10` · `cooldown 6` s · `hit_range 6` m · `hit_width 1.2` m · `cast_duration 0.3` s · `min_cooldown 1.5` s · `min_cast_duration 0.12` s |
| `upgrades/*.tres` | +5 de daño base · +5 % de escalado · −0.5 s de enfriamiento · +1.5 m de recorrido · +0.4 m de ancho · −0.03 s de sprint |
| `swift_strike_indicator_config.tres` | los mismos valores que el de la Estocada |

## 3. Cambios en el motor de habilidades

- `AbilityBehavior`: suma `controls_motion()` y `move_body(ability, delta)`. Además se extraen a la base funciones compartidas con la Estocada: `face_nearest_enemy`, `play_cast_animation`, `play_animation`, `show_indicator` y `hit_damage`.
- `AbilityComponent`: suma el export `body`, `controls_motion()`, `move_body(delta)` y `get_cast_remaining()`.
- `Player._handle_movement`: mientras castea, si la habilidad controla el movimiento, delega en ella. Si no, el jugador se queda quieto (`hold`), como antes.
- `SwiftStrikeAbility.move_body`: el último paso se acorta para que el recorrido sea exacto, igual que `DashComponent`. Después de cada `move_and_slide`, barre el tramo recorrido con `HitboxMath.in_rectangle` y golpea a los enemigos nuevos.
- Animaciones `swift_strike` (corte horizontal durante el sprint) y `swift_strike_recover` en `player.tscn`.

## 4. Criterios de aceptación

- **AC75** El sprint recorre `HIT_RANGE` (±0.1 m) hacia el enemigo más cercano, o hacia donde mira el personaje si no hay enemigos, y después se queda quieto.
- **AC76** Los enemigos dentro del ancho a lo largo del recorrido reciben `12 + 0.10 × DAMAGE` **una sola vez**. Los que quedan fuera del ancho o más allá del recorrido no reciben daño.
- **AC77** Una pared corta el sprint.
- **AC78** Sin invulnerabilidad. Durante el sprint no hay ataques ni dash, y al terminar el ataque vuelve a funcionar.
- **AC79** +1.5 m de recorrido lleva el sprint y el indicador a 7.5 m. El indicador muestra el ancho efectivo.
- **AC80** El menú ofrece 2 habilidades. Elegir Swift Strike arma el pool solo con sus mejoras.
- **AC81** Regresión: la suite completa en verde.
  - *Nota:* en `ability_run_test.gd`, AC53 ahora espera 2 habilidades en el menú.

### Review de la constitución (cierre)
- **I:** Combate y Progresión, como declara la spec.
- **II:** solo animaciones de la espada negra y el indicador de `BoxMesh` con el material compartido.
- **III:** todos los valores viven en `.tres`. No hace falta un stat nuevo y ningún Resource se muta.
- **IV:** tipado completo. `Player._handle_movement` delega en `_move_while_casting`.
- **V:** hitbox lógico sin `Area3D`, con buffers (`_already_hit`, `_hit_buffer`) reutilizados y sin allocations por frame.
- **VI:** sin inputs nuevos.

## 5. Fuera de alcance

- Iframes, sangrado o reinicio del cooldown al matar.
- Rebalancear la Estocada.
